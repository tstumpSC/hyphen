/// Stub implementation of [Hyphen] for unsupported platforms.
///
/// This exists so that code can still import the `Hyphen` API everywhere,
/// but will throw immediately if used on platforms that don’t provide
/// a native or JS runtime (e.g. plain Dart VM).
///
/// All methods throw [UnsupportedError].
class Hyphen {
  Hyphen._();

  /// Attempts to create a [Hyphen] from the given dictionary path.
  ///
  /// Always throws [UnsupportedError] on this platform.
  static Future<Hyphen> fromDictionaryPath(String assetPath) async =>
      throw UnsupportedError('Hyphen is not supported on this platform.');

  /// Attempts to hyphenate [text] using hyphenate2 rules.
  ///
  /// Always throws [UnsupportedError] on this platform.
  String hnjHyphenate2(String text, {String separator = "="}) =>
      throw UnsupportedError('Hyphen is not supported on this platform.');

  /// Attempts to hyphenate [text] using hyphenate3 rules.
  ///
  /// Always throws [UnsupportedError] on this platform.
  String hnjHyphenate3(
    String text, {
    String separator = '=',
    int lhmin = 2,
    int rhmin = 3,
    int clhmin = 2,
    int crhmin = 3,
  }) => throw UnsupportedError('Hyphen is not supported on this platform.');

  void dispose() =>
      throw UnsupportedError('Hyphen is not supported on this platform.');
}
