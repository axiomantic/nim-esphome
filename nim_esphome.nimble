# Package

version = "0.0.1"
author = "Axiomantic Maintainers"
description = "Write ESPHome custom components, device logic, and drivers in Nim with zero-overhead C++ interop"
license = "MIT"
srcDir = "src"
installExt = @["nim"]

# Dependencies

requires "nim >= 2.0.0"

# Tasks

task test, "Run test suite":
  for file in listFiles("tests"):
    if (file.startsWith("tests/test") or file.startsWith("tests/t")) and
        file.endsWith(".nim") and not file.endsWith("config.nims"):
      exec "nim r --hints:off " & file
