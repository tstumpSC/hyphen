#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

BASE="https://raw.githubusercontent.com/LibreOffice/dictionaries/master"
SUMS="corpus/sha256sums.txt"

mkdir -p corpus/dicts corpus/words
: > "$SUMS.new"

while read -r lang kind path; do
  [[ -z "${lang:-}" || "$lang" == \#* ]] && continue
  case "$kind" in
    hyph)  dest="corpus/dicts/$lang.dic" ;;
    words) dest="corpus/words/$lang.dic" ;;
    *) echo "unknown kind: $kind" >&2; exit 1 ;;
  esac

  if [[ ! -f "$dest" ]]; then
    echo "fetching $lang/$kind ..."
    curl -sSLf --max-time 120 -o "$dest" "$BASE/$path"
  fi
  shasum -a 256 "$dest" >> "$SUMS.new"
done < corpus_manifest.txt

if [[ -f "$SUMS" ]]; then
  if ! diff -q "$SUMS" "$SUMS.new" >/dev/null; then
    echo "ERROR: corpus checksums changed since last fetch." >&2
    diff "$SUMS" "$SUMS.new" >&2 || true
    echo "A changed upstream invalidates existing goldens. Delete corpus/ and" >&2
    echo "regenerate both sides if this change is intended." >&2
    exit 1
  fi
  rm "$SUMS.new"
else
  mv "$SUMS.new" "$SUMS"
  echo "Pinned checksums written to $SUMS"
fi

echo "Corpus ready:"
wc -l corpus/words/*.dic
