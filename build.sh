#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/caf.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
swiftc "$ROOT/Sources/main.swift" \
  -O \
  -framework AppKit \
  -framework Carbon \
  -o "$APP/Contents/MacOS/caf"

codesign --force --sign - "$APP"
echo "$APP"
