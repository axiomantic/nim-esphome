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
