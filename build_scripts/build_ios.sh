#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
HY_DIR="src/hyphen_lib"
FFI_DIR="src/wrapper"
OUTPUT_XCFRAMEWORK="build_scripts/output/ios/libhyphen.xcframework"

# --- Prep ---
mkdir -p "$(dirname "$OUTPUT_XCFRAMEWORK")"

# --- SDK paths ---
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SDK_SIM="$(xcrun --sdk iphonesimulator --show-sdk-path)"

echo "📦 Building iOS (device: arm64)..."
clang -arch arm64 -isysroot "$SDK" -c -o hyphen_ffi_arm64.o "$FFI_DIR/hyphen_ffi.c" -I"$HY_DIR"
clang -arch arm64 -isysroot "$SDK" -c -o hyphen_arm64.o "$HY_DIR/hyphen.c" -I"$HY_DIR"
clang -arch arm64 -isysroot "$SDK" -c -o hnjalloc_arm64.o "$HY_DIR/hnjalloc.c" -I"$HY_DIR"

echo "📦 Building iOS Simulator (x86_64)..."
clang -arch x86_64 -isysroot "$SDK_SIM" -c -o hyphen_ffi_sim_x86_64.o "$FFI_DIR/hyphen_ffi.c" -I"$HY_DIR"
clang -arch x86_64 -isysroot "$SDK_SIM" -c -o hyphen_sim_x86_64.o "$HY_DIR/hyphen.c" -I"$HY_DIR"
clang -arch x86_64 -isysroot "$SDK_SIM" -c -o hnjalloc_sim_x86_64.o "$HY_DIR/hnjalloc.c" -I"$HY_DIR"

echo "📦 Building iOS Simulator (arm64)..."
clang -arch arm64 -isysroot "$SDK_SIM" -c -o hyphen_ffi_sim_arm64.o "$FFI_DIR/hyphen_ffi.c" -I"$HY_DIR"
clang -arch arm64 -isysroot "$SDK_SIM" -c -o hyphen_sim_arm64.o "$HY_DIR/hyphen.c" -I"$HY_DIR"
clang -arch arm64 -isysroot "$SDK_SIM" -c -o hnjalloc_sim_arm64.o "$HY_DIR/hnjalloc.c" -I"$HY_DIR"

# --- Create intermediate structure ---
mkdir -p libhyphen.xcframework/ios libhyphen.xcframework/sim

# Device (arm64)
ar rcs libhyphen.a hyphen_ffi_arm64.o hyphen_arm64.o hnjalloc_arm64.o
mv libhyphen.a libhyphen.xcframework/ios/

# Simulator (merge arm64 + x86_64)
ar rcs libhyphen_ios_sim_x86_64.a hyphen_ffi_sim_x86_64.o hyphen_sim_x86_64.o hnjalloc_sim_x86_64.o
ar rcs libhyphen_ios_sim_arm64.a   hyphen_ffi_sim_arm64.o   hyphen_sim_arm64.o   hnjalloc_sim_arm64.o
lipo -create libhyphen_ios_sim_arm64.a libhyphen_ios_sim_x86_64.a -output libhyphen.a
mv libhyphen.a libhyphen.xcframework/sim/

# --- Create final XCFramework ---
xcodebuild -create-xcframework \
  -library libhyphen.xcframework/ios/libhyphen.a -headers "$FFI_DIR" \
  -library libhyphen.xcframework/sim/libhyphen.a -headers "$FFI_DIR" \
  -output "$OUTPUT_XCFRAMEWORK"

# --- Cleanup intermediate files ---
rm -rf \
  hyphen_ffi_*.o hyphen_*.o hnjalloc_*.o \
  libhyphen_ios_sim_*.a \
  libhyphen.xcframework

echo "✅ Built XCFramework at: $OUTPUT_XCFRAMEWORK"