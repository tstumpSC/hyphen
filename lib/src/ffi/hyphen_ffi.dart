import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import '../utils.dart';
import 'dynamic_library_loader.dart';
import 'hyphen_ffi_bindings_generated.dart';

/// Hyphen FFI wrapper.
///
/// This class provides a safe Dart interface to the native `libhyphen`
/// hyphenation library across supported platforms. It handles:
///
/// * **Dictionary loading**
///   – [fromDictionaryPath] copies a `.dic` asset into a temporary file,
///     loads it through `hyphen_load`, and returns a [Hyphen] instance.
///   – Supports an environment override `HYF_LIB_PATH` via
///     [resolveLibrarySpec], useful for CI or custom builds.
///
/// * **Hyphenation**
///   - [hyphenate] calls `hnj_hyphen_hyphenate2` or `hnj_hyphen_hyphenate3`, depending on whether
///     or not you pass one of the additional parameters (`lhmin`, `rhmin`, `clhmin`, `crhmin`).
///   – [hnjHyphenate2] calls `hnj_hyphen_hyphenate2`.
///   – [hnjHyphenate3] calls `hnj_hyphen_hyphenate3` with tunable `lhmin`,
///     `rhmin`, `clhmin`, `crhmin` parameters.
///   – Both allocate scratch buffers, invoke the C API, then free memory.
///   – Raw hyphenation marks (0/1 bytes or ASCII '0'/'1') are normalized
///     through [HyphenUtils.applyHyphenationMarksLegacy] to insert separators
///     (default `"="`) into the original text.
///
/// * **Memory management**
///   – Uses [Allocator] (default `calloc`) to allocate temporary buffers.
///   – All allocated buffers are freed in a `finally` block.
///   – [dispose] releases the underlying `HyphenDict` when no longer needed.
///
/// * **Dynamic library resolution**
///   – Uses [_dylib] to load the correct native library depending on platform.
///   – macOS/iOS: process symbols.
///   – Android: `libhyphen_ffi.so`.
///   – Linux: architecture-specific path.
///   – Windows: local `hyphen_ffi.dll` (with PATH fallback).
///
/// ### Example
/// ```dart
/// final hyphen = await Hyphen.fromDictionaryPath('assets/hyph_en_US.dic');
/// final result = hyphen.hyphenate('hyphenation');
/// print(result); // e.g. "hy-phen-ation"
/// hyphen.dispose();
/// ```
///
/// Throws [InitializationException] if the dictionary cannot be loaded,
/// or [Exception] if the native hyphenation call returns non-zero.

class Hyphen {
  late Pointer<HyphenDict> _hyphenDict;
  final HyphenFfiBindings _bindings;
  final Allocator _allocator;
  final DictEncoding _dictEncoding;

  Hyphen._(
    this._hyphenDict,
    this._bindings,
    this._allocator,
    this._dictEncoding,
  );

  static Future<Hyphen> _fromDictionaryPathInternal(
    String path,
    HyphenFfiBindings bindings,
    Allocator allocator, {
    DictEncoding? encodingOverride,
  }) async {
    String filePath = await _prepareDictFile(path);

    final utf8Bytes = filePath.toNativeUtf8();
    final pathPtr = utf8Bytes.cast<Char>();
    final dict = bindings.hyphen_load(pathPtr);
    final encoding =
        encodingOverride ?? DictEncoding.fromUtf8IntValue(dict.ref.utf8);
    allocator.free(utf8Bytes);

    if (dict == nullptr) {
      throw InitializationException("Dictionary could not be loaded");
    }
    return Hyphen._(dict, bindings, allocator, encoding);
  }

  /// Loads a dictionary from the given [path] using the real
  /// [HyphenFfiBindings] and the default allocator ([calloc]).
  static Future<Hyphen> fromDictionaryPath(String path) async {
    final bindings = HyphenFfiBindings(_dylib);
    return _fromDictionaryPathInternal(path, bindings, calloc);
  }

  /// Loads a dictionary from [path] with injected [bindings] and [allocator].
  /// Intended for tests and custom setups.
  static Future<Hyphen> fromDictionaryPathWithBindingsAndAllocator(
    String path,
    HyphenFfiBindings bindings,
    Allocator allocator,
    DictEncoding encoding,
  ) async {
    return _fromDictionaryPathInternal(
      path,
      bindings,
      allocator,
      encodingOverride: encoding,
    );
  }

  static Future<String> _prepareDictFile(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final file = File('${Directory.systemTemp.path}/hyph_${data.hashCode}.dic');
    await file.writeAsBytes(data.buffer.asUint8List());
    return file.path;
  }

