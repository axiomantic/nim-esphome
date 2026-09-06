# Package

version       = "0.2.0"
author        = "Elijah Rust"
description   = "Write ESPHome custom components and logic in Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"

task test, "Run native host unit tests":
  exec "nim c -r --path:src tests/test_basic.nim"
  exec "nim c -r --path:src tests/test_entities.nim"
  exec "nim c -r --path:src tests/test_peripherals.nim"
  exec "nim c -r --path:src tests/test_preferences.nim"
  exec "nim c -r --path:src tests/test_dsp.nim"
  exec "nim c -r --path:src tests/test_dsl.nim"

task check_cpp, "Verify embedded C++ generation for ESP32 target":
  exec "nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on --path:src examples/blink/blink.nim"
