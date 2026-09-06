import std/unittest
import nim_esphome

suite "nim-esphome DSL and Satellite Voice Architecture":
  test "esphomeControls declarative macro":
    type SoundProfile = enum
      spSilent = "Silent"
      spSpinner = "Spinner"
      spPulse = "Pulse"

    var selectedStyle = spSilent
    var chosenVolume = 0.0'f32
    var chimeActive = false
    var buttonHit = false

    esphomeControls:
      select[SoundProfile]("processing_sound"):
        name = "Processing Sound Style"
        default = spSpinner
        persist = true
        onSelect(style):
          selectedStyle = style

      number("processing_volume"):
        name = "Processing Volume"
        min = 0.0
        max = 100.0
        step = 5.0
        default = 80.0
        persist = true
        onChange(vol):
          chosenVolume = vol

      switch("wake_chime"):
        name = "Wake Chime Enabled"
        default = true
        persist = true
        onToggle(enabled):
          chimeActive = enabled

      button("test_trigger"):
        name = "Test Trigger"
        onPress:
          buttonHit = true

    # Defaults should have initialized and fired callbacks
    check selectedStyle == spSpinner
    check chosenVolume == 80.0'f32
    check chimeActive == true

    # Inbound triggers from Home Assistant
    triggerSelectState("processing_sound", "Pulse")
    check selectedStyle == spPulse

    triggerNumberState("processing_volume", 45.0'f32)
    check chosenVolume == 45.0'f32

    triggerSwitchState("wake_chime", false)
    check chimeActive == false

    triggerButtonPress("test_trigger")
    check buttonHit == true

  test "satellite pipeline lifecycle and processing sound loop":
    let pipeline = newSatellitePipeline()
    var stateTransitions: seq[SatelliteState] = @[]
    var audioTicks: seq[int] = @[]
    var chimePlayed = false
    var errorHandled = ""

    pipeline.onStateChange = proc(oldState, newState: SatelliteState) =
      stateTransitions.add(newState)

    pipeline.onPlayWakeChime = proc(vol: float32) =
      chimePlayed = true

    pipeline.onError = proc(code: string) =
      errorHandled = code

    pipeline.processingLoop.onTick = proc(style: ProcessingSoundStyle, vol: float32, count: int) =
      audioTicks.add(count)

    check pipeline.state == ssIdle
    check not pipeline.isProcessing()

    # 1. Wake word detected
    pipeline.handleWakeWord("okay nabu", 135.0'f32)
    check pipeline.state == ssListening
    check pipeline.lastWakeWord == "okay nabu"
    check pipeline.lastDoaAngle == 135.0'f32
    check chimePlayed == true
    check not pipeline.isProcessing()

    # 2. User finished speaking -> Processing starts
    pipeline.handleSpeechEnded()
    check pipeline.state == ssProcessing
    check pipeline.isProcessing()

    # 3. Time advances during LLM processing -> Processing loop ticks
    pipeline.tick(100)
    check audioTicks.len == 1
    check audioTicks[0] == 1

    pipeline.tick(150) # not yet elapsed (interval is 120ms)
    check audioTicks.len == 1

    pipeline.tick(230) # 130ms later -> second tick
    check audioTicks.len == 2
    check audioTicks[1] == 2

    # 4. Assistant begins streaming TTS response -> Speaking starts, processing loop stops immediately
    pipeline.handleTtsStart()
    check pipeline.state == ssSpeaking
    check not pipeline.isProcessing()

    # Extra ticks while speaking do nothing
    pipeline.tick(360)
    check audioTicks.len == 2

    # 5. Assistant finishes speaking -> Idle
    pipeline.handleTtsEnd()
    check pipeline.state == ssIdle
    check not pipeline.isProcessing()

    # 6. Error handling
    pipeline.handleSpeechEnded()
    check pipeline.state == ssProcessing
    pipeline.handleError("timeout_error")
    check errorHandled == "timeout_error"
    check pipeline.state == ssIdle
    check not pipeline.isProcessing()

    check ssListening in stateTransitions
    check ssProcessing in stateTransitions
    check ssSpeaking in stateTransitions
