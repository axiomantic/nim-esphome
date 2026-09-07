## `nim_esphome/dsl/installer`: Declarative Web Installer & Dynamic Flashing DSL.
##
## This module enables developers to programmatically specify web flashing forms,
## custom file upload fields (audio files, display bitmaps, configuration blobs),
## and dynamic manifest generation with verified ESP32 flash partition safety.
##
## Features:
## - Declarative `esphomeInstaller` builder.
## - Support for file uploads, selects, text inputs, and checkboxes.
## - Automated partition layout calculation ensuring user assets never collide with OTA partitions (`app0`/`app1`).
## - Full HTML + WebSerial JavaScript generation using modern `<esp-web-install-button>`.
## - Base and dynamic `manifest.json` generation.
##
## ## Example
##
## ```nim
## import nim_esphome/dsl/installer
##
## let satelliteInstaller = esphomeInstaller("voice-satellite"):
##   installer.title = "Voice Satellite Web Installer"
##   installer.chipFamily = "ESP32-S3"
##   installer.description = "Flash verified voice satellite firmware and customize audio assets."
##
##   installer.addFileField(
##     name = "custom_audio",
##     label = "Custom Processing Audio (.wav)",
##     accept = ".wav,audio/wav",
##     partition = "sound_data",
##     maxSize = 262144, # 256 KB
##     description = "Optional audio loop played while assistant is thinking"
##   )
##
##   installer.addSelectField(
##     name = "default_style",
##     label = "Audio Feedback Style",
##     options = @["Spinner", "Pulse", "Sonar", "Tick", "Silent"],
##     defaultVal = "Spinner"
##   )
##
## echo satelliteInstaller.generatePartitionsCsv(flashSizeMb = 4)
## echo satelliteInstaller.generateHtml()
## ```

import std/[json, strutils]

type
  InstallerFieldKind* = enum
    ## Field types available for the web installer form.
    ifkFile = "file"
    ifkSelect = "select"
    ifkText = "text"
    ifkNumber = "number"
    ifkCheckbox = "checkbox"
    ifkWakeWordSlots = "wake_word_slots"

  FlashPartition* = object
    ## Definition of a custom data partition in ESP32 flash.
    name*: string
    partType*: string
    subType*: string
    offset*: uint32
    size*: uint32

  OptionDetail* = object
    ## Rich documentation for a select dropdown option.
    value*: string
    cadence*: string
    description*: string

  InstallerField* = object
    ## A customizable input field on the flashing webpage.
    name*: string
    kind*: InstallerFieldKind
    label*: string
    description*: string
    required*: bool
    # File-specific fields
    accept*: string
    maxSize*: int
    partition*: string
    flashOffset*: uint32
    # Multi-slot specific fields
    maxSlots*: int
    slotOffsets*: seq[uint32]
    presetModels*: seq[(string, string)]
    presetAudios*: seq[(string, string, string)]
    # Select / Text specific fields
    options*: seq[string]
    optionDetails*: seq[OptionDetail]
    defaultVal*: string
    minVal*: float
    maxVal*: float
    stepVal*: float
    placeholder*: string
    calloutHtml*: string
    hasAudioPreview*: bool
    # Reactive / conditional dependency
    dependsOnField*: string
    dependsOnValue*: string

  InstallerTarget* = object
    ## Definition of a specific hardware board / chip variant target.
    name*: string
    binPath*: string
    chipFamily*: string
    description*: string

  InstallerDefinition* = ref object
    ## Complete definition of an ESP-Web-Tools web installer.
    name*: string
    title*: string
    description*: string
    chipFamily*: string
    version*: string
    homeAssistantDomain*: string
    fundingUrl*: string
    factoryBinPath*: string
    fields*: seq[InstallerField]
    targets*: seq[InstallerTarget]
    customPartitions*: seq[FlashPartition]

proc optionDetail*(value: string, cadence: string = "", description: string = ""): OptionDetail =
  ## Helper to construct rich documentation for select options.
  OptionDetail(value: value, cadence: cadence, description: description)

proc newInstallerDefinition*(
    name: string,
    title: string = "",
    chipFamily: string = "ESP32-S3",
    version: string = "0.2.0"
): InstallerDefinition =
  ## Creates a new InstallerDefinition.
  InstallerDefinition(
    name: name,
    title: if title.len > 0: title else: name & " Installer",
    description: "",
    chipFamily: chipFamily,
    version: version,
    homeAssistantDomain: "esphome",
    fundingUrl: "",
    factoryBinPath: "firmware-factory.bin",
    fields: @[],
    targets: @[],
    customPartitions: @[]
  )

proc addFileField*(
    installer: InstallerDefinition,
    name: string,
    label: string,
    accept: string = ".wav",
    partition: string = "custom_data",
    maxSize: int = 262144, # 256 KB default
    flashOffset: uint32 = 0x370000'u32,
    required: bool = false,
    description: string = "",
    dependsOnField: string = "",
    dependsOnValue: string = ""
) =
  ## Adds a custom file upload field that will be flashed to a designated partition.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkFile,
    label: label,
    accept: accept,
    partition: partition,
    maxSize: maxSize,
    flashOffset: flashOffset,
    required: required,
    description: description,
    dependsOnField: dependsOnField,
    dependsOnValue: dependsOnValue
  ))
  # Ensure the partition is registered
  var found = false
  for p in installer.customPartitions:
    if p.name == partition:
      found = true
      break
  if not found:
    installer.customPartitions.add(FlashPartition(
      name: partition,
      partType: "data",
      subType: "0x82",
      offset: flashOffset,
      size: uint32(maxSize)
    ))

proc addTarget*(
    installer: InstallerDefinition,
    name: string,
    binPath: string,
    chipFamily: string = "ESP32-S3",
    description: string = ""
) =
  ## Registers a hardware board target with its corresponding factory binary.
  installer.targets.add(InstallerTarget(
    name: name,
    binPath: binPath,
    chipFamily: chipFamily,
    description: description
  ))

proc addSelectField*(
    installer: InstallerDefinition,
    name: string,
    label: string,
    options: seq[string],
    defaultVal: string = "",
    description: string = "",
    optionDetails: seq[OptionDetail] = @[],
    hasAudioPreview: bool = false,
    presetAudios: seq[(string, string, string)] = @[]
) =
  ## Adds a dropdown selector to the installer with optional rich preset metadata.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkSelect,
    label: label,
    options: options,
    optionDetails: optionDetails,
    defaultVal: defaultVal,
    description: description,
    hasAudioPreview: hasAudioPreview,
    presetAudios: presetAudios
  ))

proc addTextField*(
    installer: InstallerDefinition,
    name: string,
    label: string,
    defaultVal: string = "",
    placeholder: string = "",
    calloutHtml: string = "",
    description: string = "",
    dependsOnField: string = "",
    dependsOnValue: string = ""
) =
  ## Adds a text input to the installer.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkText,
    label: label,
    defaultVal: defaultVal,
    placeholder: placeholder,
    calloutHtml: calloutHtml,
    description: description,
    dependsOnField: dependsOnField,
    dependsOnValue: dependsOnValue
  ))

proc addNumberField*(
    installer: InstallerDefinition,
    name: string,
    label: string,
    min: float = 0.0,
    max: float = 100.0,
    step: float = 1.0,
    defaultVal: float = 0.0,
    description: string = ""
) =
  ## Adds a numeric input to the installer.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkNumber,
    label: label,
    minVal: min,
    maxVal: max,
    stepVal: step,
    defaultVal: $defaultVal,
    description: description
  ))

proc addCheckboxField*(
    installer: InstallerDefinition,
    name: string,
    label: string,
    defaultVal: bool = false,
    description: string = ""
) =
  ## Adds a boolean checkbox to the installer.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkCheckbox,
    label: label,
    defaultVal: if defaultVal: "true" else: "false",
    description: description
  ))

proc addWakeWordSlotsField*(
    installer: InstallerDefinition,
    name: string = "wake_words",
    label: string = "Active Wake Word Models (Up to 3 Concurrent)",
    options: seq[string] = @["Okay Nabu (Default)", "Hey Jarvis", "Alexa"],
    maxSlots: int = 3,
    slotOffsets: seq[uint32] = @[0x3B0000'u32, 0x3F0000'u32, 0x430000'u32],
    description: string = "ESP32-S3 hardware neural accelerator runs up to 3 wake word models concurrently in parallel. Add slots to configure multiple active wake words.",
    presetModels: seq[(string, string)] = @[]
) =
  ## Registers a multi-slot wake word selector with support for concurrent models,
  ## bundled example/preset models, and pre-trained .tflite uploads.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkWakeWordSlots,
    label: label,
    options: options,
    maxSlots: maxSlots,
    slotOffsets: slotOffsets,
    description: description,
    presetModels: presetModels
  ))
  for i in 0 ..< maxSlots:
    let partName = "wake_model_" & $(i + 1)
    let offset = if i < slotOffsets.len: slotOffsets[i] else: uint32(0x3B0000 + (i * 0x40000))
    var found = false
    for p in installer.customPartitions:
      if p.name == partName:
        found = true
        break
    if not found:
      installer.customPartitions.add(FlashPartition(
        name: partName,
        partType: "data",
        subType: "0x82",
        offset: offset,
        size: 262144'u32
      ))

proc generatePartitionsCsv*(installer: InstallerDefinition, flashSizeMb: int = 4): string =
  ## Generates an ESP-IDF / ESPHome compliant partition table CSV.
  ## Calculates `app0` and `app1` sizes to ensure custom user partitions never overlap OTA slots.
  var lines: seq[string] = @[
    "# ESP-IDF Partition Table generated by nim-esphome installer DSL",
    "# Name,   Type, SubType, Offset,   Size, Flags",
    "nvs,      data, nvs,     0x9000,   0x5000,",
    "otadata,  data, ota,     0xe000,   0x2000,"
  ]

  let totalBytes = flashSizeMb * 1024 * 1024
  var customTotal: uint32 = 0
  for p in installer.customPartitions:
    customTotal += p.size

  if flashSizeMb == 4:
    # On 4MB flash (0x400000):
    # App starts at 0x10000. We allocate 1.7MB (0x1B0000) for app0 and app1.
    # Total app usage: 0x360000 (ends at 0x370000).
    # Custom partition space starts safely at 0x370000 (up to 512KB).
    lines.add("app0,     app,  ota_0,   0x10000,  0x1B0000,")
    lines.add("app1,     app,  ota_1,   0x1C0000, 0x1B0000,")
    var currentOffset: uint32 = 0x370000
    for p in installer.customPartitions:
      let hexOffset = "0x" & currentOffset.toHex(6).toLowerAscii
      let hexSize = "0x" & p.size.toHex(6).toLowerAscii
      lines.add(p.name & ", data, " & p.subType & ", " & hexOffset & ", " & hexSize & ",")
      currentOffset += p.size
    assert currentOffset <= uint32(totalBytes), "Custom partitions exceed 4MB flash limit"
  elif flashSizeMb >= 8:
    # On 8MB+ flash:
    # App0: 3MB (0x300000), App1: 3MB (0x300000) -> ends at 0x610000.
    lines.add("app0,     app,  ota_0,   0x10000,  0x300000,")
    lines.add("app1,     app,  ota_1,   0x310000, 0x300000,")
    var currentOffset: uint32 = 0x610000
    for p in installer.customPartitions:
      let hexOffset = "0x" & currentOffset.toHex(6).toLowerAscii
      let hexSize = "0x" & p.size.toHex(6).toLowerAscii
      lines.add(p.name & ", data, " & p.subType & ", " & hexOffset & ", " & hexSize & ",")
      currentOffset += p.size
    assert currentOffset <= uint32(totalBytes), "Custom partitions exceed flash limit"

  result = lines.join("\n") & "\n"

proc generateManifest*(installer: InstallerDefinition): string =
  ## Generates the static baseline `manifest.json`.
  var root = newJObject()
  root["name"] = %installer.name
  root["version"] = %installer.version
  root["home_assistant_domain"] = %installer.homeAssistantDomain
  if installer.fundingUrl.len > 0:
    root["funding_url"] = %installer.fundingUrl
  root["new_install_prompt_erase"] = %true

  var buildObj = newJObject()
  buildObj["chipFamily"] = %installer.chipFamily
  var parts = newJArray()
  var basePart = newJObject()
  basePart["path"] = %installer.factoryBinPath
  basePart["offset"] = %0
  parts.add(basePart)
  buildObj["parts"] = parts

  var builds = newJArray()
  builds.add(buildObj)
  root["builds"] = builds

  result = pretty(root, 2)

