#!/usr/bin/env bash
set -euo pipefail

export MACOSX_DEPLOYMENT_TARGET=11.0

# Paths
SRC_DIR="src"
HY_DIR="src/hyphen_lib"
FFI_DIR="src/wrapper"

# Output
OUTPUT_LIB="build_scripts/output/macos/libhyphen_ffi.a"

mkdir -p "$(dirname "$OUTPUT_LIB")"

# Architectures to build
ARCHS=("arm64" "x86_64")

# Compile and archive for each architecture
for ARCH in "${ARCHS[@]}"; do
    echo "Building for $ARCH..."

    clang -c -arch "$ARCH" -o "hyphen_ffi_${ARCH}.o" "$FFI_DIR/hyphen_ffi.c" -I"$SRC_DIR" -I"$HY_DIR"
    clang -c -arch "$ARCH" -o "hyphen_${ARCH}.o" "$HY_DIR/hyphen.c" -I"$HY_DIR"
    clang -c -arch "$ARCH" -o "hnjalloc_${ARCH}.o" "$HY_DIR/hnjalloc.c" -I"$HY_DIR"

    ar rcs "libhyphen_ffi_${ARCH}.a" \
        "hyphen_ffi_${ARCH}.o" \
        "hyphen_${ARCH}.o" \
        "hnjalloc_${ARCH}.o"
done

# Combine into a universal binary
echo "Creating universal binary $OUTPUT_LIB..."
lipo -create -output "$OUTPUT_LIB" \
    libhyphen_ffi_arm64.a \
    libhyphen_ffi_x86_64.a

# Cleanup step
echo "Cleaning up intermediate files..."
rm -f hyphen_ffi_*.o hyphen_*.o hnjalloc_*.o libhyphen_ffi_arm64.a libhyphen_ffi_x86_64.a

echo "✅ Done. Output: $OUTPUT_LIB"
