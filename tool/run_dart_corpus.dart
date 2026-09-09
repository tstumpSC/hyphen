// tool/run_dart_corpus.dart
//
// Task 13: drives the Dart port through the same corpus gen_goldens.dart
// drives the C reference through, emitting the identical record shape so
// compare.dart can diff the two JSONL files.
import 'dart:convert';
import 'dart:io';

import '../lib/src/dict_loader.dart';
import '../lib/src/engine.dart';
import '../lib/src/hyphen_dict.dart';

import 'lib/corpus.dart';
import 'lib/public_output.dart';

void main(List<String> args) {
  final limit = args.isEmpty ? null : int.parse(args.first);
  final out = File('goldens/dart.jsonl');
  out.parent.createSync(recursive: true);
  final sink = out.openWrite();

  var written = 0;

  for (final d in corpusDicts()) {
    final HyphenDict dict;
    try {
      dict = loadDictBytes(File(d.dictPath).readAsBytesSync());
    } catch (e) {
      stderr.writeln('skipping ${d.label}: $e');
      continue;
    }

    final words = [...wordsFor(d, limit: limit), ...fuzzWords()];

    for (final params in kParamSets) {
      for (final word in words) {
        sink.writeln(jsonEncode(_record(dict, d, params, word)));
        written++;
      }
    }
    stderr.writeln(
        '${d.label}: done ($written records written so far, cumulative across all dictionaries)');
  }

  sink.close();
  stderr.writeln('wrote $written records to ${out.path}');
}

Map<String, Object?> _record(
  HyphenDict dict,
  CorpusDict d,
  ParamSet params,
  String word,
) {
  final base = {'dict': d.label, 'params': params.label, 'word': word};
  try {
    final bytes = encodeWord(word, utf8Dict: dict.utf8);
    final wordLen = bytes.length;
    final hyphens = List<int>.filled(wordLen + 8, 0);
    final carrier = RepCarrier(wordLen == 0 ? 1 : wordLen);

    final rc = params.isV2
        ? hyphenate2(dict, bytes, wordLen, hyphens, null, carrier)
        : hyphenate3(dict, bytes, wordLen, hyphens, null, carrier,
            params.lhmin, params.rhmin, params.clhmin, params.crhmin);
    if (rc != 0) throw StateError('hyphenation failed with code $rc');

    final marks = hyphens.sublist(0, wordLen);
    return {
      ...base,
      'marks': marks,
      'out': applyMarks(word, marks),
      'legacy': applyMarksLegacy(word, marks, '='),
    };
  } catch (e) {
    return {...base, 'error': e.runtimeType.toString()};
  }
}
