#!/usr/bin/env bash
set -euo pipefail

# scripts/ci/test.sh: Unified test runner for nim-esphome.
# Can be run standalone locally or in CI (Forgejo Actions, GitHub Actions).

NIM_BIN="${NIM_BIN:-nim}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "=== Running nim-esphome unit tests (${NIM_BIN}) ==="
${NIM_BIN} c -r --path:src tests/test_basic.nim
rm -f tests/test_basic
${NIM_BIN} c -r --path:src tests/test_entities.nim
rm -f tests/test_entities
${NIM_BIN} c -r --path:src tests/test_peripherals.nim
rm -f tests/test_peripherals
${NIM_BIN} c -r --path:src tests/test_preferences.nim
rm -f tests/test_preferences
${NIM_BIN} c -r --path:src tests/test_dsp.nim
rm -f tests/test_dsp
${NIM_BIN} c -r --path:src tests/test_dsl.nim
rm -f tests/test_dsl
${NIM_BIN} c -r --path:src tests/test_examples.nim
rm -f tests/test_examples
if [ -f tests/test_freertos_ota.nim ]; then
    ${NIM_BIN} c -r --path:src tests/test_freertos_ota.nim
    rm -f tests/test_freertos_ota
fi

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

echo "=== All nim-esphome test checks passed! ==="
