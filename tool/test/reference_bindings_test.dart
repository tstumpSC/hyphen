import 'dart:convert';
import 'package:test/test.dart';
import '../lib/reference_bindings.dart';

const _dylib = 'libhyphen_ffi.dylib';
const _enUs = '../example/assets/hyph_en_US.dic';

void main() {
  test('hyphenation through en_US returns the README marks', () {
    final dict = ReferenceHyphen(_dylib).load(_enUs);
    addTearDown(dict.free);

    final marks = dict.hyphenate2(utf8.encode('hyphenation'));

    expect(marks, [48, 51, 48, 48, 50, 53, 52, 50, 48, 48, 48]);
  });

  test('en_US dictionary reports utf8', () {
    final dict = ReferenceHyphen(_dylib).load(_enUs);
    addTearDown(dict.free);
    expect(dict.isUtf8, isTrue);
  });

  test('de_DE dictionary reports iso8859', () {
    final dict = ReferenceHyphen(_dylib).load('../example/assets/hyph_de_DE.dic');
    addTearDown(dict.free);
    expect(dict.isUtf8, isFalse);
  });

  test('hyphenate3 with wide hyphenmins suppresses all breaks', () {
    final dict = ReferenceHyphen(_dylib).load(_enUs);
    addTearDown(dict.free);

    final marks = dict.hyphenate3(utf8.encode('hyphenation'), 20, 20, 20, 20);

    expect(marks.every((m) => (m >= 48 ? m - 48 : m) & 1 == 0), isTrue);
  });

  test('loading a missing dictionary throws', () {
    expect(() => ReferenceHyphen(_dylib).load('nope.dic'), throwsStateError);
  });
}
