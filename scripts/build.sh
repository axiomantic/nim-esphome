#!/usr/bin/env bash
set -euo pipefail

NIM_BIN="${NIM_BIN:-nim}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "=== Running nim-esphome unit tests (${NIM_BIN}) ==="
for t in tests/test_basic.nim tests/test_entities.nim tests/test_peripherals.nim tests/test_preferences.nim tests/test_dsp.nim tests/test_dsl.nim tests/test_examples.nim tests/test_freertos_ota.nim; do
    if [ -f "$t" ]; then
        ${NIM_BIN} c -r --path:src "$t"
        rm -f "${t%.nim}"
    fi
done

echo "=== Testing embedded C++ code generation (Xtensa ESP32 target) ==="
${NIM_BIN} cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Testing embedded C++ code generation (RISC-V ESP32-C3/C6 target) ==="
${NIM_BIN} cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:riscv32 --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Testing embedded C++ code generation (ARM RP2040 target) ==="
${NIM_BIN} cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:arm --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Running Python component tests ==="
if command -v uv >/dev/null 2>&1; then
    uv run --with esphome python -m unittest discover -s tests -p "test_*.py"
elif [ -n "${VIRTUAL_ENV:-}" ] && [ -x "${VIRTUAL_ENV}/bin/python" ]; then
    "${VIRTUAL_ENV}/bin/python" -m unittest discover -s tests -p "test_*.py"
elif command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
    "${PYTHON_BIN}" -m unittest discover -s tests -p "test_*.py"
else
    echo "Python not found, skipping Python component tests"
fi

echo "=== Building documentation site with Zensical ==="
if command -v asdf >/dev/null 2>&1 && asdf which nim >/dev/null 2>&1; then
    NIM_PATH="$(asdf which nim)"
else
    NIM_PATH="$(which nim)"
fi
NIM_REAL="$(readlink -f "$NIM_PATH" 2>/dev/null || echo "$NIM_PATH")"
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
