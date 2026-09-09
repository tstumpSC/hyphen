import 'package:test/test.dart';
import '../lib/corpus.dart';

void main() {
  test('six parameter sets, one v2 and five v3', () {
    expect(kParamSets.length, 6);
    expect(kParamSets.where((p) => p.isV2).length, 1);
  });

  test('parameter set labels are unique', () {
    final labels = kParamSets.map((p) => p.label).toSet();
    expect(labels.length, kParamSets.length);
  });

  test('corpus includes the three local dicts and the six fetched', () {
    final labels = corpusDicts().map((d) => d.label).toList();
    expect(labels, contains('local_de_DE'));
    expect(labels, contains('local_de_DE_UTF'));
    expect(labels, contains('local_en_US'));
    expect(labels, containsAll(['de', 'en', 'hu', 'nl', 'sv', 'ca']));
  });

  test('only the German word list is flagged latin1', () {
    final withWords = corpusDicts().where((d) => d.wordsPath != null);
    final latin1 = withWords.where((d) => d.wordsAreLatin1).map((d) => d.label);
    expect(latin1, everyElement(anyOf('de', 'local_de_DE', 'local_de_DE_UTF')));
    expect(latin1, containsAll(['de', 'local_de_DE', 'local_de_DE_UTF']));
  });

  test('hungarian words load and include generated compounds', () {
    final hu = corpusDicts().firstWhere((d) => d.label == 'hu');
    final limited = wordsFor(hu, limit: 5000);

    expect(limited.length, greaterThan(1000));
    // Generated compounds exceed any single root. Measured: at limit 5000,
    // 283 of 3000 compounds are longer than 30 chars while the longest root
    // in that pool is 24.
    expect(limited.any((w) => w.length > 30), isTrue);
  });

  test('the full hungarian list contains asszony', () {
    // Asserted WITHOUT a limit, deliberately. hu_HU.dic is NOT sorted — its
    // first entries are 'üzér', 'üzletág', … — and 'asszony' sits at index
    // 49,625 of 97,580 parsed roots, so it is absent from any small slice.
    // Measured 2026-09-07. This word matters because it is the one that
    // exercises hu's non-standard pattern as5szon2y/sz=,2,1.
    final hu = corpusDicts().firstWhere((d) => d.label == 'hu');
    expect(wordsFor(hu), contains('asszony'));
  });

  test('affix flags are stripped from word list entries', () {
    final hu = corpusDicts().firstWhere((d) => d.label == 'hu');
    expect(wordsFor(hu, limit: 5000).every((w) => !w.contains('/')), isTrue);
  });

  test('fuzz set covers the documented edge cases', () {
    final f = fuzzWords();
    expect(f, contains(''));
    expect(f.any((w) => w.length > 100), isTrue);
    expect(f, contains('é'));           // decomposed accent, hazard 4
    expect(f.any((w) => w.contains('ﬀ')), isTrue); // ff ligature
    expect(f.any((w) => w.contains('123')), isTrue);
    expect(f.any((w) => w.runes.any((r) => r > 0xFFFF)), isTrue);
    expect(f.any((w) => w.contains('\x00')), isTrue); // embedded NUL
  });
}
