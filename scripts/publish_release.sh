#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
REPO="fabi-wi/top-of-mind"
if [[ "$(git branch --show-current)" != "main" || -n "$(git status --porcelain)" ]]; then
  echo "Publish from a clean committed main branch." >&2
  exit 1
fi
REMOTE="$(git remote get-url origin)"
if [[ "$REMOTE" != "https://github.com/$REPO.git" && "$REMOTE" != "git@github.com:$REPO.git" ]]; then
  echo "Origin must be $REPO." >&2
  exit 1
fi
if git rev-parse --verify "refs/tags/v$VERSION" >/dev/null 2>&1; then
  echo "The release tag already exists; choose a new version." >&2
  exit 1
fi
git fetch origin main --tags
if git rev-parse --verify "refs/tags/v$VERSION" >/dev/null 2>&1; then
  echo "The remote release tag already exists." >&2
  exit 1
fi
git merge-base --is-ancestor origin/main HEAD
./scripts/package_release.sh "$VERSION"
git push origin HEAD:main
git tag -a "v$VERSION" -m "Top of Mind $VERSION"
git push origin "v$VERSION"
gh release create "v$VERSION" \
  "dist/TopOfMind-v$VERSION-macos-universal.zip" \
  "dist/TopOfMind-v$VERSION-macos-universal.zip.sha256" \
  --repo "$REPO" --verify-tag --title "Top of Mind $VERSION" \
  --notes-file "docs/releases-v$VERSION.md"
