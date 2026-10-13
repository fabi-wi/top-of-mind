#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
./scripts/build_app.sh
open "$PROJECT_ROOT/dist/Top of Mind.app"
