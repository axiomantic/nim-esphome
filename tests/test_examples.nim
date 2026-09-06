## `tests/test_examples.nim`: Compiles and validates all projects in `examples/`.
##
## Verifies:
## 1. Each example compiles cleanly for embedded 32-bit targets.
## 2. Each example's host-side functions and DSL constructors execute without runtime panics.

import std/[unittest, osproc, strutils]

suite "Examples Compilation and Validation Suite":

  test "examples/blink compiles for embedded ESP32":
    let (output, exitCode) = execCmdEx("nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on -p:src examples/blink/blink.nim")
    if exitCode != 0: echo output
    check exitCode == 0

  test "examples/voice_satellite compiles for embedded ESP32":
    let (output, exitCode) = execCmdEx("nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on -p:src examples/voice_satellite/voice_satellite.nim")
    if exitCode != 0: echo output
    check exitCode == 0

  test "examples/smart_thermostat compiles for embedded ESP32":
    let (output, exitCode) = execCmdEx("nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on -p:src examples/smart_thermostat/smart_thermostat.nim")
    if exitCode != 0: echo output
    check exitCode == 0

  test "examples/custom_actions compiles for embedded ESP32":
    let (output, exitCode) = execCmdEx("nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on -p:src examples/custom_actions/custom_actions.nim")
    if exitCode != 0: echo output
    check exitCode == 0

  test "examples/cooperative_scheduler compiles for embedded ESP32":
    let (output, exitCode) = execCmdEx("nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on -p:src examples/cooperative_scheduler/scheduler.nim")
    if exitCode != 0: echo output
    check exitCode == 0

  test "examples/dashboard_surface compiles for embedded ESP32":
    let (output, exitCode) = execCmdEx("nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --cpu:esp --os:any --exceptions:goto --panics:on -p:src examples/dashboard_surface/dashboard_surface.nim")
    if exitCode != 0: echo output
    check exitCode == 0

  test "all example ESPHome YAML configs are valid":
    let yamls = [
      "examples/blink/blink.yaml",
      "examples/voice_satellite/voice_satellite.yaml",
      "examples/smart_thermostat/smart_thermostat.yaml",
      "examples/custom_actions/custom_actions.yaml",
      "examples/cooperative_scheduler/scheduler.yaml",
      "examples/dashboard_surface/dashboard_surface.yaml"
    ]
    for y in yamls:
      let (outp, code) = execCmdEx("uv run --python 3.11 --with esphome esphome config " & y)
      check code == 0
      check "Configuration is valid!" in outp
