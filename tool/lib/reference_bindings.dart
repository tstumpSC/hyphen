import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Mirrors the head of `struct _HyphenDict` (hyphen.h) up to and including
/// `utf8`. Trailing fields (states, nextlevel) are not modelled — nothing
/// here needs them.
final class _HyphenDictHead extends Struct {
  @Int8() external int lhmin;
  @Int8() external int rhmin;
  @Int8() external int clhmin;
  @Int8() external int crhmin;
  external Pointer<Uint8> nohyphen;
  @Int32() external int nohyphenl;
  @Int32() external int numStates;
  @Array(20) external Array<Uint8> cset;
  @Int32() external int utf8;
}

typedef _LoadNative = Pointer<_HyphenDictHead> Function(Pointer<Utf8>);
typedef _FreeNative = Void Function(Pointer<_HyphenDictHead>);
typedef _FreeDart = void Function(Pointer<_HyphenDictHead>);

typedef _H2Native = Int32 Function(
    Pointer<_HyphenDictHead>, Pointer<Uint8>, Int32, Pointer<Uint8>);
typedef _H2Dart = int Function(
    Pointer<_HyphenDictHead>, Pointer<Uint8>, int, Pointer<Uint8>);

typedef _H3Native = Int32 Function(Pointer<_HyphenDictHead>, Pointer<Uint8>,
    Int32, Pointer<Uint8>, Int32, Int32, Int32, Int32);
typedef _H3Dart = int Function(Pointer<_HyphenDictHead>, Pointer<Uint8>, int,
    Pointer<Uint8>, int, int, int, int);

class ReferenceHyphen {
  /// Resolves [dylibPath] to an absolute path before opening it. A
  /// hardened-runtime-signed `dart` (the default Homebrew build on macOS)
  /// refuses `dlopen` on any relative path — even one with a leading `./` —
  /// so this resolution is required for the library to load regardless of
  /// which `dart` binary is running or what the process's cwd is. Do not
  /// simplify this back to opening `dylibPath` directly.
  ReferenceHyphen(String dylibPath)
      : _lib = DynamicLibrary.open(File(dylibPath).absolute.path);

  final DynamicLibrary _lib;

  ReferenceDict load(String dictPath) {
    final load = _lib.lookupFunction<_LoadNative, _LoadNative>('hyphen_load');
    final pathPtr = dictPath.toNativeUtf8();
    try {
      final dict = load(pathPtr);
      if (dict == nullptr) {
        throw StateError('hyphen_load returned NULL for $dictPath');
      }
      return ReferenceDict._(_lib, dict);
    } finally {
      calloc.free(pathPtr);
    }
  }
}

class ReferenceDict {
  ReferenceDict._(this._lib, this._dict)
      : _h2 = _lib.lookupFunction<_H2Native, _H2Dart>('hyphen_hyphenate2'),
        _h3 = _lib.lookupFunction<_H3Native, _H3Dart>('hyphen_hyphenate3');

  final DynamicLibrary _lib;
  Pointer<_HyphenDictHead> _dict;
  final _H2Dart _h2;
  final _H3Dart _h3;

  bool get isUtf8 => _dict.ref.utf8 == 1;

  List<int> hyphenate2(List<int> wordBytes) =>
      _call((w, len, hy) => _h2(_dict, w, len, hy), wordBytes);

  List<int> hyphenate3(
    List<int> wordBytes,
    int lhmin,
    int rhmin,
    int clhmin,
    int crhmin,
  ) =>
      _call(
        (w, len, hy) => _h3(_dict, w, len, hy, lhmin, rhmin, clhmin, crhmin),
        wordBytes,
      );

  /// Buffer sizes and the `wordBytes.length` read-back both mirror
  /// `hyphen_ffi.dart:_getHyphenationMarks` exactly, including the fact that
  /// for a UTF-8 dictionary `norm` has compacted the marks and the tail of
  /// the returned list is stale (spec hazard 3).
  List<int> _call(
    int Function(Pointer<Uint8>, int, Pointer<Uint8>) invoke,
    List<int> wordBytes,
  ) {
    final len = wordBytes.length;
    final word = calloc<Uint8>(len + 1);
    final hyphens = calloc<Uint8>(len + 8);
    try {
      word.asTypedList(len).setAll(0, wordBytes);
      final rc = invoke(word, len, hyphens);
      if (rc != 0) throw StateError('hyphenation failed with code $rc');
      return List<int>.from(hyphens.asTypedList(len));
    } finally {
      calloc.free(word);
      calloc.free(hyphens);
    }
  }

  void free() {
    if (_dict != nullptr) {
      _lib.lookupFunction<_FreeNative, _FreeDart>('hyphen_free')(_dict);
      _dict = nullptr;
    }
  }
}
