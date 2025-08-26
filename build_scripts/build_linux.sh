#!/bin/bash
set -e

SRC_DIR="src/wrapper"
LIB_DIR="src/hyphen_lib"
OUT_DIR="build_scripts/output/linux"

WRAPPER="$SRC_DIR/hyphen_ffi.c"
SOURCES="$LIB_DIR/hyphen.c $LIB_DIR/hnjalloc.c"
INCLUDES="-I$SRC_DIR -I$LIB_DIR"

# Architecture : Compiler pairings
TARGETS=(
  "x64:x86_64-unknown-linux-gnu-gcc"
  "arm64:aarch64-unknown-linux-gnu-gcc"
)

for target in "${TARGETS[@]}"; do
  IFS=":" read -r ARCH CC <<< "$target"
  OUTPUT_DIR="$OUT_DIR/$ARCH"
  OUTPUT_FILE="$OUTPUT_DIR/libhyphen_ffi.so"

  echo "📦 Building for Linux $ARCH using $CC"

  if ! command -v $CC >/dev/null 2>&1; then
    echo "❌ Compiler '$CC' not found."
    echo "   Install it via Homebrew:"
    echo "   brew tap messense/macos-cross-toolchains"
    echo "   brew install ${CC%%-*}"
    exit 1
  fi

  mkdir -p "$OUTPUT_DIR"

  $CC -fPIC -shared \
    $INCLUDES \
    $WRAPPER $SOURCES \
    -o "$OUTPUT_FILE"

  echo "✅ Built $OUTPUT_FILE"
done

echo "🎉 All Linux .so files built successfully"