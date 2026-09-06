## Custom Actions and Remote Services Example
## Demonstrates `haService` / `haAction` for type-safe Home Assistant remote actions.

import nim_esphome
import nim_esphome/dsl/actions

var
  lastToneFreq: int = 440
  lastToneDuration: int = 200
  ledPattern: string = "solid"
  ledBrightness: float32 = 1.0'f32
  activeBuzzer = newSwitch("buzzer_relay")

# 1. Action with integer and string parameters
haService("play_tone"):
  def.description = "Plays a tone on the physical buzzer"
  param "frequency", pkInt, min = 100.0, max = 5000.0, defaultVal = "440", description = "Tone frequency in Hz"
  param "duration_ms", pkInt, min = 10.0, max = 2000.0, defaultVal = "200", description = "Duration in milliseconds"

  onExecute(ctx):
    lastToneFreq = ctx.getInt("frequency")
    lastToneDuration = ctx.getInt("duration_ms")
    info("ToneAction", "Playing tone: " & $lastToneFreq & " Hz for " & $lastToneDuration & " ms")
    activeBuzzer.publishState(true)

# 2. Action with float and string parameters
haAction("set_light_effect"):
  def.description = "Sets the RGB notification effect"
  param "pattern", pkString, defaultVal = "pulse", description = "Effect name (pulse, blink, solid)"
  param "brightness", pkFloat, min = 0.0, max = 1.0, defaultVal = "0.8", description = "Target brightness"

  onExecute(ctx):
    ledPattern = ctx.getString("pattern")
    ledBrightness = float32(ctx.getFloat("brightness"))
    info("LedAction", "Pattern set to: " & ledPattern & " at brightness=" & $ledBrightness)

esphomeSetup:
  info("CustomActions", "Services play_tone and set_light_effect registered successfully")

esphomeLoop:
  discard
