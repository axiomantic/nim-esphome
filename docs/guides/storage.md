# Flash Preferences & Non-Volatile Storage (NVS)

This guide explains how to store configuration settings, calibration data, and runtime state across power loss and firmware reboots using `nim_esphome/preferences`.

---

## Why NVS Preferences?

Microcontroller RAM is volatile—whenever power is cycled or the watchdog triggers a reboot, all variable states are reset. 

ESPHome incorporates a flash-backed Non-Volatile Storage (NVS) subsystem (`ESPPreferences`) with built-in wear leveling. `nim-esphome` wraps this system into idiomatic, generic Nim procedures:
- Store numeric primitives (`int32`, `float32`, `bool`)
- Store custom structs (`CalibrationData`, `NetworkConfig`)
- Store arbitrary strings (`SSID`, token strings)
- Key items using either 32-bit integer IDs or human-readable string names

---

## String Keys & FNV-1a Hashing

ESPHome's internal preference engine identifies storage slots using 32-bit integer hashes. `nim-esphome` allows you to pass string keys directly; behind the scenes, it computes a standard 32-bit **Fowler–Noll–Vo (FNV-1a)** hash:

$$\text{hash} = \left( (\text{hash} \oplus \text{byte}) \times 16777619 \right) \pmod{2^{32}}$$

```nim
import nim_esphome

# Both are functionally identical:
discard savePreference("boot_count", 42'i32)
discard savePreference(fnv1a("boot_count"), 42'i32)
```

---

## Storing and Loading Primitives

`loadPreference` supports type inference from the default fallback value:

```nim
import nim_esphome

# Load previous boot counter; fallback to 0 on initial device flash
var bootCount = loadPreference("boot_count", 0'i32)
inc bootCount
discard savePreference("boot_count", bootCount)
info("Boot", "Device boot count: " & $bootCount)

# Load target temperature threshold; fallback to 21.5°C
var targetTemp = loadPreference("target_temp", 21.5'f32)
```

---

## Storing Custom Structs

Any fixed-size `object` or `tuple` can be persisted directly:

```nim
import nim_esphome

type
  SensorCalibration = object
    offset: float32
    multiplier: float32
    calibratedAtBoot: uint32

var cal = loadPreference("temp_cal", SensorCalibration(offset: 0.0'f32, multiplier: 1.0'f32, calibratedAtBoot: 0))

# Update and persist
cal.offset = -0.45'f32
cal.multiplier = 1.02'f32
cal.calibratedAtBoot = millis()
discard savePreference("temp_cal", cal)
```

---

## Storing Strings

Null-terminated strings can be saved and loaded with a configurable maximum buffer size (default 128 bytes):

```nim
import nim_esphome

# Save string
discard savePreference("wifi_ssid", "HomeAutomation-IoT")

# Load string (fallback if missing)
let currentSsid = loadPreference("wifi_ssid", "DefaultFallbackSSID", maxLen = 64)
info("WiFi", "Configured SSID: " & currentSsid)
```
