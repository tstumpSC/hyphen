// test/src/dict_loader_file_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/src/dict_loader.dart';

void main() {
  test('the encoding line sets utf8 and cset', () {
    final d = loadDictBytes(utf8.encode('UTF-8\nte1st\n'));
    expect(d.utf8, isTrue);
    expect(d.cset, 'UTF-8');
  });

  test('an ISO8859-1 encoding line leaves utf8 false', () {
    final d = loadDictBytes(utf8.encode('ISO8859-1\nte1st\n'));
    expect(d.utf8, isFalse);
    expect(d.cset, 'ISO8859-1');
  });

  test('a dictionary without NEXTLEVEL returns the synthesised level', () {
    // hazard 7: C returns dict[1], whose nextlevel is the real patterns.
    final d = loadDictBytes(utf8.encode('UTF-8\nte1st\n'));

    expect(d.nextlevel, isNotNull,
        reason: 'returned level must point at the real pattern level');
    expect(d.nohyphen, isNotEmpty,
        reason: 'synthesised level carries the default NOHYPHEN list');
    expect(d.clhmin, 3, reason: 'defaults to 3 when unset (hyphen.c:529)');
    expect(d.crhmin, 3);
  });

  test('a dictionary with NEXTLEVEL returns level 0 with level 1 attached', () {
    final d = loadDictBytes(utf8.encode('UTF-8\na1b\nNEXTLEVEL\nc1d\n'));
    expect(d.nextlevel, isNotNull);
    expect(d.nohyphen, isEmpty,
        reason: 'no synthesised level, so no default NOHYPHEN');
    // The discriminator vs. the no-NEXTLEVEL case above: the returned dict
    // here is level 0, whose clhmin/crhmin stay at their unset default of 0
    // (they are only defaulted to 3 on the synthesised-level return path,
    // hyphen.c:529-530). `nextlevel != null` and `nohyphen.isEmpty` both
    // hold on either branch of loadDictBytes's return, so they alone do not
    // distinguish the two — this does.
    expect(d.clhmin, 0);
    expect(d.crhmin, 0);
  });

  test('comment lines are skipped', () {
    final d = loadDictBytes(utf8.encode('UTF-8\n% a comment\nte1st\n'));
    // Exact count, not a lower bound: if the '%' check were disabled, the
    // comment line would parse as the one-character word '%' and add a
    // state, so this must be able to fail.
    expect(d.nextlevel!.states.length, 5);
  });

  test('a pattern at or beyond MAX_CHARS is discarded but the file loads on', () {
    // hazard 8
    final long = 'a1${'b' * 200}';
    final d = loadDictBytes(utf8.encode('UTF-8\n$long\nte1st\n'));

    final level0 = d.nextlevel!;
    final hasLong = level0.states.any((s) => (s.match?.length ?? 0) > 150);
    expect(hasLong, isFalse, reason: 'over-long pattern must be dropped');
    // Exact count, not a lower bound: the reader caps every read regardless
    // of `lastWasTruncated`, so an un-discarded over-long line arrives as
    // truncated ~99-byte fragments whose match never exceeds 150 chars —
    // `hasLong` above cannot catch a broken discard. This can: 5 states
    // when the line is correctly dropped whole, 103 when it is not.
    expect(level0.states.length, 5,
        reason: 'te1st after it must still load, and nothing else');
  });

  test(
      'an over-long cset line is capped at MAX_NAME, not MAX_CHARS, '
      'and the remainder is not discarded', () {
    // Finding 1, fix round 1: hyphen.c:426 reads the cset line into a
    // 20-byte buffer (MAX_NAME), not the 100-byte MAX_CHARS pattern
    // buffer — at most 19 content bytes. And unlike a too-long pattern
    // line, fgets does not discard the overflow: it just stops, so the
    // remainder of the line stays in the stream and is parsed by the next
    // (100-byte) read as a pattern line. No real dictionary's encoding
    // name is this long, but the C source is authoritative even on input
    // no shipped file triggers.
    final d = loadDictBytes(
        utf8.encode('CustomCharsetNameExceedsNineteenChars\nte1st\n'));
    expect(d.cset, 'CustomCharsetNameEx', reason: 'capped at 19 bytes');
    // Measured against the reference C library: the leftover
    // "ceedsNineteenChars" plus "te1st" parse into 23 states total.
    expect(d.nextlevel!.states.length, 23);
  });

  test('CRLF line endings are handled', () {
    final d = loadDictBytes(utf8.encode('UTF-8\r\nte1st\r\n'));
    expect(d.cset, 'UTF-8');
  });

  test('every tracked corpus fixture loads with the encoding its header declares', () {
    // Originally read the three real dictionaries shipped in
    // example/assets/ and asserted each built a pattern tree with
    // greaterThan(100) states. Fix round, 2026-09-08: example/.gitignore
    // contains `/assets/`, so those three .dic files are not tracked — this
    // passed only because they happened to exist locally, and would fail
    // on a clean clone. There is no tracked large real dictionary to stand
    // in for them (see tool/extract_curated.dart's header for why
    // committing one was rejected), so this now sweeps every dictionary
    // tool/.gitignore actually keeps tracked (`corpus/*` +
    // `!corpus/synth/`) instead, checking a fact loadDictBytes computes
    // per file rather than a loose lower bound.
    final dir = Directory('tool/corpus/synth');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dic'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    // Exact count, not a lower bound: if tool/.gitignore's `!corpus/synth/`
    // exception ever stopped covering one of these files, or a fixture were
    // deleted, this must fail rather than silently sweep fewer files.
    expect(files.length, 9, reason: 'tool/corpus/synth/*.dic');

    for (final f in files) {
      final d = loadDictBytes(f.readAsBytesSync());
      // Every fixture but empty.dic declares UTF-8 on its first line;
      // empty.dic has no encoding line at all (0 bytes) and so falls back
      // to the ISO8859-1 default (utf8 = false), matching the reference
      // library's undocumented-but-measured behaviour on an empty file
      // (also pinned in test/src/hyphen_test.dart).
      final expectUtf8 = !f.path.endsWith('empty.dic');
      expect(d.utf8, expectUtf8, reason: f.path);
      // hnj_hyphen_load always returns a level with a real (possibly
      // synthesised) pattern tree attached, never a bare null.
      expect(d.nextlevel, isNotNull, reason: f.path);
    }
  });
}
