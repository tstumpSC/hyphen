import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:hyphen/src/utils.dart';

import 'js_runtime/js_runtime.dart';
import 'js_runtime/loader/js_runtime_loader.dart';
import 'js_runtime/loader/js_runtime_loader_facade.dart';

/// Hyphen Web/JS wrapper.
///
/// This class provides a Dart interface to the `libhyphen` hyphenation
/// engine when compiled to Web. Instead of FFI, it delegates to a
/// [JsHyphenRuntime], which bridges to the underlying WebAssembly (via
/// Emscripten’s `ccall`, `malloc`, and `HEAPU8`).
///
/// * **Dictionary loading**
///   – [fromDictionaryPath] loads a `.dic` file from a given URL, injects it
///     into the in-memory FS, and calls `hyphen_load` through the runtime.
///   – A `JsRuntimeLoader` can be passed in to customize module creation
///     (defaults to [getDefaultJsLoader]).
///   – If the native load returns `0`, an [InitializationException] is thrown.
///
/// * **Hyphenation**
///   – [hnjHyphenate2] calls `hyphen_hyphenate2`.
///   – [hnjHyphenate3] calls `hyphen_hyphenate3` with tunable parameters
///     (`lhmin`, `rhmin`, `clhmin`, `crhmin`).
///   – Both allocate temporary buffers in the WASM heap, pass them to the C
///     API, then free them afterward.
///   – Raw hyphenation marks are read back from the WASM heap as ASCII bytes
///     (`'0'`/`'1'`) or numeric values, then normalized by
///     [HyphenUtils.applyHyphenationMarks] to insert the chosen separator.
///
/// * **Memory management**
///   – Uses the runtime’s `malloc` and `free` to manage heap pointers.
///   – Ensures buffers are freed in a `finally` block even on errors.
///
/// * **Testing**
///   – [forTest] allows constructing a [Hyphen] with an injected
///     [JsHyphenRuntime] and a dummy dictionary pointer.
///   – This makes the hyphenation logic testable on the Dart VM without a
///     browser or actual WASM module.
///
/// ### Example
/// ```dart
/// final hyphen = await Hyphen.fromDictionaryPath('assets/hyph_en_US.dic');
/// final result = hyphen.hnjHyphenate2('hyphenation');
/// print(result); // e.g. "hy-phen-ation"
/// ```
///
/// Throws [InitializationException] if the dictionary cannot be loaded,
/// or [Exception] if the underlying hyphenation call fails.

class Hyphen {
  final JsHyphenRuntime _runtime;
  int _dictPtr;
  final DictEncoding _dictEncoding;

  Hyphen._(this._runtime, this._dictPtr, this._dictEncoding);

  /// Loads a dictionary from the given [assetPath] into the WASM module
  /// using the provided [JsRuntimeLoader] or the default loader.
  /// Throws [InitializationException] if the dictionary could not be loaded.
  static Future<Hyphen> fromDictionaryPath(
    String assetPath, {
    JsRuntimeLoader? loader,
  }) async {
    final l = loader ?? getDefaultJsLoader();
    final result = await l.load(assetPath);
    if (result.dictPointer == 0) {
      throw InitializationException('Dictionary could not be loaded');
    }
    return Hyphen._(result.runtime, result.dictPointer, result.dictEncoding);
  }

  /// Creates a [Hyphen] with a provided [JsHyphenRuntime] and optional
  /// [dictPtr] for tests. Useful for running on Dart VM without a browser.
  static Hyphen forTest(JsHyphenRuntime runtime, {int dictPtr = 1}) =>
      Hyphen._(runtime, dictPtr, DictEncoding.iso8859);

  /// Hyphenates [text] using the `hyphen_hyphenate2` API.
  /// Inserts [separator] at valid break positions.
  String hnjHyphenate2(String text, {String separator = "="}) =>
      _hnjHyphenateInternal(text: text, separator: separator, useV3: false);

