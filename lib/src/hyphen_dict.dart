// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Derived from the Hunspell/Hyphen library (https://github.com/hunspell/hyphen),
// offered by its authors under a GPL 2.0 / LGPL 2.1 / MPL 1.1 tri-license.
// This port is distributed under the MPL branch of that grant, at version 2.0.
// See THIRD_PARTY_LICENSES.md.
//
// Dart port of the HyphenDict / HyphenState / HyphenTrans model from
// Hunspell/Hyphen's hyphen.h, and of the state-allocation helpers
// hnj_get_state / hnj_add_trans (hyphen.c:181-227).
//
// Ported faithfully rather than idiomatically so it can be diffed against
// the C by eye. Line numbers refer to upstream hyphen.c.

/// One transition out of a state. Mirrors `struct _HyphenTrans`.
class HyphenTrans {
  HyphenTrans(this.ch, this.newState);

  /// A single byte, not a rune — the C matches byte by byte.
  final int ch;
  final int newState;
}

/// Mirrors `struct _HyphenState`.
class HyphenState {
  /// Pattern digits as ASCII bytes ('0'..'9'), as C stores them.
  List<int>? match;

  /// Non-standard replacement text, or null. C's `repl`.
  List<int>? repl;

  int replindex = 0;
  int replcut = 0;
  int fallbackState = -1;

  /// Insertion-ordered: the FSM takes the first match (hyphen.c:855-861).
  final List<HyphenTrans> trans = [];
}

/// Mirrors `struct _HyphenDict`.
class HyphenDict {
  int lhmin = 0;
  int rhmin = 0;
  int clhmin = 0;
  int crhmin = 0;

  /// C keeps one NUL-separated blob plus a count and walks it with pointer
  /// arithmetic (hyphen.c:1145-1156). Pre-split here; iteration order in
  /// engine.dart matches.
  List<List<int>> nohyphen = [];

  bool utf8 = false;
  String cset = '';

  /// State 0 is the root, allocated eagerly as C does (hyphen.c:407-413).
  final List<HyphenState> states = [HyphenState()];

  HyphenDict? nextlevel;

  /// hnj_get_state, hyphen.c:181-204.
  int getState(Map<String, int> hashtab, String key) {
    final existing = hashtab[key];
    if (existing != null) return existing;

    final stateNum = states.length;
    hashtab[key] = stateNum;
    states.add(HyphenState());
    return stateNum;
  }

  /// hnj_add_trans, hyphen.c:209-227.
  void addTrans(int state1, int state2, int ch) {
    states[state1].trans.add(HyphenTrans(ch, state2));
  }
}
