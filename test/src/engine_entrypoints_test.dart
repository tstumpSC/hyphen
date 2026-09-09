import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/src/dict_loader.dart';
import 'package:hyphen/src/engine.dart';

void main() {
  test('hyphenate2 on an en_US excerpt reproduces the README marks', () {
    // Originally read the shipped dictionary file directly. An earlier
    // draft before that routed this through a fabricated `_enUsBytes()`
    // stub that returned an empty list in both branches of a const ternary
    // — it would have loaded an EMPTY dictionary and asserted the en_US
    // mark vector against it, which cannot pass and asserts nothing about
    // the code under test.
    //
    // Fix round, 2026-09-08: example/assets/hyph_en_US.dic is not tracked
    // (example/.gitignore has `/assets/`), so reading it here failed on a
    // clean clone. Replaced with the minimal excerpt of the real file's own
    // patterns that reproduces the exact same marks for this word: every
    // pattern from the real dictionary whose letters (patterns' digits
    // stripped) occur as a substring of ".hyphenation." — the only patterns
    // that can possibly match this word under the standard TeX hyphenation
    // algorithm. Verified against the real (local, untracked) file before
    // this change: this 15-pattern excerpt produces byte-for-byte identical
    // marks to the full ~5,500-pattern dictionary for this specific word.
    const excerpt = [
      'a1t2io',
      'atio2n',
      'e1na',
      'he2n',
      'he1na4',
      'hen5at',
      'hy3ph',
      '2io',
      'io2n',
      '1na',
      'n2at',
      'o2n',
      'phe2n',
      '1t2io',
      'tio2n',
    ];
    final d = loadDictBytes(utf8.encode('UTF-8\n${excerpt.join('\n')}\n'));
    final w = utf8.encode('hyphenation');
    final h = List<int>.filled(w.length + 8, 0);

    expect(hyphenate2(d, w, w.length, h, null, RepCarrier(w.length)), 0);
    expect(h.sublist(0, w.length),
        [48, 51, 48, 48, 50, 53, 52, 50, 48, 48, 48]);
  });

  test('hyphenNorm rejects a word starting with a continuation byte', () {
    // hyphen.c:1053-1056
    final h = List<int>.filled(8, 0x30);
    expect(hyphenNorm([0x80, 0x61], 2, h, null), 1);
  });

  test('hyphenNorm compacts byte positions to codepoint positions', () {
    final w = utf8.encode('äb'); // 3 bytes, 2 codepoints
    final h = [0x30, 0x31, 0x32, 0, 0, 0, 0, 0];
    expect(hyphenNorm(w, 3, h, null), 0);
    // marks for byte 1 (second byte of ä) collapse onto codepoint 0
    expect(h[0], 0x31);
    expect(h[1], 0x32);
  });

  // Hazard 1 needs a dictionary with an EXPLICIT NEXTLEVEL. Without one the
  // loader returns the synthesised level 1 and the file's own NOHYPHEN never
  // takes effect, so the suppression pass does nothing and neither of these
  // tests would mean anything. Measured against the reference library.
  const nohyphenDict =
      'UTF-8\nNOHYPHEN bc\na1b\nb1c\nc1d\nNEXTLEVEL\na1b\nb1c\nc1d\n';

  test('hyphenate2 suppresses nohyphen positions with ASCII zero', () {
    // hazard 1: hyphenate2 writes '0' (48). Measured C result: [48,49,48,48].
    final d = loadDictBytes(utf8.encode(nohyphenDict));
    final w = utf8.encode('abcd');
    final h = List<int>.filled(w.length + 8, 0);

    hyphenate2(d, w, w.length, h, null, RepCarrier(w.length));

    expect(h.sublist(0, w.length), [48, 49, 48, 48]);
    expect(h.sublist(0, w.length), isNot(contains(0)),
        reason: 'hyphenate2 must write ASCII 48, never NUL');
  });

  test('hyphenate3 suppresses nohyphen positions with NUL', () {
    // hazard 1: hyphenate3 writes 0 (NUL) at the same positions.
    // Measured C result: [0,49,0,48] — positions 0 and 2 are NUL, not 48.
    final d = loadDictBytes(utf8.encode(nohyphenDict));
    final w = utf8.encode('abcd');
    final h = List<int>.filled(w.length + 8, 0);

    hyphenate3(d, w, w.length, h, null, RepCarrier(w.length), 0, 0, 0, 0);

    expect(h.sublist(0, w.length), [0, 49, 0, 48]);
  });

  test('hyphenate3 raises hyphenmins to the dictionary floor', () {
    // hyphen.c:1173-1176 takes the maximum of caller and dictionary
    final d = loadDictBytes(
        utf8.encode('UTF-8\nLEFTHYPHENMIN 5\na1b\nb1c\nc1d\nd1e\ne1f\n'));
    final w = utf8.encode('abcdef');
    final h = List<int>.filled(w.length + 8, 0);

    hyphenate3(d, w, w.length, h, null, RepCarrier(w.length), 1, 1, 1, 1);

    expect((h[0] & 1), 0, reason: 'lhmin 5 from the dict must win over 1');
    expect((h[1] & 1), 0);
  });

  test('an empty word returns 0 and produces no marks', () {
    final d = loadDictBytes(utf8.encode('UTF-8\nte1st\n'));
    final h = List<int>.filled(8, 0);
    expect(hyphenate2(d, const [], 0, h, null, RepCarrier(1)), 0);
  });

  test('hyphword renders standard breaks with =', () {
    final w = utf8.encode('abcd');
    final h = [0x30, 0x31, 0x30, 0x30];
    final out = List<int>.filled(2 * w.length, 0);
    hyphenHyphword(w, w.length, h, out, null);
    expect(utf8.decode(out.takeWhile((c) => c != 0).toList()), 'ab=cd');
  });

  // Not in the brief. Added to close a real gap: none of the brief's tests
  // pass a non-null hyphword to hyphenate3 together with a NOHYPHEN dict, so
  // none of them can observe hazard 2 (hyphword built BEFORE nohyphen in
  // hyphenate3 -- hyphen.c:1197 runs before hyphen.c:1200-1210). Measured
  // against the reference library directly via FFI (hnj_hyphen_hyph_ +
  // hnj_hyphen_lhmin + hnj_hyphen_rhmin give pre-nohyphen marks
  // [48,49,49,49,48,48]; hnj_hyphen_hyphenate3 gives post-nohyphen marks
  // [48,0,49,0,48,48] and hyphword "ab=c=d=ef" -- three '=' signs, matching
  // the THREE breaks present before nohyphen suppressed two of them, not
  // the single break that survives after). If hyphword were built after
  // nohyphen, this word would render "abc=def" instead.
  test('hyphenate3 builds hyphword from marks BEFORE nohyphen suppression',
      () {
    final d = loadDictBytes(utf8.encode(
        'UTF-8\nNOHYPHEN cd\na1b\nb1c\nc1d\nd1e\ne1f\nNEXTLEVEL\na1b\nb1c\nc1d\nd1e\ne1f\n'));
    final w = utf8.encode('abcdef');
    final h = List<int>.filled(w.length + 8, 0);
    final hw = List<int>.filled(2 * w.length + 8, 0);

    final ret = hyphenate3(
        d, w, w.length, h, hw, RepCarrier(w.length), 0, 0, 0, 0);

    expect(ret, 0);
    expect(h.sublist(0, w.length), [48, 0, 49, 0, 48, 48]);
    expect(utf8.decode(hw.takeWhile((c) => c != 0).toList()), 'ab=c=d=ef');
  });

  // Not in the brief. hyphen_ffi.c passes NULL for hyphword in both entry
  // points, so this branch of hyphenHyphword is unreachable through the
  // shipped wrapper and the earlier differential run (45,534 comparisons)
  // never touched it. The rendered string "asz=szony" is the linguistically
  // correct Hungarian hyphenation of "asszony" -- one this package's public
  // API can never produce, because the wrapper discards rep/pos/cut. This
  // test exists because nothing on the shipped path can reach this branch
  // to be differential-tested; it has to be pinned directly.
  //
  // Fix round, 2026-09-08: originally loaded the full real Hungarian
  // dictionary from tool/corpus/dicts/hu.dic (987 KB), which
  // tool/.gitignore does NOT track (`corpus/*` un-ignores only
  // `corpus/synth/`), so this failed on a clean clone. Replaced with the
  // single pattern that actually produces the replacement — the real
  // dictionary's `as5szon2y/sz=,2,1` line, isolated. With only this one
  // pattern loaded, the edge marks (positions 0 and 2) come out lower than
  // they did against the full ~1 MB pattern set, because those two
  // positions were previously also touched by unrelated, generic patterns
  // elsewhere in the file; the oddness that drives every hyphenation
  // decision, and the replacement itself, are unaffected -- confirmed by
  // running both dictionaries side by side before making this change. The
  // marks below are this single-pattern dictionary's exact, self-contained
  // output, not a claim about the real dictionary's.
  test('hyphword renders a NON-STANDARD replacement', () {
    final d = loadDictBytes(utf8.encode('UTF-8\nas5szon2y/sz=,2,1\n'));
    final w = utf8.encode('asszony');
    final h = List<int>.filled(w.length + 8, 0);
    final carrier = RepCarrier(w.length);
    hyphenHyph(d, w, w.length, h, carrier, 1, 1, 1, 1);
    expect(h.sublist(0, w.length), [48, 53, 48, 48, 48, 50, 48]);

    final out = List<int>.filled(2 * w.length + 8, 0);
    hyphenHyphword(w, w.length, h, out, carrier);
    expect(utf8.decode(out.takeWhile((c) => c != 0).toList()), 'asz=szony');
  });
}
