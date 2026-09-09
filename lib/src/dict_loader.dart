// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Derived from the Hunspell/Hyphen library (https://github.com/hunspell/hyphen),
// offered by its authors under a GPL 2.0 / LGPL 2.1 / MPL 1.1 tri-license.
// This port is distributed under the MPL branch of that grant, at version 2.0.
// See THIRD_PARTY_LICENSES.md.
// lib/src/dict_loader.dart
//
// Dart port of hnj_hyphen_load_line and hnj_hyphen_load_file from
// Hunspell/Hyphen's hyphen.c. Line numbers refer to upstream hyphen.c.

import 'hyphen_dict.dart';

/// C's MAX_CHARS. Patterns that do not fit are discarded, matching the C.
const int kMaxChars = 100;

const int _kZero = 0x30; // '0'
const int _kNine = 0x39; // '9'
const int _kSpace = 0x20;
const int _kSlash = 0x2F; // '/'
const int _kComma = 0x2C;
const int _kDot = 0x2E;

/// hnj_strchomp, hyphen.c:79-84. Trims one trailing \r or \n, then a second
/// \r if present.
List<int> strchomp(List<int> s) {
  var k = s.length;
  if (k > 0 && (s[k - 1] == 0x0D || s[k - 1] == 0x0A)) k--;
  if (k > 1 && s[k - 1] == 0x0D) k--;
  return s.sublist(0, k);
}

int _atoi(List<int> bytes, int from) {
  var i = from;
  while (i < bytes.length && (bytes[i] == _kSpace || bytes[i] == 0x09)) {
    i++;
  }
  var sign = 1;
  if (i < bytes.length && (bytes[i] == 0x2D || bytes[i] == 0x2B)) {
    if (bytes[i] == 0x2D) sign = -1;
    i++;
  }
  var v = 0;
  while (i < bytes.length && bytes[i] >= _kZero && bytes[i] <= _kNine) {
    v = v * 10 + (bytes[i] - _kZero);
    i++;
  }
  return sign * v;
}

bool _startsWith(List<int> buf, String prefix) {
  if (buf.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (buf[i] != prefix.codeUnitAt(i)) return false;
  }
  return true;
}

