import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/src/dict_loader.dart';
import 'package:hyphen/src/engine.dart';

/// Loads only level 0 — the real patterns — so the compound recursion in
/// Task 10 is not exercised here.
List<int> _marks(String dictBody, String word) {
  final full = loadDictBytes(utf8.encode(dictBody));
  final level0 = full.nextlevel!..nextlevel = null;
  final bytes = utf8.encode(word);
  final hyphens = List<int>.filled(bytes.length + 8, 0);
  hyphenHyph(level0, bytes, bytes.length, hyphens, null, 0, 0, 1, 1);
  return hyphens.sublist(0, bytes.length);
}

void main() {
  test('byteAt returns 0 past the end of the buffer', () {
    expect(byteAt([1, 2, 3], 0), 1);
    expect(byteAt([1, 2, 3], 2), 3);
    expect(byteAt([1, 2, 3], 3), 0);
    expect(byteAt([1, 2, 3], 99), 0);
    expect(byteAt([1, 2, 3], -1), 0);
  });

  test('a single pattern marks the expected position', () {
    // te1st -> break after "te" in "test"
    expect(_marks('UTF-8\nte1st\n', 'test'), [0x30, 0x31, 0x30, 0x30]);
  });

  test('a higher digit wins over a lower one at the same position', () {
    // hyphen.c:900-903 keeps the maximum
    final m = _marks('UTF-8\na1b\na3b\n', 'ab');
    expect(m[0], 0x33, reason: '3 must beat 1');
  });

  test('a pattern anchored with a dot only matches at the word start', () {
    expect(_marks('UTF-8\n.a1b\n', 'ab')[0], 0x31);
    expect(_marks('UTF-8\n.a1b\n', 'xab')[1], 0x30);
  });

  test('digits in the input are rewritten to dots before matching', () {
    // hyphen.c:814-818 — a digit becomes '.', so a dot-anchored pattern fires
    expect(_marks('UTF-8\n.a1b\n', '5ab')[1], 0x31);
  });

  test('an empty word produces no marks and does not throw', () {
    expect(_marks('UTF-8\nte1st\n', ''), isEmpty);
  });

  test('a word with no matching pattern is all zeroes', () {
    expect(_marks('UTF-8\nte1st\n', 'xyz'), [0x30, 0x30, 0x30]);
  });

  test('overlapping patterns all contribute', () {
    final m = _marks('UTF-8\na1b\nb1c\n', 'abc');
    expect(m[0], 0x31);
    expect(m[1], 0x31);
  });

  test(
      'a higher digit written first is not overwritten by a lower digit '
      'from a later-matching overlapping pattern', () {
    // hyphen.c:900-903 — two DIFFERENT patterns (abc/3, bcd/1) both write to
    // the boundary after "c". "abc" reaches its match state before "bcd"
    // does (it needs one fewer letter), so the 3 is written first and the
    // later 1 must not downgrade it. Unlike the two tests above, this one
    // fails if the max-check is deleted entirely (verified by mutation:
    // replacing `hyphens[offset + k] < match[k]` with `true` leaves the
    // other tests green but flips this one's mark at index 2 from 0x33 to
    // 0x31).
    final m = _marks('UTF-8\nabc3\nbc1d\n', 'abcd');
    expect(m, [0x30, 0x30, 0x33, 0x30]);
  });

  test(
      'the goto try_next_letter reset skips the match check — a match '
      'on the root state itself is never applied', () {
    // hyphen.c:842-847. A lone-digit pattern line ("5", no letters) has an
    // empty word key, so its digit installs onto the root state's own
    // match field. The root's match can only be reached via the
    // `state == -1` reset path (root has fallback -1 by construction, and
    // no trie transition ever targets state 0), so it is a direct probe of
    // the skipMatch/goto translation: `goto try_next_letter` must skip the
    // match check entirely, not fall into it with the freshly-reset state.
    // Verified by mutation: deleting `if (skipMatch) continue;` leaves
    // every other test in this file green but plants a stray '5' at index
    // 0 here (confirmed byte-for-byte against the C reference library,
    // which also produces no '5': C=[48,48,49,48,48,48] for this exact
    // dictionary and word).
    final m = _marks('UTF-8\n5\nte1st\n', 'xtestx');
    expect(m, [0x30, 0x30, 0x31, 0x30, 0x30, 0x30]);
  });

  test(
      'a non-standard-hyphenation pattern populates the RepCarrier '
      '(matchindex/matchlen/matchrepl bookkeeping)', () {
    // hyphen.c:935-962. `d3d1ze/dz=,1,1` is the real pattern from
    // hu.dic:14598, splitting a doubled "ddz" digraph. Measured against
    // the C reference library directly (not just reasoned out): for word
    // "addze", C fills rep[1]="dz=", pos[1]=1, cut[1]=1, and every other
    // slot is untouched (null / 0). This is the only test in this file
    // that passes a non-null carrier — none of the brief's own tests do,
    // so without this the isrepl/matchindex/matchrepl bookkeeping has no
    // committed coverage at all.
    final full = loadDictBytes(utf8.encode('UTF-8\nd3d1ze/dz=,1,1\n'));
    final level0 = full.nextlevel!..nextlevel = null;
    final bytes = utf8.encode('addze');
    final hyphens = List<int>.filled(bytes.length + 8, 0);
    final carrier = RepCarrier(bytes.length);

    hyphenHyph(level0, bytes, bytes.length, hyphens, carrier, 0, 0, 1, 1);

    expect(hyphens.sublist(0, bytes.length), [0x30, 0x33, 0x31, 0x30, 0x30]);
    expect(carrier.rep, [null, 'dz='.codeUnits, null, null, null]);
    expect(carrier.pos, [0, 1, 0, 0, 0]);
    expect(carrier.cut, [0, 1, 0, 0, 0]);
  });

  test(
      'a match ending exactly on the last letter (no trailing dot) is '
      'discarded by the left-shift, not folded into the last position', () {
    // hyphen.c:924-933 — the shift/truncation loop runs to `j - 3`
    // (== word_size - 1), then explicitly zeroes index word_size - 1; it
    // must NOT also shift in hyphens[word_size] (the mark written while
    // scanning the word's last letter, prepWord index word_size). "ab1"
    // (no dot anchor) on "xab" writes a nonzero mark exactly there.
    // Verified by mutation: widening the shift bound from `j - 3` to
    // `j - 2` leaves every other test in this file green (all of them
    // happen to have a zero at that exact source position) but flips this
    // one's last mark from 0x30 to 0x31 — confirmed against the C
    // reference library, which also discards it (C=[48,48,48]).
    expect(_marks('UTF-8\nab1\n', 'xab'), [0x30, 0x30, 0x30]);
  });

  test(
      'a matchindex of 0 does not underflow the RepCarrier arrays '
      '(spec hazard 11)', () {
    // hyphen.c:944-956 writes (*rep)[matchindex[i]-1], (*pos)[...] and
    // (*cut)[...] UNCONDITIONALLY — it never checks matchindex[i]-1 >= 0.
    // ".1xy/z=,1,1" on word "xy" produces matchindex[0] == 0 at runtime, so
    // C performs a one-element heap underflow write just before the
    // calloc'd rep/pos/cut arrays (undefined behaviour). engine.dart's
    // `mi - 1 >= 0` guard is the forced deviation that keeps Dart from
    // throwing RangeError there instead. Measured against the C reference
    // library directly: marks=[48,48], and rep/pos/cut are all
    // null/0/0 — the underflowed write is never observable through the
    // caller-visible arrays. If the guard is later "simplified" away, this
    // test must fail loudly (a thrown RangeError) rather than the
    // divergence going unnoticed.
    final full = loadDictBytes(utf8.encode('UTF-8\n.1xy/z=,1,1\n'));
    final level0 = full.nextlevel!..nextlevel = null;
    final bytes = utf8.encode('xy');
    final hyphens = List<int>.filled(bytes.length + 8, 0);
    final carrier = RepCarrier(bytes.length);

    hyphenHyph(level0, bytes, bytes.length, hyphens, carrier, 0, 0, 1, 1);

    expect(hyphens.sublist(0, bytes.length), [0x30, 0x30]);
    expect(carrier.rep, [null, null]);
    expect(carrier.pos, [0, 0]);
    expect(carrier.cut, [0, 0]);
  });
}
