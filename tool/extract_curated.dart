// tool/extract_curated.dart
//
// Selects a committed subset of the golden corpus for test/golden_test.dart.
// Stratified rather than random, restricted to the nine synthetic
// dictionaries under tool/corpus/synth/ — the only dictionaries this repo
// actually tracks in git.
//
// Fix round, 2026-09-08: the original version of this script (and the task
// brief it followed) restricted to the three "local_*" dictionaries under
// example/assets/, on the stated assumption that those three ship in the
// package. That assumption was never checked: example/.gitignore contains
// `/assets/`, so example/assets/*.dic is untracked. tool/goldens/c.jsonl
// (this script's own input) is gitignored too, and was generated on a
// machine where those untracked files happened to exist locally — so the
// committed golden file built from them silently depended on files a clean
// clone does not have. Every downstream consumer (test/golden_test.dart,
// plus three unrelated tests that separately read the same untracked
// files) passed here and would have failed on a clean checkout.
//
// tool/.gitignore deliberately un-ignores tool/corpus/synth/ (`corpus/*` +
// `!corpus/synth/`), so those nine hazard-focused synthetic dictionaries —
// authored for this project, not third-party licensed data — are the only
// dictionaries safe to build a committed test around. Re-verified before
// making that swap: they are the only dict labels for which
// `git ls-files` finds the underlying .dic tracked.
//
// Committing the three real dictionaries instead (~490 KB combined) was
// considered and rejected: measured directly against the corpus, all three
// declare zero NEXTLEVEL, zero non-standard (replacement) patterns, zero
// NOHYPHEN, and zero explicit hyphenmin settings, while the nine synth_*
// dictionaries between them cover all four (synth_nextlevel, synth_malformed
// /synth_hash_comment for non-standard-adjacent parsing hazards,
// synth_nohyphen, synth_hyphenmin). The synthetic set is not just smaller,
// it is strictly more hazard-dense than the real dictionaries would be.
//
// Strata, in priority order (unchanged in spirit from the first version;
// see its history for the parts>=4-without-a-cap mistake that blew the
// file out to 594 MB before these caps were added):
//   1. Every fuzz input (corpus.dart's fuzzWords()) that produced a record
//      for a tracked synth dictionary. Unconditional, no cap.
//   2. Every error record. Unconditional, no cap.
//   3. "Extreme" outputs: word split into >= 8 parts. Capped per
//      dict/param bucket at _extremeCapPerBucket.
//   4. "Interesting" outputs: word split into 4-7 parts. Capped per bucket
//      at _interestingCapPerBucket.
//   5. Ordinary outputs: 0-3 parts. Capped per bucket at
//      _ordinaryCapPerBucket, sampled in corpus (word) order.
//
// In practice, for these nine dictionaries strata 3-5 barely fire: none of
// them has a wordsPath (see corpus.dart's corpusDicts()), so the only
// inputs ever run against them are fuzzWords() — the corpus's
// dictionary/param records for every synth_* label are fuzz records by
// construction. The caps are kept anyway as a guard against that changing
// (e.g. if a future corpus run adds a wordsPath to one of them).
import 'dart:convert';
import 'dart:io';

import 'lib/corpus.dart';

const _shippedDicts = {
  'synth_empty',
  'synth_encoding_only',
  'synth_malformed',
  'synth_pattern_99',
  'synth_pattern_100',
  'synth_hyphenmin',
  'synth_nohyphen',
  'synth_nextlevel',
  'synth_hash_comment',
};

const _extremeCapPerBucket = 8; // parts >= 8
const _interestingCapPerBucket = 15; // 4 <= parts <= 7
const _ordinaryCapPerBucket = 50; // parts <= 3

void main() {
  final fuzz = fuzzWords().toSet();
  final selected = <Map<String, Object?>>[];
  final capPerBucket = <String, int>{};
  var scanned = 0;
  var matchedDict = 0;

  for (final line in File('goldens/c.jsonl').readAsLinesSync()) {
    if (line.isEmpty) continue;
    scanned++;
    final r = jsonDecode(line) as Map<String, Object?>;
    if (!_shippedDicts.contains(r['dict'])) continue;
    matchedDict++;

    final word = r['word'] as String;
    final isFuzz = fuzz.contains(word);
    final isError = r.containsKey('error');

    if (isFuzz || isError) {
      selected.add(r);
      continue;
    }

    final parts = (r['out'] as List?)?.length ?? 0;
    final String tier;
    final int cap;
    if (parts >= 8) {
      tier = 'extreme';
      cap = _extremeCapPerBucket;
    } else if (parts >= 4) {
      tier = 'interesting';
      cap = _interestingCapPerBucket;
    } else {
      tier = 'ordinary';
      cap = _ordinaryCapPerBucket;
    }

    final key = '${r['dict']}/${r['params']}/$tier';
    final n = capPerBucket[key] ?? 0;
    if (n < cap) {
      capPerBucket[key] = n + 1;
      selected.add(r);
    }
  }

  final out = File('../test/golden/curated.json');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(selected)}\n',
  );
  stderr.writeln(
    'scanned $scanned lines, $matchedDict for tracked synth dicts, '
    'wrote ${selected.length} cases to ${out.path}',
  );
}
