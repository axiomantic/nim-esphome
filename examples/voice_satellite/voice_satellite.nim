## Voice Satellite Example
## Demonstrates `esphomeControls`, `satellitePipeline`, and audio processing sound loop.

import nim_esphome
import nim_esphome/dsl/satellite
import nim_esphome/dsl/entities
import nim_esphome/dsl/dashboard

var
  pipeline* = newSatellitePipeline()
  configuredStyle* = psSpinner
  configuredVolume* = 75.0'f32
  wakeChimeActive* = true
  wakeChimeVol* = 80.0'f32

esphomeControls:
  select[ProcessingSoundStyle]("processing_sound"):
    name = "Processing Audio Style"
    default = psSpinner
    persist = true
    onSelect(style):
      configuredStyle = style
      pipeline.processingLoop.style = style

  number("processing_sound_volume"):
    name = "Processing Volume"
    min = 0.0
    max = 100.0
    step = 5.0
    default = 75.0
    persist = true
    onChange(vol):
      configuredVolume = vol
      pipeline.processingLoop.volume = vol / 100.0

  switch("wake_chime"):
    name = "Wake Chime"
    default = true
    persist = true
    onToggle(enabled):
      wakeChimeActive = enabled
      pipeline.wakeChimeEnabled = enabled

  number("wake_chime_volume"):
    name = "Wake Chime Volume"
    min = 0.0
    max = 100.0
    step = 5.0
    default = 80.0
    persist = true
    onChange(vol):
      wakeChimeVol = vol
      pipeline.wakeChimeVolume = vol / 100.0

proc onWakeWordDetected*(word: cstring) {.exportEsphome.} =
  info("Satellite", "Wake word detected: " & $word)
  pipeline.handleWakeWord($word, 0.0'f32)

proc onSpeechEnded*() {.exportEsphome.} =
  info("Satellite", "Speech finished -> entering processing state")
  pipeline.handleSpeechEnded()
  pipeline.startProcessingLoop(configuredStyle)

proc onTtsStarted*() {.exportEsphome.} =
  info("Satellite", "TTS playback started -> halting processing loop")
  pipeline.stopProcessingLoop()
  pipeline.handleTtsStart()

proc onTtsFinished*() {.exportEsphome.} =
  info("Satellite", "TTS finished -> returning to idle")
  pipeline.handleTtsEnd()

proc onError*(code: cstring) {.exportEsphome.} =
  warn("Satellite", "Error encountered: " & $code)
  pipeline.stopProcessingLoop()
  pipeline.handleError($code)

proc generateLovelaceCard*(): string =
  let myCard = haCard(ctEntities, "Voice Satellite Controls", "mdi:microphone"):
    card.addEntity "select.processing_sound", name = "Audio Feedback", icon = "mdi:progress-clock"
    card.addEntity "number.processing_sound_volume", name = "Processing Volume"
    card.addEntity "switch.wake_chime", name = "Wake Chime", icon = "mdi:bell-ring"
    card.addEntity "number.wake_chime_volume", name = "Chime Volume"
  myCard.toYaml()

esphomeSetup:
  info("VoiceSatellite", "Satellite pipeline and controls initialized")

esphomeLoop:
  pipeline.tick(millis())
