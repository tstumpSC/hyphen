#!/usr/bin/env bash
set -euo pipefail

# ====== Config (edit as needed) ======
EMCC_BIN="${EMCC_BIN:-emcc}"                      # path to emcc, or just 'emcc' if on PATH
WRAPPER_SRC="${WRAPPER_SRC:-src/wrapper/hyphen_ffi.c}"
HYPHEN_DIR="${HYPHEN_DIR:-src/hyphen_lib}"       # folder with hyphen.c / hnjalloc.c
OUT_JS="${OUT_JS:-build_scripts/output/web/hyphen.js}"          # output JS (WASM will sit next to it)
OPT="${OPT:-O3}"                                  # O0/O1/O2/O3/Os/Oz
ENVIRONMENT="${ENVIRONMENT:-web}"                 # web / worker / node / combinations like web,worker
EXPORT_NAME="${EXPORT_NAME:-createHyphenModule}"  # JS factory name

# Emscripten exports
EXPORTED_FUNCTIONS='["_hyphen_load","_hyphen_free","_hyphen_hyphenate2","_hyphen_hyphenate3","_malloc","_free", "_hyphen_dict_get_utf8"]'
EXPORTED_RUNTIME_METHODS='["cwrap", "ccall", "UTF8ToString", "stringToUTF8", "getValue", "setValue", "FS", "lengthBytesUTF8", "HEAPU8", "HEAPU32"]'

# ====== Checks & prep ======
if ! command -v "$EMCC_BIN" >/dev/null 2>&1; then
  echo "❌ emcc not found. Set EMCC_BIN or add emcc to PATH." >&2
  exit 1
fi

OUT_DIR="$(dirname "$OUT_JS")"
mkdir -p "$OUT_DIR"

echo "ℹ️ Using emcc: $("$EMCC_BIN" --version | head -n1 || echo "$EMCC_BIN")"
echo "🔧 Building to: $OUT_JS"

# ====== Build ======

"$EMCC_BIN" \
  "$WRAPPER_SRC" \
  "$HYPHEN_DIR/hyphen.c" \
  "$HYPHEN_DIR/hnjalloc.c" \
  "-$OPT" \
  -s WASM=1 \
  -s MODULARIZE=1 \
  -s "EXPORT_NAME=$EXPORT_NAME" \
  -s "ENVIRONMENT=$ENVIRONMENT" \
  -s "EXPORTED_FUNCTIONS=$EXPORTED_FUNCTIONS" \
  -s "EXPORTED_RUNTIME_METHODS=$EXPORTED_RUNTIME_METHODS" \
  -o "$OUT_JS"



# ====== Append helper JS ======
cat >> "$OUT_JS" <<'EOF'

// --- Appended helpers ---
function injectDicFile(module, filename, bytes) {
  if (!module.FS || !module.FS.writeFile) {
    console.error("FS.writeFile is not available on module");
    return;
  }

  try {
    module.FS.writeFile(filename, bytes, { canOwn: true });
  } catch (err) {
    console.error("❌ Failed to inject file:", err);
  }
}

if (typeof window !== 'undefined') {
  window.createHyphenModule = createHyphenModule;
}
EOF

echo "✅ Done."
echo "   JS   : $OUT_JS"
echo "   WASM : ${OUT_JS%.js}.wasm"
