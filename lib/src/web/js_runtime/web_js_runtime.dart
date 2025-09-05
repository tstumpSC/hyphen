import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:web/web.dart' as web;

import '../../utils.dart';
import '../hyphen_web_bindings.dart';
import 'js_runtime.dart';

/// Concrete implementation of [JsHyphenRuntime] that talks to the actual
/// Emscripten-compiled Hyphenation WASM module in the browser.
///
/// Wraps calls to `ccall`, `_malloc`, `_free`, and direct access
/// to the `HEAPU8` buffer.
class WebJsHyphenRuntime implements JsHyphenRuntime {
  final JSObject _module;

  WebJsHyphenRuntime._(this._module);

  /// Initializes the runtime by:
  /// - downloading the dictionary at [dictionaryPath],
  /// - injecting it into the virtual FS of the WASM module,
  /// - and invoking `ffi_hyphen_load` to obtain a [dictPointer].
  /// Returns runtime and [dictPointer]
  ///
  /// Throws [InitializationException] if the dictionary cannot be loaded.
  static Future<
    ({WebJsHyphenRuntime runtime, int dictPointer, DictEncoding dictEncoding})
  >
  initializeWithDictionary(String dictionaryPath) async {
    final resp = await http.get(Uri.parse(dictionaryPath));
    final bytes = Uint8List.view(resp.bodyBytes.buffer);

    await HyphenScriptLoader.load();
    final module = await HyphenModule.instance();

    final fileName = '/${p.basename(dictionaryPath)}';
    injectDicFile(module, fileName.toJS, JSUint8Array(bytes.buffer.toJS));

    final dictEncoding = _parseDicEncodingFromBytes(bytes);

    final dictPointer =
        (_ccall(module).callAsFunction(
                  module,
                  'hyphen_load'.toJS,
                  'number'.toJS,
                  <JSString>['string'.toJS].toJS,
                  <JSString>['/$fileName'.toJS].toJS,
                )
                as JSNumber)
            .toDartInt;

    if (dictPointer == 0) {
      throw InitializationException('Dictionary could not be loaded');
    }
    return (
      runtime: WebJsHyphenRuntime._(module),
      dictPointer: dictPointer,
      dictEncoding: dictEncoding,
    );
  }

  static DictEncoding _parseDicEncodingFromBytes(Uint8List bytes) {
    int nl = bytes.indexOf(0x0A);
    int end = (nl >= 0) ? nl : bytes.length;
    if (end > 0 && bytes[end - 1] == 0x0D) end--;

    final header =
        ascii
            .decode(bytes.sublist(0, end), allowInvalid: true)
            .trim()
            .toUpperCase();

    return DictEncoding.fromString(header);
  }

  /// Allocates [size] bytes on the WASM heap.
  @override
  int malloc(int size) =>
      (_malloc(_module).callAsFunction(size.toJS) as JSNumber).toDartInt;

  /// Frees a previously allocated pointer [ptr].
  @override
  void free(int ptr) => _free(_module).callAsFunction(ptr.toJS);

  /// Calls an exported WASM function [fn] using Emscripten’s `ccall`.
  ///
  /// Converts Dart [argTypes] and [args] into JS values before dispatching.
  @override
  int ccall(String fn, List<String?> argTypes, List<Object?> args) {
    final bound = _ccall(_module);
    final jsArgTypes = argTypes.map((s) => s?.toJS).toList().toJS;
    final jsArgs =
        args
            .map<JSAny>((a) {
              if (a is int) return a.toJS;
              if (a is String) return a.toJS;
              throw ArgumentError('Unsupported arg: $a');
            })
            .toList()
            .toJS;

    return (bound.callAsFunction(
              _module,
              fn.toJS,
              'number'.toJS,
              jsArgTypes,
              jsArgs,
            )
            as JSNumber)
        .toDartInt;
  }

  /// Reads a single byte at [index] from the WASM heap (`HEAPU8`).
  @override
  int heapAt(int index) {
    final heapU8 = _module.getProperty('HEAPU8'.toJS) as JSObject;
    return (heapU8.callMethod('at'.toJS, <JSAny>[index.toJS].toJS) as JSNumber)
        .toDartInt;
  }

  /// Writes a single byte into the WebAssembly heap.
  @override
  void heapSet(int index, int value) {
    final heapU8 = _module.getProperty('HEAPU8'.toJS) as JSObject;
    heapU8.setProperty(index.toString().toJS, value.toJS);
  }

  /// Binds the module’s `ccall` function.
  static JSFunction _ccall(JSObject module) =>
      (module.getProperty('ccall'.toJS) as JSFunction).callMethod(
            'bind'.toJS,
            module,
          )
          as JSFunction;

  /// Binds the module’s `_malloc` function.
  static JSFunction _malloc(JSObject module) =>
      (module.getProperty('_malloc'.toJS) as JSFunction).callMethod(
            'bind'.toJS,
            module,
          )
          as JSFunction;

  /// Binds the module’s `_free` function.
  static JSFunction _free(JSObject module) =>
      (module.getProperty('_free'.toJS) as JSFunction).callMethod(
            'bind'.toJS,
            module,
          )
          as JSFunction;

  @override
  void dispose(int dictPointer) {
    _ccall(_module).callAsFunction(
      _module,
      'hyphen_free'.toJS,
      'void'.toJS,
      ['number'.toJS].toJS,
      [dictPointer.toJS].toJS,
    );
  }
}

/// Loads the Emscripten `hyphen.js` script once and ensures that
/// the global `createHyphenModule` factory is available.
class HyphenScriptLoader {
  static Future<void>? _pendingInjection;

  static Future<void> load() {
    if (_isAlreadyLoaded()) return Future.value();
    return _pendingInjection ??= _injectAndWait();
  }

  static bool _isAlreadyLoaded() {
    final v = globalContext.getProperty('createHyphenModule'.toJS);
    return v != null && v is JSFunction;
  }

  static Future<void> _injectAndWait() {
    final c = Completer<void>();

    final script =
        web.HTMLScriptElement()
          ..src = 'assets/packages/hyphen/web/assets/hyphen.js'
          ..type = 'text/javascript';

    // NOTE: convert Dart closures to JSFunction with .toJS
    script.addEventListener(
      'load',
      (JSAny? _) {
        if (_isAlreadyLoaded()) {
          c.complete();
        } else {
          c.completeError(
            StateError('createHyphenModule not found after hyphen.js load'),
          );
        }
      }.toJS,
    );

    script.addEventListener(
      'error',
      (JSAny? _) {
        c.completeError(StateError('Failed to load hyphen.js'));
      }.toJS,
    );

    web.document.head!.append(script);
    return c.future;
  }
}

/// Wraps the `createHyphenModule` factory to guarantee that the
/// module is only instantiated once and shared across callers.
class HyphenModule {
  HyphenModule._();

  static JSObject? _module;
  static Future<JSObject>? _pendingInstance;

  static Future<JSObject> instance() {
    if (_module != null) {
      return Future.value(_module);
    }
    if (_pendingInstance != null) {
      return _pendingInstance!;
    }

    _pendingInstance = _create();
    return _pendingInstance!;
  }

  static Future<JSObject> _create() async {
    try {
      final module = await createHyphenModule().toDart;
      _module = module;
      return module;
    } catch (e) {
      _pendingInstance = null;
      rethrow;
    } finally {
      _pendingInstance = null;
    }
  }
}
