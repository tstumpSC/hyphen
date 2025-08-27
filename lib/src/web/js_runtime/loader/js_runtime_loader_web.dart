import '../js_runtime.dart';
import '../web_js_runtime.dart';
import 'js_runtime_loader.dart';

/// Web loader used when running with `dart:js_interop`.
///
/// Creates a [WebJsHyphenRuntime] and loads the dictionary at [assetPath].
class _WebLoader implements JsRuntimeLoader {
  @override
  Future<({JsHyphenRuntime runtime, int dictPointer})> load(
    String assetPath,
  ) async => await WebJsHyphenRuntime.initializeWithDictionary(assetPath);
}

/// Returns the default runtime loader for the current platform.
///
/// - On web: returns a [_WebLoader].
/// - On non-web: returns a [_StubLoader].
JsRuntimeLoader getDefaultJsLoader() => _WebLoader();
