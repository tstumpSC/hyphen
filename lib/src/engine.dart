// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Derived from the Hunspell/Hyphen library (https://github.com/hunspell/hyphen),
// offered by its authors under a GPL 2.0 / LGPL 2.1 / MPL 1.1 tri-license.
// This port is distributed under the MPL branch of that grant, at version 2.0.
// See THIRD_PARTY_LICENSES.md.
// lib/src/engine.dart
//
// Dart port of the hyphenation engine from Hunspell/Hyphen's hyphen.c.
//
// Faithful transliteration: index arithmetic, buffer sizes and quirks match
// the C so the two can be diffed by eye. Comments marking a reproduced C
// quirk are deliberate -- changing that behaviour changes output. Line
// numbers refer to upstream hyphen.c.

import 'hyphen_dict.dart';

const int _kZero = 0x30; // '0'
const int _kNine = 0x39; // '9'
const int _kDot = 0x2E;

/// C reads past the end of the word buffer in several places — notably the
/// ligature probe in hnj_hyphen_lhmin (hyphen.c:727,750), which lands in
/// non-zeroed heap. Undefined behaviour there; defined as 0 here.
int byteAt(List<int> b, int i) => (i < 0 || i >= b.length) ? 0 : b[i];

/// C threads `char ***rep, int **pos, int **cut` through every function.
/// Bundled here; a null carrier means the caller passed NULL for all three.
class RepCarrier {
  RepCarrier(int wordSize)
      : rep = List<List<int>?>.filled(wordSize, null),
        pos = List<int>.filled(wordSize, 0),
        cut = List<int>.filled(wordSize, 0);

  List<List<int>?> rep;
  List<int> pos;
  List<int> cut;
}

