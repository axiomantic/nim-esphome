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
nim c -r --path:src tests/test_dsl.nim
rm -f tests/test_dsl
nim c -r --path:src tests/test_examples.nim
rm -f tests/test_examples

echo "=== Testing embedded C++ code generation (Xtensa ESP32 target) ==="
nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Testing embedded C++ code generation (RISC-V ESP32-C3/C6 target) ==="
nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:riscv32 --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Testing embedded C++ code generation (ARM RP2040 target) ==="
nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:arm --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Running Python component tests ==="
if command -v uv >/dev/null 2>&1; then
    uv run --with esphome python -m unittest discover -s tests -p "test_*.py"
elif [ -n "${VIRTUAL_ENV:-}" ] && [ -x "${VIRTUAL_ENV}/bin/python" ]; then
    "${VIRTUAL_ENV}/bin/python" -m unittest discover -s tests -p "test_*.py"
else
    python3 -m unittest discover -s tests -p "test_*.py"
fi

echo "=== All nim-esphome checks passed! ==="
