import 'dart:convert';
import 'dart:io';
import 'dart:math';

class ParamSet {
  const ParamSet.v2()
      : isV2 = true, lhmin = 0, rhmin = 0, clhmin = 0, crhmin = 0;
  const ParamSet.v3(this.lhmin, this.rhmin, this.clhmin, this.crhmin)
      : isV2 = false;

  final bool isV2;
  final int lhmin, rhmin, clhmin, crhmin;

  String get label => isV2 ? 'v2' : 'v3($lhmin,$rhmin,$clhmin,$crhmin)';
}

const kParamSets = <ParamSet>[
  ParamSet.v2(),
  ParamSet.v3(2, 3, 2, 3),
  ParamSet.v3(0, 0, 0, 0),
  ParamSet.v3(1, 1, 1, 1),
  ParamSet.v3(5, 5, 5, 5),
  ParamSet.v3(3, 2, 3, 2),
];

class CorpusDict {
  const CorpusDict({
    required this.label,
    required this.dictPath,
    this.wordsPath,
    this.wordsAreLatin1 = false,
  });

  final String label;
  final String dictPath;
  final String? wordsPath;
  final bool wordsAreLatin1;
}

/// German is the one ISO8859-1 word list (from its `.aff` SET line); the
/// local de dictionaries reuse it, so they inherit the flag.
List<CorpusDict> corpusDicts() => [
      const CorpusDict(
        label: 'local_de_DE',
        dictPath: '../example/assets/hyph_de_DE.dic',
        wordsPath: 'corpus/words/de.dic',
        wordsAreLatin1: true,
      ),
      const CorpusDict(
        label: 'local_de_DE_UTF',
        dictPath: '../example/assets/hyph_de_DE_UTF.dic',
        wordsPath: 'corpus/words/de.dic',
        wordsAreLatin1: true,
      ),
      const CorpusDict(
        label: 'local_en_US',
        dictPath: '../example/assets/hyph_en_US.dic',
        wordsPath: 'corpus/words/en.dic',
      ),
      for (final l in ['de', 'en', 'hu', 'nl', 'sv', 'ca'])
        CorpusDict(
          label: l,
          dictPath: 'corpus/dicts/$l.dic',
          wordsPath: 'corpus/words/$l.dic',
          wordsAreLatin1: l == 'de',
        ),
      for (final s in _synthNames)
        CorpusDict(label: 'synth_$s', dictPath: 'corpus/synth/$s.dic'),
    ];

const _synthNames = [
  'empty',
  'encoding_only',
  'malformed',
  'pattern_99',
  'pattern_100',
  'hyphenmin',
  'nohyphen',
  'nextlevel',
  'hash_comment', // hazard 9
];

/// Reads a hunspell spelling dictionary: a count on line 1, then one
/// `word/FLAGS` entry per line. Everything from `/` onward is an affix flag
/// set, not part of the word.
List<String> wordsFor(CorpusDict d, {int? limit}) {
  final path = d.wordsPath;
  if (path == null) return const [];

  final bytes = File(path).readAsBytesSync();
  final text = d.wordsAreLatin1 ? latin1.decode(bytes) : utf8.decode(bytes);

  final words = <String>[];
  var first = true;
  for (final raw in const LineSplitter().convert(text)) {
    if (first) {
      first = false;
      continue; // entry count
    }
    if (raw.isEmpty || raw.startsWith('#') || raw.startsWith('\t')) continue;
    final slash = raw.indexOf('/');
    final word = (slash >= 0 ? raw.substring(0, slash) : raw).trim();
    if (word.isEmpty) continue;
    words.add(word);
    if (limit != null && words.length >= limit) break;
  }

  words.addAll(_generatedCompounds(words));
  return words;
}

/// Targeted stress on the compound-boundary code. Natural compounds in these
/// lists are plentiful but cluster at typical lengths; these land boundaries
/// at offsets the naturals happen not to reach. Seeded so runs are
/// reproducible.
List<String> _generatedCompounds(List<String> roots) {
  if (roots.length < 3) return const [];
  final rnd = Random(20260907);
  final out = <String>[];
  for (var i = 0; i < 2000; i++) {
    final a = roots[rnd.nextInt(roots.length)];
    final b = roots[rnd.nextInt(roots.length)];
    out.add('$a$b');
    if (i.isEven) out.add('$a$b${roots[rnd.nextInt(roots.length)]}');
  }
  return out;
}

List<String> fuzzWords() => [
      '',
      'a',
      'ab',
      'abc',
      '1',
      '123',
      'a1b2c3',
      '123456789',
      '-',
      '--',
      "'",
      '.',
      '...',
      '-abc',
      'abc-',
      '-abc-',
      "d'abc",
      'abc.def',
      '#',                     // hazard 9: live pattern char in de, not a comment
      'a#b',
      'ABC',
      'AbCdEfGhIj',
      'STRASSE',
      'a' * 99,
      'a' * 100,
      'a' * 101,
      'a' * 250,
      'ab' * 60,
      'é',                    // decomposed acute, hazard 4
      'café',
      'á́́b',
      'é',                     // precomposed, for contrast
      'ﬀ',                     // ff ligature
      'ﬁ',                     // fi
      'ﬂ',                     // fl
      'ﬃ',                     // ffi
      'ﬄ',                     // ffl
      'ﬅ',                     // long st
      'ﬆ',                     // st
      'aﬀb',
      'schaﬀen',
      '–',                     // en dash
      '’',                     // right single quote
      'abc–def',
      'abc’s',
      '\u{1F600}',                  // non-BMP
      'a\u{1F600}b',
      '\u{10400}\u{10401}',
      '\x00',              // embedded NUL: strnlen stops here,
      'a\x00b',             // word_size does not
      '\n',
      'a\nb',
      ' ',
      'a b',
      ' abc ',
      '\t',
      'Äquipotentialfläche',
      'Donaudampfschifffahrtsgesellschaft',
      'asszony',
      'dzsungel',
    ];
