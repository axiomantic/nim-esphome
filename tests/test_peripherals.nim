import std/unittest
import nim_esphome

suite "nim-esphome peripheral abstractions":
  test "gpio pin mode and write/read":
    pinMode(2, Output)
    digitalWrite(2, High)
    check digitalRead(2) == High

    digitalWrite(2, Low)
    check digitalRead(2) == Low

    digitalWrite(2, true)
    check digitalRead(2) == High
    digitalWrite(2, false)
    check digitalRead(2) == Low

  test "i2c device read and write register":
    let dev = newI2CDevice(0x68)
    check dev.writeRegister(0x10, [0xAA'u8, 0xBB'u8])
    let data = dev.readRegister(0x10, 2)
    check data.len == 2
    check data[0] == 0xAA'u8
    check data[1] == 0xBB'u8

  test "i2c single byte read and write":
    let dev = newI2CDevice(0x48)
    check dev.writeByte(0x01, 0x7F'u8)
    check dev.readByte(0x01) == 0x7F'u8