/// hnj_hyphen_load_line, hyphen.c:246-373.
///
/// [buf] is one raw line INCLUDING its newline, as C's fgets delivers it.
void loadLine(List<int> buf, HyphenDict dict, Map<String, int> hashtab) {
  // --- settings keywords, hyphen.c:258-285 -------------------------------
  if (_startsWith(buf, 'LEFTHYPHENMIN')) {
    dict.lhmin = _atoi(buf, 13);
    return;
  } else if (_startsWith(buf, 'RIGHTHYPHENMIN')) {
    dict.rhmin = _atoi(buf, 14);
    return;
  } else if (_startsWith(buf, 'COMPOUNDLEFTHYPHENMIN')) {
    dict.clhmin = _atoi(buf, 21);
    return;
  } else if (_startsWith(buf, 'COMPOUNDRIGHTHYPHENMIN')) {
    dict.crhmin = _atoi(buf, 22);
    return;
  } else if (_startsWith(buf, 'NOHYPHEN')) {
    var start = 8;
    while (start < buf.length &&
        (buf[start] == _kSpace || buf[start] == 0x09)) {
      start++;
    }
    var body = buf.sublist(start);
    // C zeroes the final byte unconditionally (hyphen.c:277-278), which for
    // a newline-terminated line strips the newline, and otherwise eats a
    // real character. Reproduced verbatim.
    if (body.isNotEmpty) body = body.sublist(0, body.length - 1);
    dict.nohyphen = _splitNohyphen(body);
    return;
  }

  // --- non-standard replacement suffix, hyphen.c:288-308 -----------------
  var line = buf;
  List<int>? repl;
  var replindex = 0;
  var replcut = 0;

  final slash = line.indexOf(_kSlash);
  if (slash >= 0) {
    final tail = line.sublist(slash + 1);
    line = line.sublist(0, slash); // C: *repl = '\0'

    final comma = tail.indexOf(_kComma);
    if (comma >= 0) {
      final comma2 = tail.indexOf(_kComma, comma + 1);
      if (comma2 >= 0) {
        replindex = _atoi(tail, comma + 1) - 1;
        replcut = _atoi(tail, comma2 + 1);
        repl = tail.sublist(0, comma);
      } else {
        // hyphen.c:291-308: the replindex/replcut assignments sit INSIDE
        // `if (index2)` at 297-301. With one comma and no second one, C
        // falls out of that inner `if` having set neither, so both stay at
        // the outer 0 from lines 289-290 — the
        // `replcut == 0 ? word.length : replcut` fallback below then
        // supplies strlen(word). The `strchomp`/`replcut = line.length`
        // handling at 302-306 fires ONLY when there is no comma at all
        // (`if (index)` false) — do not "fix" this branch by reusing it;
        // that was measured to disagree with the reference library.
        repl = tail.sublist(0, comma);
      }
    } else {
      replindex = 0;
      replcut = line.length;
      repl = strchomp(tail);
    }
  }

  // --- split letters from digits, hyphen.c:309-320 -----------------------
  final word = <int>[];
  final pattern = <int>[_kZero];
  var j = 0;
  for (var i = 0; i < line.length && line[i] > _kSpace; i++) {
    if (line[i] >= _kZero && line[i] <= _kNine) {
      pattern[j] = line[i];
    } else {
      word.add(line[i]);
      j++;
      pattern.add(_kZero);
    }
  }

  // --- trim / convert the match vector, hyphen.c:321-347 -----------------
  var i = 0;
  if (repl == null) {
    while (i < pattern.length && pattern[i] == _kZero) {
      i++;
    }
  } else {
    if (word.isNotEmpty && word[0] == _kDot) i++;
    if (dict.utf8) {
      var pu = -1;
      var ps = -1;
      var pc = (word.isNotEmpty && word[0] == _kDot) ? 1 : 0;
      for (; pc < word.length + 1; pc++) {
        if (pc >= word.length || (word[pc] >> 6) != 2) pu++;
        if (ps < 0 && replindex == pu) {
          ps = replindex;
          replindex = pc;
        }
        if (ps >= 0 && (pu - ps) == replcut) {
          replcut = pc - replindex;
          break;
        }
      }
      if (word.isNotEmpty && word[0] == _kDot) replindex--;
    }
  }

  // --- install the state, hyphen.c:352-361 -------------------------------
  final wordKey = String.fromCharCodes(word);
  final found = hashtab[wordKey];
  var stateNum = dict.getState(hashtab, wordKey);

  dict.states[stateNum].match = pattern.sublist(i, j + 1);
  dict.states[stateNum].repl = repl;
  dict.states[stateNum].replindex = replindex;
  dict.states[stateNum].replcut = replcut == 0 ? word.length : replcut;

  // --- prefix transitions, hyphen.c:363-373 ------------------------------
  var seen = found != null;
  final prefix = List<int>.of(word);
  for (; !seen && j > 0; j--) {
    final lastState = stateNum;
    final ch = prefix[j - 1];
    final key = String.fromCharCodes(prefix.sublist(0, j - 1));
    seen = hashtab[key] != null;
    stateNum = dict.getState(hashtab, key);
    dict.addTrans(stateNum, lastState, ch);
  }
}

/// C stores nohyphen as one NUL-separated blob plus a count, splitting on
/// commas from the end backwards and never splitting at offset 0
/// (hyphen.c:279-283). Reproduced, including that last detail.
List<List<int>> _splitNohyphen(List<int> body) {
  if (body.isEmpty) return const [];
  final parts = <List<int>>[];
  var start = 0;
  for (var i = 1; i < body.length; i++) {
    if (body[i] == _kComma) {
      parts.add(body.sublist(start, i));
      start = i + 1;
    }
  }
  parts.add(body.sublist(start));
  return parts;
}

