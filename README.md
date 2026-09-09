# Hyphen

[![pub package](https://img.shields.io/pub/v/hyphen.svg)](https://pub.dev/packages/hyphen)
[![License: MIT + MPL 2.0](https://img.shields.io/badge/License-MIT%20+%20MPL--2.0-orange.svg)](#-license)

**Hyphen** is a cross-platform Flutter package that provides high-quality word hyphenation,
implemented in pure Dart. The same code runs on every platform Flutter supports — there is no
native library to build and nothing to link.

The engine is a Dart port of [hunspell/hyphen](https://github.com/hunspell/hyphen), the
TeX-pattern hyphenation library originally cut from libHnj for OpenOffice.org. It reads the same
`hyph_*.dic` dictionaries and was verified against the original C implementation over 9.26 million
cases across 18 dictionaries, so output is identical rather than merely similar.

With Hyphen, you can split words into their hyphenation parts according to language-specific
rules. The API returns a `List<String>` where each element is a chunk of the word between possible
hyphenation points.

---

## ❗️ Breaking change in v0.4.0

- The `dart:ffi` bindings, the Emscripten JS/WASM runtime, the native build trees, and the
  `Hyphen.fromDictionaryPathWithBindingsAndAllocator` constructor are all gone. See the
  [Changelog](./CHANGELOG.md) for details.

---

## ✨ Features

- Works on **all Flutter platforms**: Android, iOS, macOS, Windows, Linux, Web — one pure-Dart
  implementation, no platform-specific builds
- Uses battle-tested [hyphen](https://github.com/hunspell/hyphen) dictionaries
- Combines hunspell/hyphen's two hyphenation APIs `hnj_hyphen_hyphenate2` and `hnj_hyphen_hyphenate3`
  into a single `hyphenate` function
- Unified API for all platforms – always use the same `Hyphen` class, no matter the platform

---

## 📦 Installing

Add to your `pubspec.yaml`:

```yaml
dependencies:
  hyphen: ^0.4.0
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

### Loading a dictionary

From a Flutter asset:

```dart
final hyphen = await Hyphen.fromDictionaryPath('assets/hyph_en_US.dic');
```

From bytes, with no asset bundle — usable in plain Dart, tests and CLI tools:

```dart
import 'dart:io';

final hyphen = Hyphen.fromDictionaryBytes(File('hyph_en_US.dic').readAsBytesSync());
```

---

## 🖥 Platform Notes

Hyphen is a pure-Dart package. It runs identically on Android, iOS, macOS, Windows, Linux and
Web — there is no native library to build, no platform-specific plugin implementation, and
nothing to link. On every platform, you must still provide your own `.dic` file; see
Dictionaries above.

---

## ⚠️ License

This package is dual-licensed:

- **Package code** (the public API, dictionary loading and hyphenation engine): licensed under
  [MIT](./LICENSE).
- A small number of files are a Dart port of [Hunspell/Hyphen](https://github.com/hunspell/hyphen)
  C sources and remain covered by that project's license. See
  [THIRD_PARTY_LICENSES.md](./THIRD_PARTY_LICENSES.md) for exactly which files and terms.

Hyphenation **dictionaries** come with their own licenses – check the
[hunspell/hyphen repo](https://github.com/hunspell/hyphen) before redistributing.

---

## 🤝 Contributing

Issues and pull requests are welcome!
