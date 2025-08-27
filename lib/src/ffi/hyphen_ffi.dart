import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:hyphen/src/utils.dart';

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
///   – [hnjHyphenate2] calls `hyphen_hyphenate2`.
///   – [hnjHyphenate3] calls `hyphen_hyphenate3` with tunable `lhmin`,
///     `rhmin`, `clhmin`, `crhmin` parameters.
///   – Both allocate scratch buffers, invoke the C API, then free memory.
///   – Raw hyphenation marks (0/1 bytes or ASCII '0'/'1') are normalized
///     through [HyphenUtils.applyHyphenationMarks] to insert separators
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
/// final result = hyphen.hnjHyphenate2('hyphenation');
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

  Hyphen._(this._hyphenDict, this._bindings, this._allocator);

  static Future<Hyphen> _fromDictionaryPathInternal(
    String path,
    HyphenFfiBindings bindings,
    Allocator allocator,
  ) async {
    String filePath = await _prepareDictFile(path);

    final utf8Bytes = filePath.toNativeUtf8();
    final pathPtr = utf8Bytes.cast<Char>();
    final dict = bindings.hyphen_load(pathPtr);
    allocator.free(utf8Bytes);

    if (dict == nullptr) {
      throw InitializationException("Dictionary could not be loaded");
    }
    return Hyphen._(dict, bindings, allocator);
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
  ) async {
    return _fromDictionaryPathInternal(path, bindings, allocator);
  }

  static Future<String> _prepareDictFile(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final file = File('${Directory.systemTemp.path}/hyph.dic');
    await file.writeAsBytes(data.buffer.asUint8List());
    return file.path;
  }

  /// Hyphenates [text] using the legacy `hnj_hyphen_hyphenate2` API.
  /// Inserts [separator] at allowed break positions.
  String hnjHyphenate2(String text, {String separator = "="}) =>
      _hnjHyphenateInternal(text: text, separator: separator);

  /// Hyphenates [text] using the extended `hnj_hyphen_hyphenate3` API.
  /// Allows tuning [lhmin], [rhmin], [clhmin], [crhmin] for min word lengths.
  String hnjHyphenate3(
    String text, {
    String separator = '=',
    int lhmin = 2,
    int rhmin = 3,
    int clhmin = 2,
    int crhmin = 3,
  }) => _hnjHyphenateInternal(
    text: text,
    separator: separator,
    useV3: true,
    lhmin: lhmin,
    rhmin: rhmin,
    clhmin: clhmin,
    crhmin: crhmin,
  );

  /// Internal helper that performs the actual hyphenation call.
  ///
  /// - Allocates all required native buffers.
  /// - Invokes either `hyphen_hyphenate2` or `hyphen_hyphenate3`.
  /// - Translates the returned hyphenation marks into a Dart string with
  ///   [separator] inserted at allowed positions.
  /// - Ensures all allocated buffers are freed (even on error).
  String _hnjHyphenateInternal({
    required String text,
    required String separator,
    bool useV3 = false,
    int lhmin = 2,
    int rhmin = 3,
    int clhmin = 2,
    int crhmin = 3,
  }) {
    final utf8Bytes = text.toNativeUtf8();
    final wordPtr = utf8Bytes.cast<Char>();
    final wordLen = utf8Bytes.length;

    final hyphens = _allocator.allocate<Int8>((wordLen + 8) * sizeOf<Int8>());

    try {
      final result =
          useV3
              ? _bindings.hyphen_hyphenate3(
                _hyphenDict,
                wordPtr,
                wordLen,
                hyphens.cast<Char>(),
                lhmin,
                rhmin,
                clhmin,
                crhmin,
              )
              : _bindings.hyphen_hyphenate2(
                _hyphenDict,
                wordPtr,
                wordLen,
                hyphens.cast<Char>(),
              );

      if (result == 0) {
        final marks = hyphens.asTypedList(wordLen);
        final out = HyphenUtils.applyHyphenationMarks(text, marks, separator);
        return out;
      } else {
        throw Exception("Hyphenation failed with code $result");
      }
    } finally {
      _allocator.free(utf8Bytes);
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
