// test/golden_test.dart
//
// Committed regression suite: replays a stratified sample of the C
// differential corpus (tool/goldens/c.jsonl, see tool/extract_curated.dart)
// through the public API, restricted to the nine synthetic dictionaries
// under tool/corpus/synth/ so this passes on a clean checkout with no
// fetched corpus and no C reference library.
//
// Fix round, 2026-09-08: this originally pointed at the three "local_*"
// dictionaries under example/assets/. That directory is NOT tracked —
// example/.gitignore contains `/assets/` — so on a clean clone every case
// here failed, along with three unrelated tests that separately read the
// same untracked files. tool/.gitignore deliberately un-ignores
// tool/corpus/synth/ (`corpus/*` + `!corpus/synth/`), so those nine
// hazard-focused synthetic dictionaries are what's actually committed; see
// tool/extract_curated.dart's header for the full account, including why
// committing the three real dictionaries instead was considered and
// rejected (they measure out to less hazard coverage than the synthetics
// already in the repo, not more).
//
// This file deliberately exercises the deprecated hnjHyphenate2/
// hnjHyphenate3 API, because that is the API the golden records' `legacy`
// field was generated through (a '='-separated string). Dropping down to
// the deprecated surface here is intentional, not an oversight.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/hyphen.dart';

const _dictPaths = {
  'synth_empty': 'tool/corpus/synth/empty.dic',
  'synth_encoding_only': 'tool/corpus/synth/encoding_only.dic',
  'synth_hash_comment': 'tool/corpus/synth/hash_comment.dic',
  'synth_hyphenmin': 'tool/corpus/synth/hyphenmin.dic',
  'synth_malformed': 'tool/corpus/synth/malformed.dic',
  'synth_nextlevel': 'tool/corpus/synth/nextlevel.dic',
  'synth_nohyphen': 'tool/corpus/synth/nohyphen.dic',
  'synth_pattern_100': 'tool/corpus/synth/pattern_100.dic',
  'synth_pattern_99': 'tool/corpus/synth/pattern_99.dic',
};

// The exact record count tool/extract_curated.dart wrote the last time it
// was run. Asserted exactly, not with greaterThan: an empty or truncated
// golden file must fail loudly, and this is a measured value, not an
// estimate. If the corpus is regenerated with different caps, regenerate
// this constant too.
const _expectedCaseCount = 3240;

void main() {
  final cases =
      (jsonDecode(File('test/golden/curated.json').readAsStringSync()) as List)
          .cast<Map<String, Object?>>();

  test('the golden file has exactly the expected case count', () {
    expect(cases.length, _expectedCaseCount);
  });

  final hyphens = <String, Hyphen>{
    for (final e in _dictPaths.entries)
      e.key: Hyphen.fromDictionaryBytes(File(e.value).readAsBytesSync()),
  };

  // Grouped by dictionary and parameter set so a failure is localised, but
  // one expect per case so the message names the exact dictionary,
  // parameter set, and word.
  final byBucket = <String, List<Map<String, Object?>>>{};
  for (final c in cases) {
    byBucket.putIfAbsent('${c['dict']}/${c['params']}', () => []).add(c);
  }

  test('every dict/param bucket from extract_curated.dart is present', () {
    // Guards against a mis-stratified or partially-written extraction: 9
    // tracked synth dictionaries x 6 param sets (corpus.dart's kParamSets).
    expect(byBucket.keys.toSet().length, 54);
  });

  byBucket.forEach((bucket, bucketCases) {
    test('golden: $bucket (${bucketCases.length} cases)', () {
      for (final c in bucketCases) {
        final h = hyphens[c['dict']]!;
        final word = c['word'] as String;
        final params = c['params'] as String;
        final reason =
            'dict=${c['dict']} params=$params word=${jsonEncode(word)}';

        if (c.containsKey('error')) {
          // The C reference threw for this input (non-Latin-1 text against
          // an ISO8859-1 dictionary). The Dart port's replay path is
          // latin1.encode, which raises ArgumentError for the same reason.
          // Assert the throw itself, not the message: only the *error*
          // field, never the marks/out/legacy fields, is populated on
          // these records, so there is no expected string to compare
          // against.
          expect(
            () => _run(h, word, params),
            throwsA(isA<ArgumentError>()),
            reason: reason,
          );
          continue;
        }

        final expected = c['legacy'] as String;
        expect(_run(h, word, params), expected, reason: reason);
      }
    });
  });
}

/// Replays one case through the deprecated legacy API, matching the C's
/// `legacy` field: '='-separated for both hnjHyphenate2 and hnjHyphenate3.
/// `params` is either 'v2' or 'v3(l,r,cl,cr)' (see corpus.dart's
/// ParamSet.label).
String _run(Hyphen h, String word, String params) {
  if (params == 'v2') return h.hnjHyphenate2(word);

  // Parse only inside the parens: a naive `-?\d+` match over the whole
  // string also catches the "3" in the "v3" prefix, which silently shifts
  // every value by one position. (Caught by this test failing against the
  // golden on first run — e.g. v3(0,0,0,0) replayed as if it were
  // lhmin=3,rhmin=0,clhmin=0,crhmin=0.)
  final inner = params.substring(params.indexOf('(') + 1, params.indexOf(')'));
  final nums = inner.split(',').map(int.parse).toList();
  return h.hnjHyphenate3(
    word,
    lhmin: nums[0],
    rhmin: nums[1],
    clhmin: nums[2],
    crhmin: nums[3],
  );
}
