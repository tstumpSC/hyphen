library;

/// Public entrypoint for the `hyphen` package.
///
/// Uses **conditional exports** to provide the correct implementation of
/// [Hyphen] depending on the platform:
///
/// - On non-web/VM platforms with no FFI or HTML: falls back to `hyphen_stub.dart`,
///   which throws `UnsupportedError`.
/// - On the Web: exports `hyphen_web.dart` (JS/WASM runtime).
/// - On native platforms with `dart:ffi`: exports `hyphen_ffi.dart`
///   (native library bindings).
///
/// Consumers just `import 'package:hyphen/hyphen.dart';` and always get a
/// `Hyphen` class appropriate for their platform.
export 'src/hyphen_stub.dart'
    if (dart.library.html) 'src/web/hyphen_web.dart'
    if (dart.library.ffi) 'src/ffi/hyphen_ffi.dart'
    show Hyphen;