/// hnj_hyphen_hyph_, hyphen.c:785-1046.
///
/// Mutates [hyphens] in place. [hyphens] must have room for at least
/// `wordSize + 3` bytes, matching the C allocation.
void hyphenHyph(
  HyphenDict dict,
  List<int> word,
  int wordSize,
  List<int> hyphens,
  RepCarrier? carrier,
  int clhmin,
  int crhmin,
  int lend,
  int rend,
) {
  final prepWordSize = wordSize + 3;
  final prepWord = List<int>.filled(prepWordSize, 0);
  final matchlen = List<int>.filled(wordSize + 3, 0);
  final matchindex = List<int>.filled(wordSize + 3, -1);
  final matchrepl = List<List<int>?>.filled(wordSize + 3, null);
  var isrepl = 0;

  // Build ".word." with digits rewritten to dots, hyphen.c:810-825.
  var j = 0;
  prepWord[j++] = _kDot;
  for (var i = 0; i < wordSize; i++) {
    if (word[i] <= _kNine && word[i] >= _kZero) {
      prepWord[j++] = _kDot;
    } else {
      prepWord[j++] = word[i];
    }
  }
  prepWord[j++] = _kDot;

  for (var i = 0; i < j; i++) {
    hyphens[i] = _kZero;
  }

  // Run the state machine, hyphen.c:833-914.
  //
  // C uses two labels here. `goto found_state` leaves the transition search
  // and FALLS INTO the match check; `goto try_next_letter` skips the match
  // check entirely and is reached only from the `state == -1` reset. The
  // skipMatch flag encodes that difference.
  var state = 0;
  for (var i = 0; i < j; i++) {
    final ch = prepWord[i];
    var skipMatch = false;

    for (;;) {
      if (state == -1) {
        state = 0;
        skipMatch = true; // C: goto try_next_letter
        break;
      }
      final hstate = dict.states[state];
      var moved = false;
      for (var k = 0; k < hstate.trans.length; k++) {
        if (hstate.trans[k].ch == ch) {
          state = hstate.trans[k].newState;
          moved = true;
          break; // C: goto found_state
        }
      }
      if (moved) break;
      state = hstate.fallbackState;
    }
    if (skipMatch) continue;

    final match = dict.states[state].match;
    final repl = dict.states[state].repl;
    final replindex = dict.states[state].replindex;
    final replcut = dict.states[state].replcut;

    if (match != null) {
      final offset = i + 1 - match.length;
      if (repl != null) {
        if (isrepl == 0) {
          for (; isrepl < wordSize; isrepl++) {
            matchrepl[isrepl] = null;
            matchindex[isrepl] = -1;
          }
        }
        matchlen[offset + replindex] = replcut;
      }
      for (var k = 0; k < match.length; k++) {
        if (hyphens[offset + k] < match[k]) {
          hyphens[offset + k] = match[k];
          if (match[k] & 1 != 0) {
            matchrepl[offset + k] = repl;
            if (repl != null && k >= replindex && k <= replindex + replcut) {
              matchindex[offset + replindex] = offset + k;
            }
          }
        }
      }
    }
  }

  // Shift left by one and zero the tail, hyphen.c:924-934.
  var i = 0;
  for (; i < j - 3; i++) {
    hyphens[i] = hyphens[i + 1];
  }
  for (; i < wordSize; i++) {
    hyphens[i] = _kZero;
  }
  if (wordSize < hyphens.length) hyphens[wordSize] = 0;

  // Populate rep/pos/cut from the recorded matches, hyphen.c:935-962.
  if (isrepl != 0 && carrier != null) {
    for (var i2 = 0; i2 < wordSize; i2++) {
      final mi = matchindex[i2];
      if (mi >= 0 && matchrepl[mi] != null) {
        // C writes (*rep)[matchindex[i]-1] etc. at
        // hyphen.c:944-956 UNCONDITIONALLY — it never checks that
        // matchindex[i]-1 is >= 0. It can be -1 (measured: dictionary line
        // ".1xy/z=,1,1" on word "xy" produces matchindex[0] == 0 at
        // runtime), which makes C perform a one-element heap underflow
        // write before the calloc'd rep/pos/cut arrays. That is undefined
        // behaviour in C, so there is no literal translation to be
        // faithful to; a literal port would make Dart throw RangeError
        // where C silently corrupts memory. This guard is the forced,
        // deliberate deviation: skip the write when the index would be
        // negative. Measured against the reference library for the case
        // above and neighbouring shapes: the underflow lands outside the
        // region any caller reads, so skipping it changes nothing
        // observable — but that is a property of this allocator's memory
        // layout, not a guarantee. Do not "simplify" this guard away.
        if (mi - 1 >= 0 && mi - 1 < carrier.rep.length) {
          carrier.rep[mi - 1] = matchrepl[mi];
          carrier.pos[mi - 1] = mi - i2;
          carrier.cut[mi - 1] = matchlen[i2];
        }
        i2 += matchlen[i2] - 1;
      }
    }
  }

  // Recursive hyphenation of compound-level segments, hyphen.c:965-1044.
  final next = dict.nextlevel;
  if (next != null) {
    final carrier2 = RepCarrier(wordSize == 0 ? 1 : wordSize);
    final hyphens2 = List<int>.filled(wordSize + 3, 0);
    var begin = 0;

    for (var i3 = 0; i3 < wordSize; i3++) {
      if ((hyphens[i3] & 1) != 0 || (begin > 0 && i3 + 1 == wordSize)) {
        if (i3 - begin > 0) {
          var hyph = 0;
          final savedPrep = prepWord[i3 + 2];
          prepWord[i3 + 2] = 0;

          // Non-standard hyphenation at a compound boundary (Schiffahrt),
          // hyphen.c:977-987.
          if (carrier != null && carrier.rep[i3] != null) {
            final r = carrier.rep[i3]!;
            final l = _indexOfByte(r, 0, 0x3D);
            final offset = 2 + i3 - carrier.pos[i3];
            for (var t = 0;
                t < r.length && offset + t < prepWordSize - 1;
                t++) {
              prepWord[offset + t] = r[t];
            }
            if (l >= 0) {
              hyph = l - carrier.pos[i3];
              if (2 + i3 + hyph < prepWordSize) prepWord[2 + i3 + hyph] = 0;
            }
          }

          hyphenHyph(
            dict,
            prepWord.sublist(begin + 1),
            i3 - begin + 1 + hyph,
            hyphens2,
            carrier2,
            clhmin,
            crhmin,
            begin > 0 ? 0 : lend,
            (hyphens[i3] & 1) != 0 ? 0 : rend,
          );

          for (var j2 = 0; j2 < i3 - begin; j2++) {
            hyphens[begin + j2] = hyphens2[j2];
            if (carrier2.rep[j2] != null && carrier != null) {
              carrier.rep[begin + j2] = carrier2.rep[j2];
              carrier.pos[begin + j2] = carrier2.pos[j2];
              carrier.cut[begin + j2] = carrier2.cut[j2];
            }
          }

          prepWord[i3 + 2] = byteAt(word, i3 + 1);
          if (carrier != null && carrier.rep[i3] != null) {
            for (var t = 0; t < wordSize && 1 + t < prepWordSize - 1; t++) {
              prepWord[1 + t] = word[t];
            }
          }
          // This restore has no counterpart at hyphen.c:965-1044 and is
          // provably inert (confirmed in review): `prepWord[i3 + 2] == 0`
          // above is only true when `byteAt(word, i3 + 1)` returns 0
          // through the out-of-bounds guard in byteAt, which by
          // construction happens only when `i3 + 1 == wordSize` — i.e. on
          // the loop's final relevant iteration. After that iteration
          // `prepWord` is never read again: the `begin == 0` branch below
          // recurses on the raw `word`, not `prepWord`. Left in place as a
          // no-op rather than removed, to stay a literal port of the
          // brief; do not read significance into it.
          if (savedPrep != 0 && prepWord[i3 + 2] == 0) {
            prepWord[i3 + 2] = savedPrep;
          }
        }
        begin = i3 + 1;
        for (var j2 = 0; j2 < carrier2.rep.length; j2++) {
          carrier2.rep[j2] = null;
        }
      }
    }

    // Non-compound: recurse into the next level over the whole word,
    // hyphen.c:1030-1038.
    if (begin == 0) {
      hyphenHyph(next, word, wordSize, hyphens, carrier, clhmin, crhmin,
          lend, rend);
      if (lend == 0) {
        hyphenLhmin(dict.utf8, word, wordSize, hyphens, carrier, clhmin);
      }
      if (rend == 0) {
        hyphenRhmin(dict.utf8, word, wordSize, hyphens, carrier, crhmin);
      }
    }
  }
}

