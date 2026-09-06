## `nim_esphome/dsl/dashboard`: Lovelace Dashboard Surface DSL.
##
## This module enables firmware developers to declaratively define Home Assistant
## Lovelace dashboard cards directly within their embedded Nim code.
##
## Features:
## - Compile-time construction of Lovelace `entities`, `tile`, `glance`, `grid`, and `button` cards.
## - Direct export to JSON and YAML formats compatible with Home Assistant Raw Dashboard Config.
## - Easy integration with ESPHome web servers or diagnostic configuration sensors.
##
## ## Example
##
## ```nim
## import nim_esphome/dsl/dashboard
##
## let satelliteCard = haCard(ctEntities, title = "Voice Satellite"):
##   card.icon = "mdi:microphone"
##   card.addEntity "select.processing_sound", name = "Processing Audio", icon = "mdi:progress-clock"
##   card.addEntity "number.processing_sound_volume", name = "Volume"
##   card.addEntity "switch.wake_chime", name = "Wake Chime", icon = "mdi:bell-ring"
##
## echo satelliteCard.toYaml()
## ```

import std/[json, strutils, options]

type
  CardType* = enum
    ## Standard Home Assistant Lovelace card types.
    ctEntities = "entities"
    ctTile = "tile"
    ctGlance = "glance"
    ctGrid = "grid"
    ctButton = "button"
    ctCustom = "custom"

  DashboardEntity* = object
    ## An entity row within a Lovelace card.
    entityId*: string
    name*: Option[string]
    icon*: Option[string]
    secondaryInfo*: Option[string]

  DashboardCard* = object
    ## A Lovelace card configuration.
    cardType*: CardType
    title*: Option[string]
    icon*: Option[string]
    columns*: Option[int]
    entities*: seq[DashboardEntity]
    customType*: Option[string]
    extraProps*: JsonNode

  LovelaceView* = object
    ## A view tab within a Home Assistant dashboard.
    title*: string
    path*: Option[string]
    icon*: Option[string]
    cards*: seq[DashboardCard]

  LovelaceDashboard* = object
    ## A complete Home Assistant Lovelace dashboard.
    title*: string
    views*: seq[LovelaceView]

proc newDashboardEntity*(
    entityId: string,
    name: string = "",
    icon: string = "",
    secondaryInfo: string = ""
): DashboardEntity =
  ## Creates a new Lovelace entity entry.
  DashboardEntity(
    entityId: entityId,
    name: if name.len > 0: some(name) else: none(string),
    icon: if icon.len > 0: some(icon) else: none(string),
    secondaryInfo: if secondaryInfo.len > 0: some(secondaryInfo) else: none(string)
  )

proc newDashboardCard*(
    cardType: CardType = ctEntities,
    title: string = "",
    icon: string = "",
    columns: int = 0
): DashboardCard =
  ## Creates a new Lovelace card with the specified card type.
  DashboardCard(
    cardType: cardType,
    title: if title.len > 0: some(title) else: none(string),
    icon: if icon.len > 0: some(icon) else: none(string),
    columns: if columns > 0: some(columns) else: none(int),
    entities: @[],
    customType: none(string),
    extraProps: newJObject()
  )

proc setTitle*(card: var DashboardCard, t: string) =
  ## Sets the title of the card.
  card.title = if t.len > 0: some(t) else: none(string)

proc setIcon*(card: var DashboardCard, ic: string) =
  ## Sets the icon of the card.
  card.icon = if ic.len > 0: some(ic) else: none(string)

proc setColumns*(card: var DashboardCard, cols: int) =
  ## Sets the column count for grid/glance cards.
  card.columns = if cols > 0: some(cols) else: none(int)

proc addEntity*(
    card: var DashboardCard,
    entityId: string,
    name: string = "",
    icon: string = "",
    secondaryInfo: string = ""
) =
  ## Appends an entity row to the Lovelace card.
  card.entities.add(newDashboardEntity(entityId, name, icon, secondaryInfo))

proc addEntity*(card: var DashboardCard, entity: DashboardEntity) =
  ## Appends an existing DashboardEntity to the card.
  card.entities.add(entity)

proc newLovelaceView*(title: string, path: string = "", icon: string = ""): LovelaceView =
  ## Creates a new dashboard view tab.
  LovelaceView(
    title: title,
    path: if path.len > 0: some(path) else: none(string),
    icon: if icon.len > 0: some(icon) else: none(string),
    cards: @[]
  )

proc addCard*(view: var LovelaceView, card: DashboardCard) =
  ## Adds a card to the dashboard view.
  view.cards.add(card)

proc newLovelaceDashboard*(title: string): LovelaceDashboard =
  ## Creates a new dashboard container.
  LovelaceDashboard(title: title, views: @[])

proc addView*(dashboard: var LovelaceDashboard, view: LovelaceView) =
  ## Adds a view tab to the dashboard.
  dashboard.views.add(view)

