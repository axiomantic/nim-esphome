#!/usr/bin/env bash
set -euo pipefail

echo "=== Running nim-esphome unit tests ==="
nim c -r --path:src tests/test_basic.nim
rm -f tests/test_basic
nim c -r --path:src tests/test_entities.nim
rm -f tests/test_entities
nim c -r --path:src tests/test_peripherals.nim
rm -f tests/test_peripherals
nim c -r --path:src tests/test_preferences.nim
rm -f tests/test_preferences
nim c -r --path:src tests/test_dsp.nim
rm -f tests/test_dsp

echo "=== Testing embedded C++ code generation (Xtensa ESP32 target) ==="
nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Testing embedded C++ code generation (RISC-V ESP32-C3/C6 target) ==="
nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:riscv32 --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Testing embedded C++ code generation (ARM RP2040 target) ==="
nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:arm --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Running Python component tests ==="
PYTHON_BIN="python3"
if [ -n "${VIRTUAL_ENV:-}" ] && [ -x "${VIRTUAL_ENV}/bin/python" ]; then
    PYTHON_BIN="${VIRTUAL_ENV}/bin/python"
fi
$PYTHON_BIN -m unittest discover -s tests -p "test_*.py"

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

