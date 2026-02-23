#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/raw-screenshot.png [output-dir]" >&2
  exit 1
fi

SRC="$1"
OUT_DIR="${2:-$(cd "$(dirname "$0")" && pwd)/screenshots}"

if [[ ! -f "$SRC" ]]; then
  echo "Error: source image not found: $SRC" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

sips -z 800 1280 "$SRC" --out "$OUT_DIR/screenshot-1280x800.png" >/dev/null
sips -z 900 1440 "$SRC" --out "$OUT_DIR/screenshot-1440x900.png" >/dev/null
sips -z 1600 2560 "$SRC" --out "$OUT_DIR/screenshot-2560x1600.png" >/dev/null

cp "$OUT_DIR/screenshot-2560x1600.png" "$OUT_DIR/screenshot-1-main.png"
cp "$OUT_DIR/screenshot-1440x900.png" "$OUT_DIR/screenshot-2-metadata-editing.png"
cp "$OUT_DIR/screenshot-1280x800.png" "$OUT_DIR/screenshot-3-batch-log.png"

echo "Created resized screenshots in: $OUT_DIR"
ls -lh "$OUT_DIR"
