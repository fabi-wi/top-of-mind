#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
VERSION="${1:-$APP_VERSION}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || "$VERSION" != "$APP_VERSION" ]]; then
  echo "Version must match Info.plist ($APP_VERSION)." >&2
  exit 1
fi
swift test
TOP_OF_MIND_ARCH=universal ./scripts/build_app.sh
APP_DIR="$PROJECT_ROOT/dist/Top of Mind.app"
ARCHS="$(lipo -archs "$APP_DIR/Contents/MacOS/TopOfMind")"
if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
  echo "Both Apple Silicon and Intel binaries are required." >&2
  exit 1
fi
plutil -lint "$APP_DIR/Contents/Info.plist"
codesign --verify --strict "$APP_DIR"
ARCHIVE="TopOfMind-v$VERSION-macos-universal.zip"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr -c -k --keepParent "$APP_DIR" "$PROJECT_ROOT/dist/$ARCHIVE"
unzip -tq "$PROJECT_ROOT/dist/$ARCHIVE"
(
  cd dist
  shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
)
echo "Release: $PROJECT_ROOT/dist/$ARCHIVE"
