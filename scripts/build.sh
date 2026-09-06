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

echo "=== Testing embedded C++ code generation (Xtensa ESP32 target) ==="
nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Testing embedded C++ code generation (RISC-V ESP32-C3/C6 target) ==="
nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:riscv32 --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Testing embedded C++ code generation (ARM RP2040 target) ==="
nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:arm --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== Running Python component tests ==="
PYTHON_BIN="python3"
if [ -x "/Users/eek/Development/voicesolate/.venv/bin/python" ]; then
    PYTHON_BIN="/Users/eek/Development/voicesolate/.venv/bin/python"
fi
$PYTHON_BIN -m unittest discover -s tests -p "test_*.py"

echo "=== All nim-esphome checks passed! ==="
