## Lovelace Dashboard Surface Example
## Demonstrates `haDashboard`, `haCard`, and publishing Lovelace YAML to an ESPHome text sensor.

import nim_esphome
import nim_esphome/dsl/dashboard

var
  dashboardConfigSensor = newTextSensor("lovelace_card_yaml")
  roomTempSensor = newSensor("room_temp")
  doorBinary = newBinarySensor("door_contact")
  powerRelay = newSwitch("main_power")

proc buildLovelaceDashboard*(): string =
  let myDashboard = haDashboard("Smart Home Room Panel"):
    # 1. Main Controls View
    var controlsView = newLovelaceView("Controls", path = "controls", icon = "mdi:view-dashboard")

    let controlsCard = haCard(ctEntities, "Room Controls", "mdi:home"):
      card.addEntity "switch.main_power", name = "Main Power Relay", icon = "mdi:power"
      card.addEntity "sensor.room_temp", name = "Room Temperature"
      card.addEntity "binary_sensor.door_contact", name = "Door Sensor"

    controlsView.addCard(controlsCard)

    # 2. Quick Glance Status Card
    let statusCard = haCard(ctGlance, "Quick Status"):
      card.setColumns(3)
      card.addEntity "sensor.room_temp", name = "Temp"
      card.addEntity "binary_sensor.door_contact", name = "Door"
      card.addEntity "switch.main_power", name = "Power"

    controlsView.addCard(statusCard)
    dash.addView(controlsView)

  myDashboard.toYaml()

esphomeSetup:
  info("DashboardExample", "Synthesizing Lovelace dashboard YAML...")
  let yamlStr = buildLovelaceDashboard()
  dashboardConfigSensor.publishState(yamlStr)
  info("DashboardExample", "Lovelace YAML published to text_sensor.lovelace_card_yaml")

esphomeLoop:
  discard
