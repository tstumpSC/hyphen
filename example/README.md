# hyphen_example

Demonstrates how to use the `hyphen` package.

## Dictionaries

This example is not runnable from a fresh checkout until you supply
dictionary files: `pubspec.yaml` declares `assets/` as a Flutter asset
directory, but `.dic` files are third-party licensed and are not committed
(`.gitignore` ignores `/assets/`).

Create `example/assets/` and add the two files `lib/main.dart` loads
(lines 76 and 79) before running the app:

- `hyph_de_DE_UTF.dic` (UTF-8-encoded German)
- `hyph_de_DE.dic` (ISO8859-1-encoded German)

See the "Dictionaries" section of the root [README](../README.md) for how to
obtain or generate them. Without `example/assets/` present, `flutter analyze` reports
an `asset_directory_does_not_exist` warning and the app fails at runtime
when it tries to load a dictionary — both expected until the files are in
place.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
