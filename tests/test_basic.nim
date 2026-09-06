import unittest
import nim_esphome

suite "nim-esphome core":
  test "exportEsphome macro":
    proc myAdd(a, b: int32): int32 {.exportEsphome.} =
      a + b
    check myAdd(2, 3) == 5

  test "lifecycle templates compile":
    esphomeSetup:
      discard
    esphomeLoop:
      discard
    check true