const int _kLigXx = 0;
const int _kLigXxx = 1;

/// hnj_ligature, hyphen.c:692-703. [c] is the third byte of a
/// U+FB00..U+FB06 sequence.
///
/// LIG_xx/LIG_xxx come from hyphen.c:54-60. The reference build does not
/// define LONG_LIGATURE, so LIG_xx == 0 and LIG_xxx == 1 (measured against
/// the reference library — see task-10-brief.md's measured-values table).
int hnjLigature(int c) {
  switch (c) {
    case 0x80: // ff
    case 0x81: // fi
    case 0x82: // fl
      return _kLigXx;
    case 0x83: // ffi
    case 0x84: // ffl
      return _kLigXxx;
    case 0x85: // long st
    case 0x86: // st
      return _kLigXx;
  }
  return 0;
}

/// hnj_hyphen_strnlen, hyphen.c:706-719. Character length of the first [n]
/// bytes.
int hyphenStrnlen(List<int> word, int n, bool utf8) {
  var i = 0;
  var j = 0;
  while (j < n && byteAt(word, j) != 0) {
    i++;
    if (utf8 && byteAt(word, j) == 0xEF && byteAt(word, j + 1) == 0xAC) {
      i += hnjLigature(byteAt(word, j + 2));
    }
    for (j++; utf8 && (byteAt(word, j) & 0xc0) == 0x80; j++) {}
  }
  return i;
}

int _indexOfByte(List<int> b, int from, int needle) {
  for (var i = from; i < b.length; i++) {
    if (b[i] == needle) return i;
  }
  return -1;
}

/// hnj_hyphen_lhmin, hyphen.c:721-756.
void hyphenLhmin(
  bool utf8,
  List<int> word,
  int wordSize,
  List<int> hyphens,
  RepCarrier? carrier,
  int lhmin,
) {
  var i = 1;

  if (utf8 && byteAt(word, 0) == 0xEF && byteAt(word, 1) == 0xAC) {
    i += hnjLigature(byteAt(word, 2));
  }

  // Ignore leading numbers, hyphen.c:735.
  for (var j = 0;
      byteAt(word, j) <= _kNine && byteAt(word, j) >= _kZero;
      j++) {
    i--;
  }

  var j = 0;
  while (i < lhmin && byteAt(word, j) != 0) {
    do {
      final rep = carrier?.rep;
      if (rep != null && j < rep.length && rep[j] != null) {
        final r = rep[j]!;
        final rh = _indexOfByte(r, 0, 0x3D /* '=' */);
        if (rh >= 0 &&
            (hyphenStrnlen(word, j - carrier!.pos[j] + 1, utf8) +
                    hyphenStrnlen(r, rh, utf8)) <
                lhmin) {
          carrier.rep[j] = null;
          hyphens[j] = _kZero;
        }
      } else {
        hyphens[j] = _kZero;
      }
      j++;

      if (utf8 && byteAt(word, j) == 0xEF && byteAt(word, j + 1) == 0xAC) {
        i += hnjLigature(byteAt(word, j + 2));
      }
    } while (utf8 && (byteAt(word, j) & 0xc0) == 0x80);
    i++;
  }
}

