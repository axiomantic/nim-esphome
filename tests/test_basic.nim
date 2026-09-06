import unittest
import nim_esphome

suite "nim-esphome core":
  test "exportEsphome macro":
    proc myAdd(a, b: int32): int32 {.exportEsphome.} =
      a + b
    proc voidProc() {.exportEsphome.} =
      discard
    proc stringLen(s: cstring): int32 {.exportEsphome.} =
      int32(len($s))

    check myAdd(2, 3) == 5
    check stringLen("esphome") == 7
    voidProc()

  test "timing APIs":
    let t0 = millis()
    let u0 = micros()
    delayMs(5)
    let t1 = millis()
    let u1 = micros()
    check t1 >= t0
    check u1 >= u0

  test "logging templates":
    info("TestTag", "Info message")
    warn("TestTag", "Warning message")
    error("TestTag", "Error message")
    debug("TestTag", "Debug message")
    check true

  test "lifecycle templates":
    esphomeSetup:
      discard
    esphomeLoop:
      discard
    check true
