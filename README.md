# Hyphen

[![pub package](https://img.shields.io/pub/v/hyphen.svg)](https://pub.dev/packages/hyphen)
[![License: MIT + MPL 2.0](https://img.shields.io/badge/License-MIT%20+%20MPL--2.0-orange.svg)](#-license)

**Hyphen** is a cross-platform Flutter plugin that provides high-quality word hyphenation.  
It uses the [hunspell/hyphen](https://github.com/hunspell/hyphen) C library under the hood (via FFI)
on native platforms, and a WebAssembly/JS runtime on the Web.

With Hyphen, you can split words into their hyphenation parts according to language-specific
rules. The API returns a List<String> where each element is a chunk of the word between possible
hyphenation points.

---

## ❗️ Breaking change in v0.2.0

- See [Changelog](./CHANGELOG.md) for details

---

## ✨ Features

- Works on **all Flutter platforms**: Android, iOS, macOS, Windows, Linux, Web
- Uses battle-tested [hyphen](https://github.com/hunspell/hyphen) dictionaries
- Combines hunspell/hyphen's two hyphenation APIs `hnj_hyphen_hyphenate2`and `hnj_hyphen_hyphenate3`
  into a single `hyphenate` function
- Unified API for all platforms – always use the same `Hyphen` class, no matter the platform

---

## 📦 Installing

Add to your `pubspec.yaml`:

```yaml
dependencies:
  hyphen: ^0.2.0
```

Then run:

```bash
flutter pub get
```

---

## 📚 Dictionaries

`Hyphen` requires a `.dic` file for the language you want to hyphenate.\
These are not bundled due to licensing reasons.

👉 You need to generate or obtain these `.dic` files yourself.

### Where to get dictionary files

Hyphenation dictionaries are created from **TeX hyphenation pattern
files** (commonly available on [CTAN](https://ctan.org/tex-archive/language/hyph-utf8)
and other TeX distribution sources).

------------------------------------------------------------------------

### 🔨 Step-by-step Example: English (US)

1. Download the pattern file
   [`hyph-en-us.tex`](https://satztexnik.com/tex-archive/language/hyph-utf8/tex/patterns/tex/hyph-en-us.tex)

2. Run the `substrings.pl` script (from
   [hunspell/hyphen](https://github.com/hunspell/hyphen)):

   ``` bash
   perl substrings.pl hyph-en-us.tex hyph_en_US.dic UTF-8
   ```

   This generates a file called `hyph_en_US.dic`.

3. Add the file to your Flutter project:

       assets/hyph_en_US.dic

4. Declare it in `pubspec.yaml`:

   ``` yaml
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
  final result = hyphen.hyphenate('hyphenation');
  print(result); // ["hy", "phen", "ation"]

  // Using the additional parameters to define a minimum distance from the start/end of the word
  // to the first break
  final result2 = hyphen.hyphenate(
    'hyphenation',
    lhmin: 3,
    rhmin: 3,
  );
  print(result2); // ["hyphen", "ation"]
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
- **Hyphenation engine**: incorporates code
  from [Hunspell/Hyphen](https://github.com/hunspell/hyphen),
  which is licensed under the [Mozilla Public License (MPL)](./THIRD_PARTY_LICENSES.md).

Hyphenation **dictionaries** come with their own licenses – check the  
[hunspell/hyphen repo](https://github.com/hunspell/hyphen) before redistributing.

---

## 🤝 Contributing

Issues and pull requests are welcome!
