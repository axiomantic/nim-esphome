import unittest
import nim_esphome

suite "nim_esphome":
  test "hello returns expected greeting":
    check hello() == "hello from nim_esphome"

  test "version present":
    check projectVersion == "0.0.1"
