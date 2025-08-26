// Conditional export:
// - when dart.library.js_interop is available (web build),
//   `js_runtime_loader_web.dart` is used.
// - otherwise, `js_runtime_loader_stub.dart` is used.

export 'js_runtime_loader_stub.dart'
if (dart.library.js_interop) 'js_runtime_loader_web.dart';
