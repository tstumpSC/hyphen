# Hyphen

[![pub package](https://img.shields.io/pub/v/hyphen.svg)](https://pub.dev/packages/hyphen)
[![License: MIT + MPL 2.0](https://img.shields.io/badge/License-MIT%20+%20MPL--2.0-orange.svg)](#-license)

**Hyphen** is a cross-platform Flutter plugin that provides high-quality word hyphenation.  
It uses the [hunspell/hyphen](https://github.com/hunspell/hyphen) C library under the hood (via FFI) on native platforms, and a WebAssembly/JS runtime on the Web.

With `Hyphen`, you can automatically insert hyphenation marks into words based on language-specific rules.
By default, the plugin uses "=" as the separator, but you can configure it to use any custom separator you want.

---

## ✨ Features

- Works on **all Flutter platforms**: Android, iOS, macOS, Windows, Linux, Web
- Uses battle-tested [hyphen](https://github.com/hunspell/hyphen) dictionaries
- Two hyphenation APIs available:
  - `hnjHyphenate2` – classic hyphenation
  - `hnjHyphenate3` – extended API with additional options
- Unified API – always use the same `Hyphen` class, no matter the platform

---

## 📦 Installing

Add to your `pubspec.yaml`:

```yaml
dependencies:
  hyphen: ^0.1.0
```

Then run:

```bash
flutter pub get
```

---

## 📚 Dictionaries

`Hyphen` requires a `.dic` file for the language you want to hyphenate.  
These are not bundled due to licensing reasons.

👉 For instructions on how to obtain dictionary-files, see
[hunspell/hyphen](https://github.com/hunspell/hyphen)

Place your dictionary in your Flutter project under `assets/`, and declare it in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/hyph_en_US.dic
```

---

## 🚀 Usage

```dart
import 'package:hyphen/hyphen.dart';

Future<void> main() async {
  // Load a dictionary from assets
  final hyphen = await Hyphen.fromDictionaryPath('assets/hyph_en_US.dic');

  // Hyphenate a word
  final result = hyphen.hnjHyphenate2('hyphenation', separator: '-');
  print(result); // "hy-phen-ation"

  // Using the extended API
  final result2 = hyphen.hnjHyphenate3(
    'hyphenation',
    separator: '=',
    lhmin: 3,
    rhmin: 3,
  );
  print(result2); // "hyphen=ation"
}
```

---

## 🖥 Platform Notes

- **Android/iOS/macOS/Linux/Windows:** Uses the native hyphen lib via FFI.
- **Web:** Uses a WASM build of the hyphen lib via `hyphen.js`.
- On all platforms, you must provide your own `.dic` file.

---

## ⚠️ License

This package is dual-licensed:

- **Plugin code** (Dart, FFI bindings and wrappers): licensed under [MIT](./LICENSE).
- **Hyphenation engine**: incorporates code from [Hunspell/Hyphen](https://github.com/hunspell/hyphen),  
  which is licensed under the [Mozilla Public License (MPL)](./THIRD_PARTY_LICENSES.md).

Hyphenation **dictionaries** come with their own licenses – check the  
[hunspell/hyphen repo](https://github.com/hunspell/hyphen) before redistributing.

---

## 🤝 Contributing

Issues and pull requests are welcome!
