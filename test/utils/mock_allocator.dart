import 'dart:ffi';

import 'package:ffi/ffi.dart';

class MockAllocator implements Allocator {
  final allocatedMemory = <Type, List<int>>{};
  final freedPointers = <Pointer>[];

  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    allocatedMemory.putIfAbsent(T, () => []).add(byteCount);
    final ptr = calloc.allocate<T>(byteCount);

    return ptr;
  }

  @override
  void free(Pointer<NativeType> pointer) {
    freedPointers.add(pointer);
    calloc.free(pointer);
  }
}
