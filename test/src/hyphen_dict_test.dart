import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/src/hyphen_dict.dart';

void main() {
  test('a new dict has exactly one state, the root', () {
    final d = HyphenDict();
    expect(d.states.length, 1);
    expect(d.states[0].match, isNull);
    expect(d.states[0].fallbackState, -1);
    expect(d.states[0].trans, isEmpty);
  });

  test('getState allocates a new state on first request and reuses it after', () {
    final d = HyphenDict();
    final hashtab = <String, int>{'': 0};

    final first = d.getState(hashtab, 'abc');
    expect(first, 1);
    expect(d.states.length, 2);

    final second = d.getState(hashtab, 'abc');
    expect(second, 1, reason: 'same key must not allocate a second state');
    expect(d.states.length, 2);
  });

  test('getState returns the existing state number for a pre-seeded key', () {
    final d = HyphenDict();
    expect(d.getState(<String, int>{'': 0}, ''), 0);
  });

  test('addTrans appends transitions in insertion order', () {
    final d = HyphenDict();
    final hashtab = <String, int>{'': 0};
    final s = d.getState(hashtab, 'a');

    d.addTrans(0, s, 0x61);
    d.addTrans(0, s, 0x62);

    expect(d.states[0].trans.map((t) => t.ch), [0x61, 0x62]);
    expect(d.states[0].trans.map((t) => t.newState), [s, s]);
  });
}
