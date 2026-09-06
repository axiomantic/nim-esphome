import std/unittest
import nim_esphome

suite "nim-esphome entity bindings":
  test "sensor publish state":
    let s = newSensor("temperature")
    check s.publishState(23.5'f32)
    check getSensorState("temperature") == 23.5'f32

  test "binary sensor publish state":
    let bs = newBinarySensor("motion")
    check bs.publishState(true)
    check getBinarySensorState("motion") == true
    check bs.publishState(false)
    check getBinarySensorState("motion") == false

  test "switch publish state":
    let sw = newSwitch("relay_1")
    check sw.publishState(true)
    check getSwitchState("relay_1") == true

  test "text sensor publish state":
    let ts = newTextSensor("status")
    check ts.publishState("online")
    check getTextSensorState("status") == "online"

  test "select entity callback and state publishing":
    type SoundTheme = enum
      stSpinner = "Spinner"
      stChime = "Chime"
      stSilent = "Silent"

    var selectedTheme = stSilent
    let sel = newSelect[SoundTheme]("sound_profile")
    sel.onState proc(theme: SoundTheme) =
      selectedTheme = theme

    triggerSelectState("sound_profile", "Spinner")
    check selectedTheme == stSpinner
    check getSelectState("sound_profile") == "Spinner"

    check sel.publishState(stChime)
    check getSelectState("sound_profile") == "Chime"

  test "number entity callback and state publishing":
    var observedVolume = 0.0'f32
    let num = newNumber("feedback_volume", min = 0.0, max = 100.0, step = 5.0)
    num.onState proc(vol: float32) =
      observedVolume = vol

    triggerNumberState("feedback_volume", 85.0'f32)
    check observedVolume == 85.0'f32
    check getNumberState("feedback_volume") == 85.0'f32

    check num.publishState(50.0'f32)
    check getNumberState("feedback_volume") == 50.0'f32

  test "switch entity callback":
    var switchVal = false
    let sw = newSwitch("wake_chime_switch")
    sw.onState proc(state: bool) =
      switchVal = state

    triggerSwitchState("wake_chime_switch", true)
    check switchVal == true

  test "button entity press callback":
    var pressed = false
    let btn = newButton("play_preview")
    btn.onPress proc() =
      pressed = true

    triggerButtonPress("play_preview")
    check pressed == true
    check getButtonPressCount("play_preview") == 1

