/// Abstraction over a runtime that can call into the Hyphenation
/// WebAssembly module (or a mock during tests).
///
/// Exposes only the minimal set of operations needed by [Hyphen]:
/// - allocate/free heap memory,
/// - call exported C functions,
/// - and read raw bytes from the heap.
abstract class JsHyphenRuntime {
  /// Allocates [size] bytes on the module heap and returns the pointer.
  int malloc(int size);

  /// Frees a previously allocated pointer [ptr].
  void free(int ptr);

  /// Calls an exported C function [fn] with the given [argTypes] and [args].
  ///
  /// - [argTypes] is a list of type descriptors (`"number"`, `"string"`, etc.)
  ///   understood by Emscripten’s `ccall`.
  /// - [args] are the actual argument values.
  ///
  /// Returns the result of the call as an `int`.
  int ccall(String fn, List<String?> argTypes, List<Object?> args);

  /// Reads a single byte at [index] from the module’s heap (`HEAPU8`).
  int heapAt(int index);

  void dispose(int dictPointer);
}