  /// Hyphenates [text] using either the `hnj_hyphen_hyphenate2` or the `hnj_hyphen_hyphenate3` API.
  /// Returns the hyphenated text parts as a [List<String>]
  List<String> hyphenate(
    String text, {
    int? lhmin,
    int? rhmin,
    int? clhmin,
    int? crhmin,
  }) {
    final hyphenationMarks = _getHyphenationMarks(
      text: text,
      lhmin: lhmin,
      rhmin: rhmin,
      clhmin: clhmin,
      crhmin: crhmin,
    );

    return HyphenUtils.applyHyphenationMarks(text, hyphenationMarks);
  }

  /// Hyphenates [text] using the legacy `hnj_hyphen_hyphenate2` API.
  /// Inserts [separator] at allowed break positions.
  String hnjHyphenate2(String text, {String separator = "="}) =>
      _hnjHyphenateLegacy(text: text, separator: separator);

  /// Hyphenates [text] using the extended `hnj_hyphen_hyphenate3` API.
  /// Allows tuning [lhmin], [rhmin], [clhmin], [crhmin] for min word lengths.
  String hnjHyphenate3(
    String text, {
    String separator = '=',
    int lhmin = 2,
    int rhmin = 3,
    int clhmin = 2,
    int crhmin = 3,
  }) => _hnjHyphenateLegacy(
    text: text,
    separator: separator,
    lhmin: lhmin,
    rhmin: rhmin,
    clhmin: clhmin,
    crhmin: crhmin,
  );

  /// Retrieves the hyphenation marks and passes them into [HyphenUtils.applyHyphenationMarksLegacy]
  /// to add the separators
  String _hnjHyphenateLegacy({
    required String text,
    required String separator,
    int lhmin = 2,
    int rhmin = 3,
    int clhmin = 2,
    int crhmin = 3,
  }) {
    final hyphenationMarks = _getHyphenationMarks(
      text: text,
      lhmin: lhmin,
      rhmin: rhmin,
      clhmin: clhmin,
      crhmin: crhmin,
    );

    return HyphenUtils.applyHyphenationMarksLegacy(
      text,
      hyphenationMarks,
      separator,
    );
  }

  /// Internal helper that performs the actual hyphenation call.
  ///
  /// - Allocates all required native buffers.
  /// - Invokes either `hnj_hyphen_hyphenate2` or `hnj_hyphen_hyphenate3`.
  /// - Returns the hyphenation marks that indicate where to insert hyphens
  /// - Ensures all allocated buffers are freed (even on error).
  List<int> _getHyphenationMarks({
    required String text,
    int? lhmin,
    int? rhmin,
    int? clhmin,
    int? crhmin,
  }) {
    final bytes =
        (_dictEncoding == DictEncoding.utf8)
            ? utf8.encode(text)
            : latin1.encode(text);

    final wordBuf = _allocator.allocate<Uint8>(
      (bytes.length + 1) * sizeOf<Uint8>(),
    );
    wordBuf.asTypedList(bytes.length).setAll(0, bytes);
    wordBuf[bytes.length] = 0;

    final hyphens = _allocator.allocate<Int8>(
      (bytes.length + 8) * sizeOf<Int8>(),
    );

    final wordPtr = wordBuf.cast<Char>();
    final wordLen = bytes.length;

    final useV3 =
        lhmin != null || rhmin != null || clhmin != null || crhmin != null;

    try {
      final result =
          useV3
              ? _bindings.hyphen_hyphenate3(
                _hyphenDict,
                wordPtr,
                wordLen,
                hyphens.cast<Char>(),
                lhmin ?? 0,
                rhmin ?? 0,
                clhmin ?? 0,
                crhmin ?? 0,
              )
              : _bindings.hyphen_hyphenate2(
                _hyphenDict,
                wordPtr,
                wordLen,
                hyphens.cast<Char>(),
              );

      if (result == 0) {
        return List.from(hyphens.asTypedList(wordLen));
      } else {
        throw Exception("Hyphenation failed with code $result");
      }
    } finally {
      _allocator.free(wordBuf);
      _allocator.free(hyphens);
    }
  }

  /// Frees the dictionary and releases native resources.
  /// Must be called when the instance is no longer needed.
  void dispose() {
    if (_hyphenDict != nullptr) {
      _bindings.hyphen_free(_hyphenDict);
      _hyphenDict = nullptr;
    }
  }

  /// The dynamic library in which the symbols for [HyphenFfiBindings] can be found.
  static final DynamicLibrary _dylib = () {
    final spec = resolveLibrarySpec(const IoPlatformInfo());
    if (spec is ProcessLibrary) return DynamicLibrary.process();
    if (spec is PathLibrary) {
      try {
        return DynamicLibrary.open(spec.path);
      } catch (_) {
        // Optional Windows fallback to PATH if local path failed:
        if (Platform.isWindows) return DynamicLibrary.open('hyphen_ffi.dll');
        rethrow;
      }
    }
    throw StateError('Unreachable');
  }();
}
