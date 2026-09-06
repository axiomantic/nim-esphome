#!/usr/bin/env bash
set -euo pipefail

echo "=== Running nim-esphome unit tests ==="
nim c -r --path:src tests/test_basic.nim
rm -f tests/test_basic

echo "=== Testing embedded C++ code generation (ESP32-S3 target) ==="
nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim

echo "=== All nim-esphome checks passed! ==="
