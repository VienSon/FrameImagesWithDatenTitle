#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPSTORE_DIR="$ROOT_DIR/AppStoreProject"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Error: xcodegen not found." >&2
  echo "Install with: brew install xcodegen" >&2
  exit 1
fi

if [[ ! -f "$APPSTORE_DIR/project.yml" ]]; then
  echo "Error: missing $APPSTORE_DIR/project.yml" >&2
  exit 1
fi

cd "$APPSTORE_DIR"
xcodegen generate

echo "Generated: $APPSTORE_DIR/FrameMacApp.xcodeproj"
echo "Open with: open \"$APPSTORE_DIR/FrameMacApp.xcodeproj\""