proc renderFieldBody(html: var seq[string], field: InstallerField, installer: InstallerDefinition) =
  let disabledAttr = if field.dependsOnField.len > 0: " disabled" else: ""
  case field.kind
  of ifkFile:
    html.add("        <input type=\"file\" id=\"field_" & field.name & "\" accept=\"" & field.accept & "\" data-offset=\"" & $field.flashOffset & "\" data-maxsize=\"" & $field.maxSize & "\"" & disabledAttr & ">")
    if field.accept.contains(".wav") or field.partition == "sound_data":
      html.add("        <div class=\"format-callout\"><strong>Format:</strong> 16-bit Mono PCM WAV (.wav), 16kHz recommended, max 256 KB.<br>Flashed to safe dedicated partition at 0x370000, 100% safe from OTA firmware updates.</div>")
    html.add("        <div class=\"file-status\" id=\"status_" & field.name & "\"></div>")
  of ifkSelect:
    html.add("        <select id=\"field_" & field.name & "\"" & disabledAttr & ">")
    for opt in field.options:
      let selected = if opt == field.defaultVal: " selected" else: ""
      html.add("          <option value=\"" & opt & "\"" & selected & ">" & opt & "</option>")
    html.add("        </select>")
    if field.optionDetails.len > 0:
      html.add("        <div class=\"preset-card\" id=\"presetCard_" & field.name & "\">")
      html.add("          <div class=\"preset-view\" id=\"presetView_" & field.name & "\">")
      html.add("            <div class=\"preset-header\">")
      html.add("              <span class=\"preset-badge\" id=\"presetCadence_" & field.name & "\"></span>")
      html.add("            </div>")
      html.add("            <p class=\"preset-desc\" id=\"presetDesc_" & field.name & "\"></p>")
      html.add("          </div>")
      for child in installer.fields:
        if child.dependsOnField == field.name:
          let extraAttrs = " data-depends-on=\"" & child.dependsOnField & "\" data-depends-val=\"" & child.dependsOnValue & "\" style=\"display: none;\""
          html.add("          <div class=\"custom-slot\" id=\"group_" & child.name & "\" data-field=\"" & child.name & "\"" & extraAttrs & ">")
          case child.kind
          of ifkFile:
            html.add("            <input type=\"file\" id=\"field_" & child.name & "\" accept=\"" & child.accept & "\" data-offset=\"" & $child.flashOffset & "\" data-maxsize=\"" & $child.maxSize & "\" disabled>")
            if child.accept.contains(".wav") or child.partition.contains("sound") or child.partition.contains("chime"):
              let hexOffset = "0x" & child.flashOffset.toHex(6).toLowerAscii
              let kbSize = child.maxSize div 1024
              html.add("            <div class=\"format-callout\"><strong>Custom Audio:</strong> 16-bit Mono PCM WAV (.wav), 16kHz recommended, max " & $kbSize & " KB.<br>Flashed to dedicated " & child.partition & " partition at " & hexOffset & ".</div>")
            html.add("            <div class=\"file-status\" id=\"status_" & child.name & "\"></div>")
          else:
            html.renderFieldBody(child, installer)
          html.add("          </div>")
      if field.hasAudioPreview:
        html.add("          <div class=\"preview-actions\">")
        html.add("            <button type=\"button\" class=\"preview-btn\" id=\"previewBtn_" & field.name & "\"><svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"currentColor\"><polygon points=\"6 4 20 12 6 20 6 4\"></polygon></svg> <span>Preview Sound</span></button>")
        html.add("          </div>")
      html.add("        </div>")
  of ifkText:
    let placeholderAttr = if field.placeholder.len > 0: " placeholder=\"" & field.placeholder & "\"" else: ""
    html.add("        <input type=\"text\" id=\"field_" & field.name & "\" value=\"" & field.defaultVal & "\"" & placeholderAttr & disabledAttr & ">")
    if field.calloutHtml.len > 0:
      html.add("        <div class=\"phonetic-callout\">" & field.calloutHtml & "</div>")
  of ifkNumber:
    html.add("        <input type=\"number\" id=\"field_" & field.name & "\" min=\"" & $field.minVal & "\" max=\"" & $field.maxVal & "\" step=\"" & $field.stepVal & "\" value=\"" & field.defaultVal & "\"" & disabledAttr & ">")
  of ifkCheckbox:
    let checked = if field.defaultVal == "true": " checked" else: ""
    html.add("        <input type=\"checkbox\" id=\"field_" & field.name & "\"" & checked & disabledAttr & ">")
  of ifkWakeWordSlots:
    html.add("        <div class=\"wake-slots-container\" id=\"wakeSlotsContainer_" & field.name & "\" data-field=\"" & field.name & "\" data-max-slots=\"" & $field.maxSlots & "\">")
    html.add("          <div id=\"slotsList_" & field.name & "\" class=\"slots-list\"></div>")
    html.add("          <button type=\"button\" class=\"btn-add-slot\" id=\"btnAddSlot_" & field.name & "\"><svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><line x1=\"12\" y1=\"5\" x2=\"12\" y2=\"19\"></line><line x1=\"5\" y1=\"12\" x2=\"19\" y2=\"12\"></line></svg> <span>Add Wake Word Model Slot</span></button>")
    html.add("        </div>")

