// lib/src/hyphen.dart
import 'dart:convert';

import 'package:flutter/services.dart';

import 'dict_loader.dart';
import 'engine.dart';
import 'hyphen_dict.dart';
import 'utils.dart';

/// Pure-Dart word hyphenation using Hunspell/Hyphen dictionaries.
///
/// ### Example
/// ```dart
/// final hyphen = await Hyphen.fromDictionaryPath('assets/hyph_en_US.dic');
/// print(hyphen.hyphenate('hyphenation')); // [hy, phen, ation]
/// ```
class Hyphen {
  Hyphen._(this._dict, this._encoding);

  final HyphenDict _dict;
  final DictEncoding _encoding;

  /// Loads a dictionary from a Flutter asset [path].
  static Future<Hyphen> fromDictionaryPath(String path) async {
    final data = await rootBundle.load(path);
    return fromDictionaryBytes(data.buffer.asUint8List());
  }

  /// Loads a dictionary from raw [bytes]. Synchronous, and needs no Flutter
  /// asset bundle.
  static Hyphen fromDictionaryBytes(List<int> bytes) {
    // No empty-input guard, deliberately. `hnj_hyphen_load` succeeds on an
    // empty file: it returns a dictionary with an empty cset, utf8 = 0, and
    // the synthesised ISO8859-1 level, which hyphenates everything to no
    // breaks. Verified against the reference library on 2026-09-07. Throwing
    // here would diverge from the C on the corpus's `synth_empty` fixture.
    final HyphenDict dict;
    try {
      dict = loadDictBytes(bytes);
    } catch (e) {
      throw InitializationException('Dictionary could not be loaded: $e');
    }
    return Hyphen._(
      dict,
      dict.utf8 ? DictEncoding.utf8 : DictEncoding.iso8859,
    );
  }

  /// Hyphenates [text] and returns the parts.
  List<String> hyphenate(
    String text, {
    int? lhmin,
    int? rhmin,
    int? clhmin,
    int? crhmin,
  }) =>
      HyphenUtils.applyHyphenationMarks(
        text,
        _getHyphenationMarks(
          text: text,
          lhmin: lhmin,
          rhmin: rhmin,
          clhmin: clhmin,
          crhmin: crhmin,
        ),
      );

  /// Hyphenates [text], inserting [separator] at each break.
  // The annotation below is load-bearing: it is the only deprecation warning
  // callers of this method receive. Do not remove it.
  @Deprecated("Depcrecated in v0.2.0. Use hyphenate() instead.")
  String hnjHyphenate2(String text, {String separator = "="}) =>
      _hnjHyphenateLegacy(text: text, separator: separator);

  /// Hyphenates [text] with tunable minimum distances.
  @Deprecated("Depcrecated in v0.2.0. Use hyphenate() instead.")
  String hnjHyphenate3(
    String text, {
    String separator = '=',
    int lhmin = 2,
    int rhmin = 3,
    int clhmin = 2,
    int crhmin = 3,
  }) =>
      _hnjHyphenateLegacy(
        text: text,
        separator: separator,
        lhmin: lhmin,
        rhmin: rhmin,
        clhmin: clhmin,
        crhmin: crhmin,
      );

  String _hnjHyphenateLegacy({
    required String text,
    required String separator,
    int? lhmin,
    int? rhmin,
    int? clhmin,
    int? crhmin,
  }) =>
      HyphenUtils.applyHyphenationMarksLegacy(
        text,
        _getHyphenationMarks(
          text: text,
          lhmin: lhmin,
          rhmin: rhmin,
          clhmin: clhmin,
          crhmin: crhmin,
        ),
        separator,
      );

  // Buffer sizes and the `wordLen`-byte read-back match the C exactly,
  // including returning wordLen bytes even though `norm` has compacted the
  // marks for a UTF-8 dictionary, so the tail of the result can be stale.
  // Faithful to the C; do not "fix" without regenerating the goldens.
  List<int> _getHyphenationMarks({
    required String text,
    int? lhmin,
    int? rhmin,
    int? clhmin,
    int? crhmin,
  }) {
    final bytes = _encoding == DictEncoding.utf8
        ? utf8.encode(text)
        : latin1.encode(text);

    final wordLen = bytes.length;
    final hyphens = List<int>.filled(wordLen + 8, 0);
    final carrier = RepCarrier(wordLen == 0 ? 1 : wordLen);

    final useV3 =
        lhmin != null || rhmin != null || clhmin != null || crhmin != null;

    final result = useV3
        ? hyphenate3(_dict, bytes, wordLen, hyphens, null, carrier,
            lhmin ?? 0, rhmin ?? 0, clhmin ?? 0, crhmin ?? 0)
        : hyphenate2(_dict, bytes, wordLen, hyphens, null, carrier);

    if (result != 0) {
      throw Exception('Hyphenation failed with code $result');
    }
    return hyphens.sublist(0, wordLen);
  }

  /// Retained for source compatibility. The Dart engine holds no native
  /// resources, so this does nothing.
  void dispose() {}
}
