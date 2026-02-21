#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="$ROOT_DIR/assets"
ICONSET_DIR="$ASSETS_DIR/AppIcon.iconset"
ICON_ICNS="$ASSETS_DIR/AppIcon.icns"

PYTHON_BIN="$ROOT_DIR/venv-gui/bin/python"
if [[ ! -x "$PYTHON_BIN" ]]; then
  PYTHON_BIN="python3"
fi

mkdir -p "$ASSETS_DIR"

echo "Generating icon PNG + iconset..."
"$PYTHON_BIN" "$ROOT_DIR/generate_app_icon.py"

if [[ ! -d "$ICONSET_DIR" ]]; then
  echo "Error: missing iconset: $ICONSET_DIR" >&2
  exit 1
fi

echo "Creating .icns..."
iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"
echo "Wrote $ICON_ICNS"
