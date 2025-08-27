@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/src/ffi/dynamic_library_loader.dart';

class FakePlatform implements PlatformInfo {
  FakePlatform({
    this.macOS = false,
    this.iOS = false,
    this.android = false,
    this.linux = false,
    this.windows = false,
    this.resolvedExecutable = '/tmp/dart',
    this.version = 'Dart VM x64',
    Map<String, String>? environment,
  }) : environment = environment ?? {};
  final bool macOS, iOS, android, linux, windows;

  @override
  bool get isMacOS => macOS;

  @override
  bool get isIOS => iOS;

  @override
  bool get isAndroid => android;

  @override
  bool get isLinux => linux;

  @override
  bool get isWindows => windows;
  @override
  String resolvedExecutable;
  @override
  String version;
  @override
  Map<String, String> environment;
}

void main() {
  test('env override wins', () {
    final p = FakePlatform(
      environment: {'HYF_LIB_PATH': '/abs/custom/libhyphen_ffi.so'},
      linux: true,
    );
    final spec = resolveLibrarySpec(p);
    expect(spec, isA<PathLibrary>());
    expect((spec as PathLibrary).path, '/abs/custom/libhyphen_ffi.so');
  });

  test('macOS/iOS uses process library', () {
    expect(
      resolveLibrarySpec(FakePlatform(macOS: true)),
      isA<ProcessLibrary>(),
    );
    expect(resolveLibrarySpec(FakePlatform(iOS: true)), isA<ProcessLibrary>());
  });

  test('Android path', () {
    final spec = resolveLibrarySpec(FakePlatform(android: true));
    expect((spec as PathLibrary).path, 'libhyphen_ffi.so');
  });

  test('Linux x64 path', () {
    final spec = resolveLibrarySpec(
      FakePlatform(linux: true, version: 'Dart VM 3.5.0 (x64)'),
    );
    expect((spec as PathLibrary).path, '../linux/x64/libhyphen_ffi.so');
  });

  test('Linux arm64 path', () {
    final spec = resolveLibrarySpec(
      FakePlatform(linux: true, version: 'Dart VM (arm64)'),
    );
    expect((spec as PathLibrary).path, '../linux/arm64/libhyphen_ffi.so');
  });

  test('Windows local-first path', () {
    final spec = resolveLibrarySpec(
      FakePlatform(windows: true, resolvedExecutable: r'C:\Dart\bin\dart.exe'),
    );
    expect((spec as PathLibrary).path, './hyphen_ffi.dll');
  });
}
