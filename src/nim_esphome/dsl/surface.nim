## `nim_esphome/dsl/surface`: Composite Hardware Device DSL.
##
## This module provides a unified abstraction for modeling smart home hardware surfaces
## that combine controls, telemetry sensors, actions, and dashboard UI representations.
##
## Features:
## - Single declarative specification combining device metadata, controls, and telemetry.
## - Auto-generates a matched Home Assistant Lovelace dashboard card (`DashboardCard`).
## - Auto-generates the corresponding ESPHome component YAML.
## - Automatically associates all entities with the Home Assistant Device Registry.
##
## ## Example
##
## ```nim
## import nim_esphome/dsl/surface
## import nim_esphome/dsl/dashboard
##
## let satelliteSurface = haSurface("voice_satellite"):
##   surface.name = "Voice Satellite"
##   surface.model = "ReSpeaker XVF3800"
##   surface.manufacturer = "Seeed Studio"
##   surface.area = "Living Room"
##
##   surface.addControl(sekSelect, "processing_sound", name = "Processing Sound", icon = "mdi:progress-clock")
##   surface.addControl(sekNumber, "processing_sound_volume", name = "Volume", icon = "mdi:volume-high")
##   surface.addControl(sekSwitch, "wake_chime", name = "Wake Chime", icon = "mdi:bell-ring")
##
##   surface.addTelemetry(sekSensor, "wifi_rssi", name = "Wi-Fi Signal", unit = "dBm")
##
## let card = satelliteSurface.generateDashboardCard()
## echo card.toYaml()
## ```

import std/[options, strutils, strformat]
import nim_esphome/dsl/dashboard

type
  SurfaceEntityKind* = enum
    ## Supported entity domains within a hardware surface.
    sekSelect = "select"
    sekNumber = "number"
    sekSwitch = "switch"
    sekButton = "button"
    sekSensor = "sensor"
    sekBinarySensor = "binary_sensor"
    sekTextSensor = "text_sensor"

  SurfaceEntityDef* = object
    ## Definition of a control or telemetry entity on the surface.
    kind*: SurfaceEntityKind
    id*: string
    name*: string
    icon*: Option[string]
    unit*: Option[string]
    deviceClass*: Option[string]
    isControl*: bool

  HardwareSurface* = ref object
    ## Unified model representing a physical device surface in Home Assistant.
    id*: string
    name*: string
    model*: string
    manufacturer*: string
    area*: string
    entities*: seq[SurfaceEntityDef]

proc newHardwareSurface*(id: string, name: string = ""): HardwareSurface =
  ## Creates a new HardwareSurface instance.
  HardwareSurface(
    id: id,
    name: if name.len > 0: name else: id,
    model: "ESPHome Smart Device",
    manufacturer: "Axiomantic",
    area: "",
    entities: @[]
  )

proc addControl*(
    surface: HardwareSurface,
    kind: SurfaceEntityKind,
    id: string,
    name: string = "",
    icon: string = "",
    unit: string = "",
    deviceClass: string = ""
) =
  ## Adds an interactive control entity (select, number, switch, button) to the surface.
  surface.entities.add(SurfaceEntityDef(
    kind: kind,
    id: id,
    name: if name.len > 0: name else: id,
    icon: if icon.len > 0: some(icon) else: none(string),
    unit: if unit.len > 0: some(unit) else: none(string),
    deviceClass: if deviceClass.len > 0: some(deviceClass) else: none(string),
    isControl: true
  ))

proc addTelemetry*(
    surface: HardwareSurface,
    kind: SurfaceEntityKind,
    id: string,
    name: string = "",
    icon: string = "",
    unit: string = "",
    deviceClass: string = ""
) =
  ## Adds a read-only telemetry sensor (sensor, binary_sensor, text_sensor) to the surface.
  surface.entities.add(SurfaceEntityDef(
    kind: kind,
    id: id,
    name: if name.len > 0: name else: id,
    icon: if icon.len > 0: some(icon) else: none(string),
    unit: if unit.len > 0: some(unit) else: none(string),
    deviceClass: if deviceClass.len > 0: some(deviceClass) else: none(string),
    isControl: false
  ))

proc generateDashboardCard*(surface: HardwareSurface): DashboardCard =
  ## Synthesizes a matched Home Assistant Lovelace Entities card for this surface.
  var card = newDashboardCard(ctEntities, title = surface.name)
  for ent in surface.entities:
    let domainPrefix = $ent.kind & "."
    let fullEntityId = if ent.id.startsWith(domainPrefix): ent.id else: domainPrefix & ent.id
    var dEntity = newDashboardEntity(fullEntityId, name = ent.name)
    if ent.icon.isSome:
      dEntity.icon = ent.icon
    card.addEntity(dEntity)
  card

proc generateLovelaceYaml*(surface: HardwareSurface): string =
  ## Generates the ready-to-paste Lovelace YAML card for this surface.
  let card = surface.generateDashboardCard()
  card.toYaml()

proc generateEsphomeYaml*(surface: HardwareSurface): string =
  ## Generates the ESPHome YAML entity declarations for this surface.
  var lines: seq[string] = @[]
  lines.add("# =============================================================================")
  lines.add(fmt"# Generated Hardware Surface: {surface.name} ({surface.model})")
  lines.add("# =============================================================================")

  # Group by domain
  var byDomain: seq[(SurfaceEntityKind, seq[SurfaceEntityDef])] = @[]
  for e in surface.entities:
    var found = false
    for i in 0 ..< byDomain.len:
      if byDomain[i][0] == e.kind:
        byDomain[i][1].add(e)
        found = true
        break
    if not found:
      byDomain.add((e.kind, @[e]))

  for (kind, ents) in byDomain:
    lines.add("")
    lines.add($kind & ":")
    for ent in ents:
      lines.add("  - platform: template")
      lines.add("    id: " & ent.id)
      lines.add("    name: \"" & ent.name & "\"")
      if ent.icon.isSome:
        lines.add("    icon: \"" & ent.icon.get() & "\"")
      if ent.unit.isSome:
        lines.add("    unit_of_measurement: \"" & ent.unit.get() & "\"")
      if ent.deviceClass.isSome:
        lines.add("    device_class: \"" & ent.deviceClass.get() & "\"")
      if ent.isControl:
        lines.add("    optimistic: true")

  result = lines.join("\n")

template haSurface*(surfaceId: string, body: untyped): HardwareSurface =
  ## Declarative builder template for a HardwareSurface.
  var surface {.inject.} = newHardwareSurface(surfaceId)
  body
  surface
