import 'package:hyphen/src/utils.dart';

import '../js_runtime.dart';
import 'js_runtime_loader.dart';

/// Stub loader used on non-web platforms.
///
/// Always throws, because the JS/WASM runtime is only available in browsers.
/// This makes test/VM builds fail fast if someone tries to call into it.
class _StubLoader implements JsRuntimeLoader {
  @override
  Future<
    ({JsHyphenRuntime runtime, int dictPointer, DictEncoding dictEncoding})
  >
  load(String assetPath) async {
    throw UnsupportedError('Web runtime not available on this platform.');
  }
}

JsRuntimeLoader getDefaultJsLoader() => _StubLoader();