proc generateHtml*(installer: InstallerDefinition): string =
  ## Generates the complete HTML page with embedded reactive WebSerial flashing logic,
  ## rich preset cards, Web Audio synthesis preview, and safe partition callouts.
  var html: seq[string] = @[]
  html.add("<!DOCTYPE html>")
  html.add("<html lang=\"en\">")
  html.add("<head>")
  html.add("  <meta charset=\"utf-8\">")
  html.add("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">")
  html.add("  <meta http-equiv=\"Cache-Control\" content=\"no-cache, no-store, must-revalidate\">")
  html.add("  <meta http-equiv=\"Pragma\" content=\"no-cache\">")
  html.add("  <meta http-equiv=\"Expires\" content=\"0\">")
  html.add("  <title>" & installer.title & "</title>")
  html.add("  <script type=\"module\" src=\"https://unpkg.com/esp-web-tools@10/dist/web/install-button.js?module\"></script>")
  html.add("  <script type=\"module\" src=\"https://unpkg.com/improv-wifi-serial-sdk@2.5.0/dist/web/serial-launch-button.js?module\"></script>")
  html.add("  <style>")
  html.add("    :root { --primary: #3b82f6; --primary-hover: #2563eb; --bg: #0b0f19; --card: #151e2e; --card-inner: #0d1524; --text: #f8fafc; --muted: #94a3b8; --border: #24324a; --accent-badge: rgba(16, 185, 129, 0.15); --accent-badge-text: #34d399; }")
  html.add("    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: var(--bg); color: var(--text); min-height: 100vh; margin: 0; padding: 24px; display: flex; align-items: center; justify-content: center; }")
  html.add("    .card { background: var(--card); border: 1px solid var(--border); border-radius: 16px; padding: 32px; max-width: 600px; width: 100%; box-shadow: 0 25px 35px -5px rgba(0,0,0,0.6); }")
  html.add("    h1 { margin-top: 0; font-size: 1.75rem; color: #60a5fa; }")
  html.add("    p.desc { color: var(--muted); line-height: 1.5; margin-bottom: 24px; font-size: 0.95rem; }")
  html.add("    .form-group { text-align: left; margin-bottom: 20px; background: var(--card-inner); padding: 18px; border-radius: 10px; border: 1px solid var(--border); transition: all 0.2s ease; }")
  html.add("    .form-group[data-depends-on] { display: none !important; }")
  html.add("    .nested-field { margin-top: 14px; padding-top: 14px; border-top: 1px dashed var(--border); transition: all 0.2s ease; }")
  html.add("    .nested-field[data-depends-on] { display: none !important; }")
  html.add("    .form-group.highlight { border-color: var(--primary); box-shadow: 0 0 0 1px var(--primary); }")
  html.add("    label { display: block; font-weight: 600; margin-bottom: 8px; font-size: 0.95rem; color: #e2e8f0; }")
  html.add("    .hint { font-size: 0.82rem; color: var(--muted); margin-top: 6px; line-height: 1.4; }")
  html.add("    input[type='file'], select, input[type='text'], input[type='number'] { width: 100%; box-sizing: border-box; padding: 10px 12px; background: #080d1a; border: 1px solid var(--border); border-radius: 6px; color: var(--text); font-size: 0.95rem; }")
  html.add("    select { cursor: pointer; }")
  html.add("    .preset-card { margin-top: 12px; background: #080d1a; border: 1px solid #202b3d; border-radius: 8px; padding: 14px; text-align: left; }")
  html.add("    .preset-view { margin-bottom: 8px; }")
  html.add("    .preset-header { display: flex; align-items: center; margin-bottom: 6px; }")
  html.add("    .preset-badge { font-size: 0.75rem; background: var(--accent-badge); color: var(--accent-badge-text); padding: 2px 8px; border-radius: 12px; font-weight: 500; font-family: monospace; }")
  html.add("    .preset-desc { font-size: 0.85rem; color: #cbd5e1; margin: 4px 0 6px 0; line-height: 1.4; }")
  html.add("    .custom-slot { margin-bottom: 10px; }")
  html.add("    .custom-slot[data-depends-on] { display: none !important; }")
  html.add("    .preview-btn { background: #1e293b; color: #38bdf8; border: 1px solid #334155; padding: 6px 14px; border-radius: 6px; font-size: 0.82rem; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; transition: all 0.15s ease; }")
  html.add("    .preview-btn:hover { background: #334155; color: #7dd3fc; }")
  html.add("    .preview-btn.playing { background: #0284c7; color: #ffffff; border-color: #0284c7; }")
  html.add("    .format-callout { margin-top: 8px; background: rgba(59, 130, 246, 0.08); border-left: 3px solid #3b82f6; padding: 8px 12px; border-radius: 4px; font-size: 0.8rem; color: #93c5fd; line-height: 1.4; }")
  html.add("    .phonetic-callout { margin-top: 8px; background: rgba(245, 158, 11, 0.1); border-left: 3px solid #f59e0b; padding: 10px 14px; border-radius: 4px; font-size: 0.82rem; color: #fde68a; line-height: 1.45; }")
  html.add("    .phonetic-callout strong { color: #fbbf24; }")
  html.add("    .phonetic-callout code { background: #1e293b; padding: 2px 6px; border-radius: 4px; font-family: monospace; font-size: 0.85em; color: #cbd5e1; }")
  html.add("    .file-status { margin-top: 8px; font-size: 0.85rem; color: #34d399; display: none; background: rgba(16, 185, 129, 0.1); padding: 8px 12px; border-radius: 6px; border: 1px solid rgba(16, 185, 129, 0.2); }")
  html.add("    .wake-slots-container { display: flex; flex-direction: column; gap: 12px; margin-top: 10px; }")
  html.add("    .wake-slot-card { background: #080d1a; border: 1px solid #202b3d; border-radius: 8px; padding: 14px; transition: all 0.2s ease; }")
  html.add("    .wake-slot-card.slot-highlight { border-color: var(--primary); }")
  html.add("    .slot-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }")
  html.add("    .slot-title { font-size: 0.85rem; font-weight: 600; color: #60a5fa; display: flex; align-items: center; gap: 8px; }")
  html.add("    .slot-badge-num { background: rgba(59, 130, 246, 0.15); color: #93c5fd; padding: 2px 8px; border-radius: 10px; font-size: 0.72rem; }")
  html.add("    .btn-remove-slot { background: transparent; border: 1px solid rgba(239, 68, 68, 0.4); color: #f87171; border-radius: 6px; padding: 3px 8px; font-size: 0.72rem; cursor: pointer; transition: all 0.15s ease; }")
  html.add("    .btn-remove-slot:hover { background: rgba(239, 68, 68, 0.15); border-color: #ef4444; }")
  html.add("    .btn-add-slot { background: #0f172a; border: 1px dashed #3b82f6; color: #60a5fa; border-radius: 8px; padding: 9px 14px; font-size: 0.82rem; font-weight: 600; cursor: pointer; width: 100%; text-align: center; margin-top: 8px; transition: all 0.2s ease; display: inline-flex; align-items: center; justify-content: center; gap: 6px; }")
  html.add("    .btn-add-slot:hover { background: rgba(59, 130, 246, 0.1); border-color: #60a5fa; color: #93c5fd; }")
  html.add("    .btn-add-slot:disabled { opacity: 0.5; cursor: not-allowed; border-color: #334155; color: #64748b; }")
  html.add("    .custom-wake-box { margin-top: 12px; padding-top: 12px; border-top: 1px dashed #1e293b; }")
  html.add("    .custom-wake-guide { background: rgba(30, 41, 59, 0.5); border: 1px solid #334155; border-radius: 6px; padding: 10px 12px; margin-bottom: 12px; font-size: 0.8rem; color: #cbd5e1; }")
  html.add("    .guide-title { font-weight: 600; color: #e2e8f0; margin-bottom: 4px; display: flex; align-items: center; gap: 6px; }")
  html.add("    .guide-text { font-size: 0.76rem; color: #94a3b8; line-height: 1.45; margin-bottom: 8px; }")
  html.add("    .guide-links { display: flex; flex-wrap: wrap; gap: 8px; }")
  html.add("    .guide-link { display: inline-flex; align-items: center; gap: 5px; background: #0f172a; border: 1px solid #3b82f6; color: #60a5fa; padding: 5px 10px; border-radius: 4px; font-size: 0.75rem; text-decoration: none; font-weight: 500; transition: all 0.15s ease; }")
  html.add("    .guide-link:hover { background: rgba(59, 130, 246, 0.15); color: #93c5fd; border-color: #60a5fa; }")
  html.add("    .upload-box { background: #040812; border: 1px solid #1e293b; border-radius: 6px; padding: 12px; }")
  html.add("    .cached-models-bar { margin-bottom: 10px; background: rgba(30, 41, 59, 0.6); border: 1px solid #334155; border-radius: 6px; padding: 8px 10px; display: flex; align-items: center; gap: 8px; font-size: 0.8rem; }")
  html.add("    .cached-models-label { color: #94a3b8; font-weight: 600; white-space: nowrap; font-size: 0.75rem; display: flex; align-items: center; gap: 5px; }")
  html.add("    .select-cached-model { flex: 1; min-width: 0; background: #0f172a; border: 1px solid #475569; color: #e2e8f0; padding: 5px 8px; border-radius: 4px; font-size: 0.75rem; }")
  html.add("    .btn-cache-action { background: #1e293b; border: 1px solid #475569; color: #cbd5e1; padding: 5px 9px; border-radius: 4px; font-size: 0.75rem; cursor: pointer; transition: all 0.15s ease; font-weight: 600; white-space: nowrap; }")
  html.add("    .btn-cache-action:hover { background: #334155; color: white; border-color: #64748b; }")
  html.add("    .btn-cache-delete { color: #f87171; border-color: rgba(239, 68, 68, 0.4); padding: 5px 8px; display: inline-flex; align-items: center; justify-content: center; }")
  html.add("    .btn-cache-delete:hover { background: rgba(239, 68, 68, 0.2); border-color: #ef4444; color: #fca5a5; }")
  html.add("    .upload-actions-bar { margin-top: 8px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px; }")
  html.add("    .download-model-btn { background: #064e3b; color: #a7f3d0; border: 1px solid #059669; padding: 5px 12px; border-radius: 5px; font-size: 0.75rem; text-decoration: none; font-weight: 600; cursor: pointer; white-space: nowrap; display: inline-flex; align-items: center; gap: 5px; transition: all 0.15s ease; }")
  html.add("    .download-model-btn:hover { background: #047857; color: #ffffff; border-color: #34d399; }")
  html.add("    .icon { display: inline-block; vertical-align: -0.15em; flex-shrink: 0; }")
  html.add("    .icon-alert { color: #f87171; vertical-align: -0.18em; margin-right: 6px; }")
  html.add("    .icon-check { color: #34d399; vertical-align: -0.15em; margin-right: 5px; }")
  html.add("    .install-warning-notice { width: 100%; box-sizing: border-box; margin-bottom: 8px; background: rgba(239, 68, 68, 0.1); border-left: 3px solid #ef4444; padding: 10px 14px; border-radius: 4px; font-size: 0.82rem; color: #fca5a5; display: none; text-align: left; }")
  html.add("    button.install-btn:disabled, button.install-btn.disabled-btn { background: #334155 !important; color: #64748b !important; cursor: not-allowed !important; box-shadow: none !important; opacity: 0.6; }")
  html.add("    .actions { margin-top: 28px; display: flex; flex-direction: column; align-items: center; gap: 12px; }")
  html.add("    button.install-btn { background: var(--primary); color: white; border: none; padding: 14px 28px; font-size: 1.05rem; font-weight: 600; border-radius: 8px; cursor: pointer; transition: background 0.2s; width: 100%; }")
  html.add("    button.install-btn:hover { background: var(--primary-hover); }")
  html.add("    .action-buttons-row { width: 100%; display: flex; gap: 12px; flex-wrap: wrap; align-items: stretch; }")
  html.add("    .action-buttons-row esp-web-install-button { flex: 2; min-width: 180px; }")
  html.add("    .action-buttons-row improv-wifi-serial-launch-button { flex: 1.5; min-width: 160px; }")
  html.add("    button.wifi-btn { background: #0284c7; color: white; border: none; padding: 14px 18px; font-size: 0.95rem; font-weight: 600; border-radius: 8px; cursor: pointer; transition: background 0.2s; width: 100%; display: inline-flex; align-items: center; justify-content: center; gap: 6px; }")
  html.add("    button.wifi-btn:hover { background: #0369a1; }")
  html.add("    .modal-wifi-btn { background: #0284c7; color: white; border: none; padding: 8px 14px; font-size: 0.82rem; font-weight: 600; border-radius: 6px; cursor: pointer; display: inline-flex; align-items: center; gap: 5px; }")
  html.add("    .modal-wifi-btn:hover { background: #0369a1; }")
  html.add("    .btn-guide-wifi { background: #0284c7; color: white; border: none; padding: 8px 14px; font-size: 0.82rem; font-weight: 600; border-radius: 6px; cursor: pointer; display: inline-flex; align-items: center; gap: 5px; }")
  html.add("    .btn-guide-wifi:hover { background: #0369a1; }")
  html.add("    .erase-btn { flex: 1; min-width: 180px; background: #1e293b; color: #f87171; border: 1px solid rgba(239, 68, 68, 0.4); padding: 14px 18px; font-size: 0.92rem; font-weight: 600; border-radius: 8px; cursor: pointer; transition: all 0.2s ease; display: inline-flex; align-items: center; justify-content: center; gap: 8px; }")
  html.add("    .erase-btn:hover { background: rgba(239, 68, 68, 0.15); border-color: #ef4444; color: #fca5a5; }")
  html.add("    .erase-status { width: 100%; box-sizing: border-box; border-radius: 6px; padding: 12px 16px; font-size: 0.85rem; line-height: 1.5; margin-top: 4px; text-align: left; }")
  html.add("    .erase-status.in-progress { background: rgba(59, 130, 246, 0.1); border: 1px solid #3b82f6; color: #93c5fd; }")
  html.add("    .erase-status.success { background: rgba(16, 185, 129, 0.1); border: 1px solid #10b981; color: #a7f3d0; }")
  html.add("    .erase-status.error { background: rgba(239, 68, 68, 0.1); border: 1px solid #ef4444; color: #fca5a5; }")
  html.add("    .setup-guide-card { margin-top: 36px; padding-top: 28px; border-top: 1px solid #1e293b; width: 100%; text-align: left; }")
  html.add("    .guide-header { margin-bottom: 18px; }")
  html.add("    .guide-badge { background: rgba(59, 130, 246, 0.15); color: #60a5fa; border: 1px solid rgba(59, 130, 246, 0.3); font-size: 0.7rem; font-weight: 700; letter-spacing: 0.05em; padding: 3px 8px; border-radius: 4px; text-transform: uppercase; }")
  html.add("    .guide-header h3 { margin: 8px 0 4px; font-size: 1.25rem; color: #f1f5f9; }")
  html.add("    .guide-steps { display: flex; flex-direction: column; gap: 14px; }")
  html.add("    .guide-step { display: flex; gap: 14px; background: #080d1a; border: 1px solid #1e293b; border-radius: 8px; padding: 16px 18px; }")
  html.add("    .step-number { width: 30px; height: 30px; border-radius: 50%; background: #1e293b; color: #60a5fa; border: 1px solid #3b82f6; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 0.9rem; flex-shrink: 0; }")
  html.add("    .step-content { flex: 1; }")
  html.add("    .step-content h4 { margin: 0 0 6px; font-size: 0.95rem; color: #e2e8f0; }")
  html.add("    .step-content p { margin: 0 0 8px; font-size: 0.85rem; color: #94a3b8; line-height: 1.5; }")
  html.add("    .step-tip { background: rgba(15, 23, 42, 0.8); border-left: 3px solid #3b82f6; border-radius: 0 4px 4px 0; padding: 8px 12px; font-size: 0.8rem; color: #cbd5e1; }")
  html.add("    .step-tip code { background: #1e293b; color: #38bdf8; padding: 2px 6px; border-radius: 4px; font-family: monospace; font-size: 0.82rem; }")
  html.add("    .modal-overlay { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.8); backdrop-filter: blur(4px); display: flex; align-items: center; justify-content: center; z-index: 10000; padding: 20px; animation: fadeIn 0.2s ease; }")
  html.add("    .modal-card { background: #0b1329; border: 1px solid #3b82f6; border-radius: 12px; max-width: 580px; width: 100%; padding: 28px; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7); text-align: left; }")
  html.add("    .modal-header { display: flex; align-items: center; gap: 14px; margin-bottom: 16px; }")
  html.add("    .modal-icon-success { width: 40px; height: 40px; border-radius: 50%; background: rgba(16, 185, 129, 0.2); border: 2px solid #10b981; color: #34d399; display: flex; align-items: center; justify-content: center; font-size: 1.3rem; font-weight: bold; flex-shrink: 0; }")
  html.add("    .modal-header h2 { margin: 0; font-size: 1.3rem; color: #f8fafc; }")
  html.add("    .modal-subtitle { color: #94a3b8; font-size: 0.82rem; margin-top: 2px; }")
  html.add("    .modal-intro { color: #94a3b8; font-size: 0.9rem; margin-bottom: 20px; }")
  html.add("    .next-steps-list { display: flex; flex-direction: column; gap: 14px; margin-bottom: 24px; }")
  html.add("    .next-step-item { display: flex; gap: 12px; font-size: 0.86rem; color: #cbd5e1; line-height: 1.45; }")
  html.add("    .next-step-item .num { width: 22px; height: 22px; border-radius: 50%; background: #1e293b; color: #60a5fa; border: 1px solid #3b82f6; display: flex; align-items: center; justify-content: center; font-size: 0.75rem; font-weight: 700; flex-shrink: 0; margin-top: 1px; }")
  html.add("    .next-step-item .subtext { color: #64748b; font-size: 0.78rem; margin-top: 4px; }")
  html.add("    .next-step-item code { background: #1e293b; color: #38bdf8; padding: 1px 5px; border-radius: 4px; font-family: monospace; font-size: 0.8rem; }")
  html.add("    .modal-actions { display: flex; gap: 12px; justify-content: flex-end; }")
  html.add("    .btn-ha-link { background: var(--primary); color: white; border: none; padding: 10px 18px; border-radius: 6px; font-size: 0.88rem; font-weight: 600; text-decoration: none; display: inline-flex; align-items: center; gap: 6px; }")
  html.add("    .btn-ha-link:hover { background: var(--primary-hover); }")
  html.add("    .btn-modal-close { background: #1e293b; color: #94a3b8; border: 1px solid #334155; padding: 10px 16px; border-radius: 6px; font-size: 0.88rem; cursor: pointer; }")
  html.add("    .btn-modal-close:hover { background: #334155; color: white; }")
  html.add("    .spinner { display: inline-block; width: 12px; height: 12px; border: 2px solid rgba(255,255,255,0.3); border-radius: 50%; border-top-color: currentColor; animation: spin 0.8s linear infinite; vertical-align: -0.1em; margin-right: 6px; }")
  html.add("    @keyframes spin { to { transform: rotate(360deg); } }")
  html.add("    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }")
  html.add("    .footer { margin-top: 24px; font-size: 0.8rem; color: var(--muted); text-align: center; }")
  html.add("  </style>")
  html.add("</head>")
  html.add("<body>")
  html.add("  <div class=\"card\">")
  html.add("    <h1>" & installer.title & "</h1>")
  if installer.description.len > 0:
    html.add("    <p class=\"desc\">" & installer.description & "</p>")

  # Render Form Fields
  if installer.targets.len > 0:
    html.add("    <div class=\"form-group\" id=\"group_hardware_target\" data-field=\"hardware_target\">")
    html.add("      <label for=\"field_hardware_target\">Hardware Target</label>")
    html.add("      <select id=\"field_hardware_target\">")
    for idx, t in installer.targets:
      let selected = if idx == 0: " selected" else: ""
      html.add("        <option value=\"" & t.name & "\"" & selected & ">" & t.name & "</option>")
    html.add("      </select>")
    if installer.targets[0].description.len > 0:
      html.add("      <div class=\"hint\" id=\"target_desc\">" & installer.targets[0].description & "</div>")
    html.add("    </div>")

  if installer.fields.len > 0:
    html.add("    <div class=\"fields-container\">")
    for field in installer.fields:
      if field.dependsOnField.len > 0:
        continue
      html.add("      <div class=\"form-group\" id=\"group_" & field.name & "\" data-field=\"" & field.name & "\">")
      html.add("        <label for=\"field_" & field.name & "\">" & field.label & "</label>")
      html.renderFieldBody(field, installer)
      if field.description.len > 0:
        html.add("        <div class=\"hint\">" & field.description & "</div>")
      if field.kind != ifkSelect or field.optionDetails.len == 0:
        for child in installer.fields:
          if child.dependsOnField == field.name:
            let extraAttrs = " data-depends-on=\"" & child.dependsOnField & "\" data-depends-val=\"" & child.dependsOnValue & "\" style=\"display: none;\""
            html.add("        <div class=\"nested-field\" id=\"group_" & child.name & "\" data-field=\"" & child.name & "\"" & extraAttrs & ">")
            html.add("          <label for=\"field_" & child.name & "\">" & child.label & "</label>")
            html.renderFieldBody(child, installer)
            if child.description.len > 0:
              html.add("          <div class=\"hint\">" & child.description & "</div>")
            html.add("        </div>")
      html.add("      </div>")
    html.add("    </div>")

  # Install & Erase Buttons
  html.add("    <div class=\"actions\">")
  html.add("      <div id=\"installWarningNotice\" class=\"install-warning-notice\"></div>")
  html.add("      <div class=\"action-buttons-row\">")
  html.add("        <esp-web-install-button id=\"installBtn\" manifest=\"manifest.json\">")
  html.add("          <button slot=\"activate\" class=\"install-btn\">Install Firmware</button>")
  html.add("          <span slot=\"unsupported\">WebSerial is not supported in this browser. Please use Chrome or Edge on desktop.</span>")
  html.add("        </esp-web-install-button>")
  html.add("        <improv-wifi-serial-launch-button>")
  html.add("          <button slot=\"activate\" class=\"wifi-btn\" title=\"Configure Wi-Fi credentials directly over USB without re-flashing\">")
  html.add("            <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M5 12.55a11 11 0 0 1 14.08 0\"></path><path d=\"M1.42 9a16 16 0 0 1 21.16 0\"></path><path d=\"M8.53 16.11a6 6 0 0 1 6.95 0\"></path><line x1=\"12\" y1=\"20\" x2=\"12.01\" y2=\"20\"></line></svg>")
  html.add("            <span>Configure Wi-Fi</span>")
  html.add("          </button>")
  html.add("          <span slot=\"unsupported\"></span>")
  html.add("        </improv-wifi-serial-launch-button>")
  html.add("        <button type=\"button\" id=\"btnEraseDevice\" class=\"erase-btn\" title=\"Completely wipe all flash partitions, cached Wi-Fi credentials, and NVS settings\">")
  html.add("          <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M3 6h18\"></path><path d=\"M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2\"></path></svg>")
  html.add("          <span>Erase Device</span>")
  html.add("        </button>")
  html.add("      </div>")
  html.add("      <div id=\"eraseStatus\" class=\"erase-status\" style=\"display: none;\"></div>")
  html.add("    </div>")
  html.add("")
  html.add("    <!-- Next Steps: Connecting to Home Assistant Guide -->")
  html.add("    <div class=\"setup-guide-card\">")
  html.add("      <div class=\"guide-header\">")
  html.add("        <span class=\"guide-badge\">WHAT TO DO NEXT</span>")
  html.add("        <h3>Next Steps: Connecting to Home Assistant</h3>")
  html.add("      </div>")
  html.add("      <div class=\"guide-steps\">")
  html.add("        <div class=\"guide-step\">")
  html.add("          <div class=\"step-number\">1</div>")
  html.add("          <div class=\"step-content\">")
  html.add("            <h4>Reboot Board &amp; Connect to Wi-Fi</h4>")
  html.add("            <div class=\"step-tip\" style=\"background: rgba(234, 179, 8, 0.15); border-left: 3px solid #eab308; margin-bottom: 10px;\"><strong>⚠️ Essential for ESP32-S3 (ReSpeaker Lite):</strong> Because this board uses native USB, software resets cannot exit the ROM bootloader after flashing or erasing. <strong>Unplug and reconnect the USB-C cable</strong> (or tap the <strong>RST</strong> button) once before configuring Wi-Fi! If you click before rebooting, it will report <em>\"Improv Wi-Fi Serial not detected\"</em> because ESPHome has not booted yet.</div>")
  html.add("            <p>Once replugged, connect your satellite to Wi-Fi using either method below:</p>")
  html.add("            <div style=\"display: flex; gap: 8px; flex-wrap: wrap; margin: 10px 0;\">")
  html.add("              <improv-wifi-serial-launch-button>")
  html.add("                <button slot=\"activate\" class=\"btn-guide-wifi\">")
  html.add("                  <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M5 12.55a11 11 0 0 1 14.08 0\"></path><path d=\"M1.42 9a16 16 0 0 1 21.16 0\"></path><path d=\"M8.53 16.11a6 6 0 0 1 6.95 0\"></path><line x1=\"12\" y1=\"20\" x2=\"12.01\" y2=\"20\"></line></svg>")
  html.add("                  <span>Configure Wi-Fi via USB (Improv)</span>")
  html.add("                </button>")
  html.add("              </improv-wifi-serial-launch-button>")
  html.add("            </div>")
  html.add("            <div class=\"step-tip\"><strong>Method B (Fallback Hotspot):</strong> Connect your phone or laptop to the open Wi-Fi network <code>Satellite Fallback Hotspot</code>. The captive portal at <code>http://192.168.4.1</code> opens automatically to enter your Wi-Fi credentials.</div>")
  html.add("          </div>")
  html.add("        </div>")
  html.add("        <div class=\"guide-step\">")
  html.add("          <div class=\"step-number\">2</div>")
  html.add("          <div class=\"step-content\">")
  html.add("            <h4>Add in Home Assistant</h4>")
  html.add("            <p>Open Home Assistant and navigate to <strong>Settings &rarr; Devices &amp; Services</strong>. Your new <strong>Voice Satellite</strong> will appear highlighted at the top under <strong>Discovered</strong>.</p>")
  html.add("            <p>Click <strong>Configure</strong>, then click <strong>Submit</strong> (no encryption key required).</p>")
  html.add("          </div>")
  html.add("        </div>")
  html.add("        <div class=\"guide-step\">")
  html.add("          <div class=\"step-number\">3</div>")
  html.add("          <div class=\"step-content\">")
  html.add("            <h4>Configure Voice Assistant &amp; Audio Presets</h4>")
  html.add("            <p>Go to <strong>Settings &rarr; Voice Assistants</strong> to link the satellite to your Assist pipeline (Cloud, Whisper/Piper, or Ollama).</p>")
  html.add("            <p>On the device card, you can customize your <strong>Wake Chime</strong> (<em>Modern Chime</em>, <em>Crystal Glass</em>, <em>Warm Kalimba</em>, <em>Meditation Bell</em>) and <strong>Processing Sound</strong> (<em>Typewriter</em>, <em>Clockwork</em>, <em>Water Droplets</em>) anytime!</p>")
  html.add("          </div>")
  html.add("        </div>")
  html.add("        <div class=\"guide-step\">")
  html.add("          <div class=\"step-number\">&#8635;</div>")
  html.add("          <div class=\"step-content\">")
  html.add("            <h4>Testing Clean Flow / Factory Reset</h4>")
  html.add("            <p>If your device previously had another Wi-Fi network or an old encryption key saved in NVS memory, click <strong>Erase Device (Factory Reset)</strong> above or run <code>esptool.py erase_flash</code> in terminal before clicking Install Firmware.</p>")
  html.add("          </div>")
  html.add("        </div>")
  html.add("      </div>")
  html.add("    </div>")
  html.add("    <div class=\"footer\">Powered by <a href=\"https://github.com/axiomantic/nim-esphome\" target=\"_blank\" style=\"color: #60a5fa;\">nim-esphome</a> &amp; ESP-Web-Tools</div>")
  html.add("  </div>")

  # Client-side JavaScript abstraction
  let initialBin = if installer.targets.len > 0: installer.targets[0].binPath else: installer.factoryBinPath
  let initialChip = if installer.targets.len > 0: installer.targets[0].chipFamily else: installer.chipFamily
  html.add("  <script>")
  html.add("    const ICONS = {")
  html.add("      play: '<svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"currentColor\"><polygon points=\"6 4 20 12 6 20 6 4\"></polygon></svg>',")
  html.add("      stop: '<svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"currentColor\"><rect x=\"5\" y=\"5\" width=\"14\" height=\"14\" rx=\"2\"></rect></svg>',")
  html.add("      alert: '<svg class=\"icon icon-alert\" viewBox=\"0 0 24 24\" width=\"15\" height=\"15\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z\"></path><line x1=\"12\" y1=\"9\" x2=\"12\" y2=\"13\"></line><line x1=\"12\" y1=\"17\" x2=\"12.01\" y2=\"17\"></line></svg>',")
  html.add("      check: '<svg class=\"icon icon-check\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><polyline points=\"20 6 9 17 4 12\"></polyline></svg>',")
  html.add("      download: '<svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4\"></path><polyline points=\"7 10 12 15 17 10\"></polyline><line x1=\"12\" y1=\"15\" x2=\"12\" y2=\"3\"></line></svg>',")
  html.add("      upload: '<svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4\"></path><polyline points=\"17 8 12 3 7 8\"></polyline><line x1=\"12\" y1=\"3\" x2=\"12\" y2=\"15\"></line></svg>',")
  html.add("      database: '<svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><ellipse cx=\"12\" cy=\"5\" rx=\"9\" ry=\"3\"></ellipse><path d=\"M21 12c0 1.66-4 3-9 3s-9-1.34-9-3\"></path><path d=\"M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5\"></path></svg>',")
  html.add("      x: '<svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"12\" height=\"12\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><line x1=\"18\" y1=\"6\" x2=\"6\" y2=\"18\"></line><line x1=\"6\" y1=\"6\" x2=\"18\" y2=\"18\"></line></svg>',")
  html.add("      plus: '<svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><line x1=\"12\" y1=\"5\" x2=\"12\" y2=\"19\"></line><line x1=\"5\" y1=\"12\" x2=\"19\" y2=\"12\"></line></svg>',")
  html.add("      book: '<svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M4 19.5A2.5 2.5 0 0 1 6.5 17H20\"></path><path d=\"M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z\"></path></svg>',")
  html.add("      external: '<svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"12\" height=\"12\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6\"></path><polyline points=\"15 3 21 3 21 9\"></polyline><line x1=\"10\" y1=\"14\" x2=\"21\" y2=\"3\"></line></svg>'")
  html.add("    };")
  html.add("    const BASE_MANIFEST = {")
  html.add("      name: " & escapeJson(installer.name) & ",")
  html.add("      version: " & escapeJson(installer.version) & ",")
  html.add("      home_assistant_domain: " & escapeJson(installer.homeAssistantDomain) & ",")
  html.add("      new_install_prompt_erase: true,")
  html.add("      builds: [{ chipFamily: " & escapeJson(initialChip) & ", parts: [{ path: " & escapeJson(initialBin) & ", offset: 0 }] }]")
  html.add("    };")
  if installer.targets.len > 0:
    var targetObj = newJObject()
    for t in installer.targets:
      var to = newJObject()
      to["bin"] = %t.binPath
      to["chip"] = %t.chipFamily
      to["desc"] = %t.description
      targetObj[t.name] = to
    html.add("    const TARGET_MAP = " & $targetObj & ";")
    html.add("    const targetSelect = document.getElementById('field_hardware_target');")
    html.add("    const targetDesc = document.getElementById('target_desc');")
    html.add("    if (targetSelect) {")
    html.add("      targetSelect.addEventListener('change', () => {")
    html.add("        const info = TARGET_MAP[targetSelect.value];")
    html.add("        if (info) {")
    html.add("          if (targetDesc && info.desc) targetDesc.textContent = info.desc;")
    html.add("          updateDynamicManifest();")
    html.add("        }")
    html.add("      });")
    html.add("    }")
  html.add("    const installBtn = document.getElementById('installBtn');")
  html.add("    const uploadedParts = new Map();")
  html.add("    let activeManifestUrl = null;")
  html.add("    let activeAudioCtx = null;")
  html.add("    let activeAudioTimer = null;")
  html.add("    let activeAudioElement = null;")
  html.add("    const PRESET_MODELS = {};")
  html.add("    const PRESET_AUDIO = {};")
  html.add("    let WAKE_OFFSETS = [];")
  html.add("")
  html.add("    function stopAudioPreview() {")
  html.add("      if (activeAudioTimer) { clearInterval(activeAudioTimer); activeAudioTimer = null; }")
  html.add("      if (activeAudioCtx) { try { activeAudioCtx.close(); } catch(e) {} activeAudioCtx = null; }")
  html.add("      if (activeAudioElement) { activeAudioElement.pause(); activeAudioElement = null; }")
  html.add("      document.querySelectorAll('.preview-btn').forEach(btn => {")
  html.add("        btn.classList.remove('playing');")
  html.add("        btn.innerHTML = ICONS.play + ' <span>Preview Sound</span>';")
  html.add("      });")
  html.add("    }")
  html.add("")
  html.add("    function playToneBurst(ctx, freq, durationSec, type = 'sine', gainVal = 0.25) {")
  html.add("      const osc = ctx.createOscillator();")
  html.add("      const gain = ctx.createGain();")
  html.add("      osc.type = type;")
  html.add("      osc.frequency.value = freq;")
  html.add("      gain.gain.setValueAtTime(gainVal, ctx.currentTime);")
  html.add("      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + durationSec);")
  html.add("      osc.connect(gain); gain.connect(ctx.destination);")
  html.add("      osc.start(); osc.stop(ctx.currentTime + durationSec + 0.01);")
  html.add("    }")
  html.add("")
  html.add("    function playPresetAudio(styleName, btn) {")
  html.add("      if (btn && btn.classList.contains('playing')) { stopAudioPreview(); return; }")
  html.add("      stopAudioPreview();")
  html.add("      if (btn) { btn.classList.add('playing'); btn.innerHTML = ICONS.stop + ' <span>Stop Preview</span>'; }")
  html.add("      if (styleName.startsWith('Silent')) {")
  html.add("        alert('Silent mode: no acoustic cues will be emitted.');")
  html.add("        stopAudioPreview();")
  html.add("        return;")
  html.add("      }")
  html.add("      if (typeof PRESET_AUDIO !== 'undefined' && PRESET_AUDIO[styleName]) {")
  html.add("        const audioUrl = PRESET_AUDIO[styleName].preview || PRESET_AUDIO[styleName].flash;")
  html.add("        const audio = new Audio(audioUrl);")
  html.add("        activeAudioElement = audio;")
  html.add("        audio.onended = () => stopAudioPreview();")
  html.add("        audio.play().catch(() => stopAudioPreview());")
  html.add("        return;")
  html.add("      }")
  html.add("      if (styleName.startsWith('Custom')) {")
  html.add("        for (const [key, part] of uploadedParts.entries()) {")
  html.add("          if (part.url && (key.includes('sound') || key.includes('audio') || key.includes('chime'))) {")
  html.add("            const audio = new Audio(part.url);")
  html.add("            activeAudioElement = audio;")
  html.add("            audio.onended = () => stopAudioPreview();")
  html.add("            audio.play().catch(() => stopAudioPreview());")
  html.add("            return;")
  html.add("          }")
  html.add("        }")
  html.add("        alert('Please select or upload a custom .wav audio file first to preview.');")
  html.add("        stopAudioPreview();")
  html.add("        return;")
  html.add("      }")
  html.add("      const ctx = new (window.AudioContext || window.webkitAudioContext)();")
  html.add("      activeAudioCtx = ctx;")
  html.add("      let ticks = 0;")
  html.add("      if (styleName.startsWith('Bell Ping')) {")
  html.add("        playToneBurst(ctx, 880, 0.8, 'sine', 0.4);")
  html.add("        activeAudioTimer = setTimeout(() => stopAudioPreview(), 850);")
  html.add("      } else if (styleName.startsWith('Modern Chime')) {")
  html.add("        playToneBurst(ctx, 587.33, 0.25, 'sine', 0.35);")
  html.add("        activeAudioTimer = setTimeout(() => {")
  html.add("          if (activeAudioCtx) playToneBurst(ctx, 880, 0.6, 'sine', 0.4);")
  html.add("          activeAudioTimer = setTimeout(() => stopAudioPreview(), 650);")
  html.add("        }, 130);")
  html.add("      } else if (styleName.startsWith('Marimba')) {")
  html.add("        playToneBurst(ctx, 523.25, 0.3, 'sine', 0.35);")
  html.add("        setTimeout(() => { if (activeAudioCtx) playToneBurst(ctx, 659.25, 0.3, 'sine', 0.35); }, 70);")
  html.add("        setTimeout(() => { if (activeAudioCtx) playToneBurst(ctx, 783.99, 0.5, 'sine', 0.35); }, 140);")
  html.add("        activeAudioTimer = setTimeout(() => stopAudioPreview(), 750);")
  html.add("      } else if (styleName.startsWith('Subtle Beep')) {")
  html.add("        playToneBurst(ctx, 600, 0.08, 'triangle', 0.25);")
  html.add("        activeAudioTimer = setTimeout(() => stopAudioPreview(), 180);")
  html.add("      } else if (styleName === 'Spinner') {")
  html.add("        activeAudioTimer = setInterval(() => {")
  html.add("          if (++ticks > 24) { stopAudioPreview(); return; }")
  html.add("          playToneBurst(ctx, 880, 0.035, 'square', 0.15);")
  html.add("        }, 120);")
  html.add("      } else if (styleName === 'Pulse') {")
  html.add("        activeAudioTimer = setInterval(() => {")
  html.add("          if (++ticks > 12) { stopAudioPreview(); return; }")
  html.add("          playToneBurst(ctx, 220, 0.15, 'sine', 0.3);")
  html.add("        }, 250);")
  html.add("      } else if (styleName === 'Sonar') {")
  html.add("        activeAudioTimer = setInterval(() => {")
  html.add("          if (++ticks > 4) { stopAudioPreview(); return; }")
  html.add("          playToneBurst(ctx, 1760, 0.45, 'sine', 0.35);")
  html.add("        }, 800);")
  html.add("      } else if (styleName === 'Tick') {")
  html.add("        activeAudioTimer = setInterval(() => {")
  html.add("          if (++ticks > 6) { stopAudioPreview(); return; }")
  html.add("          playToneBurst(ctx, 1200, 0.025, 'triangle', 0.3);")
  html.add("        }, 500);")
  html.add("      } else if (styleName === 'Typewriter') {")
  html.add("        const audio = new Audio('sounds/typewriter.mp3');")
  html.add("        activeAudioElement = audio;")
  html.add("        audio.onended = () => stopAudioPreview();")
  html.add("        audio.play().catch(() => {")
  html.add("          activeAudioTimer = setInterval(() => {")
  html.add("            if (++ticks > 24) { stopAudioPreview(); return; }")
  html.add("            playToneBurst(ctx, 1200 + Math.random() * 400, 0.02, 'triangle', 0.2);")
  html.add("          }, 110);")
  html.add("        });")
  html.add("      }")
  html.add("    }")
  html.add("")
  html.add("    function updateDynamicManifest() {")
  html.add("      const manifest = JSON.parse(JSON.stringify(BASE_MANIFEST));")
  html.add("      const targetSelect = document.getElementById('field_hardware_target');")
  html.add("      if (targetSelect && typeof TARGET_MAP !== 'undefined') {")
  html.add("        const info = TARGET_MAP[targetSelect.value];")
  html.add("        if (info) {")
  html.add("          manifest.builds[0].parts[0].path = info.bin;")
  html.add("          if (info.chip) manifest.builds[0].chipFamily = info.chip;")
  html.add("        }")
  html.add("      }")
  html.add("      if (typeof PRESET_AUDIO !== 'undefined') {")
  html.add("        for (const [key, info] of Object.entries(PRESET_AUDIO)) {")
  html.add("          if (!info || !info.flash) continue;")
  html.add("          for (const sel of document.querySelectorAll('select')) {")
  html.add("            if (sel.value === key) {")
  html.add("              let isOverridden = false;")
  html.add("              const off = info.offset || 0x370000;")
  html.add("              for (const [upKey, _] of uploadedParts.entries()) {")
  html.add("                if (off >= 0x390000 && upKey.includes('chime')) {")
  html.add("                  isOverridden = true;")
  html.add("                  break;")
  html.add("                } else if (off < 0x390000 && (upKey.includes('sound') || upKey.includes('audio'))) {")
  html.add("                  isOverridden = true;")
  html.add("                  break;")
  html.add("                }")
  html.add("              }")
  html.add("              if (!isOverridden) {")
  html.add("                manifest.builds[0].parts.push({ path: info.flash, offset: off });")
  html.add("              }")
  html.add("            }")
  html.add("          }")
  html.add("        }")
  html.add("      }")
  html.add("      for (const [name, part] of uploadedParts.entries()) {")
  html.add("        const group = document.getElementById('group_' + name);")
  html.add("        if (group) {")
  html.add("          const parentName = group.dataset.dependsOn;")
  html.add("          const expectedVal = group.dataset.dependsVal;")
  html.add("          if (parentName && expectedVal) {")
  html.add("            const parentEl = document.getElementById('field_' + parentName);")
  html.add("            if (parentEl && parentEl.value !== expectedVal) continue;")
  html.add("          }")
  html.add("        }")
  html.add("        manifest.builds[0].parts.push({ path: part.url, offset: part.offset });")
  html.add("      }")
  html.add("      const slotCards = document.querySelectorAll('.wake-slot-card');")
  html.add("      for (let i = 0; i < slotCards.length; i++) {")
  html.add("        const card = slotCards[i];")
  html.add("        const slotIdx = card.dataset.slot || (i + 1);")
  html.add("        const slotOffset = (WAKE_OFFSETS && WAKE_OFFSETS[slotIdx - 1]) || (0x3B0000 + (slotIdx - 1) * 0x40000);")
  html.add("        const modelSelect = card.querySelector('.slot-model-select');")
  html.add("        if (modelSelect && PRESET_MODELS && PRESET_MODELS[modelSelect.value]) {")
  html.add("          manifest.builds[0].parts.push({ path: PRESET_MODELS[modelSelect.value], offset: slotOffset });")
  html.add("        }")
  html.add("      }")
  html.add("      const vTag = manifest.version ? ('?v=' + encodeURIComponent(manifest.version)) : '';")
  html.add("      if (vTag && manifest.builds && manifest.builds[0] && manifest.builds[0].parts) {")
  html.add("        manifest.builds[0].parts.forEach(p => {")
  html.add("          if (p.path && !p.path.startsWith('blob:') && !p.path.includes('?')) {")
  html.add("            p.path += vTag;")
  html.add("          }")
  html.add("        });")
  html.add("      }")
  html.add("      const blob = new Blob([JSON.stringify(manifest)], { type: 'application/json' });")
  html.add("      if (activeManifestUrl) URL.revokeObjectURL(activeManifestUrl);")
  html.add("      activeManifestUrl = URL.createObjectURL(blob);")
  html.add("      installBtn.manifest = activeManifestUrl;")
  html.add("    }")
  html.add("")
  html.add("    function checkInstallReadiness() {")
  html.add("      let canInstall = true;")
  html.add("      let reason = '';")
  html.add("      const installBtnWrapper = document.getElementById('installBtn');")
  html.add("      const installBtnEl = installBtnWrapper ? installBtnWrapper.querySelector('button') : null;")
  html.add("      const notice = document.getElementById('installWarningNotice');")
  html.add("      const slotCards = document.querySelectorAll('.wake-slot-card');")
  html.add("      for (let i = 0; i < slotCards.length; i++) {")
  html.add("        const card = slotCards[i];")
  html.add("        const slotIdx = card.dataset.slot || (i + 1);")
  html.add("        const modelSelect = card.querySelector('.slot-model-select');")
  html.add("        if (modelSelect && modelSelect.value === 'Custom Wake Word') {")
  html.add("          if (!uploadedParts.has('wake_slot_' + slotIdx)) {")
  html.add("            canInstall = false;")
  html.add("            reason = 'Please select or load a .tflite microWakeWord model for Slot ' + slotIdx + ' before installing firmware.';")
  html.add("            break;")
  html.add("          }")
  html.add("        }")
  html.add("      }")
  html.add("      if (installBtnEl) {")
  html.add("        if (!canInstall) {")
  html.add("          installBtnEl.disabled = true;")
  html.add("          installBtnEl.classList.add('disabled-btn');")
  html.add("          if (notice) {")
  html.add("            notice.innerHTML = ICONS.alert + ' <span>' + reason + '</span>';")
  html.add("            notice.style.display = 'block';")
  html.add("          }")
  html.add("        } else {")
  html.add("          installBtnEl.disabled = false;")
  html.add("          installBtnEl.classList.remove('disabled-btn');")
  html.add("          if (notice) {")
  html.add("            notice.style.display = 'none';")
  html.add("          }")
  html.add("        }")
  html.add("      }")
  html.add("    }")
  html.add("")
  html.add("    function updateFieldDependencies() {")
  html.add("      document.querySelectorAll('[data-depends-on]').forEach(group => {")
  html.add("        const parentName = group.dataset.dependsOn;")
  html.add("        const expectedVal = group.dataset.dependsVal;")
  html.add("        const parentEl = document.getElementById('field_' + parentName);")
  html.add("        if (parentEl) {")
  html.add("          const match = (parentEl.value === expectedVal);")
  html.add("          if (match) {")
  html.add("            group.style.setProperty('display', 'block', 'important');")
  html.add("            group.classList.add('highlight');")
  html.add("            group.querySelectorAll('input, select, button, textarea').forEach(el => { el.disabled = false; });")
  html.add("          } else {")
  html.add("            group.style.setProperty('display', 'none', 'important');")
  html.add("            group.classList.remove('highlight');")
  html.add("            group.querySelectorAll('input, select, button, textarea').forEach(el => { el.disabled = true; });")
  html.add("          }")
  html.add("        }")
  html.add("      });")
  html.add("      updateDynamicManifest();")
  html.add("    }")
  html.add("")

  for field in installer.fields:
    if field.kind == ifkWakeWordSlots:
      let optionsArray = newJArray()
      for opt in field.options:
        optionsArray.add(%opt)
      optionsArray.add(%"Custom Wake Word")
      let offsetsArray = newJArray()
      for off in field.slotOffsets:
        offsetsArray.add(%int(off))
      var presetModelsObj = newJObject()
      for item in field.presetModels:
        presetModelsObj[item[0]] = %item[1]
      html.add("    (function initWakeWordSlots() {")
      html.add("      const PRESETS = " & $optionsArray & ";")
      html.add("      const OFFSETS = " & $offsetsArray & ";")
      html.add("      Object.assign(PRESET_MODELS, " & $presetModelsObj & ");")
      html.add("      WAKE_OFFSETS = OFFSETS;")
      html.add("      const MAX_SLOTS = " & $field.maxSlots & ";")
      html.add("      const container = document.getElementById('slotsList_" & field.name & "');")
      html.add("      const addBtn = document.getElementById('btnAddSlot_" & field.name & "');")
      html.add("      let slotCount = 0;")
      html.add("")
      html.add("      function uint8ToBase64(u8) {")
      html.add("        let binary = '';")
      html.add("        const len = u8.byteLength;")
      html.add("        for (let i = 0; i < len; i++) binary += String.fromCharCode(u8[i]);")
      html.add("        return window.btoa(binary);")
      html.add("      }")
      html.add("")
      html.add("      function base64ToUint8(b64) {")
      html.add("        const binary = window.atob(b64);")
      html.add("        const len = binary.length;")
      html.add("        const u8 = new Uint8Array(len);")
      html.add("        for (let i = 0; i < len; i++) u8[i] = binary.charCodeAt(i);")
      html.add("        return u8;")
      html.add("      }")
      html.add("")
      html.add("      const MWW_CACHE_KEY = 'esphome_mww_cache_v1';")
      html.add("")
      html.add("      function getMwwCache() {")
      html.add("        try {")
      html.add("          return JSON.parse(localStorage.getItem(MWW_CACHE_KEY) || '{}');")
      html.add("        } catch (e) {")
      html.add("          return {};")
      html.add("        }")
      html.add("      }")
      html.add("")
      html.add("      function saveMwwCache(phrase, u8Array, meta) {")
      html.add("        try {")
      html.add("          meta = meta || {};")
      html.add("          const cache = getMwwCache();")
      html.add("          const cleanId = (phrase || 'wake_word').toLowerCase().replace(/[^a-z0-9]/g, '_');")
      html.add("          cache[cleanId] = {")
      html.add("            id: cleanId,")
      html.add("            phrase: phrase,")
      html.add("            b64: uint8ToBase64(u8Array),")
      html.add("            size: u8Array.length,")
      html.add("            filename: meta.filename || (cleanId + '.tflite'),")
      html.add("            timestamp: Date.now()")
      html.add("          };")
      html.add("          localStorage.setItem(MWW_CACHE_KEY, JSON.stringify(cache));")
      html.add("          updateAllCacheSelectors();")
      html.add("          return cleanId;")
      html.add("        } catch (e) {")
      html.add("          console.warn('LocalStorage save failed:', e);")
      html.add("          return null;")
      html.add("        }")
      html.add("      }")
      html.add("")
      html.add("      function deleteMwwCache(id) {")
      html.add("        try {")
      html.add("          const cache = getMwwCache();")
      html.add("          delete cache[id];")
      html.add("          localStorage.setItem(MWW_CACHE_KEY, JSON.stringify(cache));")
      html.add("          updateAllCacheSelectors();")
      html.add("        } catch (e) {")
      html.add("          console.warn('LocalStorage delete failed:', e);")
      html.add("        }")
      html.add("      }")
      html.add("")
      html.add("      function updateAllCacheSelectors() {")
      html.add("        const cache = getMwwCache();")
      html.add("        const entries = Object.values(cache);")
      html.add("        document.querySelectorAll('.wake-slot-card').forEach(c => {")
      html.add("          const bar = c.querySelector('.cached-models-bar');")
      html.add("          const sel = c.querySelector('.select-cached-model');")
      html.add("          if (!bar || !sel) return;")
      html.add("          const currentVal = sel.value;")
      html.add("          sel.innerHTML = '<option value=\"\">-- Load from Saved Models (' + entries.length + ') --</option>';")
      html.add("          if (entries.length === 0) {")
      html.add("            bar.style.display = 'none';")
      html.add("          } else {")
      html.add("            bar.style.display = 'flex';")
      html.add("            entries.forEach(entry => {")
      html.add("              const opt = document.createElement('option');")
      html.add("              opt.value = entry.id;")
      html.add("              opt.textContent = entry.phrase + ' (' + Math.round(entry.size / 1024) + ' KB)';")
      html.add("              sel.appendChild(opt);")
      html.add("            });")
      html.add("            if (currentVal && cache[currentVal]) sel.value = currentVal;")
      html.add("          }")
      html.add("        });")
      html.add("      }")
      html.add("")
      html.add("      function createSlotCard(slotIdx) {")
      html.add("        slotCount++;")
      html.add("        const card = document.createElement('div');")
      html.add("        card.className = 'wake-slot-card';")
      html.add("        card.id = 'wake_slot_card_' + slotIdx;")
      html.add("        card.dataset.slot = slotIdx;")
      html.add("        const slotOffset = OFFSETS[slotIdx - 1] || (0x3B0000 + (slotIdx - 1) * 0x40000);")
      html.add("        const hexOffset = '0x' + slotOffset.toString(16).toUpperCase();")
      html.add("")
      html.add("        let selectHtml = '<select class=\"slot-model-select\" id=\"slot_select_' + slotIdx + '\">';")
      html.add("        PRESETS.forEach(p => { selectHtml += '<option value=\"' + p + '\">' + p + '</option>'; });")
      html.add("        selectHtml += '</select>';")
      html.add("")
      html.add("        card.innerHTML = `")
      html.add("          <div class=\"slot-header\">")
      html.add("            <span class=\"slot-title\"><span class=\"slot-badge-num\">Slot ${slotIdx}</span> Active Wake Model</span>")
      html.add("            <button type=\"button\" class=\"btn-remove-slot\" style=\"display: none;\">${ICONS.x} <span>Remove</span></button>")
      html.add("          </div>")
      html.add("          ${selectHtml}")
      html.add("          <div class=\"custom-wake-box\" style=\"display: none;\">")
      html.add("            <div class=\"custom-wake-guide\">")
      html.add("              <div class=\"guide-title\">${ICONS.book} <span>Train Your Custom Wake Word</span></div>")
      html.add("              <div class=\"guide-text\">microWakeWord models require neural network training with speech and background noise datasets. Train your custom model using the official Google Colab notebook, then upload the resulting <code>.tflite</code> file below:</div>")
      html.add("              <div class=\"guide-links\">")
      html.add("                <a class=\"guide-link\" href=\"https://colab.research.google.com/github/kahrendt/microWakeWord/blob/main/notebooks/microWakeWord_model_training.ipynb\" target=\"_blank\" rel=\"noopener\">${ICONS.external} <span>Open 1-Click Colab Trainer</span></a>")
      html.add("                <a class=\"guide-link\" href=\"https://github.com/kahrendt/microWakeWord\" target=\"_blank\" rel=\"noopener\">${ICONS.external} <span>microWakeWord GitHub Docs</span></a>")
      html.add("              </div>")
      html.add("            </div>")
      html.add("            <div class=\"upload-box\">")
      html.add("              <div class=\"cached-models-bar\" style=\"display: none;\">")
      html.add("                <span class=\"cached-models-label\">${ICONS.database} <span>Saved:</span></span>")
      html.add("                <select class=\"select-cached-model\">")
      html.add("                  <option value=\"\">-- Load from Browser Cache --</option>")
      html.add("                </select>")
      html.add("                <button type=\"button\" class=\"btn-cache-action btn-cache-load\">Load</button>")
      html.add("                <button type=\"button\" class=\"btn-cache-action btn-cache-delete\" title=\"Delete from cache\">${ICONS.x}</button>")
      html.add("              </div>")
      html.add("              <label>Upload microWakeWord Model (.tflite)</label>")
      html.add("              <input type=\"file\" class=\"input-model-file\" accept=\".tflite\" data-maxsize=\"262144\" data-offset=\"${slotOffset}\">")
      html.add("              <div class=\"file-status\" style=\"display: none;\"></div>")
      html.add("              <div class=\"upload-actions-bar\" style=\"display: none;\">")
      html.add("                <div class=\"hint\" style=\"margin: 0;\">Flashed to safe partition <code>${hexOffset}</code></div>")
      html.add("                <a class=\"download-model-btn upload-download-btn\" download=\"model.tflite\" title=\"Download loaded .tflite model\">${ICONS.download} <span>Download .tflite</span></a>")
      html.add("              </div>")
      html.add("              <div class=\"hint upload-default-hint\">Target partition: <code>${hexOffset}</code> (max 256 KB)</div>")
      html.add("            </div>")
      html.add("          </div>")
      html.add("        `;")
      html.add("")
      html.add("        const modelSelect = card.querySelector('.slot-model-select');")
      html.add("        const customBox = card.querySelector('.custom-wake-box');")
      html.add("        const removeBtn = card.querySelector('.btn-remove-slot');")
      html.add("        const fileInput = card.querySelector('.input-model-file');")
      html.add("        const fileStatus = card.querySelector('.file-status');")
      html.add("        const selectCached = card.querySelector('.select-cached-model');")
      html.add("        const btnCacheLoad = card.querySelector('.btn-cache-load');")
      html.add("        const btnCacheDelete = card.querySelector('.btn-cache-delete');")
      html.add("        const uploadActionsBar = card.querySelector('.upload-actions-bar');")
      html.add("        const uploadDownloadBtn = card.querySelector('.upload-download-btn');")
      html.add("        const uploadDefaultHint = card.querySelector('.upload-default-hint');")
      html.add("")
      html.add("        modelSelect.addEventListener('change', () => {")
      html.add("          if (modelSelect.value === 'Custom Wake Word') {")
      html.add("            customBox.style.display = 'block';")
      html.add("            card.classList.add('slot-highlight');")
      html.add("          } else {")
      html.add("            customBox.style.display = 'none';")
      html.add("            card.classList.remove('slot-highlight');")
      html.add("            uploadedParts.delete('wake_slot_' + slotIdx);")
      html.add("          }")
      html.add("          checkInstallReadiness();")
      html.add("          updateDynamicManifest();")
      html.add("        });")
      html.add("")
      html.add("        btnCacheLoad.addEventListener('click', () => {")
      html.add("          const chosenId = selectCached.value;")
      html.add("          if (!chosenId) return;")
      html.add("          const cache = getMwwCache();")
      html.add("          const item = cache[chosenId];")
      html.add("          if (item && item.b64) {")
      html.add("            const bytes = base64ToUint8(item.b64);")
      html.add("            const blob = new Blob([bytes], { type: 'application/octet-stream' });")
      html.add("            const blobUrl = URL.createObjectURL(blob);")
      html.add("            uploadedParts.set('wake_slot_' + slotIdx, { url: blobUrl, offset: slotOffset });")
      html.add("            fileStatus.style.display = 'block';")
      html.add("            fileStatus.innerHTML = ICONS.check + ' <span>Loaded from cache: \"' + item.phrase + '\" (' + Math.round(bytes.length / 1024) + ' KB at ' + hexOffset + ')</span>';")
      html.add("            const fileName = (item.phrase.replace(/[^a-z0-9]/gi, '_') || 'wake_word') + '.tflite';")
      html.add("            uploadDownloadBtn.href = blobUrl;")
      html.add("            uploadDownloadBtn.download = fileName;")
      html.add("            uploadActionsBar.style.display = 'flex';")
      html.add("            if (uploadDefaultHint) uploadDefaultHint.style.display = 'none';")
      html.add("            checkInstallReadiness();")
      html.add("            updateDynamicManifest();")
      html.add("          }")
      html.add("        });")
      html.add("")
      html.add("        selectCached.addEventListener('change', () => {")
      html.add("          if (selectCached.value) btnCacheLoad.click();")
      html.add("        });")
      html.add("")
      html.add("        btnCacheDelete.addEventListener('click', () => {")
      html.add("          const chosenId = selectCached.value;")
      html.add("          if (!chosenId) return;")
      html.add("          const cache = getMwwCache();")
      html.add("          const item = cache[chosenId];")
      html.add("          const name = item ? item.phrase : chosenId;")
      html.add("          if (confirm('Remove \"' + name + '\" from saved browser storage?')) {")
      html.add("            deleteMwwCache(chosenId);")
      html.add("          }")
      html.add("        });")
      html.add("")
      html.add("        fileInput.addEventListener('change', (e) => {")
      html.add("          const file = e.target.files[0];")
      html.add("          if (!file) {")
      html.add("            uploadedParts.delete('wake_slot_' + slotIdx);")
      html.add("            fileStatus.style.display = 'none';")
      html.add("            uploadActionsBar.style.display = 'none';")
      html.add("            if (uploadDefaultHint) uploadDefaultHint.style.display = 'block';")
      html.add("            checkInstallReadiness();")
      html.add("            updateDynamicManifest();")
      html.add("            return;")
      html.add("          }")
      html.add("          if (file.size > 262144) {")
      html.add("            alert('Model file exceeds 256 KB limit.');")
      html.add("            fileInput.value = '';")
      html.add("            return;")
      html.add("          }")
      html.add("          const blobUrl = URL.createObjectURL(file);")
      html.add("          uploadedParts.set('wake_slot_' + slotIdx, { url: blobUrl, offset: slotOffset });")
      html.add("          fileStatus.style.display = 'block';")
      html.add("          fileStatus.innerHTML = ICONS.check + ' <span>Model loaded: ' + file.name + ' (' + Math.round(file.size / 1024) + ' KB at ' + hexOffset + ')</span>';")
      html.add("          uploadDownloadBtn.href = blobUrl;")
      html.add("          uploadDownloadBtn.download = file.name;")
      html.add("          uploadActionsBar.style.display = 'flex';")
      html.add("          if (uploadDefaultHint) uploadDefaultHint.style.display = 'none';")
      html.add("")
      html.add("          const reader = new FileReader();")
      html.add("          reader.onload = function(evt) {")
      html.add("            try {")
      html.add("              const arrBuf = evt.target.result;")
      html.add("              const u8 = new Uint8Array(arrBuf);")
      html.add("              const modelName = file.name.replace(/\\.tflite$/i, '').replace(/[-_]/g, ' ');")
      html.add("              saveMwwCache(modelName, u8, { source: 'upload', filename: file.name });")
      html.add("            } catch (err) {")
      html.add("              console.warn('Could not cache uploaded model:', err);")
      html.add("            }")
      html.add("          };")
      html.add("          reader.readAsArrayBuffer(file);")
      html.add("")
      html.add("          checkInstallReadiness();")
      html.add("          updateDynamicManifest();")
      html.add("        });")
      html.add("")
      html.add("        removeBtn.addEventListener('click', () => {")
      html.add("          uploadedParts.delete('wake_slot_' + slotIdx);")
      html.add("          card.remove();")
      html.add("          refreshSlots();")
      html.add("          checkInstallReadiness();")
      html.add("          updateDynamicManifest();")
      html.add("        });")
      html.add("")
      html.add("        container.appendChild(card);")
      html.add("        refreshSlots();")
      html.add("        updateAllCacheSelectors();")
      html.add("      }")
      html.add("")
      html.add("      function refreshSlots() {")
      html.add("        const cards = container.querySelectorAll('.wake-slot-card');")
      html.add("        cards.forEach((card, idx) => {")
      html.add("          const num = idx + 1;")
      html.add("          card.dataset.slot = num;")
      html.add("          const badge = card.querySelector('.slot-badge-num');")
      html.add("          if (badge) badge.textContent = 'Slot ' + num;")
      html.add("          const rm = card.querySelector('.btn-remove-slot');")
      html.add("          if (rm) rm.style.display = (cards.length > 1) ? 'inline-flex' : 'none';")
      html.add("        });")
      html.add("        if (addBtn) addBtn.disabled = (cards.length >= MAX_SLOTS);")
      html.add("      }")
      html.add("")
      html.add("      if (addBtn) {")
      html.add("        addBtn.addEventListener('click', () => {")
      html.add("          const current = container.querySelectorAll('.wake-slot-card').length;")
      html.add("          if (current < MAX_SLOTS) { createSlotCard(current + 1); checkInstallReadiness(); }")
      html.add("        });")
      html.add("      }")
      html.add("")
      html.add("      createSlotCard(1);")
      html.add("    })();")
      html.add("")

    if field.kind == ifkSelect and field.presetAudios.len > 0:
      var audObj = newJObject()
      let defaultOffset = if field.name.contains("chime"): 0x390000'u32 else: 0x370000'u32
      for item in field.presetAudios:
        var it = newJObject()
        it["preview"] = %item[1]
        it["flash"] = %item[2]
        it["offset"] = %defaultOffset
        audObj[item[0]] = it
      html.add("    Object.assign(PRESET_AUDIO, " & $audObj & ");")

    if field.kind == ifkSelect and field.optionDetails.len > 0:
      var detailsObj = newJObject()
      for opt in field.optionDetails:
        var o = newJObject()
        o["cadence"] = %opt.cadence
        o["desc"] = %opt.description
        detailsObj[opt.value] = o
      html.add("    const OPTION_DETAILS_" & field.name & " = " & $detailsObj & ";")
      html.add("    const select_" & field.name & " = document.getElementById('field_" & field.name & "');")
      html.add("    const presetView_" & field.name & " = document.getElementById('presetView_" & field.name & "');")
      html.add("    const customSlot_" & field.name & " = document.querySelector('.custom-slot[data-depends-on=\"" & field.name & "\"]');")
      html.add("    const cadence_" & field.name & " = document.getElementById('presetCadence_" & field.name & "');")
      html.add("    const desc_" & field.name & " = document.getElementById('presetDesc_" & field.name & "');")
      if field.hasAudioPreview:
        html.add("    const btn_" & field.name & " = document.getElementById('previewBtn_" & field.name & "');")
      html.add("    function updatePreset_" & field.name & "() {")
      if field.hasAudioPreview:
        html.add("      stopAudioPreview();")
      html.add("      const val = select_" & field.name & ".value;")
      html.add("      const isCustom = val.startsWith('Custom');")
      html.add("      const isSilent = val.startsWith('Silent');")
      html.add("      if (isCustom) {")
      html.add("        if (presetView_" & field.name & ") presetView_" & field.name & ".style.display = 'none';")
      html.add("        if (customSlot_" & field.name & ") {")
      html.add("          customSlot_" & field.name & ".style.setProperty('display', 'block', 'important');")
      html.add("          customSlot_" & field.name & ".querySelectorAll('input, select, button, textarea').forEach(el => el.disabled = false);")
      html.add("        }")
      if field.hasAudioPreview:
        html.add("        if (btn_" & field.name & ") {")
        html.add("          btn_" & field.name & ".style.display = 'inline-flex';")
        html.add("          btn_" & field.name & ".innerHTML = ICONS.play + ' <span>Preview Custom Audio</span>';")
        html.add("        }")
      html.add("      } else {")
      html.add("        if (customSlot_" & field.name & ") {")
      html.add("          customSlot_" & field.name & ".style.setProperty('display', 'none', 'important');")
      html.add("          customSlot_" & field.name & ".querySelectorAll('input, select, button, textarea').forEach(el => el.disabled = true);")
      html.add("        }")
      html.add("        if (presetView_" & field.name & ") presetView_" & field.name & ".style.display = 'block';")
      html.add("        if (isSilent) {")
      html.add("          if (cadence_" & field.name & ") cadence_" & field.name & ".textContent = 'Muted';")
      html.add("          if (desc_" & field.name & ") desc_" & field.name & ".textContent = 'Silent mode without audible cues.';")
      if field.hasAudioPreview:
        html.add("          if (btn_" & field.name & ") btn_" & field.name & ".style.display = 'none';")
      html.add("        } else {")
      html.add("          const info = OPTION_DETAILS_" & field.name & "[val] || { cadence: '', desc: '' };")
      html.add("          if (cadence_" & field.name & ") cadence_" & field.name & ".textContent = info.cadence;")
      html.add("          if (desc_" & field.name & ") desc_" & field.name & ".textContent = info.desc;")
      if field.hasAudioPreview:
        html.add("          if (btn_" & field.name & ") {")
        html.add("            btn_" & field.name & ".style.display = 'inline-flex';")
        html.add("            btn_" & field.name & ".innerHTML = ICONS.play + ' <span>Preview Sound</span>';")
        html.add("          }")
      html.add("        }")
      html.add("      }")
      html.add("      updateFieldDependencies();")
      html.add("      checkInstallReadiness();")
      html.add("    }")
      html.add("    if (select_" & field.name & ") {")
      html.add("      select_" & field.name & ".addEventListener('change', updatePreset_" & field.name & ");")
      html.add("      updatePreset_" & field.name & "();")
      html.add("    }")
      if field.hasAudioPreview:
        html.add("    if (btn_" & field.name & ") {")
        html.add("      btn_" & field.name & ".addEventListener('click', () => {")
        html.add("        playPresetAudio(select_" & field.name & ".value, btn_" & field.name & ");")
        html.add("      });")
        html.add("    }")

    if field.kind == ifkFile:
      html.add("    const fileInput_" & field.name & " = document.getElementById('field_" & field.name & "');")
      html.add("    const status_" & field.name & " = document.getElementById('status_" & field.name & "');")
      html.add("    if (fileInput_" & field.name & ") {")
      html.add("      fileInput_" & field.name & ".addEventListener('change', (e) => {")
      html.add("        stopAudioPreview();")
      html.add("        const file = e.target.files[0];")
      html.add("        if (!file) { uploadedParts.delete('" & field.name & "'); updateDynamicManifest(); checkInstallReadiness(); return; }")
      html.add("        const maxSizeBytes = parseInt(fileInput_" & field.name & ".dataset.maxsize || '262144', 10);")
      html.add("        if (file.size > maxSizeBytes) {")
      html.add("          alert('File exceeds maximum allowed size of ' + Math.round(maxSizeBytes / 1024) + ' KB');")
      html.add("          fileInput_" & field.name & ".value = '';")
      html.add("          return;")
      html.add("        }")
      html.add("        const offset = parseInt(fileInput_" & field.name & ".dataset.offset || '0', 10);")
      html.add("        const blobUrl = URL.createObjectURL(file);")
      html.add("        uploadedParts.set('" & field.name & "', { url: blobUrl, offset: offset });")
      html.add("        if (status_" & field.name & ") {")
      html.add("          status_" & field.name & ".style.display = 'block';")
      html.add("          status_" & field.name & ".innerHTML = ICONS.check + ' <span>Ready to flash: ' + file.name + ' (' + Math.round(file.size / 1024) + ' KB at safe partition 0x' + offset.toString(16).toUpperCase() + ')</span>';")
      html.add("        }")
      # Automatically select Custom if dependency field exists
      if field.dependsOnField.len > 0 and field.dependsOnValue.len > 0:
        html.add("        const depSelect = document.getElementById('field_" & field.dependsOnField & "');")
        html.add("        if (depSelect) {")
        html.add("          depSelect.value = '" & field.dependsOnValue & "';")
        html.add("          depSelect.dispatchEvent(new Event('change'));")
        html.add("        }")
      html.add("        updateDynamicManifest();")
      html.add("        checkInstallReadiness();")
      html.add("      });")
      html.add("    }")

  html.add("    document.querySelectorAll('select, input').forEach(el => {")
  html.add("      el.addEventListener('change', () => { updateFieldDependencies(); checkInstallReadiness(); });")
  html.add("      el.addEventListener('input', () => { updateFieldDependencies(); checkInstallReadiness(); });")
  html.add("    });")
  html.add("    updateFieldDependencies();")
  html.add("    checkInstallReadiness();")
  html.add("")
  html.add("    // Success Modal Logic")
  html.add("    const installBtnEl = document.getElementById('installBtn');")
  html.add("    const successModal = document.getElementById('installSuccessModal');")
  html.add("    const btnCloseModal = document.getElementById('btnCloseSuccessModal');")
  html.add("    if (installBtnEl && successModal) {")
  html.add("      installBtnEl.addEventListener('state-changed', (ev) => {")
  html.add("        if (ev && ev.detail && (ev.detail.state === 'success' || ev.detail.state === 'DONE')) {")
  html.add("          successModal.style.display = 'flex';")
  html.add("        }")
  html.add("      });")
  html.add("    }")
  html.add("    if (btnCloseModal && successModal) {")
  html.add("      btnCloseModal.addEventListener('click', () => { successModal.style.display = 'none'; });")
  html.add("      successModal.addEventListener('click', (e) => { if (e.target === successModal) successModal.style.display = 'none'; });")
  html.add("    }")
  html.add("")
  html.add("    // Factory Reset / Erase Device Button")
  html.add("    const btnErase = document.getElementById('btnEraseDevice');")
  html.add("    const eraseStatus = document.getElementById('eraseStatus');")
  html.add("    if (btnErase && eraseStatus) {")
  html.add("      btnErase.addEventListener('click', async () => {")
  html.add("        if (!navigator.serial) {")
  html.add("          alert('WebSerial is not supported in this browser. Please use Google Chrome or Microsoft Edge on desktop.');")
  html.add("          return;")
  html.add("        }")
  html.add("        if (!confirm('This will completely wipe all flash partitions, cached Wi-Fi credentials, and NVS settings on your ESP32 device.\\n\\nAre you sure you want to proceed with a factory reset?')) {")
  html.add("          return;")
  html.add("        }")
  html.add("        eraseStatus.style.display = 'block';")
  html.add("        eraseStatus.className = 'erase-status in-progress';")
  html.add("        eraseStatus.innerHTML = '<span class=\"spinner\"></span> Requesting serial port... Please select your ESP32 device in the browser prompt.';")
  html.add("        try {")
  html.add("          const port = await navigator.serial.requestPort();")
  html.add("          eraseStatus.innerHTML = '<span class=\"spinner\"></span> Loading WebSerial flasher engine...';")
  html.add("          const { ESPLoader, Transport } = await import('https://unpkg.com/esptool-js@0.6.1/bundle.js');")
  html.add("          const transport = new Transport(port, true);")
  html.add("          const esploader = new ESPLoader({")
  html.add("            transport: transport,")
  html.add("            baudrate: 115200,")
  html.add("            terminal: { clean() {}, writeLine(d) { console.log('[esptool]', d); }, write(d) { console.log('[esptool]', d); } }")
  html.add("          });")
  html.add("          eraseStatus.innerHTML = '<span class=\"spinner\"></span> Connecting to ESP32 bootloader...';")
  html.add("          await esploader.main();")
  html.add("          eraseStatus.innerHTML = '<span class=\"spinner\"></span> Erasing entire flash memory (wiping NVS, credentials, partitions)...';")
  html.add("          await esploader.eraseFlash();")
  html.add("          await transport.disconnect();")
  html.add("          eraseStatus.className = 'erase-status success';")
  html.add("          eraseStatus.innerHTML = ICONS.check + ' <strong>Flash erased successfully!</strong> All cached Wi-Fi credentials, NVS keys, and data have been wiped clean. You can now click <strong>Install Firmware</strong> above for a pristine out-of-the-box install.';")
  html.add("        } catch (err) {")
  html.add("          console.error('Erase error:', err);")
  html.add("          eraseStatus.className = 'erase-status error';")
  html.add("          eraseStatus.innerHTML = ICONS.alert + ' <strong>Erase failed:</strong> ' + (err.message || err) + '. If the port was busy, unplug and replug the USB cable and try again.';")
  html.add("        }")
  html.add("      });")
  html.add("    }")
  html.add("  </script>")
  html.add("")
  html.add("  <!-- Post-Install Success Modal with Next Steps -->")
  html.add("  <div id=\"installSuccessModal\" class=\"modal-overlay\" style=\"display: none;\">")
  html.add("    <div class=\"modal-card\">")
  html.add("      <div class=\"modal-header\">")
  html.add("        <div class=\"modal-icon-success\">&#10003;</div>")
  html.add("        <div>")
  html.add("          <h2>Firmware Installed Successfully!</h2>")
  html.add("          <div class=\"modal-subtitle\">Follow these next steps to connect to Home Assistant</div>")
  html.add("        </div>")
  html.add("      </div>")
  html.add("      <div class=\"modal-body\">")
  html.add("        <p class=\"modal-intro\">Your ESP32-S3 voice satellite firmware has been flashed.</p>")
  html.add("        <div style=\"background: rgba(234, 179, 8, 0.15); border: 1px solid rgba(234, 179, 8, 0.35); border-radius: 8px; padding: 10px 14px; margin-bottom: 14px; font-size: 13px; line-height: 1.45; color: #fef08a;\">")
  html.add("          <strong>🔌 Action Required (ESP32-S3):</strong><br/>")
  html.add("          Because this board uses native USB, it stays in bootloader mode after flashing. <strong>Unplug and re-plug the USB-C cable</strong> (or press the board's <strong>RST</strong> button) right now to start ESPHome before clicking <em>Configure Wi-Fi</em>.")
  html.add("        </div>")
  html.add("        <div class=\"next-steps-list\">")
  html.add("          <div class=\"next-step-item\">")
  html.add("            <span class=\"num\">1</span>")
  html.add("            <div>")
  html.add("              <strong>Connect Wi-Fi:</strong> Once power-cycled, click below to send credentials over USB:")
  html.add("              <div style=\"margin: 6px 0;\">")
  html.add("                <improv-wifi-serial-launch-button>")
  html.add("                  <button slot=\"activate\" class=\"modal-wifi-btn\">")
  html.add("                    <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"12\" height=\"12\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M5 12.55a11 11 0 0 1 14.08 0\"></path><path d=\"M1.42 9a16 16 0 0 1 21.16 0\"></path><path d=\"M8.53 16.11a6 6 0 0 1 6.95 0\"></path><line x1=\"12\" y1=\"20\" x2=\"12.01\" y2=\"20\"></line></svg>")
  html.add("                    <span>Configure Wi-Fi via USB</span>")
  html.add("                  </button>")
  html.add("                </improv-wifi-serial-launch-button>")
  html.add("              </div>")
  html.add("              <div class=\"subtext\"><strong>Or via Hotspot:</strong> Connect your phone or PC to <code>Satellite Fallback Hotspot</code> and open <code>http://192.168.4.1</code>.</div>")
  html.add("            </div>")
  html.add("          </div>")
  html.add("          <div class=\"next-step-item\">")
  html.add("            <span class=\"num\">2</span>")
  html.add("            <div>")
  html.add("              <strong>Add in Home Assistant:</strong> Open Home Assistant &rarr; <strong>Settings &rarr; Devices &amp; Services</strong>. Look under <strong>Discovered</strong> for <strong>Voice Satellite</strong>. Click <strong>Configure &rarr; Submit</strong> (no encryption key needed).")
  html.add("            </div>")
  html.add("          </div>")
  html.add("          <div class=\"next-step-item\">")
  html.add("            <span class=\"num\">3</span>")
  html.add("            <div>")
  html.add("              <strong>Voice &amp; Audio Presets:</strong> Link your Assist pipeline in <strong>Settings &rarr; Voice Assistants</strong>, and choose your favorite wake chime and processing loop right on the device card!")
  html.add("            </div>")
  html.add("          </div>")
  html.add("        </div>")
  html.add("      </div>")
  html.add("      <div class=\"modal-actions\">")
  html.add("        <a href=\"https://my.home-assistant.io/redirect/config_flow_start?domain=esphome\" target=\"_blank\" class=\"btn-ha-link\">")
  html.add("          <span>Open Home Assistant</span>")
  html.add("          <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"12\" height=\"12\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6\"></path><polyline points=\"15 3 21 3 21 9\"></polyline><line x1=\"10\" y1=\"14\" x2=\"21\" y2=\"3\"></line></svg>")
  html.add("        </a>")
  html.add("        <button type=\"button\" class=\"btn-modal-close\" id=\"btnCloseSuccessModal\">Close</button>")
  html.add("      </div>")
  html.add("    </div>")
  html.add("  </div>")
  html.add("</body>")
  html.add("</html>\n")

  result = html.join("\n")

template esphomeInstaller*(installerName: string, body: untyped): untyped =
  ## Declarative builder template for an ESP-Web-Tools web installer.
  block:
    var installer {.inject.} = newInstallerDefinition(installerName)
    body
    installer
