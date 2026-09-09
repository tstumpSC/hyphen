// This file deliberately exercises the deprecated hnjHyphenate2/hnjHyphenate3
// API, so intra-package deprecation notices here are expected rather than
// actionable. The markers themselves matter — they were lost when
// lib/src/hyphen_stub.dart was deleted and restored deliberately, since
// dropping them silently unwarns every downstream caller.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/src/hyphen.dart';

// TestWidgetsFlutterBinding comes from flutter_test above; it is required
// before any rootBundle access in the fromDictionaryPath test below.

// Fix round, 2026-09-08: _enUs()/_deDe() originally read the real
// dictionaries shipped in example/assets/. That directory is not tracked
// (example/.gitignore has `/assets/`), so every test below failed on a
// clean clone despite passing wherever those files happened to already
// exist locally. _enUs() is now the same minimal excerpt of the real
// en_US patterns used in test/src/engine_entrypoints_test.dart (verified
// against the untracked real file to reproduce this word's marks exactly
// before this change); _deDe() only needs to be an ISO8859-1 dictionary
// that actually produces a break somewhere in "Silbentrennung", which a
// single pattern is enough for.
Hyphen _enUs() => Hyphen.fromDictionaryBytes(utf8.encode(
    'UTF-8\na1t2io\natio2n\ne1na\nhe2n\nhe1na4\nhen5at\nhy3ph\n2io\nio2n\n'
    '1na\nn2at\no2n\nphe2n\n1t2io\ntio2n\n'));
Hyphen _deDe() =>
    Hyphen.fromDictionaryBytes(utf8.encode('ISO8859-1\nn1t\n'));

void main() {
  test('hyphenate splits into parts', () {
    expect(_enUs().hyphenate('hyphenation'), ['hy', 'phen', 'ation']);
  });

  test('hnjHyphenate2 inserts the default separator', () {
    expect(_enUs().hnjHyphenate2('hyphenation'), 'hy=phen=ation');
  });

  test('hnjHyphenate2 honours a custom separator', () {
    expect(_enUs().hnjHyphenate2('hyphenation', separator: '-'),
        'hy-phen-ation');
  });

  test('hnjHyphenate3 with wide hyphenmins yields no breaks', () {
    expect(_enUs().hnjHyphenate3('hyphenation', lhmin: 20, rhmin: 20),
        'hyphenation');
  });

  test('hyphenate with explicit params routes through hyphenate3', () {
    // lhmin 20 must suppress every break, proving v3 was used
    expect(_enUs().hyphenate('hyphenation', lhmin: 20), ['hyphenation']);
  });

  test('an ISO8859-1 dictionary handles Latin-1 text', () {
    expect(_deDe().hnjHyphenate2('Silbentrennung'), contains('='));
  });

  test('an ISO8859-1 dictionary throws on non-Latin-1 text', () {
    // matches hyphen_ffi.dart:213 behaviour exactly
    expect(() => _deDe().hnjHyphenate2('árvíztűrő'), throwsArgumentError);
  });

  test('an empty string round-trips', () {
    expect(_enUs().hnjHyphenate2(''), '');
    expect(_enUs().hyphenate(''), isEmpty);
  });

  test('fromDictionaryPath loads a declared package asset', () async {
    // This is the entry point users actually call, and the ONLY test that
    // exercises the rootBundle path. Before the port it was covered by
    // test/lib/src/ffi/hyphen_ffi_test.dart, which Task 14 deletes — without
    // this test the package's primary public API ships untested.
    //
    // rootBundle resolves assets declared under `flutter: assets:` in the
    // package's own pubspec when running under flutter_test; the pre-port
    // suite relied on exactly this for the same file.
    TestWidgetsFlutterBinding.ensureInitialized();

    final h = await Hyphen.fromDictionaryPath('test/assets/test_dictionary.dic');

    // test_dictionary.dic declares ISO8859-1 and the single pattern te1st,
    // so 'test' breaks after 'te' and nothing else does.
    expect(h.hnjHyphenate2('test'), 'te=st');
    expect(h.hnjHyphenate2('xyz'), 'xyz');
  });

  test('dispose is safe and idempotent', () {
    final h = _enUs();
    expect(h.dispose, returnsNormally);
    expect(h.dispose, returnsNormally);
  });

  test('an empty dictionary loads and yields no breaks, matching the C', () {
    // hyphen_load does NOT fail on an empty file. Measured against the
    // reference library: utf8 = 0, synthesised ISO8859-1 level, 3 states,
    // and every word comes back unhyphenated. Asserting a throw here would
    // break Stage B parity on the corpus's synth_empty fixture.
    final h = Hyphen.fromDictionaryBytes(const []);
    expect(h.hnjHyphenate2('test'), 'test');
    expect(h.hyphenate('test'), ['test']);
  });
}