/// hnj_hyphen_load_file, hyphen.c:391-539.
///
/// C always builds two levels (the `k` loop, hyphen.c:401). Without a
/// NEXTLEVEL keyword, level 1 is synthesised from apostrophe/hyphen rules and
/// becomes the RETURNED dictionary, with the real patterns hanging off its
/// `nextlevel`.
HyphenDict loadDictBytes(List<int> bytes) {
  final reader = _LineReader(bytes);
  final dict = <HyphenDict>[HyphenDict(), HyphenDict()];
  var nextlevel = false;

  for (var k = 0; k < 2; k++) {
    final hashtab = <String, int>{'': 0};

    if (k == 0) {
      // Read the character set line, hyphen.c:425-437. This is bounded by
      // MAX_NAME (20), not MAX_CHARS: `fgets(dict[k]->cset,
      // sizeof(dict[k]->cset), f)` reads at most 19 content bytes
      // (hyphen.c:426). Unlike the pattern-reading loop below, an over-long
      // line here is NOT discarded — fgets just stops at the cap and
      // leaves the remainder of the line (which the next 100-byte read
      // then picks up and parses as a pattern) in the stream.
      final csetLine = reader.next(bufSize: 20, discardIfTooLong: false);
      var cset = '';
      if (csetLine != null) {
        // C zeroes any \r or \n within the buffer.
        final trimmed = strchomp(csetLine);
        cset = String.fromCharCodes(trimmed.takeWhile((c) => c != 0));
      }
      dict[0].cset = cset;
      dict[0].utf8 = cset == 'UTF-8';
    } else {
      dict[1].cset = dict[0].cset;
      dict[1].utf8 = dict[0].utf8;
    }

    if (k == 0 || nextlevel) {
      while (true) {
        final line = reader.next();
        if (line == null) break;

        // Over-long lines are discarded whole, hyphen.c:443-452.
        if (reader.lastWasTruncated) continue;

        if (_startsWith(line, 'NEXTLEVEL')) {
          nextlevel = true;
          break;
        } else if (line.isNotEmpty && line[0] != 0x25 /* '%' */) {
          loadLine(line, dict[k], hashtab);
        }
      }
    } else {
      // Synthesised default level, hyphen.c:461-472.
      if (!dict[0].utf8) {
        loadLine(_ascii("NOHYPHEN ',-\n"), dict[k], hashtab);
      } else {
        loadLine(
          [
            ..._ascii("NOHYPHEN ',"),
            0xE2, 0x80, 0x93, // en dash
            0x2C,
            0xE2, 0x80, 0x99, // right single quote
            0x2C, 0x2D, 0x0A,
          ],
          dict[k],
          hashtab,
        );
      }
      loadLine(_ascii('1-1\n'), dict[k], hashtab);
      loadLine(_ascii("1'1\n"), dict[k], hashtab);
      if (dict[0].utf8) {
        loadLine([0x31, 0xE2, 0x80, 0x93, 0x31, 0x0A], dict[k], hashtab);
        loadLine([0x31, 0xE2, 0x80, 0x99, 0x31, 0x0A], dict[k], hashtab);
      }
    }

    // Fallback states, hyphen.c:493-505. Each entry writes only its own
    // state's fallback, so map iteration order is irrelevant here.
    for (final entry in hashtab.entries) {
      final key = entry.key;
      if (key.isEmpty) continue;
      var stateNum = -1;
      for (var j = 1;; j++) {
        final candidate = hashtab[key.substring(j.clamp(0, key.length))];
        if (candidate != null) {
          stateNum = candidate;
          break;
        }
        if (j > key.length) break;
      }
      if (entry.value != 0) {
        dict[k].states[entry.value].fallbackState = stateNum;
      }
    }
  }

  // hyphen.c:524-538.
  if (nextlevel) {
    dict[0].nextlevel = dict[1];
    return dict[0];
  }

  dict[1].nextlevel = dict[0];
  dict[1].lhmin = dict[0].lhmin;
  dict[1].rhmin = dict[0].rhmin;
  dict[1].clhmin = dict[0].clhmin != 0
      ? dict[0].clhmin
      : (dict[0].lhmin != 0 ? dict[0].lhmin : 3);
  dict[1].crhmin = dict[0].crhmin != 0
      ? dict[0].crhmin
      : (dict[0].rhmin != 0 ? dict[0].rhmin : 3);
  return dict[1];
}

