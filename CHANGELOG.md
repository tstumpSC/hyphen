## 0.4.0

Hyphenation is now implemented in pure Dart on every platform. The `dart:ffi`
bindings, the Emscripten JS/WASM runtime, the five native build trees, the
xcframework and the Swift Package Manager manifest are all gone.

This fixes the linker failures that broke release builds of apps consuming
this package through Swift Package Manager, by removing the native linking
step entirely.

Output is unchanged. The port was verified by running 9,260,124
`(dictionary, parameter set, word)` cases through both the old C
implementation and the new Dart one and requiring identical public API
output — 18 dictionaries (3 locally-supplied, 6 downloaded, 9 synthetic
hazard fixtures), 6 parameter sets, real words in 6 languages (German,
English, Hungarian, Dutch, Swedish, Catalan) plus a generated fuzz set.
Zero mismatches on every dictionary, checked both against raw mark vectors
and against public API output, on both sides of an identical 90,264-record
error count.

### Added
- `Hyphen.fromDictionaryBytes(List<int> bytes)` — synchronous, needs no
  Flutter asset bundle.

### Changed
- The package is no longer a Flutter plugin, just a Flutter package. It
  declares no platform implementations.
- `dispose()` is now a no-op. It is retained so existing calls compile.
- Dropped dependencies: `ffi`, `web`, `http`, `path` and
  `plugin_platform_interface`, plus the `ffigen` dev dependency. The only
  remaining runtime dependencies are `flutter` and `characters`.

### Removed
- **Breaking:** `Hyphen.fromDictionaryPathWithBindingsAndAllocator` — it
  existed only to inject FFI bindings and an allocator, neither of which
  exists now.

### Known issues
- On text containing decomposed combining accents (`e` + U+0301), marks can
  be misaligned by one position. This bug predates 0.4.0 and is reproduced
  deliberately here so the port could be verified against the old behaviour;
  it is not a regression, and it will be fixed separately.
- `hnjHyphenate2`/`hnjHyphenate3` remain `@Deprecated` since 0.2.0; the port
  keeps those markers.
- Non-standard hyphenation output is discarded. The engine can produce the
  linguistically correct `asz=szony` for Hungarian *asszony*, but the
  shipped path yields `as=szony`, because the C wrapper passed `NULL` for
  `hyphword` and threw away the alternate spelling it computed. The port
  reproduces that exactly — a limitation of every release to date, not a
  regression introduced here.

## 0.3.1
- Restored the Flutter SDK constraint to `>=3.3.0`. The `>=3.41.0` bump in 0.3.0 was unnecessary: adding a `Package.swift` is additive, and Flutter versions without Swift Package Manager support simply fall back to CocoaPods.

## 0.3.0
- Added Swift Package Manager (SPM) support for iOS and macOS, alongside the existing CocoaPods integration

## 0.2.1
- Added linker flags to Android build script for 16KB page size support
- Added recompiled Android binaries with 16KB page size support
- Minor layout fix in example project

## 0.2.0
**Breaking changes:** 
- Added unified API for hnjHyphenate2 and hnjHyphenate3
- `hnjHyphenate2` → `hyphenate`
- `hnjHyphenate3` → `hyphenate`
- Returns List<String> instead of a single String filled with separators

_Migration:_
- `hnjHyphenate2(word)` → `hyphenate(word)`
- `hnjHyphenate3(word, lhmin: 3, rhmin: 4)` → `hyphenate(text, lhmin: 3, rhmin: 4)`

Non-breaking changes:
- Optimized reading the dictionary encoding
- Fixed a bug that occurred when creating multiple Hyphen instances on Web

## 0.1.4
- Added more detailed instructions on how to obtain dictionary files
- Removed any mentions of "Hyphenator" (which was the plugin's working title)

## 0.1.3
- Added support for UTF-8-encoded dictionary files

## 0.1.2
- Fixed formatting issues

## 0.1.1
- Removed unnecessary analysis options
- Fixed warnings caused by using "<>" in doc comments

## 0.1.0

- Initial release of **Hyphen** 🎉
- Cross-platform hyphenation for **Flutter**:
    - **iOS, Android, macOS, Windows, Linux** via `dart:ffi`
    - **Web** via JavaScript/WASM runtime
- Support for both **`hnj_hyphenate2`** and **`hnj_hyphenate3`** modes
- Utility to apply hyphenation marks and insert custom separators
- Documentation and minimal examples included