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