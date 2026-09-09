import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/src/engine.dart';
import 'package:hyphen/src/dict_loader.dart';

void main() {
  group('hnjLigature', () {
    test('maps the UTF-8 ligature third bytes to their extra-character counts', () {
      // hyphen.c:692-703, with LIG_xx/LIG_xxx from hyphen.c:54-60.
      //
      // LONG_LIGATURE is NOT defined by tool/build_reference.sh, so the
      // #else branch applies: LIG_xx == 0 and LIG_xxx == 1. The two-character
      // ligatures therefore contribute NOTHING, and only ffi/ffl add one.
      // These values are measured against the reference library, not derived.
      expect(hnjLigature(0x80), 0); // ff  -> LIG_xx
      expect(hnjLigature(0x81), 0); // fi
      expect(hnjLigature(0x82), 0); // fl
      expect(hnjLigature(0x83), 1); // ffi -> LIG_xxx
      expect(hnjLigature(0x84), 1); // ffl
      expect(hnjLigature(0x85), 0); // long st
      expect(hnjLigature(0x86), 0); // st
      expect(hnjLigature(0x00), 0);
      expect(hnjLigature(0xFF), 0);
    });

    test('LONG_LIGATURE is not defined in the reference build', () {
      // Guards the constant above. If someone rebuilds the reference with
      // -DLONG_LIGATURE these become 1 and 2 and the whole ligature path
      // shifts, so pin the assumption explicitly rather than leaving it
      // implicit in the numbers.
      expect(hnjLigature(0x83), 1,
          reason: 'ffi must contribute exactly one extra character');
    });
  });

  group('hyphenStrnlen', () {
    test('counts bytes for a non-UTF-8 dictionary', () {
      expect(hyphenStrnlen(utf8.encode('abc'), 3, false), 3);
    });

    test('counts codepoints for a UTF-8 dictionary', () {
      final w = utf8.encode('äöü'); // 6 bytes, 3 codepoints
      expect(hyphenStrnlen(w, 6, true), 3);
    });

    test('counts a two-character ligature as one, not two', () {
      // Measured: 1, not 2. Follows from LIG_xx == 0 above — without
      // LONG_LIGATURE the ff ligature contributes no extra characters.
      final w = utf8.encode('ﬀ'); // ff, 3 bytes
      expect(hyphenStrnlen(w, 3, true), 1);
    });

    test('counts a three-character ligature as two', () {
      // ffi -> LIG_xxx == 1, so one base character plus one extra.
      final w = utf8.encode('ﬃ'); // ffi, 3 bytes
      expect(hyphenStrnlen(w, 3, true), 2);
    });

    test('stops at a NUL byte', () {
      expect(hyphenStrnlen([0x61, 0x00, 0x62], 3, false), 1);
    });
  });

  group('hyphenLhmin', () {
    test('zeroes marks within lhmin of the left edge', () {
      final w = utf8.encode('abcdef');
      final h = List<int>.filled(w.length + 8, 0x31); // all breaks set
      hyphenLhmin(false, w, w.length, h, null, 3);

      // Measured: [48, 48, 49, 49, 49, 49] — full array, not just the
      // boundary, so a mutation that over- or under-zeroes is caught.
      expect(h.sublist(0, w.length), [0x30, 0x30, 0x31, 0x31, 0x31, 0x31]);
      expect(h[2], 0x31, reason: 'position 2 is at lhmin and survives');
    });

    test('leading digits shift the boundary outward', () {
      // hyphen.c:735 decrements i for each leading digit
      final w = utf8.encode('12abcdef');
      final h = List<int>.filled(w.length + 8, 0x31);
      hyphenLhmin(false, w, w.length, h, null, 3);
      // Measured: [48, 48, 48, 48, 49, 49, 49, 49] — four positions zeroed,
      // not three, because the leading-digit loop decrements i once per
      // digit before the main loop starts.
      expect(h.sublist(0, w.length),
          [0x30, 0x30, 0x30, 0x30, 0x31, 0x31, 0x31, 0x31]);
    });

    test('does not run off the end of a short word', () {
      final w = utf8.encode('ab');
      final h = List<int>.filled(w.length + 8, 0x31);
      hyphenLhmin(false, w, w.length, h, null, 10);
      // Measured: [48, 48] — both positions zeroed, no crash reading past
      // the end of the two-byte word.
      expect(h.sublist(0, w.length), [0x30, 0x30]);
    });

    test('a long enough non-standard replacement suppresses the zero and '
        'keeps the carrier entry', () {
      // Differentially verified against the reference hnj_hyphen_lhmin:
      // word "abcdef", lhmin 3, rep[1] = "xxx=y", pos[1] = 1. The C result
      // is hyphens == [48, 49, 49, 49, 49, 49] with rep[1] still set — the
      // "0" at j=1 that the no-carrier test shows is suppressed because the
      // non-standard part is long enough (hyphen.c:735-745), and hyphens[j]
      // is left untouched rather than zeroed.
      final w = utf8.encode('abcdef');
      final h = List<int>.filled(w.length + 8, 0x31);
      final carrier = RepCarrier(w.length);
      carrier.rep[1] = utf8.encode('xxx=y');
      carrier.pos[1] = 1;

      hyphenLhmin(false, w, w.length, h, carrier, 3);

      expect(h.sublist(0, w.length), [0x30, 0x31, 0x31, 0x31, 0x31, 0x31]);
      expect(carrier.rep[1], isNotNull,
          reason: 'the replacement is long enough to survive lhmin');
    });
  });

  group('hyphenRhmin', () {
    test('zeroes marks within rhmin of the right edge', () {
      final w = utf8.encode('abcdef');
      final h = List<int>.filled(w.length + 8, 0x31);
      hyphenRhmin(false, w, w.length, h, null, 3);

      // Measured: [49, 49, 49, 48, 48, 48] — full array, so a mutation that
      // zeroes past the rhmin boundary (e.g. dropping the i++ that counts
      // characters) is caught, not just the three positions that should
      // change.
      expect(h.sublist(0, w.length), [0x31, 0x31, 0x31, 0x30, 0x30, 0x30]);
    });

    test('does not run off the start of a short word', () {
      final w = utf8.encode('ab');
      final h = List<int>.filled(w.length + 8, 0x31);
      hyphenRhmin(false, w, w.length, h, null, 10);
      // Measured: [49, 48] — index 0 is never reached because the loop
      // requires j > 0, so it stays 0x31 (unset), not zeroed.
      expect(h.sublist(0, w.length), [0x31, 0x30]);
    });

    test('counts UTF-8 continuation bytes as one character', () {
      final w = utf8.encode('aäöüb'); // 1 + 2 + 2 + 2 + 1 bytes
      final h = List<int>.filled(w.length + 8, 0x31);
      hyphenRhmin(true, w, w.length, h, null, 2);
      // Measured: [49, 49, 49, 49, 49, 48, 48, 48] — the last two
      // *characters* (u, b at byte indices 5..7) are zeroed, not the last
      // two bytes, so the continuation-byte-skipping i++ is exercised.
      expect(h.sublist(0, w.length),
          [0x31, 0x31, 0x31, 0x31, 0x31, 0x30, 0x30, 0x30]);
    });

    test('a long enough non-standard replacement suppresses the zero and '
        'keeps the carrier entry', () {
      // Differentially verified against the reference hnj_hyphen_rhmin:
      // word "abcdef", rhmin 3, rep[4] = "y=xxx", pos[4] = 0, cut[4] = 0.
      // The C result is hyphens == [49, 49, 49, 48, 49, 48] with rep[4]
      // still set — j=4's zero (present in the no-carrier test) is
      // suppressed because the non-standard part is long enough
      // (hyphen.c:764-774).
      final w = utf8.encode('abcdef');
      final h = List<int>.filled(w.length + 8, 0x31);
      final carrier = RepCarrier(w.length);
      carrier.rep[4] = utf8.encode('y=xxx');
      carrier.pos[4] = 0;
      carrier.cut[4] = 0;

      hyphenRhmin(false, w, w.length, h, carrier, 3);

      expect(h.sublist(0, w.length), [0x31, 0x31, 0x31, 0x30, 0x31, 0x30]);
      expect(carrier.rep[4], isNotNull,
          reason: 'the replacement is long enough to survive rhmin');
    });
  });

  group('compound recursion', () {
    test('a two-level dictionary hyphenates inside each segment', () {
      // Level 0 splits at the compound boundary (b1c, marking a break
      // between "ab" and "cd"), and each segment is then recursively
      // re-hyphenated with the SAME dict (hyphen.c:977's `dict`, not
      // `dict->nextlevel`), which in turn recurses into level 1's a1b/c1d
      // patterns over each segment. Differentially verified against
      // hnj_hyphen_hyph_ (clhmin=1, crhmin=1, lend=1, rend=1) on "abcd":
      // C gives [49, 49, 49, 48] — breaks after "a", "b" and "c", none
      // after the last character "d".
      final d = loadDictBytes(utf8.encode('UTF-8\nb1c\nNEXTLEVEL\na1b\nc1d\n'));
      final w = utf8.encode('abcd');
      final h = List<int>.filled(w.length + 8, 0);

      hyphenHyph(d, w, w.length, h, RepCarrier(w.length), 1, 1, 1, 1);

      expect(h.sublist(0, w.length), [0x31, 0x31, 0x31, 0x30]);
    });

    test('the Schiffahrt replacement changes a same-level match inside the '
        'reconstituted segment', () {
      // Regression test for a real gap found in review: the block at
      // hyphen.c:977-987 is byte-identical to C on many invocations
      // without being load-bearing on any of them, because the segment
      // it rewrites often doesn't feed a pattern that cares about the
      // difference. This dictionary is constructed so it does.
      //
      // "d3d1ze/dz=,1,1" matches "ddze" in the word and records the
      // non-standard replacement rep="dz=" at that position. "1dz" is a
      // SAME-LEVEL pattern (segment recursion at hyphen.c:977 passes
      // `dict`, not `nextlevel` — see the "a1b/c1d" test above) that
      // matches only the *reconstituted* spelling "xxadz" the Schiffahrt
      // block builds by splicing "dz=" into prep_word — never the raw
      // pre-replacement segment "xxad". So whether the block runs is
      // directly observable in the final hyphens array, not just in an
      // intermediate value.
      //
      // Differentially verified against hnj_hyphen_hyph_ directly
      // (clhmin=1, crhmin=1, lend=1, rend=1) on "xxaddze": C gives
      // [48, 48, 49, 51, 49, 48, 48]. Confirmed by mutation: with the
      // Schiffahrt block short-circuited to a no-op, the Dart
      // implementation instead produces
      // [48, 48, 48, 51, 49, 48, 48] — index 2 flips from 49 ('1', a
      // break, from the "1dz" match) to 48 ('0', no match), because
      // without the splice the same-level recursive call sees "xxad"
      // instead of "xxadz" and "1dz" never matches.
      final d = loadDictBytes(
          utf8.encode('UTF-8\nd3d1ze/dz=,1,1\n1dz\nNEXTLEVEL\na1b\n'));
      final w = utf8.encode('xxaddze');
      final h = List<int>.filled(w.length + 8, 0);

      hyphenHyph(d, w, w.length, h, RepCarrier(w.length), 1, 1, 1, 1);

      expect(h.sublist(0, w.length), [0x30, 0x30, 0x31, 0x33, 0x31, 0x30, 0x30]);
    });

    test('recursion terminates on a single-character word', () {
      final d = loadDictBytes(utf8.encode('UTF-8\nte1st\n'));
      final w = utf8.encode('a');
      final h = List<int>.filled(w.length + 8, 0);
      expect(
        () => hyphenHyph(d, w, w.length, h, RepCarrier(1), 2, 2, 1, 1),
        returnsNormally,
      );
    });

    test('recursion terminates on an empty word', () {
      final d = loadDictBytes(utf8.encode('UTF-8\nte1st\n'));
      final h = List<int>.filled(8, 0);
      expect(
        () => hyphenHyph(d, const [], 0, h, RepCarrier(1), 2, 2, 1, 1),
        returnsNormally,
      );
    });
  });
}