/// hnj_hyphen_rhmin, hyphen.c:757-783.
void hyphenRhmin(
  bool utf8,
  List<int> word,
  int wordSize,
  List<int> hyphens,
  RepCarrier? carrier,
  int rhmin,
) {
  var i = 0;

  // Ignore trailing numbers, hyphen.c:764.
  for (var j = wordSize - 1;
      j > 0 && byteAt(word, j) <= _kNine && byteAt(word, j) >= _kZero;
      j--) {
    i--;
  }

  for (var j = wordSize - 1; i < rhmin && j > 0; j--) {
    final rep = carrier?.rep;
    if (rep != null && j < rep.length && rep[j] != null) {
      final r = rep[j]!;
      final rh = _indexOfByte(r, 0, 0x3D);
      if (rh >= 0 &&
          (hyphenStrnlen(
                    word.sublist(
                        (j - carrier!.pos[j] + carrier.cut[j] + 1)
                            .clamp(0, word.length)),
                    100,
                    utf8,
                  ) +
                  hyphenStrnlen(r.sublist(rh + 1), r.length - rh - 1, utf8)) <
              rhmin) {
        carrier.rep[j] = null;
        hyphens[j] = _kZero;
      }
    } else {
      hyphens[j] = _kZero;
    }
    final b = byteAt(word, j);
    if (!utf8 || (b & 0xc0) == 0xc0 || (b & 0x80) != 0x80) i++;
  }
}

/// hnj_hyphen_norm, hyphen.c:1049-1088. Compacts [hyphens] from byte
/// positions to codepoint positions IN PLACE. Returns 1 on bad UTF-8 input.
int hyphenNorm(
  List<int> word,
  int wordSize,
  List<int> hyphens,
  RepCarrier? carrier,
) {
  if ((byteAt(word, 0) >> 6) == 2) return 1;

  var j = -1;
  for (var i = 0; i < wordSize; i++) {
    if ((word[i] >> 6) != 2) j++;
    hyphens[j] = hyphens[i];

    if (carrier != null && i < carrier.pos.length) {
      var l = carrier.pos[i];
      carrier.pos[j] = 0;
      for (var k = 0; k < l; k++) {
        if ((byteAt(word, i - k) >> 6) != 2) carrier.pos[j]++;
      }
      var k = i - l + 1;
      l = k + carrier.cut[i];
      carrier.cut[j] = 0;
      for (; k < l; k++) {
        if ((byteAt(word, k) >> 6) != 2) carrier.cut[j]++;
      }
      carrier.rep[j] = carrier.rep[i];
      if (j < i) {
        carrier.rep[i] = null;
        carrier.pos[i] = 0;
        carrier.cut[i] = 0;
      }
    }
  }
  if (j + 1 < hyphens.length) hyphens[j + 1] = 0;
  return 0;
}

/// hnj_hyphen_hyphword, hyphen.c:1091-1128.
void hyphenHyphword(
  List<int> word,
  int wordSize,
  List<int> hyphens,
  List<int> hyphword,
  RepCarrier? carrier,
) {
  if (wordSize <= 0) {
    if (hyphword.isNotEmpty) hyphword[0] = 0;
    return;
  }
  final hyphwordSize = 2 * wordSize - 1;
  final nonstandard = carrier != null;

  var j = 0;
  for (var i = 0; i < wordSize && j < hyphwordSize; i++) {
    hyphword[j++] = word[i];
    if ((hyphens[i] & 1) != 0 && j < hyphwordSize) {
      if (nonstandard &&
          i < carrier.rep.length &&
          carrier.rep[i] != null &&
          j >= carrier.pos[i]) {
        j -= carrier.pos[i];
        for (final b in carrier.rep[i]!) {
          if (j >= hyphwordSize) break;
          hyphword[j++] = b;
        }
        i += carrier.cut[i] - carrier.pos[i];
      } else {
        hyphword[j++] = 0x3D; // '='
      }
    }
  }
  if (j < hyphword.length) hyphword[j] = 0;
}

