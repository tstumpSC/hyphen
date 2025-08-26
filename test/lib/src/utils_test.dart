import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/src/utils.dart';

void main() {
  group('applyHyphenationMarks', () {
    test('correctly applies hyphenation pattern', () async {
      String result = HyphenUtils.applyHyphenationMarks("Funktioniert", [
        0,
        0,
        2,
        1,
        2,
        8,
        1,
        6,
        0,
        0,
        0,
        0,
      ], "=");

      expect(result, "Funk=tio=niert");
    });

    test('correctly puts separator', () async {
      String result = HyphenUtils.applyHyphenationMarks("Funktioniert", [
        0,
        0,
        2,
        1,
        2,
        8,
        1,
        6,
        0,
        0,
        0,
        0,
      ], "-");

      expect(result, "Funk-tio-niert");
    });
  });

  group('convertAsciiHyphenationMarksToNumeric', () {
    test('converts ascii to numeric values', () {
      final ascii = [48, 48, 50, 49, 50, 56, 49, 54, 48, 48, 48, 48];
      final result = HyphenUtils.convertAsciiHyphenationMarksToNumeric(ascii);

      expect(result, [0, 0, 2, 1, 2, 8, 1, 6, 0, 0, 0, 0]);
    });

    test('values that are already numeric stay the same', () {
      final numeric = [0, 0, 2, 1, 2, 8, 1, 6, 0, 0, 0, 0];
      final result = HyphenUtils.convertAsciiHyphenationMarksToNumeric(numeric);

      expect(result, numeric);
    });
  });
}
