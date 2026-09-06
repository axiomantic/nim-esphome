import nim_esphome

var lastToggle: uint32 = 0

esphomeSetup:
  info("BlinkNim", "Hello from Nim running on ESPHome!")

esphomeLoop:
  let now = millis()
  if now - lastToggle >= 2000:
    lastToggle = now
    info("BlinkNim", "Heartbeat tick from Nim loop!")
