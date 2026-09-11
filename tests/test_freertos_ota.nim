import unittest
import nim_esphome
import nim_esphome/freertos
import nim_esphome/ota

suite "FreeRTOS & OTA Subsystems Suite":
  test "FreeRTOS task suspension and resumption mock":
    check suspendTask("mww") == true
    check "mww" in mockSuspendedTasks
    check resumeTask("mww") == true
    check "mww" notin mockSuspendedTasks

  test "OTA URL validation rules":
    check isValidOtaUrl("https://example.com/firmware.bin") == true
    check isValidOtaUrl("http://192.168.1.50/firmware.bin") == true
    check isValidOtaUrl("ftp://example.com/firmware.bin") == false
    check isValidOtaUrl("invalid") == false
    check isValidOtaUrl("") == false

  test "Host simulated OTA partition flash":
    check flashOtaPartition("https://example.com/firmware.bin") == true
    check flashOtaPartition("invalid-url") == false

  test "Preferences sync":
    check syncPreferences() == true
