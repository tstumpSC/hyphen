import 'package:characters/characters.dart';

/// Utilities shared by FFI and Web implementations for applying hyphenation
/// marks returned by the native engine.
///
/// The native/WASM layer typically returns a byte array of “marks” where each
/// position corresponds to a character boundary in [text]. A mark is treated
/// as a bitfield; in common setups, an **odd** value means “insert a hyphen
/// after this character”.
class HyphenUtils {
  HyphenUtils._();

  /// Applies hyphenation [marks] to [text] and returns a new string with
  /// [separator] inserted after characters whose corresponding mark is odd.
  ///
  /// - Handles **grapheme clusters** via `Characters` (so combining marks,
  ///   emojis, etc. are kept intact).
  /// - Accepts both **numeric marks** (`0`, `1`, `2`, …) and **ASCII digits**
  ///   (`'0'..'9'` = `48..57`); ASCII inputs are normalized automatically.
  ///
  /// Example:
  /// ```dart
  /// HyphenUtils.applyHyphenationMarks('Funktioniert',
  ///   [48,48,50,49,50,56,49,54,48,48,48,48], '='); // "Funk=tio=niert"
  /// ```
  static String applyHyphenationMarks(
    String text,
    List<int> marks,
    String separator,
  ) {
    final hyphenationMarksNumeric = convertAsciiHyphenationMarksToNumeric(
      marks,
    );

    final sb = StringBuffer();
    final chars = text.characters; // handles grapheme clusters
    var i = 0;
    for (final ch in chars) {
      sb.write(ch);
      if (i < hyphenationMarksNumeric.length &&
          (hyphenationMarksNumeric[i] & 1) == 1) {
        sb.write(separator);
      }
      i++;
    }
    return sb.toString();
  }

  /// Converts a list of raw mark bytes into numeric values.
  ///
  /// If a value is an ASCII digit (`'0'..'9'` → `48..57`), it is converted to
  /// its numeric equivalent (`0..9`). All other values are returned unchanged.
  ///
  /// This allows callers to pass the marks buffer directly from either FFI or
  /// WASM without caring whether it uses numeric or ASCII digits.
  static List<int> convertAsciiHyphenationMarksToNumeric(List<int> raw) {
    return List<int>.generate(raw.length, (i) {
      var v = raw[i];
      if (v >= 48 && v <= 57) v -= 48; // ASCII -> numeric
      return v;
    });
  }
}

/// Thrown when the hyphenation engine cannot be initialized (e.g. when a
/// dictionary fails to load or is invalid).
class InitializationException implements Exception {
  final String cause;

  InitializationException(this.cause);

  @override
  String toString() => 'Error while initializing Hyphenator: $cause';
}

enum DictEncoding {
  utf8,
  iso8859;

  static DictEncoding fromString(String encodingString) {
    if (encodingString == "UTF-8") {
      return DictEncoding.utf8;
    } else if (encodingString == "ISO8859-1") {
      return DictEncoding.iso8859;
    } else {
      throw Exception(
        "Unsupported dictionary encoding: $encodingString. Only UTF-8 and ISO8859-1 are supported.",
      );
    }
  }
}
