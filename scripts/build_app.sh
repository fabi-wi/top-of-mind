#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# A single native architecture needs only Apple's Command Line Tools.
# Build twice and combine with lipo to avoid an Xcode-only universal builder.
BUILD_ARCH="${TOP_OF_MIND_ARCH:-$(uname -m)}"
if [[ "$BUILD_ARCH" != "arm64" && "$BUILD_ARCH" != "x86_64" && "$BUILD_ARCH" != "universal" ]]; then
  echo "TOP_OF_MIND_ARCH must be arm64, x86_64 or universal." >&2
  exit 1
fi

APP_DIR="$PROJECT_ROOT/dist/Top of Mind.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

if [[ "$BUILD_ARCH" == "universal" ]]; then
  for arch in arm64 x86_64; do
    swift build -c release --triple "$arch-apple-macosx14.0"
  done
  ARM_BIN="$(swift build -c release --triple arm64-apple-macosx14.0 --show-bin-path)"
  INTEL_BIN="$(swift build -c release --triple x86_64-apple-macosx14.0 --show-bin-path)"
  lipo -create "$ARM_BIN/TopOfMindApp" "$INTEL_BIN/TopOfMindApp" -output "$APP_DIR/Contents/MacOS/TopOfMind"
else
  swift build -c release --triple "$BUILD_ARCH-apple-macosx14.0"
  BIN_DIR="$(swift build -c release --triple "$BUILD_ARCH-apple-macosx14.0" --show-bin-path)"
  cp "$BIN_DIR/TopOfMindApp" "$APP_DIR/Contents/MacOS/TopOfMind"
fi

cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
cp Resources/MenuBarIcon.png "$APP_DIR/Contents/Resources/MenuBarIcon.png"
chmod +x "$APP_DIR/Contents/MacOS/TopOfMind"
codesign --force --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"
echo "Built $APP_DIR ($BUILD_ARCH)"
