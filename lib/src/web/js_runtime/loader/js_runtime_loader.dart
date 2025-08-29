import 'package:hyphen/src/utils.dart';

import '../js_runtime.dart';

/// Abstraction for loading a [JsHyphenRuntime] and its associated
/// dictionary pointer from a given [assetPath].
///
/// Different implementations exist for different platforms:
/// - `_WebLoader`: for `dart:js_interop` (runs in browser, loads hyphen.js/wasm)
/// - `_StubLoader`: for non-web platforms, always throws
abstract class JsRuntimeLoader {
  /// Loads the runtime and dictionary from [assetPath].
  ///
  /// Returns a tuple `(JsHyphenRuntime runtime, int dictPtr)`.
  /// Throws an exception if the dictionary cannot be loaded.
  Future<
    ({JsHyphenRuntime runtime, int dictPointer, DictEncoding dictEncoding})
  >
  load(String assetPath);
}
