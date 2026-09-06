import std/unittest
import nim_esphome

suite "nim-esphome flash preferences storage":
  test "save and load primitive types":
    check savePreference(1234'u32, 42'i32)
    check loadPreference(1234'u32, 0'i32) == 42'i32

    check savePreference("target_temp", 22.5'f32)
    check loadPreference("target_temp", 0.0'f32) == 22.5'f32

    check savePreference("is_active", true)
    check loadPreference("is_active", false) == true

  test "save and load string values":
    check savePreference("wifi_ssid", "HomeIoT")
    check loadPreference("wifi_ssid", "") == "HomeIoT"

  test "default fallback on missing keys":
    check loadPreference("nonexistent_int", 99'i32) == 99'i32
    check loadPreference("nonexistent_str", "default_val") == "default_val"
