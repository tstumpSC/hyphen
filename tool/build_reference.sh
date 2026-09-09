#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

OUT="libhyphen_ffi.dylib"
ARCH="$(uname -m)"

clang -dynamiclib -O2 -arch "$ARCH" -o "$OUT" \
  reference_c/wrapper/hyphen_ffi.c \
  reference_c/hyphen_lib/hyphen.c \
  reference_c/hyphen_lib/hnjalloc.c \
  -Ireference_c -Ireference_c/hyphen_lib

echo "Built $OUT for $ARCH"
nm -gU "$OUT" | grep -E '_hyphen_(load|free|hyphenate2|hyphenate3)$'
