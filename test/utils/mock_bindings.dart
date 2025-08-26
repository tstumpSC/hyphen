// ignore_for_file: type=lint

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:hyphen/src/ffi/hyphen_ffi_bindings_generated.dart';

class MockBindings implements HyphenFfiBindings {
  String? lastLoadedPath;
  List<int> hyphensBytesToReturn;
  bool failsHyphenation;
  int freeFnCallCount = 0;

  MockBindings({
    this.hyphensBytesToReturn = const [],
    this.failsHyphenation = false,
  });

  @override
  Pointer<HyphenDict> hyphen_load(Pointer<Char> path) {
    lastLoadedPath = path.cast<Utf8>().toDartString();
    return Pointer.fromAddress(1);
  }

  @override
  int hyphen_hyphenate2(
    Pointer<HyphenDict$1> dict,
    Pointer<Char> word,
    int word_size,
    Pointer<Char> hyphens,
  ) {
    if (failsHyphenation) return 1;

    final hyphenMarks = hyphens.cast<Int8>().asTypedList(word_size);

    for (var i = 0; i < word_size && i < hyphensBytesToReturn.length; i++) {
      hyphenMarks[i] = hyphensBytesToReturn[i];
    }

    return 0;
  }

  @override
  int hyphen_hyphenate3(
    Pointer<HyphenDict$1> dict,
    Pointer<Char> word,
    int word_size,
    Pointer<Char> hyphens,
    int lhmin,
    int rhmin,
    int clhmin,
    int crhmin,
  ) => hyphen_hyphenate2(dict, word, word_size, hyphens);

  @override
  void hyphen_free(Pointer<HyphenDict> dict) {
    freeFnCallCount++;
  }
}