proc toJson*(entity: DashboardEntity): JsonNode =
  ## Converts a DashboardEntity to Home Assistant JSON format.
  if entity.name.isNone and entity.icon.isNone and entity.secondaryInfo.isNone:
    return newJString(entity.entityId)
  result = newJObject()
  result["entity"] = %entity.entityId
  if entity.name.isSome:
    result["name"] = %entity.name.get()
  if entity.icon.isSome:
    result["icon"] = %entity.icon.get()
  if entity.secondaryInfo.isSome:
    result["secondary_info"] = %entity.secondaryInfo.get()

proc toJson*(card: DashboardCard): JsonNode =
  ## Converts a DashboardCard to Home Assistant Lovelace JSON card format.
  result = newJObject()
  if card.cardType == ctCustom and card.customType.isSome:
    result["type"] = %("custom:" & card.customType.get())
  else:
    result["type"] = %( $card.cardType )
  if card.title.isSome:
    result["title"] = %card.title.get()
  if card.icon.isSome:
    result["icon"] = %card.icon.get()
  if card.columns.isSome:
    result["columns"] = %card.columns.get()
  if card.entities.len > 0:
    var entArray = newJArray()
    for e in card.entities:
      entArray.add(e.toJson())
    result["entities"] = entArray
  if card.extraProps != nil and card.extraProps.kind == JObject:
    for k, v in card.extraProps.pairs:
      result[k] = v

proc toJson*(view: LovelaceView): JsonNode =
  ## Converts a LovelaceView to Home Assistant JSON view format.
  result = newJObject()
  result["title"] = %view.title
  if view.path.isSome:
    result["path"] = %view.path.get()
  if view.icon.isSome:
    result["icon"] = %view.icon.get()
  var cardsArr = newJArray()
  for c in view.cards:
    cardsArr.add(c.toJson())
  result["cards"] = cardsArr

proc toJson*(dashboard: LovelaceDashboard): JsonNode =
  ## Converts an entire LovelaceDashboard to Home Assistant JSON format.
  result = newJObject()
  result["title"] = %dashboard.title
  var viewsArr = newJArray()
  for v in dashboard.views:
    viewsArr.add(v.toJson())
  result["views"] = viewsArr

proc toYaml*(card: DashboardCard, indentLevel: int = 0): string =
  ## Converts a DashboardCard to Home Assistant Lovelace YAML format.
  let pfx = repeat(" ", indentLevel)
  var lines: seq[string] = @[]
  if card.cardType == ctCustom and card.customType.isSome:
    lines.add(pfx & "type: custom:" & card.customType.get())
  else:
    lines.add(pfx & "type: " & $card.cardType)
  if card.title.isSome:
    lines.add(pfx & "title: \"" & card.title.get() & "\"")
  if card.icon.isSome:
    lines.add(pfx & "icon: \"" & card.icon.get() & "\"")
  if card.columns.isSome:
    lines.add(pfx & "columns: " & $card.columns.get())
  if card.entities.len > 0:
    lines.add(pfx & "entities:")
    for e in card.entities:
      if e.name.isNone and e.icon.isNone and e.secondaryInfo.isNone:
        lines.add(pfx & "  - " & e.entityId)
      else:
        lines.add(pfx & "  - entity: " & e.entityId)
        if e.name.isSome:
          lines.add(pfx & "    name: \"" & e.name.get() & "\"")
        if e.icon.isSome:
          lines.add(pfx & "    icon: \"" & e.icon.get() & "\"")
        if e.secondaryInfo.isSome:
          lines.add(pfx & "    secondary_info: \"" & e.secondaryInfo.get() & "\"")
  result = lines.join("\n")

proc toYaml*(dashboard: LovelaceDashboard): string =
  ## Converts an entire LovelaceDashboard to Home Assistant Lovelace YAML format.
  var lines: seq[string] = @[]
  lines.add("title: \"" & dashboard.title & "\"")
  lines.add("views:")
  for v in dashboard.views:
    lines.add("  - title: \"" & v.title & "\"")
    if v.path.isSome:
      lines.add("    path: " & v.path.get())
    if v.icon.isSome:
      lines.add("    icon: \"" & v.icon.get() & "\"")
    lines.add("    cards:")
    for c in v.cards:
      lines.add(c.toYaml(6))
  result = lines.join("\n")

template haCard*(cardKind: CardType, cardTitle: string = "", cardIcon: string = "", body: untyped): DashboardCard =
  ## Declarative builder template for a Lovelace dashboard card.
  var card {.inject.} = newDashboardCard(cardKind, title = cardTitle, icon = cardIcon)
  body
  card

template haDashboard*(dashTitle: string, body: untyped): LovelaceDashboard =
  ## Declarative builder template for a Lovelace dashboard.
  var dash {.inject.} = newLovelaceDashboard(dashTitle)
  body
  dash
