import std/unittest
import nim_esphome

suite "Tripwire Symbol & ABI Verification":
  test "verify foreign C function resolves and computes":
    let res = nim_esphome_add(10, 20)
    check res == 30
