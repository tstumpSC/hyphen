import 'dart:convert';
import 'dart:io';

/// Usage: dart run compare.dart <a.jsonl> <b.jsonl> [--stage-a] [--max=N] [--dict=LABEL]
///
/// `--dict=LABEL` restricts both files to records whose `dict` field equals
/// LABEL. At full corpus scale (~9.26M records per side) loading both files
/// unfiltered holds ~18.5M records in memory simultaneously — a likely OOM.
/// Task 13 loops this tool over dictionary labels rather than comparing
/// everything at once; the unfiltered default is kept for small/ad-hoc runs.
const _usage =
    'usage: compare.dart <a.jsonl> <b.jsonl> [--stage-a] [--max=N] [--dict=LABEL]';

void main(List<String> args) {
  final files = <String>[];
  var stageA = false;
  var maxReport = 25;
  String? dictFilter;

  for (final arg in args) {
    if (!arg.startsWith('--')) {
      files.add(arg);
    } else if (arg == '--stage-a') {
      stageA = true;
    } else if (arg.startsWith('--max=')) {
      final n = int.tryParse(arg.substring('--max='.length));
      if (n == null) {
        stderr.writeln(_usage);
        stderr.writeln('bad --max value: $arg');
        exit(64);
      }
      maxReport = n;
    } else if (arg.startsWith('--dict=')) {
      dictFilter = arg.substring('--dict='.length);
    } else {
      // Any other --flag (e.g. a typo like --stageA or --stage_a) is a
      // usage error, not a silently-ignored no-op: the determinism check's
      // whole point is Stage A taking effect, so a swallowed typo would
      // report a false-clean mismatched: 0 on exactly the property it
      // exists to catch.
      stderr.writeln(_usage);
      stderr.writeln('unrecognized flag: $arg');
      exit(64);
    }
  }
  if (files.length != 2) {
    stderr.writeln(_usage);
    exit(64);
  }

  final a = _load(files[0], dictFilter: dictFilter);
  final b = _load(files[1], dictFilter: dictFilter);

  var compared = 0, mismatched = 0, reported = 0;
  final byDict = <String, int>{};

  for (final key in a.keys) {
    final ra = a[key]!;
    final rb = b[key];
    if (rb == null) {
      stderr.writeln('MISSING in ${files[1]}: $key');
      mismatched++;
      byDict[ra['dict'] as String] = (byDict[ra['dict'] as String] ?? 0) + 1;
      continue;
    }
    compared++;

    final fields = stageA
        ? const ['marks', 'out', 'legacy', 'error']
        : const ['out', 'legacy', 'error'];
    final differs = fields.any((f) => jsonEncode(ra[f]) != jsonEncode(rb[f]));
    if (!differs) continue;

    mismatched++;
    byDict[ra['dict'] as String] = (byDict[ra['dict'] as String] ?? 0) + 1;
    if (reported++ < maxReport) {
      stdout.writeln('--- $key');
      for (final f in fields) {
        if (jsonEncode(ra[f]) != jsonEncode(rb[f])) {
          stdout.writeln('    $f: ${jsonEncode(ra[f])}  !=  ${jsonEncode(rb[f])}');
        }
      }
    }
  }

  // The reverse direction: a record present in b but absent from a is just
  // as much a gate failure as the reverse. Both sides share corpus.dart, so
  // the keysets normally coincide — but gen_goldens.dart (and its Task-13
  // Dart-side counterpart) silently skip a dictionary that fails to load,
  // which can make one side's corpus a strict superset of the other's
  // without either run reporting an error.
  for (final key in b.keys) {
    if (a.containsKey(key)) continue;
    final rb = b[key]!;
    stderr.writeln('MISSING in ${files[0]}: $key');
    mismatched++;
    byDict[rb['dict'] as String] = (byDict[rb['dict'] as String] ?? 0) + 1;
  }

  stdout.writeln('');
  stdout.writeln('stage:      ${stageA ? "A (marks + public output)" : "B (public output)"}');
  stdout.writeln('compared:   $compared');
  stdout.writeln('mismatched: $mismatched');
  if (byDict.isNotEmpty) {
    stdout.writeln('by dictionary:');
    final sorted = byDict.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    for (final e in sorted) {
      stdout.writeln('  ${e.key.padRight(20)} ${e.value}');
    }
  }
  exit(mismatched == 0 ? 0 : 1);
}

/// Keys each record by (dict, params, word), encoded as a JSON array rather
/// than a delimiter-joined string: fuzz words include arbitrary bytes
/// (spaces, NULs, control characters), so no plain separator is provably
/// collision-free, but JSON array encoding escapes each field unambiguously.
///
/// NOTE: the task brief's source for this function was truncated at
/// `out['${r['dict']}` (verified against the raw brief file, not a
/// rendering artifact) — this key construction is a reconstruction, not a
/// verbatim transcription.
///
/// [dictFilter], when given, skips every record whose `dict` field doesn't
/// match — bounding memory to one dictionary's worth of records instead of
/// the full corpus (see the module doc comment for why that matters).
Map<String, Map<String, Object?>> _load(String path, {String? dictFilter}) {
  final out = <String, Map<String, Object?>>{};
  var duplicates = 0;
  for (final line in File(path).readAsLinesSync()) {
    if (line.isEmpty) continue;
    final r = jsonDecode(line) as Map<String, Object?>;
    if (dictFilter != null && r['dict'] != dictFilter) continue;
    final key = jsonEncode([r['dict'], r['params'], r['word']]);
    if (out.containsKey(key)) duplicates++;
    out[key] = r;
  }
  if (duplicates > 0) {
    // Harmless — both sides dedupe identically, since a duplicate
    // (dict, params, word) triple always produces the same output — but
    // silent otherwise, and a shrinking `compared` count with no
    // explanation reads as lost records to anyone running this standalone.
    stderr.writeln(
        'note: $path: $duplicates duplicate (dict,params,word) records collapsed (last write wins)');
  }
  return out;
}
