import 'dart:convert';
import 'package:characters/characters.dart';

/// Mirrors hyphen_ffi.dart:213 — Latin-1 for a non-UTF-8 dictionary, which
/// throws ArgumentError on input outside Latin-1.
List<int> encodeWord(String text, {required bool utf8Dict}) =>
    utf8Dict ? utf8.encode(text) : latin1.encode(text);

List<int> _numeric(List<int> raw) =>
    [for (final v in raw) (v >= 48 && v <= 57) ? v - 48 : v];

/// Mirrors HyphenUtils.applyHyphenationMarks.
List<String> applyMarks(String text, List<int> marks) {
  final m = _numeric(marks);
  final result = <String>[];
  final buffer = StringBuffer();
  var i = 0;
  for (final ch in text.characters) {
    buffer.write(ch);
    if (i < m.length && (m[i] & 1) == 1) {
      result.add(buffer.toString());
      buffer.clear();
    }
    i++;
  }
  if (buffer.isNotEmpty) result.add(buffer.toString());
  return result;
}

/// Mirrors HyphenUtils.applyHyphenationMarksLegacy.
String applyMarksLegacy(String text, List<int> marks, String separator) {
  final m = _numeric(marks);
  final sb = StringBuffer();
  var i = 0;
  for (final ch in text.characters) {
    sb.write(ch);
    if (i < m.length && (m[i] & 1) == 1) sb.write(separator);
    i++;
  }
  return sb.toString();
}
