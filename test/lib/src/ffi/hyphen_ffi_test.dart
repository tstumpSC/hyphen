import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/src/ffi/hyphen_ffi.dart';

import '../../../utils/mock_allocator.dart';
import '../../../utils/mock_bindings.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('loads dictionary successfully', () async {
    MockBindings mockBindings = MockBindings();

    final path = "test/assets/test_dictionary.dic";
    await Hyphen.fromDictionaryPathWithBindingsAndAllocator(
      path,
      mockBindings,
      calloc,
    );
    expect(
      mockBindings.lastLoadedPath,
      "${Directory.systemTemp.path}/hyph.dic",
    );

    final loadedFile = File(mockBindings.lastLoadedPath!);
    final expectedBytes = await File(path).readAsBytes();
    expect(await loadedFile.readAsBytes(), expectedBytes);
  });

  test(
    'correctly applies hyphenation pattern that the native lib returns',
    () async {
      final mockBindings = MockBindings(
        hyphensBytesToReturn: [48, 48, 50, 49, 50, 56, 49, 54, 48, 48, 48, 48],
      );
      final hy = await Hyphen.fromDictionaryPathWithBindingsAndAllocator(
        'test/assets/test_dictionary.dic',
        mockBindings,
        calloc,
      );

      final result = hy.hnjHyphenate2('Funktioniert', separator: '=');

      expect(result, "Funk=tio=niert");
    },
  );

  test('throws when hyphenation result is not 0', () async {
    final mockBindings = MockBindings(failsHyphenation: true);
    final hy = await Hyphen.fromDictionaryPathWithBindingsAndAllocator(
      'test/assets/test_dictionary.dic',
      mockBindings,
      calloc,
    );

    expect(() => hy.hnjHyphenate2("test"), throwsException);
  });

  test('allocates all required buffers with correct sizes', () async {
    final mockAlloc = MockAllocator();
    final mockBindings = MockBindings();

    final hy = await Hyphen.fromDictionaryPathWithBindingsAndAllocator(
      'test/assets/test_dictionary.dic',
      mockBindings,
      mockAlloc,
    );

    hy.hnjHyphenate2('abcdef');

    expect(mockAlloc.allocatedMemory[Int8], contains((6 + 8) * sizeOf<Int8>()));
  });

  test('frees all allocated buffers', () async {
    final mockAlloc = MockAllocator();
    final mockBindings = MockBindings();

    final hy = await Hyphen.fromDictionaryPathWithBindingsAndAllocator(
      'test/assets/test_dictionary.dic',
      mockBindings,
      mockAlloc,
    );

    hy.hnjHyphenate2('abcdef');

    expect(
      mockAlloc.freedPointers.length,
      mockAlloc.allocatedMemory.values.expand((v) => v).length + 1,
    ); // +1 because we use .toNativeUtf8 once, which allocates memory without using our allocator
  });

  test('frees all allocated buffers even when hyphenation fails', () async {
    final mockAlloc = MockAllocator();
    final mockBindings = MockBindings(failsHyphenation: true);

    final hy = await Hyphen.fromDictionaryPathWithBindingsAndAllocator(
      'test/assets/test_dictionary.dic',
      mockBindings,
      mockAlloc,
    );

    expect(() => hy.hnjHyphenate2('abcdef'), throwsException);
    expect(
      mockAlloc.freedPointers.length,
      mockAlloc.allocatedMemory.values.expand((v) => v).length + 1,
    ); // +1 because we use .toNativeUtf8 once, which allocates memory without using our allocator
  });

  test('calls dispose when dict is not null', () async {
    final mockAlloc = MockAllocator();
    final mockBindings = MockBindings();

    final hy = await Hyphen.fromDictionaryPathWithBindingsAndAllocator(
      'test/assets/test_dictionary.dic',
      mockBindings,
      mockAlloc,
    );

    hy.dispose();
    expect(mockBindings.freeFnCallCount, 1);
  });

  test('does not call dispose when dict is null', () async {
    final mockAlloc = MockAllocator();
    final mockBindings = MockBindings();

    final hy = await Hyphen.fromDictionaryPathWithBindingsAndAllocator(
      'test/assets/test_dictionary.dic',
      mockBindings,
      mockAlloc,
    );

    hy.dispose();
    hy.dispose();
    hy.dispose();
    expect(mockBindings.freeFnCallCount, 1);
  });
}
