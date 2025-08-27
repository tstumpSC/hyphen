import 'dart:io';

/// Cross-platform dynamic library resolver for hyphen_ffi.
///
/// This file centralizes how the plugin decides which native library to load:
/// – macOS / iOS → [ProcessLibrary] (symbols linked into process).
/// – Android     → [PathLibrary]('libhyphen_ffi.so') (NDK loader handles lookup).
/// – Linux       → [PathLibrary]('../linux/$arch/libhyphen_ffi.so'), with
///                 `<arch>` detected from [PlatformInfo.version] (x64/arm64).
/// – Windows     → [PathLibrary]('$exeDir/hyphen_ffi.dll'), side-by-side DLL.
/// – Env override: if HYF_LIB_PATH is set, that path always wins.
///
/// The [LibrarySpec] sealed class describes what to open:
/// * [ProcessLibrary] — use [DynamicLibrary.process()].
/// * [PathLibrary]    — open the file at [PathLibrary.path] via [DynamicLibrary.open(String path)].
///
/// [PlatformInfo] abstracts the subset of [dart:io.Platform] we need.
/// This makes the resolver unit-testable: inject a fake platform in tests
/// and verify the correct [LibrarySpec] is returned without depending on the
/// actual host OS. [IoPlatformInfo] is the real implementation backed by
/// [dart:io.Platform].
///
/// Typical usage:
///
/// ```dart
/// final spec = resolveLibrarySpec(const IoPlatformInfo());
/// final dylib = switch (spec) {
///   ProcessLibrary _ => DynamicLibrary.process(),
///   PathLibrary p    => DynamicLibrary.open(p.path),
/// };
/// ```
///
/// CI / local testing can point to a custom artifact with:
///
/// ```bash
/// HYF_LIB_PATH=/abs/path/to/libhyphen_ffi.so flutter test
/// ```
///
/// Throws [UnsupportedError] or [Exception] on unknown platforms/archs.

LibrarySpec resolveLibrarySpec(PlatformInfo p) {
  // Optional env override makes CI/tests easy.
  final override = p.environment['HYF_LIB_PATH'];
  if (override != null && override.isNotEmpty) {
    return PathLibrary(override);
  }

  if (p.isMacOS || p.isIOS) {
    return const ProcessLibrary();
  } else if (p.isAndroid) {
    return const PathLibrary('libhyphen_ffi.so');
  } else if (p.isLinux) {
    final arch = p.version.contains('x64')
        ? 'x64'
        : p.version.contains('arm64')
        ? 'arm64'
        : (throw UnsupportedError('Unsupported Linux architecture'));
    return PathLibrary('../linux/$arch/libhyphen_ffi.so');
  } else if (p.isWindows) {
    final fname = 'hyphen_ffi.dll';
    final exeDir = File(p.resolvedExecutable).parent.path;
    final localPath = '$exeDir/$fname';
    return PathLibrary(localPath);
  } else {
    throw Exception('Unsupported platform detected');
  }
}

/// What to open.
sealed class LibrarySpec {
  const LibrarySpec();
}
class ProcessLibrary extends LibrarySpec {
  const ProcessLibrary();
}
class PathLibrary extends LibrarySpec {
  final String path;
  const PathLibrary(this.path);
}

/// Minimal platform surface we can fake in tests.
abstract class PlatformInfo {
  bool get isMacOS;
  bool get isIOS;
  bool get isAndroid;
  bool get isLinux;
  bool get isWindows;
  String get resolvedExecutable;
  String get version; // used for arch sniffing in your code
  Map<String, String> get environment;
}

/// Real implementation backed by dart:io Platform.
class IoPlatformInfo implements PlatformInfo {
  const IoPlatformInfo();
  @override bool get isMacOS => Platform.isMacOS;
  @override bool get isIOS => Platform.isIOS;
  @override bool get isAndroid => Platform.isAndroid;
  @override bool get isLinux => Platform.isLinux;
  @override bool get isWindows => Platform.isWindows;
  @override String get resolvedExecutable => Platform.resolvedExecutable;
  @override String get version => Platform.version;
  @override Map<String, String> get environment => Platform.environment;
}