/// Applies the dictionary's NOHYPHEN list. [suppressByte] is 0x30 for
/// hyphenate2 and 0 for hyphenate3 — the C really does differ here
/// (hyphen.c:1150-1151 vs 1191-1192).
///
/// The scan is bounded by [wordSize], not `word.length`. C's
/// `strstr(word, nh)` is implicitly bounded by the NUL the caller places at
/// `word[word_size]`; without an explicit limit here, a caller-supplied
/// `word` buffer longer than the actual word (e.g. padded with trailing
/// bytes) could let a NOHYPHEN pattern match across the real content and
/// the padding — something C's NUL-terminated scan can never do. Measured:
/// dict `UTF-8\nNOHYPHEN cde\na1b\nb1c\nc1d\nd1e\ne1f\nNEXTLEVEL\n...`, word
/// `abcd` with wordSize 4 in an exact-length buffer gives `[48,49,48,48]`;
/// the same word padded to a longer buffer but still wordSize 4 gives
/// `[48,48,48,48]` if the scan is left unbounded — the break at position 1
/// is wrongly lost to a "cde" match straddling the padding.
///
/// [nh.isEmpty] entries are skipped as a forced deviation, not a stylistic
/// choice, made for the same reason as the matchindex guard above: C's
/// `strstr(word, "")`
/// always matches at every position, so `while (nhy)` never receives NULL
/// and the loop walks `hyphens[nhy - word - 1]` past the terminator
/// indefinitely -- an unbounded write, not a defined behaviour to port
/// faithfully. A literal translation throws RangeError at `hyphens[-1]`
/// immediately. Reachable: a NOHYPHEN line with two consecutive commas
/// (e.g. `NOHYPHEN a,,b`) produces an empty entry via `_splitNohyphen`.
void _applyNohyphen(
  HyphenDict dict,
  List<int> word,
  int wordSize,
  List<int> hyphens,
  int suppressByte,
) {
  for (final nh in dict.nohyphen) {
    if (nh.isEmpty) continue;
    var from = 0;
    while (true) {
      final at = _findSequence(word, wordSize, nh, from);
      if (at < 0) break;
      final end = at + nh.length - 1;
      if (end < hyphens.length) hyphens[end] = suppressByte;
      if (at - 1 >= 0) hyphens[at - 1] = suppressByte;
      from = at + 1;
    }
  }
}

int _findSequence(List<int> haystack, int limit, List<int> needle, int from) {
  outer:
  for (var i = from; i + needle.length <= limit; i++) {
    for (var k = 0; k < needle.length; k++) {
      if (haystack[i + k] != needle[k]) continue outer;
    }
    return i;
  }
  return -1;
}

/// hnj_hyphen_hyphenate2, hyphen.c:1132-1164.
int hyphenate2(
  HyphenDict dict,
  List<int> word,
  int wordSize,
  List<int> hyphens,
  List<int>? hyphword,
  RepCarrier? carrier,
) {
  hyphenHyph(dict, word, wordSize, hyphens, carrier, dict.clhmin, dict.crhmin,
      1, 1);
  hyphenLhmin(dict.utf8, word, wordSize, hyphens, carrier,
      dict.lhmin > 0 ? dict.lhmin : 2);
  hyphenRhmin(dict.utf8, word, wordSize, hyphens, carrier,
      dict.rhmin > 0 ? dict.rhmin : 2);

  _applyNohyphen(dict, word, wordSize, hyphens, _kZero);

  if (hyphword != null) {
    hyphenHyphword(word, wordSize, hyphens, hyphword, carrier);
  }
  if (dict.utf8) return hyphenNorm(word, wordSize, hyphens, carrier);
  return 0;
}

/// hnj_hyphen_hyphenate3, hyphen.c:1167-1201.
///
/// Note the step order differs from hyphenate2: hyphword runs BEFORE
/// nohyphen here, and nohyphen writes NUL not '0'. Both are reproduced
/// as-is.
int hyphenate3(
  HyphenDict dict,
  List<int> word,
  int wordSize,
  List<int> hyphens,
  List<int>? hyphword,
  RepCarrier? carrier,
  int lhmin,
  int rhmin,
  int clhmin,
  int crhmin,
) {
  lhmin = lhmin > dict.lhmin ? lhmin : dict.lhmin;
  rhmin = rhmin > dict.rhmin ? rhmin : dict.rhmin;
  clhmin = clhmin > dict.clhmin ? clhmin : dict.clhmin;
  crhmin = crhmin > dict.crhmin ? crhmin : dict.crhmin;

  hyphenHyph(dict, word, wordSize, hyphens, carrier, clhmin, crhmin, 1, 1);
  hyphenLhmin(
      dict.utf8, word, wordSize, hyphens, carrier, lhmin > 0 ? lhmin : 2);
  hyphenRhmin(
      dict.utf8, word, wordSize, hyphens, carrier, rhmin > 0 ? rhmin : 2);

  if (hyphword != null) {
    hyphenHyphword(word, wordSize, hyphens, hyphword, carrier);
  }

  _applyNohyphen(dict, word, wordSize, hyphens, 0);

  if (dict.utf8) return hyphenNorm(word, wordSize, hyphens, carrier);
  return 0;
}
