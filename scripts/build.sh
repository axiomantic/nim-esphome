#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/ci/test.sh"

echo "=== Building documentation site with Zensical ==="
if command -v asdf >/dev/null 2>&1 && asdf which nim >/dev/null 2>&1; then
    NIM_BIN="$(asdf which nim)"
else
    NIM_BIN="$(which nim)"
fi
NIM_REAL="$(readlink -f "$NIM_BIN" 2>/dev/null || echo "$NIM_BIN")"
NIM_DIR="$(dirname "$(dirname "$NIM_REAL")")"
if [ -d "$NIM_DIR/compiler" ] && [ ! -e "$NIM_DIR/lib/compiler" ]; then
    ln -sf "$NIM_DIR/compiler" "$NIM_DIR/lib/compiler" 2>/dev/null || true
fi

ZENSICAL_BIN="zensical"
if command -v zensical >/dev/null 2>&1; then
    ZENSICAL_BIN="zensical"
elif [ -n "${VIRTUAL_ENV:-}" ] && [ -x "${VIRTUAL_ENV}/bin/zensical" ]; then
    ZENSICAL_BIN="${VIRTUAL_ENV}/bin/zensical"
fi
if command -v "$ZENSICAL_BIN" >/dev/null 2>&1 || [ -x "$ZENSICAL_BIN" ]; then
    "$ZENSICAL_BIN" build --strict
else
    echo "zensical not installed, skipping documentation build verification"
fi

echo "=== All nim-esphome checks passed! ==="

