import 'package:flutter_test/flutter_test.dart';
import 'package:hyphen/src/web/hyphen_web.dart';
import 'package:hyphen/src/web/js_runtime/js_runtime.dart';

class FakeRuntime implements JsHyphenRuntime {
  final mallocCalls = <int>[];
  final freeCalls = <int>[];
  final ccallCalls = <String>[];
  int nextPtr = 1000;
  int hyphenateRc = 0;
  final Map<int, int> heap = {};
  bool wasDisposeCalled = false;

  void preload(int base, List<int> bytes) {
    for (var i = 0; i < bytes.length; i++) {
      heap[base + i] = bytes[i];
    }
  }

  @override
  int malloc(int size) {
    mallocCalls.add(size);
    final p = nextPtr;
    nextPtr += size;
    return p;
  }

  @override
  void free(int ptr) => freeCalls.add(ptr);

  @override
  int ccall(String fn, List<String?> argTypes, List<Object?> args) {
    ccallCalls.add(fn);
    return hyphenateRc;
  }

  @override
  int heapAt(int index) => heap[index] ?? 0;

  @override
  void dispose(int dictPointer) {
    wasDisposeCalled = true;
  }
}

void main() {
  test('applies hyphenation marks (ASCII input)', () {
    final rt = FakeRuntime();
    // ASCII: 0,0,2,1,2,8,1,6,0,0,0,0 at base 1000
    rt.preload(1000, [48, 48, 50, 49, 50, 56, 49, 54, 48, 48, 48, 48]);
    final hy = Hyphen.forTest(rt, dictPtr: 123);

    final out = hy.hnjHyphenate2('Funktioniert', separator: '=');
    expect(out, 'Funk=tio=niert');

    // wordSize=12 → malloc(20)
    expect(rt.mallocCalls, containsAll([12 + 8]));
  });

  test('throws when native hyphenation returns non-zero', () {
    final rt = FakeRuntime()..hyphenateRc = 1;
    final hy = Hyphen.forTest(rt, dictPtr: 1);

    expect(() => hy.hnjHyphenate2('abcdef'), throwsException);
    expect(rt.ccallCalls, contains('hyphen_hyphenate2'));
  });

  test('frees allocated buffers on success', () {
    final rt = FakeRuntime();
    rt.preload(1000, List.filled(20, 0)); // ensure NULs
    final hy = Hyphen.forTest(rt, dictPtr: 1);

    hy.hnjHyphenate2('abcdef');
    final p1 = 1000;
    expect(rt.freeCalls, containsAll([p1]));
    expect(rt.freeCalls.length, 1);
  });

  test('frees allocated buffers when failing', () {
    final rt = FakeRuntime()..hyphenateRc = 7;
    final hy = Hyphen.forTest(rt, dictPtr: 1);

    expect(() => hy.hnjHyphenate2('abcdef'), throwsException);
    final p1 = 1000;
    expect(rt.freeCalls, containsAll([p1]));
    expect(rt.freeCalls.length, 1);
  });

  test('hnjHyphenate3 calls v3 symbol', () {
    final rt = FakeRuntime();
    final hy = Hyphen.forTest(rt, dictPtr: 1);

    hy.hnjHyphenate3('abc');
    expect(rt.ccallCalls, contains('hyphen_hyphenate3'));
  });

  test('calls dispose when dict is not null', () {
    final rt = FakeRuntime();
    final hy = Hyphen.forTest(rt, dictPtr: 1);

    hy.dispose();
    expect(rt.wasDisposeCalled, true);
  });

  test('does not call dispose when dict is null', () {
    final rt = FakeRuntime();
    final hy = Hyphen.forTest(rt, dictPtr: 0);

    hy.dispose();
    expect(rt.wasDisposeCalled, false);
  });
}