List<int> _ascii(String s) => s.codeUnits;

/// Reproduces C's fgets over a fixed-size buffer, including the
/// over-long-line discard at hyphen.c:443-452 for the MAX_CHARS pattern
/// reads, and the different (non-discarding) overflow behaviour of the
/// MAX_NAME cset read at hyphen.c:426.
class _LineReader {
  _LineReader(this._bytes);

  final List<int> _bytes;
  int _pos = 0;
  bool lastWasTruncated = false;

  /// [bufSize] mirrors C's `sizeof(buf)` for the specific fgets call being
  /// emulated: kMaxChars (100) for the pattern-reading loop, or 20
  /// (MAX_NAME) for the single cset read (hyphen.c:426). [discardIfTooLong]
  /// selects which of C's two overflow behaviours applies when the line
  /// does not fit in `bufSize - 1` bytes and no newline was found within
  /// that budget:
  ///  - true (the pattern loop, hyphen.c:443-452): consume the rest of the
  ///    line up to and including its newline, and discard the whole line
  ///    (`lastWasTruncated` is set).
  ///  - false (the cset read, hyphen.c:426): fgets simply stops at the
  ///    cap. It does NOT consume the remainder of the line — that stays in
  ///    the stream for the next read to pick up, exactly as C's fgets
  ///    leaves it for the file's next fgets call.
  List<int>? next({int bufSize = kMaxChars, bool discardIfTooLong = true}) {
    if (_pos >= _bytes.length) return null;

    lastWasTruncated = false;
    final start = _pos;
    var end = _pos;
    // fgets stops after bufSize-1 bytes or at a newline, whichever first.
    final cap = start + bufSize - 1;
    while (end < _bytes.length && end < cap && _bytes[end] != 0x0A) {
      end++;
    }
    // Only a newline found strictly within the bufSize-1 budget (end < cap)
    // is one fgets actually read: the loop only stops early on a newline
    // while `end < cap` still holds, per the while condition above. A
    // newline sitting exactly at `cap` is the (unread) bufSize-th byte and
    // must NOT be treated as "found" — that byte is one fgets never sees,
    // and its being '\n' is coincidental (see pattern_100.dic: 99 content
    // chars + '\n' lands the '\n' exactly at `cap`, and without this guard
    // it was misread as fitting instead of overflowing).
    if (end < cap && end < _bytes.length && _bytes[end] == 0x0A) {
      end++; // fgets keeps the newline
      _pos = end;
      return _bytes.sublist(start, end);
    }

    if (end >= cap) {
      if (!discardIfTooLong) {
        // fgets just stops at the buffer cap; the remainder of the line
        // (including any newline) is left unread in the stream.
        _pos = end;
        return _bytes.sublist(start, end);
      }
      // No newline within the buffer: C consumes to the next newline and
      // discards the whole line.
      lastWasTruncated = true;
      var skip = end;
      while (skip < _bytes.length && _bytes[skip] != 0x0A) {
        skip++;
      }
      _pos = skip < _bytes.length ? skip + 1 : skip;
      return _bytes.sublist(start, end);
    }

    // EOF with no trailing newline.
    _pos = end;
    return _bytes.sublist(start, end);
  }
}
