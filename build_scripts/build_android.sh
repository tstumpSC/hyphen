#!/usr/bin/env bash
set -euo pipefail

# ===== Configurable paths =====
# Override by exporting NDK=/path/to/android-ndk
NDK="${NDK:-$HOME/Library/Android/sdk/ndk/27.0.12077973}"  # change ndk version as needed
LIBHYPHEN_SRC="src/hyphen_lib"
WRAPPER_SRC="src/wrapper/hyphen_ffi.c"
INCLUDE_DIRS=("src/wrapper" "src/hyphen_lib")

BUILD_DIR="build/android"
OUT_DIR="build_scripts/output/android"

# Min Android API level
API="${API:-21}"

# ===== Detect HOST_TAG that actually exists in your NDK =====
detect_host_tag() {
  local candidates=("darwin-arm64" "darwin-x86_64" "linux-x86_64")
  for cand in "${candidates[@]}"; do
    if [ -d "$NDK/toolchains/llvm/prebuilt/$cand" ]; then
      echo "$cand"
      return 0
    fi
  done
  echo "ERROR: Could not find an NDK toolchain under $NDK/toolchains/llvm/prebuilt/{${candidates[*]}}." >&2
  exit 1
}
HOST_TAG="$(detect_host_tag)"

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG"
CLANG="$TOOLCHAIN/bin/clang"
SYSROOT="$TOOLCHAIN/sysroot"

if [ ! -x "$CLANG" ]; then
  echo "ERROR: clang not found at $CLANG" >&2
  exit 1
fi

# ===== Target ABIs and triples =====
ABIS=(
  "armeabi-v7a:armv7a-linux-androideabi"
  "arm64-v8a:aarch64-linux-android"
  "x86:i686-linux-android"
  "x86_64:x86_64-linux-android"
)

echo "🧹 Cleaning previous build output..."
rm -rf "$OUT_DIR" "$BUILD_DIR"
mkdir -p "$OUT_DIR" "$BUILD_DIR"

for abi_spec in "${ABIS[@]}"; do
  IFS=":" read -r ABI TRIPLE <<< "$abi_spec"
  echo "🔧 Building for $ABI (target ${TRIPLE}${API})"

  # Per-ABI build/output dirs
  OBJ_DIR="$BUILD_DIR/$ABI"
  ABI_OUT="$OUT_DIR/$ABI"
  mkdir -p "$OBJ_DIR" "$ABI_OUT"

  # Base flags
  CFLAGS=(-fPIC -O2 -ffunction-sections -fdata-sections --sysroot="$SYSROOT" "--target=${TRIPLE}${API}")
  LDFLAGS=(-shared -Wl,--no-undefined -Wl,--gc-sections --sysroot="$SYSROOT" "--target=${TRIPLE}${API}")

  # Include paths
  for inc in "${INCLUDE_DIRS[@]}"; do
    CFLAGS+=("-I$inc")
  done

  # Optional tuning for 32-bit ARM
  if [ "$ABI" = "armeabi-v7a" ]; then
    CFLAGS+=(-march=armv7-a -mthumb -mfpu=neon -mfloat-abi=softfp)
  fi

  # Objects
  OBJ_HYPHEN="$OBJ_DIR/hyphen.o"
  OBJ_HNJALLOC="$OBJ_DIR/hnjalloc.o"
  OBJ_WRAPPER="$OBJ_DIR/hyphen_ffi.o"

  # Compile
  "$CLANG" "${CFLAGS[@]}" -c "$LIBHYPHEN_SRC/hyphen.c"   -o "$OBJ_HYPHEN"
  "$CLANG" "${CFLAGS[@]}" -c "$LIBHYPHEN_SRC/hnjalloc.c" -o "$OBJ_HNJALLOC"
  "$CLANG" "${CFLAGS[@]}" -c "$WRAPPER_SRC"              -o "$OBJ_WRAPPER"

  # Link shared object
  "$CLANG" "${LDFLAGS[@]}" \
    "$OBJ_WRAPPER" "$OBJ_HYPHEN" "$OBJ_HNJALLOC" \
    -o "$ABI_OUT/libhyphen_ffi.so"

  echo "✅ $ABI → $ABI_OUT/libhyphen_ffi.so"
done

echo "🎉 All shared objects are in: $OUT_DIR"
