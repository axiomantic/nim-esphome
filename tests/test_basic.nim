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

  test "system and hardware APIs":
    let heap = getFreeHeap()
    check heap >= 1024'u32 * 1024'u32
    feedWatchdog()
    yieldToScheduler()
    reboot()
    check getFreeHeap() == heap

  test "logging templates":
    info("TestTag", "Info message")
    warn("TestTag", "Warning message")
    error("TestTag", "Error message")
    debug("TestTag", "Debug message")
    check true # Logging outputs to host stdout or ESP32 log buffer without throwing

  test "lifecycle templates":
    var setupExecuted = false
    var loopExecuted = false
    esphomeSetup:
      setupExecuted = true
    esphomeLoop:
      loopExecuted = true

    nim_on_setup()
    check setupExecuted == true

    nim_on_loop()
    check loopExecuted == true
