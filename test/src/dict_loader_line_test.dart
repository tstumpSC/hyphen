import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/src/dict_loader.dart';
import 'package:hyphen/src/hyphen_dict.dart';

/// Returns the dictionary AND the hashtab it was built with. Both are
/// needed: a test that wants a specific state's fields must look its number
/// up in the REAL hashtab. Building a fresh map and asking `getState` about
/// it would return that map's own seeded value and assert nothing about the
/// code under test.
class _Loaded {
  _Loaded(this.dict, this.hashtab);
  final HyphenDict dict;
  final Map<String, int> hashtab;

  /// The state installed for [word], by name.
  HyphenState stateFor(String word) {
    final n = hashtab[word];
    expect(n, isNotNull, reason: 'no state was allocated for "$word"');
    return dict.states[n!];
  }
}

_Loaded _load(List<String> lines, {bool utf8Dict = true}) {
  final dict = HyphenDict()..utf8 = utf8Dict;
  final hashtab = <String, int>{'': 0};
  for (final l in lines) {
    loadLine(utf8.encode('$l\n'), dict, hashtab);
  }
  return _Loaded(dict, hashtab);
}

void main() {
  group('settings keywords', () {
    test('LEFTHYPHENMIN and RIGHTHYPHENMIN are parsed', () {
      final d = _load(['LEFTHYPHENMIN 4', 'RIGHTHYPHENMIN 5']).dict;
      expect(d.lhmin, 4);
      expect(d.rhmin, 5);
    });

    test('COMPOUNDLEFTHYPHENMIN and COMPOUNDRIGHTHYPHENMIN are parsed', () {
      final d = _load(['COMPOUNDLEFTHYPHENMIN 2', 'COMPOUNDRIGHTHYPHENMIN 7']).dict;
      expect(d.clhmin, 2);
      expect(d.crhmin, 7);
    });

    test('a settings line allocates no state', () {
      expect(_load(['LEFTHYPHENMIN 4']).dict.states.length, 1);
    });

    test('NOHYPHEN splits on commas, stripping only the newline', () {
      // C zeroes the last byte unconditionally (hyphen.c:277-278). Because
      // the line is newline-terminated that strips the NEWLINE, not a real
      // character — so 'xy' survives intact. Measured against the reference
      // library: entries are ["'", "-", "xy"] with nohyphenl == 2.
      final d = _load(["NOHYPHEN ',-,xy"]).dict;
      expect(d.nohyphen.map(utf8.decode), ["'", '-', 'xy']);
    });

    test('NOHYPHEN with a single entry yields one entry', () {
      // Measured: ['abc'], nohyphenl == 0.
      expect(_load(['NOHYPHEN abc']).dict.nohyphen.map(utf8.decode), ['abc']);
    });
  });

  group('plain patterns', () {
    test('te1st builds the match vector with leading zeroes trimmed', () {
      // Looked up in the REAL hashtab. Passing a fabricated map to getState
      // would return that map's own value and prove nothing.
      final s = _load(['te1st']).stateFor('test');
      expect(utf8.decode(s.match!), '100');
      expect(s.repl, isNull);
    });

    test('prefix transitions are chained from the root', () {
      final d = _load(['te1st']).dict;
      // root -> t -> e -> s -> t, one transition per level
      expect(d.states[0].trans.length, 1);
      expect(d.states[0].trans.first.ch, 0x74); // 't'
    });

    test('a pattern with no digits still allocates a state', () {
      final d = _load(['abc']).dict;
      expect(d.states.length, greaterThan(1));
    });
  });

  group('non-standard patterns', () {
    test('the Hungarian as5szon2y/sz=,2,1 form parses', () {
      final d = _load(['as5szon2y/sz=,2,1']).dict;
      final s = d.states.firstWhere((s) => s.repl != null);
      expect(utf8.decode(s.repl!), 'sz=');
      expect(s.replindex, 1); // atoi("2") - 1
      expect(s.replcut, 1);
    });

    test('the German f1f/ff=f,1,2 form parses', () {
      final d = _load(['f1f/ff=f,1,2']).dict;
      final s = d.states.firstWhere((s) => s.repl != null);
      expect(utf8.decode(s.repl!), 'ff=f');
      expect(s.replindex, 0); // atoi("1") - 1
      expect(s.replcut, 2);
    });

    test('a replacement with no indices defaults replcut to the pattern length', () {
      // hyphen.c:302-306: replindex 0, replcut = strlen(buf) after the line
      // has been truncated at '/'. For 'a1b/xy' that leaves 'a1b', so
      // replcut is 3. Measured against the reference library.
      final d = _load(['a1b/xy']).dict;
      final s = d.states.firstWhere((s) => s.repl != null);
      expect(utf8.decode(s.repl!), 'xy');
      expect(s.replindex, 0);
      expect(s.replcut, 3);
      expect(utf8.decode(s.match!), '010');
    });

    test('a replacement with indices and an = in the text parses', () {
      // Measured: repl 'xy=z', replindex 0, replcut 2, match '010'.
      final d = _load(['a1b/xy=z,1,2']).dict;
      final s = d.states.firstWhere((s) => s.repl != null);
      expect(utf8.decode(s.repl!), 'xy=z');
      expect(s.replindex, 0);
      expect(s.replcut, 2);
    });

    test('one comma with no second comma leaves replcut to the fallback', () {
      // hyphen.c:291-308: with one comma and no second one, C's
      // replindex/replcut assignments (inside `if (index2)`, 297-301) never
      // run, so both stay 0 and the `replcut == 0 ? word.length : replcut`
      // fallback at 356-360 supplies strlen(word) == strlen("ab") == 2.
      final d = _load(['a1b/xy,5']).dict;
      final s = d.states.firstWhere((s) => s.repl != null);
      expect(utf8.decode(s.repl!), 'xy');
      expect(s.replindex, 0);
      expect(s.replcut, 2);
    });
  });

  test('a comment line is not the parser concern and still allocates a state', () {
    // load_line never sees '%' lines; the file loader filters them. This
    // documents that the parser itself does not special-case them.
    final d = _load(['%abc']).dict;
    expect(d.states.length, greaterThan(1));
  });
}