  /// Hyphenates [text] using the extended `hnj_hyphen_hyphenate3` API.
  /// Allows tuning [lhmin], [rhmin], [clhmin], [crhmin] for min word lengths.
  String hnjHyphenate3(
    String text, {
    String separator = "=",
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
  /// - Computes UTF-8 byte length of [text].
  /// - Allocates JS/WASM heap buffers for hyphenation results.
  /// - Invokes either `hyphen_hyphenate2` or `hyphen_hyphenate3`
  ///   through the [_runtime].
  /// - Reads hyphenation marks from the WASM heap and applies them
  ///   via [HyphenUtils.applyHyphenationMarks].
  /// - Always frees heap allocations, even if the call fails.
  String _hnjHyphenateInternal({
    required String text,
    required String separator,
    bool useV3 = false,
    int lhmin = 2,
    int rhmin = 3,
    int clhmin = 2,
    int crhmin = 3,
  }) {
    if (_dictEncoding == DictEncoding.utf8) {
      final wordSize = utf8.encode(text).length;

      final hyphensPtr = _runtime.malloc(wordSize + 8);

      try {
        final result = _runtime.ccall(
          useV3 ? 'hyphen_hyphenate3' : 'hyphen_hyphenate2',
          [
            'number', // dictPtr
            'string', // text
            'number', // wordSize
            'number', // hyphensPtr
            if (useV3) ...[
              'number', // lhmin
              'number', // rhmin
              'number', // clhmin
              'number', // crhmin
            ],
          ],
          [
            _dictPtr,
            text,
            wordSize,
            hyphensPtr,
            if (useV3) ...[lhmin, rhmin, clhmin, crhmin],
          ],
        );

        if (result != 0) {
          throw Exception('Hyphenation failed with code $result');
        }

        // Read marks from the runtime’s heap (ASCII digits or numeric bytes).
        final marks = <int>[];
        for (var i = 0; i < wordSize; i++) {
          final b = _runtime.heapAt(hyphensPtr + i);
          if (b == 0) break; // stop at NUL
          marks.add(b);
        }

        return HyphenUtils.applyHyphenationMarks(text, marks, separator);
      } finally {
        _runtime.free(hyphensPtr);
      }
    } else {
      final wordBytes = Uint8List.fromList(latin1.encode(text));
      final wordSize = wordBytes.length;
      final wordPtr = _runtime.malloc(wordSize + 1);

      for (var i = 0; i < wordSize; i++) {
        _runtime.heapSet(wordPtr + i, wordBytes[i]);
      }
      _runtime.heapSet(wordPtr + wordSize, 0);
      final hyphensPtr = _runtime.malloc(wordSize + 8);

      try {
        final result = _runtime.ccall(
          useV3 ? 'hyphen_hyphenate3' : 'hyphen_hyphenate2',
          [
            'number', // dictPtr
            'number', // wordPtr
            'number', // wordLen
            'number',
            if (useV3) ...[
              'number', // lhmin
              'number', // rhmin
              'number', // clhmin
              'number', // crhmin
            ],
          ],
          [
            _dictPtr,
            wordPtr,
            wordSize,
            hyphensPtr,
            if (useV3) ...[lhmin, rhmin, clhmin, crhmin],
          ],
        );

        if (result != 0) {
          throw Exception('Hyphenation failed with code $result');
        }

        final marks = List<int>.generate(
          wordSize,
          (i) => _runtime.heapAt(hyphensPtr + i),
        );
        return HyphenUtils.applyHyphenationMarks(text, marks, separator);
      } finally {
        _runtime.free(wordPtr);
        _runtime.free(hyphensPtr);
      }
    }
  }

  /// Frees the dictionary and releases native resources.
  /// Must be called when the instance is no longer needed.
  void dispose() {
    final ptr = _dictPtr;
    if (ptr == 0) return; // already freed
    _runtime.dispose(ptr);
    _dictPtr = 0;
  }
}
