import 'dart:convert';
import 'dart:io';

import 'lib/corpus.dart';
import 'lib/reference_bindings.dart';
import 'lib/public_output.dart';

const _dylib = 'libhyphen_ffi.dylib';

void main(List<String> args) {
  final limit = args.isEmpty ? null : int.parse(args.first);
  final out = File('goldens/c.jsonl');
  out.parent.createSync(recursive: true);
  final sink = out.openWrite();

  final ref = ReferenceHyphen(_dylib);
  var written = 0;

  for (final d in corpusDicts()) {
    final ReferenceDict dict;
    try {
      dict = ref.load(d.dictPath);
    } catch (e) {
      stderr.writeln('skipping ${d.label}: $e');
      continue;
    }

    final words = [...wordsFor(d, limit: limit), ...fuzzWords()];

    for (final params in kParamSets) {
      for (final word in words) {
        sink.writeln(jsonEncode(
          _record(dict, d, params, word),
        ));
        written++;
      }
    }
    dict.free();
    stderr.writeln('${d.label}: done ($written records written so far, cumulative across all dictionaries)');
  }

  sink.close();
  stderr.writeln('wrote $written records to ${out.path}');
}

Map<String, Object?> _record(
  ReferenceDict dict,
  CorpusDict d,
  ParamSet params,
  String word,
) {
  final base = {'dict': d.label, 'params': params.label, 'word': word};
  try {
    final bytes = encodeWord(word, utf8Dict: dict.isUtf8);
    final marks = params.isV2
        ? dict.hyphenate2(bytes)
        : dict.hyphenate3(
            bytes, params.lhmin, params.rhmin, params.clhmin, params.crhmin);
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
