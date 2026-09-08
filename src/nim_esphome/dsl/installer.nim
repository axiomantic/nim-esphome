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
    ifkAudioShowcase = "audio_showcase"
    ifkCustomWakeWord = "custom_wake_word"
    ifkCustomWakeWordSlots = "custom_wake_word_slots"
    ifkMultiAudio = "multi_audio"

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
    slotPartitions*: seq[string]
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
    nativeUsb*: bool

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
    nativeUsb*: bool
    enableEraseButton*: bool
    enableImprovWifi*: bool
    enableSuccessModal*: bool
    enableSetupGuide*: bool
    enableTerminalConsole*: bool
    enableDeviceInspector*: bool
    fallbackApSsid*: string
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
    nativeUsb: chipFamily == "ESP32-S3",
    enableEraseButton: true,
    enableImprovWifi: true,
    enableSuccessModal: true,
    enableSetupGuide: true,
    enableTerminalConsole: true,
    enableDeviceInspector: true,
    fallbackApSsid: "Satellite Fallback Hotspot",
    fields: @[],
    targets: @[],
    customPartitions: @[]
  )


proc addFileField*(
    installer: InstallerDefinition,
    name: string,
    label: string,
    accept: string = ".wav,.mp3,.ogg,.flac,.m4a,audio/*",
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

proc addCustomAudioField*(
    installer: InstallerDefinition,
    name: string,
    label: string,
    accept: string = ".wav,.mp3,.ogg,.flac,.m4a,audio/*",
    partition: string = "custom_audio",
    maxSize: int = 262144, # 256 KB default
    flashOffset: uint32 = 0x370000'u32,
    required: bool = false,
    description: string = "Upload custom audio (.wav, .mp3, .ogg, .flac, .m4a). The web installer automatically resamples to 16kHz mono 16-bit PCM WAV, applies light dynamic range compression, and normalizes peak volume to -1.0 dBFS directly in your browser before flashing.",
    dependsOnField: string = "",
    dependsOnValue: string = ""
) =
  ## Adds a custom audio upload field that automatically transcodes, compresses, and normalizes audio in-browser before flashing.
  installer.addFileField(
    name = name,
    label = label,
    accept = accept,
    partition = partition,
    maxSize = maxSize,
    flashOffset = flashOffset,
    required = required,
    description = description,
    dependsOnField = dependsOnField,
    dependsOnValue = dependsOnValue
  )

proc addTarget*(
    installer: InstallerDefinition,
    name: string,
    binPath: string,
    chipFamily: string = "ESP32-S3",
    description: string = "",
    nativeUsb: bool = false
) =
  ## Registers a hardware board target with its corresponding factory binary.
  let isNative = if nativeUsb: true elif chipFamily == "ESP32-S3": true else: false
  installer.targets.add(InstallerTarget(
    name: name,
    binPath: binPath,
    chipFamily: chipFamily,
    description: description,
    nativeUsb: isNative
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

proc addAudioShowcase*(
    installer: InstallerDefinition,
    name: string,
    label: string,
    options: seq[string],
    defaultVal: string = "",
    description: string = "",
    optionDetails: seq[OptionDetail] = @[],
    presetAudios: seq[(string, string, string)] = @[]
) =
  ## Registers an interactive Audio Showcase for browsing and previewing pre-compiled sounds.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkAudioShowcase,
    label: label,
    options: options,
    optionDetails: optionDetails,
    defaultVal: if defaultVal.len > 0: defaultVal elif options.len > 0: options[0] else: "",
    description: description,
    hasAudioPreview: true,
    presetAudios: presetAudios
  ))

proc addCustomWakeWordField*(
    installer: InstallerDefinition,
    name: string = "custom_wake_word",
    label: string = "Custom Wake Word Model (.tflite)",
    partition: string = "wake_model",
    flashOffset: uint32 = 0x510000'u32,
    maxSize: int = 524288, # 512 KB
    defaultPhrase: string = "",
    defaultCutoff: float = 0.40,
    required: bool = false,
    description: string = "Upload an optional microWakeWord .tflite model to flash into the dedicated wake_model partition."
) =
  ## Adds a custom wake word model upload field that packs a 64-byte header and flashes to flashOffset.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkCustomWakeWord,
    label: label,
    accept: ".tflite",
    partition: partition,
    flashOffset: flashOffset,
    maxSize: maxSize,
    defaultVal: defaultPhrase,
    minVal: 0.0,
    maxVal: 1.0,
    stepVal: 0.01,
    required: required,
    description: description
  ))
  var found = false
  for p in installer.customPartitions:
    if p.name == partition:
      found = true
      break
  if not found:
    installer.customPartitions.add(FlashPartition(
      name: partition,
      partType: "data",
      subType: "0x83",
      offset: flashOffset,
      size: uint32(maxSize)
    ))

proc addCustomWakeWordSlotsField*(
    installer: InstallerDefinition,
    name: string = "custom_wake_words",
    label: string = "Custom Wake Word Models (.tflite)",
    maxSlots: int = 3,
    slotOffsets: seq[uint32] = @[0x510000'u32, 0x550000'u32, 0x590000'u32],
    slotPartitions: seq[string] = @["wake_model", "wake_model_2", "wake_model_3"],
    maxSize: int = 262144, # 256 KB per slot
    description: string = "Upload up to 3 custom microWakeWord .tflite models to flash into dedicated partitions."
) =
  ## Registers dedicated slots for uploading custom microWakeWord models.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkCustomWakeWordSlots,
    label: label,
    accept: ".tflite,.json",
    maxSlots: maxSlots,
    slotOffsets: slotOffsets,
    slotPartitions: slotPartitions,
    maxSize: maxSize,
    description: description
  ))
  for i in 0 ..< maxSlots:
    let partName = if i < slotPartitions.len: slotPartitions[i] else: "wake_model_" & $(i + 1)
    let offset = if i < slotOffsets.len: slotOffsets[i] else: uint32(0x510000 + (i * 0x40000))
    var found = false
    for p in installer.customPartitions:
      if p.name == partName:
        found = true
        break
    if not found:
      installer.customPartitions.add(FlashPartition(
        name: partName,
        partType: "data",
        subType: "0x83",
        offset: offset,
        size: uint32(maxSize)
      ))

proc addMultiCustomAudioField*(
    installer: InstallerDefinition,
    name: string,
    label: string,
    partition: string,
    flashOffset: uint32,
    maxSize: int = 262144, # 256 KB
    accept: string = ".wav,.mp3,.ogg,.flac,.m4a,audio/*",
    description: string = ""
) =
  ## Registers a multi-file custom audio upload container that packs transcoded 16kHz PCM WAVs
  ## into a contiguous CAUD archive for the specified partition.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkMultiAudio,
    label: label,
    accept: accept,
    partition: partition,
    flashOffset: flashOffset,
    maxSize: maxSize,
    description: description
  ))
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
    if field.accept.contains(".wav") or field.accept.contains("audio") or field.partition.contains("sound") or field.partition.contains("chime") or field.partition.contains("audio"):
      let hexOffset = "0x" & field.flashOffset.toHex(6).toLowerAscii
      let kbSize = field.maxSize div 1024
      html.add("        <div class=\"format-callout\"><strong>Audio Auto-Processing:</strong> Custom audio (.wav, .mp3, .ogg, .flac, .m4a) is automatically resampled to 16kHz mono 16-bit PCM WAV with dynamic range compression and peak normalization (-1.0 dBFS) directly in your browser before flashing.<br>Target partition: safe dedicated <code>" & field.partition & "</code> partition at " & hexOffset & " (max " & $kbSize & " KB, 100% safe from OTA firmware updates).</div>")
    html.add("        <div class=\"file-status\" id=\"status_" & field.name & "\"></div>")
  of ifkAudioShowcase:
    html.add("        <div class=\"showcase-card\" id=\"showcaseCard_" & field.name & "\">")
    html.add("          <div class=\"showcase-header\">")
    html.add("            <span class=\"showcase-tag\">Included in Firmware</span>")
    html.add("          </div>")
    html.add("          <select id=\"field_" & field.name & "\">")
    for opt in field.options:
      let selected = if opt == field.defaultVal: " selected" else: ""
      html.add("            <option value=\"" & opt & "\"" & selected & ">" & opt & "</option>")
    html.add("          </select>")
    if field.optionDetails.len > 0:
      html.add("          <div class=\"preset-card\" id=\"presetCard_" & field.name & "\">")
      html.add("            <div class=\"preset-view\" id=\"presetView_" & field.name & "\">")
      html.add("              <div class=\"preset-header\">")
      html.add("                <span class=\"preset-badge\" id=\"presetCadence_" & field.name & "\"></span>")
      html.add("              </div>")
      html.add("              <p class=\"preset-desc\" id=\"presetDesc_" & field.name & "\"></p>")
      html.add("            </div>")
      html.add("            <div class=\"preview-actions\">")
      html.add("              <button type=\"button\" class=\"preview-btn\" id=\"previewBtn_" & field.name & "\"><svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"currentColor\"><polygon points=\"6 4 20 12 6 20 6 4\"></polygon></svg> <span>Preview Sound</span></button>")
      html.add("            </div>")
      html.add("          </div>")
    html.add("          <div class=\"showcase-note\">Pre-compiled in firmware. Selectable anytime in Home Assistant without reflashing.</div>")
    html.add("        </div>")
  of ifkCustomWakeWord:
    let hexOffset = "0x" & field.flashOffset.toHex(6).toLowerAscii
    let kbSize = field.maxSize div 1024
    html.add("        <div class=\"custom-wake-box\" id=\"wakeBox_" & field.name & "\">")
    html.add("          <input type=\"file\" id=\"field_" & field.name & "\" accept=\"" & field.accept & "\" data-offset=\"" & $field.flashOffset & "\" data-maxsize=\"" & $field.maxSize & "\">")
    html.add("          <div class=\"custom-wake-inputs\" style=\"display: flex; gap: 10px; margin-top: 8px;\">")
    html.add("            <div style=\"flex: 2;\">")
    html.add("              <label style=\"font-size: 0.76rem; color: #94a3b8; display: block; margin-bottom: 4px;\">Wake Word Name / Phrase</label>")
    html.add("              <input type=\"text\" id=\"field_" & field.name & "_phrase\" placeholder=\"e.g. Hey Jarvis or Marvin\" value=\"" & field.defaultVal & "\">")
    html.add("            </div>")
    html.add("            <div style=\"flex: 1;\">")
    html.add("              <label style=\"font-size: 0.76rem; color: #94a3b8; display: block; margin-bottom: 4px;\">Probability Cutoff</label>")
    html.add("              <input type=\"number\" id=\"field_" & field.name & "_cutoff\" min=\"0.05\" max=\"0.99\" step=\"0.01\" value=\"0.40\">")
    html.add("            </div>")
    html.add("          </div>")
    html.add("          <div class=\"format-callout\"><strong>Dedicated Partition:</strong> Flashed to <code>" & field.partition & "</code> at " & hexOffset & " (" & $kbSize & " KB). Automatic 64-byte header is prepended before flashing so firmware dynamically registers the wake word in Home Assistant.</div>")
    html.add("          <div class=\"file-status\" id=\"status_" & field.name & "\"></div>")
    html.add("        </div>")
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
            if child.accept.contains(".wav") or child.accept.contains("audio") or child.partition.contains("sound") or child.partition.contains("chime") or child.partition.contains("audio"):
              let hexOffset = "0x" & child.flashOffset.toHex(6).toLowerAscii
              let kbSize = child.maxSize div 1024
              html.add("            <div class=\"format-callout\"><strong>Audio Auto-Processing:</strong> Custom audio (.wav, .mp3, .ogg, .flac, .m4a) is resampled to 16kHz mono 16-bit PCM WAV with dynamic compression and normalization (-1.0 dBFS) in your browser.<br>Target partition: dedicated <code>" & child.partition & "</code> partition at " & hexOffset & " (max " & $kbSize & " KB).</div>")
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
  of ifkCustomWakeWordSlots:
    html.add("        <div class=\"custom-wake-slots\" id=\"customWakeSlots_" & field.name & "\">")
    html.add("          <div class=\"ha-selection-note\"><strong>Dedicated Wake Word Partitions:</strong> Flashed into dedicated slots (up to " & $field.maxSlots & " models).<br><strong>Note:</strong> Uploading and flashing custom wake words stores them in device flash memory, but does not set the active wake word. After flashing, open Home Assistant, go to your satellite's device controls page, and choose your wake word from the <em>Active Wake Word</em> dropdown.</div>")
    html.add("          <div class=\"wake-slots-grid\" style=\"display: flex; flex-direction: column; gap: 12px;\">")
    for i in 0 ..< field.maxSlots:
      let partName = if i < field.slotPartitions.len: field.slotPartitions[i] else: "wake_model_" & $(i + 1)
      let offset = if i < field.slotOffsets.len: field.slotOffsets[i] else: uint32(0x510000 + (i * 0x40000))
      let hexOffset = "0x" & offset.toHex(6).toLowerAscii
      let kbSize = field.maxSize div 1024
      html.add("            <div class=\"wake-slot-card\" id=\"slotCard_" & field.name & "_" & $i & "\">")
      html.add("              <div class=\"slot-header\">")
      html.add("                <span class=\"slot-title\">Slot " & $(i + 1) & ": <code>" & partName & "</code> (" & hexOffset & ")</span>")
      html.add("                <span class=\"slot-badge-num\">" & $kbSize & " KB max</span>")
      html.add("              </div>")
      html.add("              <input type=\"file\" id=\"slotFile_" & field.name & "_" & $i & "\" accept=\".tflite,.json\" multiple data-offset=\"" & $offset & "\" data-maxsize=\"" & $field.maxSize & "\">")
      html.add("              <div class=\"custom-wake-inputs\" style=\"display: flex; gap: 10px; margin-top: 8px;\">")
      html.add("                <div style=\"flex: 2;\">")
      html.add("                  <label style=\"font-size: 0.76rem; color: #94a3b8; display: block; margin-bottom: 4px;\">Wake Word Name / Phrase</label>")
      html.add("                  <input type=\"text\" id=\"slotPhrase_" & field.name & "_" & $i & "\" placeholder=\"e.g. Jarvis\">")
      html.add("                </div>")
      html.add("                <div style=\"flex: 1;\">")
      html.add("                  <label style=\"font-size: 0.76rem; color: #94a3b8; display: block; margin-bottom: 4px;\">Cutoff</label>")
      html.add("                  <input type=\"number\" id=\"slotCutoff_" & field.name & "_" & $i & "\" min=\"0.05\" max=\"0.99\" step=\"0.01\" value=\"0.40\">")
      html.add("                </div>")
      html.add("              </div>")
      html.add("              <div class=\"file-status\" id=\"slotStatus_" & field.name & "_" & $i & "\"></div>")
      html.add("            </div>")
    html.add("          </div>")
    html.add("        </div>")
  of ifkMultiAudio:
    let hexOffset = "0x" & field.flashOffset.toHex(6).toLowerAscii
    let kbSize = field.maxSize div 1024
    html.add("        <div class=\"multi-audio-container\" id=\"multiAudio_" & field.name & "\" data-partition=\"" & field.partition & "\" data-offset=\"" & $field.flashOffset & "\" data-maxsize=\"" & $field.maxSize & "\">")
    html.add("          <div class=\"ha-selection-note\"><strong>Dedicated Audio Partition:</strong> Flashed into <code>" & field.partition & "</code> at " & hexOffset & " (" & $kbSize & " KB max). Audio files (.wav, .mp3, .ogg, .flac, .m4a) are automatically resampled to 16kHz mono 16-bit PCM WAV with dynamic compression and normalization (-1.0 dBFS) in your browser.<br><strong>Note:</strong> Uploading and flashing custom audio stores the sounds in device flash memory, but does not set them as active. After flashing, open Home Assistant, go to your satellite's device controls page, and select your custom sound from the dropdown.</div>")
    html.add("          <div class=\"multi-audio-list\" id=\"audioList_" & field.name & "\"></div>")
    html.add("          <div class=\"multi-audio-actions\" style=\"margin-top: 10px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px;\">")
    html.add("            <label class=\"btn-add-audio\" style=\"cursor: pointer;\">")
    html.add("              <input type=\"file\" id=\"addAudioInput_" & field.name & "\" accept=\"" & field.accept & "\" multiple style=\"display: none;\">")
    html.add("              <span>+ Add Audio File</span>")
    html.add("            </label>")
    html.add("            <div class=\"audio-partition-usage\" id=\"usage_" & field.name & "\" style=\"font-size: 0.78rem; color: #94a3b8; font-family: monospace;\">0 KB / " & $kbSize & " KB used</div>")
    html.add("          </div>")
    html.add("          <div class=\"multi-audio-error\" id=\"error_" & field.name & "\" style=\"display: none; color: #f87171; font-size: 0.8rem; margin-top: 6px;\"></div>")
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
  if installer.enableImprovWifi:
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
  html.add("    .btn-add-audio { background: #0f172a; border: 1px dashed #3b82f6; color: #60a5fa; border-radius: 8px; padding: 8px 14px; font-size: 0.82rem; font-weight: 600; cursor: pointer; transition: all 0.2s ease; display: inline-flex; align-items: center; gap: 6px; }")
  html.add("    .btn-add-audio:hover { background: rgba(59, 130, 246, 0.15); border-color: #60a5fa; color: #93c5fd; }")
  html.add("    .multi-audio-item { background: #080d1a; border: 1px solid #202b3d; border-radius: 8px; padding: 10px 14px; margin-bottom: 8px; display: flex; align-items: center; justify-content: space-between; gap: 10px; flex-wrap: wrap; }")
  html.add("    .multi-audio-info { display: flex; align-items: center; gap: 10px; flex: 1; min-width: 200px; }")
  html.add("    .audio-name-input { background: #0b1329; border: 1px solid #334155; border-radius: 4px; padding: 4px 8px; color: #f8fafc; font-size: 0.85rem; flex: 1; }")
  html.add("    .audio-badge { font-size: 0.7rem; background: #0c4a6e; color: #38bdf8; border: 1px solid #0284c7; padding: 2px 6px; border-radius: 4px; white-space: nowrap; }")
  html.add("    .audio-size-badge { font-size: 0.72rem; color: #94a3b8; font-family: monospace; white-space: nowrap; }")
  html.add("    .btn-remove-audio { background: transparent; border: 1px solid rgba(239, 68, 68, 0.4); color: #f87171; border-radius: 4px; padding: 4px 8px; font-size: 0.75rem; cursor: pointer; }")
  html.add("    .btn-remove-audio:hover { background: rgba(239, 68, 68, 0.15); border-color: #ef4444; }")
  html.add("    .ha-selection-note { margin-top: 8px; margin-bottom: 12px; background: rgba(59, 130, 246, 0.08); border-left: 3px solid #3b82f6; padding: 10px 14px; border-radius: 6px; font-size: 0.82rem; color: #cbd5e1; line-height: 1.45; }")
  html.add("    .ha-selection-note strong { color: #60a5fa; }")
  html.add("    .ha-selection-note em { color: #f8fafc; font-style: normal; font-weight: 600; }")
  html.add("    .ha-selection-note code { background: #1e293b; color: #38bdf8; padding: 1px 5px; border-radius: 4px; font-family: monospace; font-size: 0.8rem; }")
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
  html.add("    .ha-btn { flex: 1.5; min-width: 170px; background: #1e293b; color: #38bdf8; border: 1px solid #0284c7; padding: 14px 18px; font-size: 0.95rem; font-weight: 600; border-radius: 8px; cursor: pointer; text-decoration: none; transition: all 0.2s ease; display: inline-flex; align-items: center; justify-content: center; gap: 8px; }")
  html.add("    .ha-btn:hover { background: rgba(2, 132, 199, 0.2); border-color: #38bdf8; color: #ffffff; }")
  html.add("    .btn-guide-ha { background: #1e293b; color: #38bdf8; border: 1px solid #0284c7; padding: 8px 14px; font-size: 0.82rem; font-weight: 600; border-radius: 6px; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 6px; transition: all 0.2s ease; }")
  html.add("    .btn-guide-ha:hover { background: rgba(2, 132, 199, 0.2); border-color: #38bdf8; color: #ffffff; }")
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
  html.add("    .modal-overlay { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.85); backdrop-filter: blur(5px); display: flex; align-items: center; justify-content: center; z-index: 999999; padding: 20px; animation: fadeIn 0.2s ease; }")
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
  html.add("    .terminal-drawer { margin-top: 32px; padding-top: 24px; border-top: 1px solid #1e293b; width: 100%; text-align: left; }")
  html.add("    .term-header { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px; margin-bottom: 12px; }")
  html.add("    .term-title-row { display: flex; align-items: center; gap: 10px; }")
  html.add("    .term-title { font-size: 1.05rem; font-weight: 600; color: #f1f5f9; margin: 0; display: flex; align-items: center; gap: 8px; }")
  html.add("    .term-badge { font-size: 0.72rem; font-weight: 600; padding: 2px 8px; border-radius: 12px; text-transform: uppercase; letter-spacing: 0.04em; }")
  html.add("    .term-badge.disconnected { background: rgba(100, 116, 139, 0.2); color: #94a3b8; border: 1px solid #475569; }")
  html.add("    .term-badge.connected { background: rgba(16, 185, 129, 0.2); color: #34d399; border: 1px solid #10b981; }")
  html.add("    .term-badge.connecting { background: rgba(234, 179, 8, 0.2); color: #facc15; border: 1px solid #eab308; }")
  html.add("    .term-actions { display: flex; align-items: center; gap: 8px; }")
  html.add("    .term-btn { padding: 6px 12px; border-radius: 6px; font-size: 0.8rem; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; transition: all 0.15s ease; }")
  html.add("    .term-btn.connect { background: #0284c7; color: white; border: none; }")
  html.add("    .term-btn.connect:hover { background: #0369a1; }")
  html.add("    .term-btn.disconnect { background: #b91c1c; color: white; border: none; }")
  html.add("    .term-btn.disconnect:hover { background: #991b1b; }")
  html.add("    .term-btn.secondary { background: #1e293b; color: #cbd5e1; border: 1px solid #334155; }")
  html.add("    .term-btn.secondary:hover { background: #334155; color: white; }")
  html.add("    .device-info-banner { display: flex; flex-wrap: wrap; gap: 8px; background: #080d1a; border: 1px solid #1e293b; border-radius: 8px; padding: 10px 14px; margin-bottom: 12px; }")
  html.add("    .info-pill { font-size: 0.76rem; background: #131d31; border: 1px solid #202e48; border-radius: 6px; padding: 4px 10px; display: inline-flex; align-items: center; gap: 6px; color: #cbd5e1; }")
  html.add("    .info-pill .pill-label { color: #64748b; text-transform: uppercase; font-size: 0.68rem; font-weight: 700; }")
  html.add("    .info-pill strong { color: #38bdf8; font-weight: 600; }")
  html.add("    .info-pill code { color: #34d399; font-family: monospace; }")
  html.add("    .term-console-wrap { position: relative; background: #050811; border: 1px solid #1e293b; border-radius: 8px; overflow: hidden; }")
  html.add("    .terminal-body { margin: 0; padding: 14px 16px; font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, Courier, monospace; font-size: 0.78rem; line-height: 1.45; color: #94a3b8; overflow-y: auto; white-space: pre-wrap; word-break: break-all; transition: max-height 0.25s ease; }")
  html.add("    .terminal-body.collapsed { max-height: 160px; }")
  html.add("    .terminal-body.expanded { max-height: 480px; }")
  html.add("    .term-line-info { color: #34d399; }")
  html.add("    .term-line-warn { color: #fbbf24; }")
  html.add("    .term-line-err { color: #f87171; }")
  html.add("    .term-line-dbg { color: #38bdf8; }")
  html.add("    .term-empty-hint { color: #475569; font-style: italic; }")
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
  if installer.enableImprovWifi:
    html.add("        <improv-wifi-serial-launch-button>")
    html.add("          <button slot=\"activate\" class=\"wifi-btn\" title=\"Configure Wi-Fi credentials directly over USB without re-flashing\">")
    html.add("            <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M5 12.55a11 11 0 0 1 14.08 0\"></path><path d=\"M1.42 9a16 16 0 0 1 21.16 0\"></path><path d=\"M8.53 16.11a6 6 0 0 1 6.95 0\"></path><line x1=\"12\" y1=\"20\" x2=\"12.01\" y2=\"20\"></line></svg>")
    html.add("            <span>Configure Wi-Fi</span>")
    html.add("          </button>")
    html.add("          <span slot=\"unsupported\"></span>")
    html.add("        </improv-wifi-serial-launch-button>")
  if installer.homeAssistantDomain.len > 0:
    html.add("        <a href=\"https://my.home-assistant.io/redirect/config_flow_start?domain=" & installer.homeAssistantDomain & "\" target=\"_blank\" class=\"ha-btn\" title=\"Open Home Assistant to configure or manage this device\">")
    html.add("          <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z\"></path><polyline points=\"9 22 9 12 15 12 15 22\"></polyline></svg>")
    html.add("          <span>Add to Home Assistant</span>")
    html.add("        </a>")
  if installer.enableEraseButton:
    html.add("        <button type=\"button\" id=\"btnEraseDevice\" class=\"erase-btn\" title=\"Completely wipe all flash partitions, cached Wi-Fi credentials, and NVS settings\">")
    html.add("          <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M3 6h18\"></path><path d=\"M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2\"></path></svg>")
    html.add("          <span>Erase Device</span>")
    html.add("        </button>")
  html.add("      </div>")
  html.add("      <div id=\"eraseStatus\" class=\"erase-status\" style=\"display: none;\"></div>")
  html.add("    </div>")
  html.add("")
  if installer.enableSetupGuide:
    let initialNative = if installer.targets.len > 0: installer.targets[0].nativeUsb else: installer.nativeUsb
    let nativeWarningStyle = if initialNative: "" else: " style=\"display: none;\""
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
    html.add("            <div class=\"step-tip native-usb-warning\"" & nativeWarningStyle & " style=\"background: rgba(234, 179, 8, 0.15); border-left: 3px solid #eab308; margin-bottom: 10px;\"><strong>Important for ESP32-S3 Native USB:</strong> Because this board uses native USB, software resets cannot exit the ROM bootloader after flashing or erasing. <strong>Unplug and reconnect the USB-C cable</strong> (or tap the <strong>RST</strong> button) once before configuring Wi-Fi! If you click before rebooting, it will report <em>\"Improv Wi-Fi Serial not detected\"</em> because ESPHome has not booted yet.</div>")
    html.add("            <p>Once replugged, connect your device to Wi-Fi using either method below:</p>")
    if installer.enableImprovWifi:
      html.add("            <div style=\"display: flex; gap: 8px; flex-wrap: wrap; margin: 10px 0;\">")
      html.add("              <improv-wifi-serial-launch-button>")
      html.add("                <button slot=\"activate\" class=\"btn-guide-wifi\">")
      html.add("                  <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M5 12.55a11 11 0 0 1 14.08 0\"></path><path d=\"M1.42 9a16 16 0 0 1 21.16 0\"></path><path d=\"M8.53 16.11a6 6 0 0 1 6.95 0\"></path><line x1=\"12\" y1=\"20\" x2=\"12.01\" y2=\"20\"></line></svg>")
      html.add("                  <span>Configure Wi-Fi via USB (Improv)</span>")
      html.add("                </button>")
      html.add("              </improv-wifi-serial-launch-button>")
      html.add("            </div>")
    if installer.fallbackApSsid.len > 0:
      html.add("            <div class=\"step-tip\"><strong>Method B (Fallback Hotspot):</strong> Connect your phone or laptop to the open Wi-Fi network <code>" & installer.fallbackApSsid & "</code>. The captive portal at <code>http://192.168.4.1</code> opens automatically to enter your Wi-Fi credentials.</div>")
    html.add("          </div>")
    html.add("        </div>")
    html.add("        <div class=\"guide-step\">")
    html.add("          <div class=\"step-number\">2</div>")
    html.add("          <div class=\"step-content\">")
    html.add("            <h4>Add in Home Assistant</h4>")
    html.add("            <p>Open Home Assistant and navigate to <strong>Settings &rarr; Devices &amp; Services</strong>. Your new device will appear under <strong>Discovered</strong> as <strong>Voice Satellite</strong> (e.g. <code>Voice Satellite ba2c6c</code>).</p>")
    html.add("            <p>Click <strong>Configure</strong>, then click <strong>Submit</strong>.</p>")
    html.add("            <div style=\"background: rgba(59, 130, 246, 0.12); border-left: 3px solid #3b82f6; padding: 10px 14px; margin: 10px 0; border-radius: 6px; font-size: 0.85rem; line-height: 1.5; color: #cbd5e1;\">")
    html.add("              <strong style=\"color: #60a5fa;\">No Encryption Key Needed:</strong> This firmware connects without an API encryption key.<br/>")
    html.add("              <div style=\"margin-top: 6px;\"><strong>If Home Assistant prompts for an Encryption Key:</strong><br/>Brand-new boards ship with Seeed's encrypted factory firmware. If Home Assistant discovered the board before it was flashed, it cached a requirement for an encryption key and will reject a blank field with <em>\"not all required fields are filled in\"</em>.</div>")
    html.add("              <div style=\"margin-top: 6px;\"><strong>Quick Fix:</strong> Cancel the prompt, click <strong>Add Integration &rarr; ESPHome</strong>, and enter your device IP (or <code>esphome-satellite-&lt;mac&gt;.local</code>) and port <code>6053</code>. It connects directly with zero encryption prompts!</div>")
    html.add("            </div>")
    if installer.homeAssistantDomain.len > 0:
      html.add("            <div style=\"display: flex; gap: 8px; flex-wrap: wrap; margin: 10px 0;\">")
      html.add("              <a href=\"https://my.home-assistant.io/redirect/config_flow_start?domain=" & installer.homeAssistantDomain & "\" target=\"_blank\" class=\"btn-guide-ha\">")
      html.add("                <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"13\" height=\"13\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z\"></path><polyline points=\"9 22 9 12 15 12 15 22\"></polyline></svg>")
      html.add("                <span>Add to Home Assistant</span>")
      html.add("              </a>")
      html.add("            </div>")
    html.add("          </div>")
    html.add("        </div>")
    html.add("        <div class=\"guide-step\">")
    html.add("          <div class=\"step-number\">3</div>")
    html.add("          <div class=\"step-content\">")
    html.add("            <h4>Customize Device &amp; Audio Presets</h4>")
    html.add("            <p>On the device card, you can customize your feedback styles, wake chimes, and runtime settings anytime directly from Home Assistant.</p>")
    html.add("          </div>")
    html.add("        </div>")
    if installer.enableEraseButton:
      html.add("        <div class=\"guide-step\">")
      html.add("          <div class=\"step-number\">&#8635;</div>")
      html.add("          <div class=\"step-content\">")
      html.add("            <h4>Testing Clean Flow / Factory Reset</h4>")
      html.add("            <p>If your device previously had another Wi-Fi network or an old encryption key saved in NVS memory, click <strong>Erase Device (Factory Reset)</strong> above or run <code>esptool.py erase_flash</code> in terminal before clicking Install Firmware.</p>")
      html.add("          </div>")
      html.add("        </div>")
    html.add("      </div>")
    html.add("    </div>")
  if installer.enableTerminalConsole:
    html.add("    <!-- Live Device Terminal & Console Drawer -->")
    html.add("    <div class=\"terminal-drawer\">")
    html.add("      <div class=\"term-header\">")
    html.add("        <div class=\"term-title-row\">")
    html.add("          <h3 class=\"term-title\">")
    html.add("            <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"15\" height=\"15\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><polyline points=\"4 17 10 11 4 5\"></polyline><line x1=\"12\" y1=\"19\" x2=\"20\" y2=\"19\"></line></svg>")
    html.add("            <span>Live Device Logs &amp; Terminal</span>")
    html.add("          </h3>")
    html.add("          <span id=\"termStatusBadge\" class=\"term-badge disconnected\">Disconnected</span>")
    html.add("        </div>")
    html.add("        <div class=\"term-actions\">")
    html.add("          <button type=\"button\" id=\"btnTermConnect\" class=\"term-btn connect\">")
    html.add("            <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"12\" height=\"12\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6\"></path></svg>")
    html.add("            <span>Connect Logs</span>")
    html.add("          </button>")
    html.add("          <button type=\"button\" id=\"btnTermReset\" class=\"term-btn secondary\" title=\"Send hardware reset pulse via RTS/DTR\">Reset Chip</button>")
    html.add("          <button type=\"button\" id=\"btnTermClear\" class=\"term-btn secondary\" title=\"Clear console output\">Clear</button>")
    html.add("          <button type=\"button\" id=\"btnTermToggle\" class=\"term-btn secondary\" title=\"Expand or collapse terminal height\">Expand ▼</button>")
    html.add("        </div>")
    html.add("      </div>")
    if installer.enableDeviceInspector:
      html.add("      <!-- Connected Device Information Inspector -->")
      html.add("      <div id=\"deviceInfoBanner\" class=\"device-info-banner\" style=\"display: none;\">")
      html.add("        <div class=\"info-pill\"><span class=\"pill-label\">Target</span> <strong id=\"devInfoTarget\">" & installer.chipFamily & "</strong></div>")
      html.add("        <div class=\"info-pill\"><span class=\"pill-label\">Firmware</span> <strong id=\"devInfoFirmware\">" & installer.name & " v" & installer.version & "</strong></div>")
      html.add("        <div class=\"info-pill\"><span class=\"pill-label\">ESPHome</span> <strong id=\"devInfoEspHome\">Detecting...</strong></div>")
      html.add("        <div class=\"info-pill\"><span class=\"pill-label\">Wi-Fi</span> <strong id=\"devInfoWifi\">--</strong></div>")
      html.add("        <div class=\"info-pill\"><span class=\"pill-label\">IP</span> <code id=\"devInfoIp\">--</code></div>")
      html.add("        <div class=\"info-pill\"><span class=\"pill-label\">MAC</span> <code id=\"devInfoMac\">--</code></div>")
      html.add("      </div>")
    html.add("      <div class=\"term-console-wrap\">")
    html.add("        <pre id=\"termOutput\" class=\"terminal-body collapsed\"><span class=\"term-empty-hint\">Click [Connect Logs] to stream live WebSerial boot and runtime logs at 115200 baud...</span></pre>")
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
      to["nativeUsb"] = %t.nativeUsb
      targetObj[t.name] = to
    html.add("    const TARGET_MAP = " & $targetObj & ";")
    html.add("    const targetSelect = document.getElementById('field_hardware_target');")
    html.add("    const targetDesc = document.getElementById('target_desc');")
    html.add("    if (targetSelect) {")
    html.add("      targetSelect.addEventListener('change', () => {")
    html.add("        const info = TARGET_MAP[targetSelect.value];")
    html.add("        if (info) {")
    html.add("          if (targetDesc && info.desc) targetDesc.textContent = info.desc;")
    html.add("          document.querySelectorAll('.native-usb-warning').forEach(el => {")
    html.add("            el.style.display = info.nativeUsb ? '' : 'none';")
    html.add("          });")
    html.add("          updateDynamicManifest();")
    html.add("          saveInstallerState();")
    html.add("        }")
    html.add("      });")
    html.add("    }")

  html.add("    const installBtn = document.getElementById('installBtn');")
  html.add("    const uploadedParts = new Map();")
  html.add("    const cachedFileStore = {};")
  html.add("    const FORM_STORAGE_KEY = 'esphome_installer_state_v1';")
  html.add("    let isRestoringState = false;")
  html.add("    let activeManifestUrl = null;")
  html.add("    let activeAudioCtx = null;")
  html.add("    let activeAudioTimer = null;")
  html.add("    let activeAudioElement = null;")
  html.add("    const PRESET_MODELS = {};")
  html.add("    const PRESET_AUDIO = {};")
  html.add("    let WAKE_OFFSETS = [];")
  html.add("")
  html.add("    function uint8ToBase64(u8) {")
  html.add("      let binary = '';")
  html.add("      const len = u8.byteLength;")
  html.add("      for (let i = 0; i < len; i++) binary += String.fromCharCode(u8[i]);")
  html.add("      return window.btoa(binary);")
  html.add("    }")
  html.add("")
  html.add("    function base64ToUint8(b64) {")
  html.add("      const binary = window.atob(b64);")
  html.add("      const len = binary.length;")
  html.add("      const u8 = new Uint8Array(len);")
  html.add("      for (let i = 0; i < len; i++) u8[i] = binary.charCodeAt(i);")
  html.add("      return u8;")
  html.add("    }")
  html.add("")
  html.add("    function packWakeModelHeader(rawModelBuffer, phrase, cutoff) {")
  html.add("      const HEADER_SIZE = 64;")
  html.add("      const headerBuf = new ArrayBuffer(HEADER_SIZE);")
  html.add("      const view = new DataView(headerBuf);")
  html.add("      const u8Header = new Uint8Array(headerBuf);")
  html.add("      view.setUint32(0, 0x57414B45, true);")
  html.add("      view.setUint16(4, 1, true);")
  html.add("      view.setUint16(6, 0, true);")
  html.add("      view.setUint32(8, rawModelBuffer.byteLength, true);")
  html.add("      const cutoffVal = parseFloat(cutoff);")
  html.add("      const quantizedCutoff = isNaN(cutoffVal) ? 102 : Math.max(1, Math.min(255, Math.round(cutoffVal * 255)));")
  html.add("      view.setUint8(12, quantizedCutoff);")
  html.add("      view.setUint8(13, 5);")
  html.add("      view.setUint16(14, 40, true);")
  html.add("      const cleanPhrase = (phrase || 'Custom Wake Word').trim().slice(0, 31);")
  html.add("      for (let i = 0; i < cleanPhrase.length; i++) {")
  html.add("        u8Header[16 + i] = cleanPhrase.charCodeAt(i);")
  html.add("      }")
  html.add("      u8Header[16 + cleanPhrase.length] = 0;")
  html.add("      const combined = new Uint8Array(HEADER_SIZE + rawModelBuffer.byteLength);")
  html.add("      combined.set(u8Header, 0);")
  html.add("      combined.set(new Uint8Array(rawModelBuffer), HEADER_SIZE);")
  html.add("      return combined;")
  html.add("    }")
  html.add("")
  html.add("    async function processCustomAudio(arrayBuffer, targetSampleRate) {")
  html.add("      targetSampleRate = targetSampleRate || 16000;")
  html.add("      const AudioCtxClass = window.AudioContext || window.webkitAudioContext;")
  html.add("      if (!AudioCtxClass) {")
  html.add("        throw new Error('Web Audio API is not supported in this browser');")
  html.add("      }")
  html.add("      const tempCtx = new AudioCtxClass();")
  html.add("      let decodedBuffer;")
  html.add("      try {")
  html.add("        decodedBuffer = await tempCtx.decodeAudioData(arrayBuffer.slice(0));")
  html.add("      } finally {")
  html.add("        if (tempCtx.state !== 'closed' && typeof tempCtx.close === 'function') {")
  html.add("          try { await tempCtx.close(); } catch (_) {}")
  html.add("        }")
  html.add("      }")
  html.add("      const numTargetSamples = Math.max(1, Math.round(decodedBuffer.duration * targetSampleRate));")
  html.add("      const OfflineCtxClass = window.OfflineAudioContext || window.webkitOfflineAudioContext;")
  html.add("      if (!OfflineCtxClass) {")
  html.add("        throw new Error('OfflineAudioContext is not supported in this browser');")
  html.add("      }")
  html.add("      const offlineCtx = new OfflineCtxClass(1, numTargetSamples, targetSampleRate);")
  html.add("      const source = offlineCtx.createBufferSource();")
  html.add("      source.buffer = decodedBuffer;")
  html.add("      source.connect(offlineCtx.destination);")
  html.add("      source.start(0);")
  html.add("      const renderedBuffer = await offlineCtx.startRendering();")
  html.add("      const channelData = renderedBuffer.getChannelData(0);")
  html.add("      const targetPeak = Math.pow(10, -1.0 / 20);")
  html.add("      let currentPeak = 0;")
  html.add("      for (let i = 0; i < channelData.length; i++) {")
  html.add("        const absVal = Math.abs(channelData[i]);")
  html.add("        if (absVal > currentPeak) currentPeak = absVal;")
  html.add("      }")
  html.add("      const normFactor = currentPeak > 0.00001 ? (targetPeak / currentPeak) : 1.0;")
  html.add("      const numSamples = channelData.length;")
  html.add("      const pcmBytes = numSamples * 2;")
  html.add("      const wavBuffer = new ArrayBuffer(44 + pcmBytes);")
  html.add("      const view = new DataView(wavBuffer);")
  html.add("      view.setUint8(0, 0x52); view.setUint8(1, 0x49); view.setUint8(2, 0x46); view.setUint8(3, 0x46);")
  html.add("      view.setUint32(4, 36 + pcmBytes, true);")
  html.add("      view.setUint8(8, 0x57); view.setUint8(9, 0x41); view.setUint8(10, 0x56); view.setUint8(11, 0x45);")
  html.add("      view.setUint8(12, 0x66); view.setUint8(13, 0x6D); view.setUint8(14, 0x74); view.setUint8(15, 0x20);")
  html.add("      view.setUint32(16, 16, true);")
  html.add("      view.setUint16(20, 1, true);")
  html.add("      view.setUint16(22, 1, true);")
  html.add("      view.setUint32(24, targetSampleRate, true);")
  html.add("      view.setUint32(28, targetSampleRate * 2, true);")
  html.add("      view.setUint16(32, 2, true);")
  html.add("      view.setUint16(34, 16, true);")
  html.add("      view.setUint8(36, 0x64); view.setUint8(37, 0x61); view.setUint8(38, 0x74); view.setUint8(39, 0x61);")
  html.add("      view.setUint32(40, pcmBytes, true);")
  html.add("      let byteOffset = 44;")
  html.add("      for (let i = 0; i < numSamples; i++) {")
  html.add("        let s = channelData[i] * normFactor;")
  html.add("        if (s > 1.0) s = 1.0;")
  html.add("        else if (s < -1.0) s = -1.0;")
  html.add("        const val16 = s < 0 ? Math.round(s * 32768) : Math.round(s * 32767);")
  html.add("        view.setInt16(byteOffset, Math.max(-32768, Math.min(32767, val16)), true);")
  html.add("        byteOffset += 2;")
  html.add("      }")
  html.add("      return wavBuffer;")
  html.add("    }")
  html.add("")
  html.add("    function packCustomAudioArchive(items) {")
  html.add("      const HEADER_SIZE = 32;")
  html.add("      const ENTRY_SIZE = 48;")
  html.add("      const count = items.length;")
  html.add("      let totalSize = HEADER_SIZE + (count * ENTRY_SIZE);")
  html.add("      const alignedDataOffsets = [];")
  html.add("      for (let i = 0; i < count; i++) {")
  html.add("        totalSize = (totalSize + 3) & ~3;")
  html.add("        alignedDataOffsets.push(totalSize);")
  html.add("        totalSize += items[i].buffer.byteLength;")
  html.add("      }")
  html.add("      const outBuf = new ArrayBuffer(totalSize);")
  html.add("      const view = new DataView(outBuf);")
  html.add("      const u8 = new Uint8Array(outBuf);")
  html.add("      view.setUint32(0, 0x44554143, true);")
  html.add("      view.setUint16(4, 1, true);")
  html.add("      view.setUint16(6, count, true);")
  html.add("      let entryOffset = HEADER_SIZE;")
  html.add("      for (let i = 0; i < count; i++) {")
  html.add("        const item = items[i];")
  html.add("        const dataOffset = alignedDataOffsets[i];")
  html.add("        const cleanName = (item.name || ('Sound ' + (i + 1))).trim().slice(0, 31);")
  html.add("        for (let c = 0; c < cleanName.length; c++) {")
  html.add("          u8[entryOffset + c] = cleanName.charCodeAt(c);")
  html.add("        }")
  html.add("        u8[entryOffset + cleanName.length] = 0;")
  html.add("        view.setUint32(entryOffset + 32, dataOffset, true);")
  html.add("        view.setUint32(entryOffset + 36, item.buffer.byteLength, true);")
  html.add("        u8.set(new Uint8Array(item.buffer), dataOffset);")
  html.add("        entryOffset += ENTRY_SIZE;")
  html.add("      }")
  html.add("      return outBuf;")
  html.add("    }")
  html.add("")
  html.add("    function getSavedInstallerState() {")
  html.add("      try {")
  html.add("        return JSON.parse(localStorage.getItem(FORM_STORAGE_KEY) || '{}');")
  html.add("      } catch (e) {")
  html.add("        return {};")
  html.add("      }")
  html.add("    }")
  html.add("")
  html.add("    function saveInstallerState() {")
  html.add("      if (isRestoringState) return;")
  html.add("      try {")
  html.add("        const state = {")
  html.add("          target: '',")
  html.add("          fields: {},")
  html.add("          wakeSlots: [],")
  html.add("          files: {}")
  html.add("        };")
  html.add("        const targetSelect = document.getElementById('field_hardware_target');")
  html.add("        if (targetSelect) state.target = targetSelect.value;")
  html.add("        document.querySelectorAll('select, input:not([type=file]):not([type=button]):not([type=submit]), textarea').forEach(el => {")
  html.add("          if (!el.id || el.id === 'field_hardware_target' || el.id.startsWith('slot_select_') || el.classList.contains('select-cached-model')) return;")
  html.add("          if (el.type === 'checkbox') state.fields[el.id] = el.checked;")
  html.add("          else state.fields[el.id] = el.value;")
  html.add("        });")
  html.add("        const slotCards = document.querySelectorAll('.wake-slot-card');")
  html.add("        slotCards.forEach((card, idx) => {")
  html.add("          const num = card.dataset.slot || (idx + 1);")
  html.add("          const sel = card.querySelector('.slot-model-select');")
  html.add("          const cachedSel = card.querySelector('.select-cached-model');")
  html.add("          state.wakeSlots.push({")
  html.add("            slot: num,")
  html.add("            model: sel ? sel.value : '',")
  html.add("            cachedId: cachedSel ? cachedSel.value : ''")
  html.add("          });")
  html.add("        });")
  html.add("        let totalFileSize = 0;")
  html.add("        for (const [key, f] of Object.entries(cachedFileStore)) {")
  html.add("          if (f && f.b64) {")
  html.add("            totalFileSize += f.b64.length;")
  html.add("            if (totalFileSize < 2500000) {")
  html.add("              state.files[key] = f;")
  html.add("            } else {")
  html.add("              console.warn('Skipping caching file ' + key + ' to keep localStorage under quota limits');")
  html.add("            }")
  html.add("          }")
  html.add("        }")
  html.add("        localStorage.setItem(FORM_STORAGE_KEY, JSON.stringify(state));")
  html.add("      } catch (e) {")
  html.add("        console.warn('Could not save installer state to localStorage:', e);")
  html.add("      }")
  html.add("    }")
  html.add("")
  html.add("    function restoreCachedFiles(filesObj) {")
  html.add("      if (!filesObj || typeof filesObj !== 'object') return;")
  html.add("      for (const [key, f] of Object.entries(filesObj)) {")
  html.add("        if (!f || !f.b64) continue;")
  html.add("        try {")
  html.add("          cachedFileStore[key] = f;")
  html.add("          const bytes = base64ToUint8(f.b64);")
  html.add("          const blob = new Blob([bytes], { type: f.type || 'application/octet-stream' });")
  html.add("          const blobUrl = URL.createObjectURL(blob);")
  html.add("          uploadedParts.set(key, { url: blobUrl, offset: f.offset, name: f.name, size: f.size });")
  html.add("          const fileStatus = document.getElementById('status_' + key);")
  html.add("          if (fileStatus) {")
  html.add("            const isWav = (f.name && f.name.toLowerCase().endsWith('.wav')) || f.type === 'audio/wav';")
  html.add("            let playBtnHtml = '';")
  html.add("            if (isWav) playBtnHtml = ' <button type=\"button\" class=\"preview-btn btn-play-uploaded\" style=\"margin-left: 8px; padding: 2px 8px; font-size: 0.72rem;\">' + ICONS.play + ' <span>Preview</span></button>';")
  html.add("            const audioBadge = isWav ? ' <span style=\"display: inline-block; background: #0c4a6e; color: #38bdf8; border: 1px solid #0284c7; padding: 1px 6px; border-radius: 4px; font-size: 0.7rem; font-weight: 500; margin-left: 6px;\">16kHz PCM &bull; Compressed &bull; Normalized</span>' : '';")
  html.add("            fileStatus.style.display = 'block';")
  html.add("            fileStatus.innerHTML = ICONS.check + ' <span>Saved file restored: ' + f.name + ' (' + Math.round(f.size / 1024) + ' KB at 0x' + f.offset.toString(16).toUpperCase() + ')' + audioBadge + '</span>' + playBtnHtml + ' <button type=\"button\" class=\"btn-clear-restored-file\" data-file-key=\"' + key + '\" style=\"margin-left: 8px; background: transparent; border: 1px solid #64748b; color: #94a3b8; border-radius: 4px; padding: 2px 6px; font-size: 0.72rem; cursor: pointer;\">Remove</button>';")
  html.add("            const playBtn = fileStatus.querySelector('.btn-play-uploaded');")
  html.add("            if (playBtn) {")
  html.add("              playBtn.addEventListener('click', () => {")
  html.add("                if (playBtn.classList.contains('playing')) { stopAudioPreview(); return; }")
  html.add("                stopAudioPreview();")
  html.add("                playBtn.classList.add('playing');")
  html.add("                playBtn.innerHTML = ICONS.stop + ' <span>Stop</span>';")
  html.add("                const audio = new Audio(blobUrl);")
  html.add("                activeAudioElement = audio;")
  html.add("                audio.onended = () => stopAudioPreview();")
  html.add("                audio.play().catch(() => stopAudioPreview());")
  html.add("              });")
  html.add("            }")
  html.add("            const rmBtn = fileStatus.querySelector('.btn-clear-restored-file');")
  html.add("            if (rmBtn) {")
  html.add("              rmBtn.addEventListener('click', () => {")
  html.add("                delete cachedFileStore[key];")
  html.add("                uploadedParts.delete(key);")
  html.add("                fileStatus.style.display = 'none';")
  html.add("                const inp = document.getElementById('field_' + key);")
  html.add("                if (inp) inp.value = '';")
  html.add("                updateDynamicManifest();")
  html.add("                checkInstallReadiness();")
  html.add("                saveInstallerState();")
  html.add("              });")
  html.add("            }")
  html.add("          }")
  html.add("        } catch (err) {")
  html.add("          console.warn('Error restoring cached file ' + key + ':', err);")
  html.add("        }")
  html.add("      }")
  html.add("    }")
  html.add("")
  html.add("    function restoreInstallerState() {")
  html.add("      const state = getSavedInstallerState();")
  html.add("      if (!state || Object.keys(state).length === 0) return;")
  html.add("      isRestoringState = true;")
  html.add("      try {")
  html.add("        if (state.files) {")
  html.add("          restoreCachedFiles(state.files);")
  html.add("        }")
  html.add("        const targetSelect = document.getElementById('field_hardware_target');")
  html.add("        if (targetSelect && state.target && typeof TARGET_MAP !== 'undefined' && TARGET_MAP[state.target]) {")
  html.add("          targetSelect.value = state.target;")
  html.add("          const info = TARGET_MAP[state.target];")
  html.add("          if (info) {")
  html.add("            const targetDesc = document.getElementById('target_desc');")
  html.add("            if (targetDesc && info.desc) targetDesc.textContent = info.desc;")
  html.add("            document.querySelectorAll('.native-usb-warning').forEach(el => {")
  html.add("              el.style.display = info.nativeUsb ? '' : 'none';")
  html.add("            });")
  html.add("          }")
  html.add("        }")
  html.add("        if (state.fields) {")
  html.add("          for (const [id, val] of Object.entries(state.fields)) {")
  html.add("            const el = document.getElementById(id);")
  html.add("            if (el && el.type !== 'file') {")
  html.add("              if (el.type === 'checkbox') el.checked = !!val;")
  html.add("              else el.value = val;")
  html.add("            }")
  html.add("          }")
  html.add("        }")
  html.add("      } finally {")
  html.add("        isRestoringState = false;")
  html.add("      }")
  html.add("    }")
  html.add("")
  html.add("    function stopAudioPreview() {")
  html.add("      if (activeAudioTimer) { clearInterval(activeAudioTimer); activeAudioTimer = null; }")
  html.add("      if (activeAudioCtx) { try { activeAudioCtx.close(); } catch(e) {} activeAudioCtx = null; }")
  html.add("      if (activeAudioElement) { activeAudioElement.pause(); activeAudioElement = null; }")
  html.add("      document.querySelectorAll('.preview-btn').forEach(btn => {")
  html.add("        btn.classList.remove('playing');")
  html.add("        if (btn.classList.contains('btn-play-uploaded')) {")
  html.add("          btn.innerHTML = ICONS.play + ' <span>Preview</span>';")
  html.add("        } else {")
  html.add("          btn.innerHTML = ICONS.play + ' <span>Preview Sound</span>';")
  html.add("        }")
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
  html.add("        let matchedPart = null;")
  html.add("        const isChime = styleName.toLowerCase().includes('chime') || (btn && btn.id && btn.id.includes('chime'));")
  html.add("        for (const [key, part] of uploadedParts.entries()) {")
  html.add("          if (!part.url) continue;")
  html.add("          if (isChime && key.includes('chime')) { matchedPart = part; break; }")
  html.add("          else if (!isChime && (key.includes('sound') || key.includes('audio')) && !key.includes('chime')) { matchedPart = part; break; }")
  html.add("        }")
  html.add("        if (!matchedPart) {")
  html.add("          for (const [key, part] of uploadedParts.entries()) {")
  html.add("            if (part.url && (key.includes('sound') || key.includes('audio') || key.includes('chime'))) {")
  html.add("              matchedPart = part;")
  html.add("              break;")
  html.add("            }")
  html.add("          }")
  html.add("        }")
  html.add("        if (matchedPart) {")
  html.add("          const audio = new Audio(matchedPart.url);")
  html.add("          activeAudioElement = audio;")
  html.add("          audio.onended = () => stopAudioPreview();")
  html.add("          audio.play().catch(() => stopAudioPreview());")
  html.add("          return;")
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
  html.add("      for (const [name, part] of uploadedParts.entries()) {")
  html.add("        if (name.startsWith('wake_slot_')) {")
  html.add("          const slotIdx = name.replace('wake_slot_', '');")
  html.add("          const card = document.getElementById('wake_slot_card_' + slotIdx);")
  html.add("          if (!card) continue;")
  html.add("          const modelSel = card.querySelector('.slot-model-select');")
  html.add("          if (modelSel && modelSel.value !== 'Custom Wake Word') continue;")
  html.add("        }")
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
  html.add("      if (canInstall) {")
  html.add("        for (const group of document.querySelectorAll('[data-depends-on]')) {")
  html.add("          const parentName = group.dataset.dependsOn;")
  html.add("          const expectedVal = group.dataset.dependsVal;")
  html.add("          const parentEl = document.getElementById('field_' + parentName);")
  html.add("          if (parentEl && parentEl.value === expectedVal) {")
  html.add("            const fileInp = group.querySelector('input[type=\"file\"]');")
  html.add("            if (fileInp) {")
  html.add("              const fieldName = fileInp.id.replace('field_', '');")
  html.add("              if (!uploadedParts.has(fieldName)) {")
  html.add("                canInstall = false;")
  html.add("                const label = group.querySelector('label');")
  html.add("                reason = 'Please select or upload a file for ' + (label ? label.textContent : fieldName) + ' before installing.';")
  html.add("                break;")
  html.add("              }")
  html.add("            }")
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
  html.add("    restoreInstallerState();")
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
      html.add("      function createSlotCard(slotIdx, initialData) {")
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
      html.add("        if (initialData && initialData.model) {")
      html.add("          modelSelect.value = initialData.model;")
      html.add("          if (initialData.model === 'Custom Wake Word') {")
      html.add("            customBox.style.display = 'block';")
      html.add("            card.classList.add('slot-highlight');")
      html.add("            const cachedSlotFile = cachedFileStore['wake_slot_' + slotIdx];")
      html.add("            if (cachedSlotFile && cachedSlotFile.b64) {")
      html.add("              const bytes = base64ToUint8(cachedSlotFile.b64);")
      html.add("              const blob = new Blob([bytes], { type: 'application/octet-stream' });")
      html.add("              const blobUrl = URL.createObjectURL(blob);")
      html.add("              uploadedParts.set('wake_slot_' + slotIdx, { url: blobUrl, offset: slotOffset, name: cachedSlotFile.name, size: cachedSlotFile.size });")
      html.add("              fileStatus.style.display = 'block';")
      html.add("              fileStatus.innerHTML = ICONS.check + ' <span>Saved model loaded: ' + cachedSlotFile.name + ' (' + Math.round(cachedSlotFile.size / 1024) + ' KB at ' + hexOffset + ')</span>';")
      html.add("              uploadDownloadBtn.href = blobUrl;")
      html.add("              uploadDownloadBtn.download = cachedSlotFile.name;")
      html.add("              uploadActionsBar.style.display = 'flex';")
      html.add("              if (uploadDefaultHint) uploadDefaultHint.style.display = 'none';")
      html.add("            } else if (initialData.cachedId) {")
      html.add("              const cache = getMwwCache();")
      html.add("              if (cache[initialData.cachedId]) {")
      html.add("                selectCached.value = initialData.cachedId;")
      html.add("                btnCacheLoad.click();")
      html.add("              }")
      html.add("            }")
      html.add("          }")
      html.add("        }")
      html.add("")
      html.add("        modelSelect.addEventListener('change', () => {")
      html.add("          if (modelSelect.value === 'Custom Wake Word') {")
      html.add("            customBox.style.display = 'block';")
      html.add("            card.classList.add('slot-highlight');")
      html.add("          } else {")
      html.add("            customBox.style.display = 'none';")
      html.add("            card.classList.remove('slot-highlight');")
      html.add("            uploadedParts.delete('wake_slot_' + slotIdx);")
      html.add("            delete cachedFileStore['wake_slot_' + slotIdx];")
      html.add("          }")
      html.add("          checkInstallReadiness();")
      html.add("          updateDynamicManifest();")
      html.add("          saveInstallerState();")
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
      html.add("            const fileName = (item.phrase.replace(/[^a-z0-9]/gi, '_') || 'wake_word') + '.tflite';")
      html.add("            uploadedParts.set('wake_slot_' + slotIdx, { url: blobUrl, offset: slotOffset, name: fileName, size: bytes.length });")
      html.add("            cachedFileStore['wake_slot_' + slotIdx] = {")
      html.add("              name: fileName,")
      html.add("              size: bytes.length,")
      html.add("              type: 'application/octet-stream',")
      html.add("              offset: slotOffset,")
      html.add("              b64: item.b64")
      html.add("            };")
      html.add("            fileStatus.style.display = 'block';")
      html.add("            fileStatus.innerHTML = ICONS.check + ' <span>Loaded from cache: \"' + item.phrase + '\" (' + Math.round(bytes.length / 1024) + ' KB at ' + hexOffset + ')</span>';")
      html.add("            uploadDownloadBtn.href = blobUrl;")
      html.add("            uploadDownloadBtn.download = fileName;")
      html.add("            uploadActionsBar.style.display = 'flex';")
      html.add("            if (uploadDefaultHint) uploadDefaultHint.style.display = 'none';")
      html.add("            checkInstallReadiness();")
      html.add("            updateDynamicManifest();")
      html.add("            saveInstallerState();")
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
      html.add("            delete cachedFileStore['wake_slot_' + slotIdx];")
      html.add("            fileStatus.style.display = 'none';")
      html.add("            uploadActionsBar.style.display = 'none';")
      html.add("            if (uploadDefaultHint) uploadDefaultHint.style.display = 'block';")
      html.add("            checkInstallReadiness();")
      html.add("            updateDynamicManifest();")
      html.add("            saveInstallerState();")
      html.add("            return;")
      html.add("          }")
      html.add("          if (file.size > 262144) {")
      html.add("            alert('Model file exceeds 256 KB limit.');")
      html.add("            fileInput.value = '';")
      html.add("            return;")
      html.add("          }")
      html.add("          const blobUrl = URL.createObjectURL(file);")
      html.add("          uploadedParts.set('wake_slot_' + slotIdx, { url: blobUrl, offset: slotOffset, name: file.name, size: file.size });")
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
      html.add("              const b64 = uint8ToBase64(u8);")
      html.add("              const modelName = file.name.replace(/\\.tflite$/i, '').replace(/[-_]/g, ' ');")
      html.add("              saveMwwCache(modelName, u8, { source: 'upload', filename: file.name });")
      html.add("              cachedFileStore['wake_slot_' + slotIdx] = {")
      html.add("                name: file.name,")
      html.add("                size: file.size,")
      html.add("                type: 'application/octet-stream',")
      html.add("                offset: slotOffset,")
      html.add("                b64: b64")
      html.add("              };")
      html.add("              saveInstallerState();")
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
      html.add("          delete cachedFileStore['wake_slot_' + slotIdx];")
      html.add("          card.remove();")
      html.add("          refreshSlots();")
      html.add("          checkInstallReadiness();")
      html.add("          updateDynamicManifest();")
      html.add("          saveInstallerState();")
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
      html.add("          if (current < MAX_SLOTS) { createSlotCard(current + 1); checkInstallReadiness(); saveInstallerState(); }")
      html.add("        });")
      html.add("      }")
      html.add("")
      html.add("      const savedState = getSavedInstallerState();")
      html.add("      const savedSlots = (savedState && Array.isArray(savedState.wakeSlots) && savedState.wakeSlots.length > 0)")
      html.add("        ? savedState.wakeSlots")
      html.add("        : [{ slot: 1, model: PRESETS[0] }];")
      html.add("      savedSlots.forEach((sData, idx) => {")
      html.add("        createSlotCard(idx + 1, sData);")
      html.add("      });")
      html.add("    })();")
      html.add("")

    if (field.kind == ifkSelect or field.kind == ifkAudioShowcase) and field.presetAudios.len > 0:
      var audObj = newJObject()
      let defaultOffset = if field.name.contains("chime"): 0x390000'u32 else: 0x370000'u32
      for item in field.presetAudios:
        var it = newJObject()
        it["preview"] = %item[1]
        it["flash"] = %item[2]
        it["offset"] = %defaultOffset
        audObj[item[0]] = it
      html.add("    Object.assign(PRESET_AUDIO, " & $audObj & ");")

    if field.kind == ifkAudioShowcase and field.optionDetails.len > 0:
      var detailsObj = newJObject()
      for opt in field.optionDetails:
        var o = newJObject()
        o["cadence"] = %opt.cadence
        o["desc"] = %opt.description
        detailsObj[opt.value] = o
      html.add("    const OPTION_DETAILS_" & field.name & " = " & $detailsObj & ";")
      html.add("    const select_" & field.name & " = document.getElementById('field_" & field.name & "');")
      html.add("    const cadence_" & field.name & " = document.getElementById('presetCadence_" & field.name & "');")
      html.add("    const desc_" & field.name & " = document.getElementById('presetDesc_" & field.name & "');")
      html.add("    const btn_" & field.name & " = document.getElementById('previewBtn_" & field.name & "');")
      html.add("    function updateShowcase_" & field.name & "() {")
      html.add("      stopAudioPreview();")
      html.add("      const val = select_" & field.name & ".value;")
      html.add("      const info = OPTION_DETAILS_" & field.name & "[val] || { cadence: '', desc: '' };")
      html.add("      if (cadence_" & field.name & ") cadence_" & field.name & ".textContent = info.cadence;")
      html.add("      if (desc_" & field.name & ") desc_" & field.name & ".textContent = info.desc;")
      html.add("    }")
      html.add("    if (select_" & field.name & ") {")
      html.add("      select_" & field.name & ".addEventListener('change', updateShowcase_" & field.name & ");")
      html.add("      updateShowcase_" & field.name & "();")
      html.add("    }")
      html.add("    if (btn_" & field.name & ") {")
      html.add("      btn_" & field.name & ".addEventListener('click', () => {")
      html.add("        playPresetAudio(select_" & field.name & ".value, btn_" & field.name & ");")
      html.add("      });")
      html.add("    }")

    if field.kind == ifkCustomWakeWord:
      html.add("    const wakeFileInput_" & field.name & " = document.getElementById('field_" & field.name & "');")
      html.add("    const wakePhraseInput_" & field.name & " = document.getElementById('field_" & field.name & "_phrase');")
      html.add("    const wakeCutoffInput_" & field.name & " = document.getElementById('field_" & field.name & "_cutoff');")
      html.add("    const wakeStatus_" & field.name & " = document.getElementById('status_" & field.name & "');")
      html.add("    let wakeModelRawBuffer_" & field.name & " = null;")
      html.add("    let wakeFileName_" & field.name & " = '';")
      html.add("")
      html.add("    function registerCustomWakeWord_" & field.name & "() {")
      html.add("      if (!wakeModelRawBuffer_" & field.name & ") return;")
      html.add("      const phrase = (wakePhraseInput_" & field.name & " ? wakePhraseInput_" & field.name & ".value : '') || 'Custom Wake Word';")
      html.add("      const cutoff = (wakeCutoffInput_" & field.name & " ? wakeCutoffInput_" & field.name & ".value : '0.40');")
      html.add("      const offset = parseInt(wakeFileInput_" & field.name & ".dataset.offset || '" & $field.flashOffset & "', 10);")
      html.add("      const combined = packWakeModelHeader(wakeModelRawBuffer_" & field.name & ", phrase, cutoff);")
      html.add("      const blob = new Blob([combined], { type: 'application/octet-stream' });")
      html.add("      const blobUrl = URL.createObjectURL(blob);")
      html.add("      uploadedParts.set('" & field.name & "', { url: blobUrl, offset: offset, name: wakeFileName_" & field.name & ", size: combined.byteLength });")
      html.add("      if (wakeStatus_" & field.name & ") {")
      html.add("        wakeStatus_" & field.name & ".style.display = 'block';")
      html.add("        wakeStatus_" & field.name & ".innerHTML = ICONS.check + ' <span>Ready to flash: ' + wakeFileName_" & field.name & " + ' with phrase &ldquo;' + phrase + '&rdquo; (' + Math.round(combined.byteLength / 1024) + ' KB at dedicated partition 0x' + offset.toString(16).toUpperCase() + ')</span> <button type=\"button\" class=\"btn-clear-file\" style=\"margin-left: 8px; background: transparent; border: 1px solid #64748b; color: #94a3b8; border-radius: 4px; padding: 2px 6px; font-size: 0.72rem; cursor: pointer;\">Remove</button>';")
      html.add("        const clrBtn = wakeStatus_" & field.name & ".querySelector('.btn-clear-file');")
      html.add("        if (clrBtn) {")
      html.add("          clrBtn.addEventListener('click', () => {")
      html.add("            wakeFileInput_" & field.name & ".value = '';")
      html.add("            wakeModelRawBuffer_" & field.name & " = null;")
      html.add("            wakeFileName_" & field.name & " = '';")
      html.add("            uploadedParts.delete('" & field.name & "');")
      html.add("            delete cachedFileStore['" & field.name & "'];")
      html.add("            wakeStatus_" & field.name & ".style.display = 'none';")
      html.add("            updateDynamicManifest();")
      html.add("            checkInstallReadiness();")
      html.add("            saveInstallerState();")
      html.add("          });")
      html.add("        }")
      html.add("      }")
      html.add("      updateDynamicManifest();")
      html.add("      checkInstallReadiness();")
      html.add("      saveInstallerState();")
      html.add("    }")
      html.add("")
      html.add("    if (wakeFileInput_" & field.name & ") {")
      html.add("      wakeFileInput_" & field.name & ".addEventListener('change', (e) => {")
      html.add("        const file = e.target.files[0];")
      html.add("        if (!file) {")
      html.add("          wakeModelRawBuffer_" & field.name & " = null;")
      html.add("          wakeFileName_" & field.name & " = '';")
      html.add("          uploadedParts.delete('" & field.name & "');")
      html.add("          delete cachedFileStore['" & field.name & "'];")
      html.add("          updateDynamicManifest();")
      html.add("          checkInstallReadiness();")
      html.add("          saveInstallerState();")
      html.add("          return;")
      html.add("        }")
      html.add("        const maxSizeBytes = parseInt(wakeFileInput_" & field.name & ".dataset.maxsize || '" & $field.maxSize & "', 10);")
      html.add("        if (file.size > maxSizeBytes) {")
      html.add("          alert('Model exceeds maximum allowed size of ' + Math.round(maxSizeBytes / 1024) + ' KB');")
      html.add("          wakeFileInput_" & field.name & ".value = '';")
      html.add("          return;")
      html.add("        }")
      html.add("        wakeFileName_" & field.name & " = file.name;")
      html.add("        if (wakePhraseInput_" & field.name & " && (!wakePhraseInput_" & field.name & ".value || wakePhraseInput_" & field.name & ".value.trim() === '')) {")
      html.add("          const rawName = file.name.replace(/\\.[^/.]+$/, '').replace(/[_-]/g, ' ');")
      html.add("          wakePhraseInput_" & field.name & ".value = rawName.replace(/\\b\\w/g, l => l.toUpperCase());")
      html.add("        }")
      html.add("        const reader = new FileReader();")
      html.add("        reader.onload = function(evt) {")
      html.add("          wakeModelRawBuffer_" & field.name & " = evt.target.result;")
      html.add("          registerCustomWakeWord_" & field.name & "();")
      html.add("        };")
      html.add("        reader.readAsArrayBuffer(file);")
      html.add("      });")
      html.add("    }")
      html.add("    if (wakePhraseInput_" & field.name & ") {")
      html.add("      wakePhraseInput_" & field.name & ".addEventListener('input', registerCustomWakeWord_" & field.name & ");")
      html.add("    }")
      html.add("    if (wakeCutoffInput_" & field.name & ") {")
      html.add("      wakeCutoffInput_" & field.name & ".addEventListener('input', registerCustomWakeWord_" & field.name & ");")
      html.add("    }")

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
      html.add("      fileInput_" & field.name & ".addEventListener('change', async (e) => {")
      html.add("        stopAudioPreview();")
      html.add("        const file = e.target.files[0];")
      html.add("        if (!file) {")
      html.add("          uploadedParts.delete('" & field.name & "');")
      html.add("          delete cachedFileStore['" & field.name & "'];")
      html.add("          if (status_" & field.name & ") status_" & field.name & ".style.display = 'none';")
      html.add("          updateDynamicManifest();")
      html.add("          checkInstallReadiness();")
      html.add("          saveInstallerState();")
      html.add("          return;")
      html.add("        }")
      html.add("        const isAudio = (file.type && file.type.startsWith('audio/')) || /\\.(wav|mp3|ogg|flac|m4a|aac|opus|wma)$/i.test(file.name);")
      html.add("        const maxSizeBytes = parseInt(fileInput_" & field.name & ".dataset.maxsize || '" & $field.maxSize & "', 10);")
      html.add("        const offset = parseInt(fileInput_" & field.name & ".dataset.offset || '" & $field.flashOffset & "', 10);")
      html.add("        if (status_" & field.name & ") {")
      html.add("          status_" & field.name & ".style.display = 'block';")
      html.add("          if (isAudio) {")
      html.add("            status_" & field.name & ".innerHTML = '<span class=\"spinner\"></span> Transcoding audio (16kHz mono, dynamic compression, -1.0 dBFS peak)...';")
      html.add("          }")
      html.add("        }")
      html.add("        let finalBuffer = null;")
      html.add("        let finalName = file.name;")
      html.add("        let finalType = file.type || 'application/octet-stream';")
      html.add("        try {")
      html.add("          const rawBuf = await file.arrayBuffer();")
      html.add("          if (isAudio) {")
      html.add("            finalBuffer = await processCustomAudio(rawBuf, 16000);")
      html.add("            finalName = file.name.replace(/\\.[^/.]+$/, '') + '.wav';")
      html.add("            finalType = 'audio/wav';")
      html.add("          } else {")
      html.add("            finalBuffer = rawBuf;")
      html.add("          }")
      html.add("        } catch (err) {")
      html.add("          console.error('File processing error:', err);")
      html.add("          if (status_" & field.name & ") {")
      html.add("            status_" & field.name & ".style.display = 'block';")
      html.add("            status_" & field.name & ".innerHTML = '<span style=\"color: #ef4444;\">Error processing audio file: ' + (err.message || err) + '</span>';")
      html.add("          }")
      html.add("          fileInput_" & field.name & ".value = '';")
      html.add("          uploadedParts.delete('" & field.name & "');")
      html.add("          delete cachedFileStore['" & field.name & "'];")
      html.add("          updateDynamicManifest();")
      html.add("          checkInstallReadiness();")
      html.add("          saveInstallerState();")
      html.add("          return;")
      html.add("        }")
      html.add("        if (finalBuffer.byteLength > maxSizeBytes) {")
      html.add("          alert('File exceeds maximum allowed size of ' + Math.round(maxSizeBytes / 1024) + ' KB (processed size: ' + Math.round(finalBuffer.byteLength / 1024) + ' KB)');")
      html.add("          fileInput_" & field.name & ".value = '';")
      html.add("          if (status_" & field.name & ") status_" & field.name & ".style.display = 'none';")
      html.add("          uploadedParts.delete('" & field.name & "');")
      html.add("          delete cachedFileStore['" & field.name & "'];")
      html.add("          updateDynamicManifest();")
      html.add("          checkInstallReadiness();")
      html.add("          saveInstallerState();")
      html.add("          return;")
      html.add("        }")
      html.add("        const blob = new Blob([finalBuffer], { type: finalType });")
      html.add("        const blobUrl = URL.createObjectURL(blob);")
      html.add("        uploadedParts.set('" & field.name & "', { url: blobUrl, offset: offset, name: finalName, size: finalBuffer.byteLength });")
      html.add("        if (status_" & field.name & ") {")
      html.add("          const isWav = finalName.toLowerCase().endsWith('.wav') || finalType === 'audio/wav';")
      html.add("          let playBtnHtml = '';")
      html.add("          if (isWav) playBtnHtml = ' <button type=\"button\" class=\"preview-btn btn-play-uploaded\" style=\"margin-left: 8px; padding: 2px 8px; font-size: 0.72rem;\">' + ICONS.play + ' <span>Preview</span></button>';")
      html.add("          const audioBadge = isAudio ? ' <span style=\"display: inline-block; background: #0c4a6e; color: #38bdf8; border: 1px solid #0284c7; padding: 1px 6px; border-radius: 4px; font-size: 0.7rem; font-weight: 500; margin-left: 6px;\">16kHz PCM &bull; Compressed &bull; Normalized</span>' : '';")
      html.add("          status_" & field.name & ".style.display = 'block';")
      html.add("          status_" & field.name & ".innerHTML = ICONS.check + ' <span>Ready to flash: ' + finalName + ' (' + Math.round(finalBuffer.byteLength / 1024) + ' KB at safe partition 0x' + offset.toString(16).toUpperCase() + ')' + audioBadge + '</span>' + playBtnHtml + ' <button type=\"button\" class=\"btn-clear-file\" style=\"margin-left: 8px; background: transparent; border: 1px solid #64748b; color: #94a3b8; border-radius: 4px; padding: 2px 6px; font-size: 0.72rem; cursor: pointer;\">Remove</button>';")
      html.add("          const playBtn = status_" & field.name & ".querySelector('.btn-play-uploaded');")
      html.add("          if (playBtn) {")
      html.add("            playBtn.addEventListener('click', () => {")
      html.add("              if (playBtn.classList.contains('playing')) { stopAudioPreview(); return; }")
      html.add("              stopAudioPreview();")
      html.add("              playBtn.classList.add('playing');")
      html.add("              playBtn.innerHTML = ICONS.stop + ' <span>Stop</span>';")
      html.add("              const audio = new Audio(blobUrl);")
      html.add("              activeAudioElement = audio;")
      html.add("              audio.onended = () => stopAudioPreview();")
      html.add("              audio.play().catch(() => stopAudioPreview());")
      html.add("            });")
      html.add("          }")
      html.add("          const clrBtn = status_" & field.name & ".querySelector('.btn-clear-file');")
      html.add("          if (clrBtn) {")
      html.add("            clrBtn.addEventListener('click', () => {")
      html.add("              stopAudioPreview();")
      html.add("              fileInput_" & field.name & ".value = '';")
      html.add("              uploadedParts.delete('" & field.name & "');")
      html.add("              delete cachedFileStore['" & field.name & "'];")
      html.add("              status_" & field.name & ".style.display = 'none';")
      html.add("              updateDynamicManifest();")
      html.add("              checkInstallReadiness();")
      html.add("              saveInstallerState();")
      html.add("            });")
      html.add("          }")
      html.add("        }")
      html.add("        try {")
      html.add("          const u8 = new Uint8Array(finalBuffer);")
      html.add("          cachedFileStore['" & field.name & "'] = {")
      html.add("            name: finalName,")
      html.add("            size: finalBuffer.byteLength,")
      html.add("            type: finalType,")
      html.add("            offset: offset,")
      html.add("            b64: uint8ToBase64(u8)")
      html.add("          };")
      html.add("          saveInstallerState();")
      html.add("        } catch (err) {")
      html.add("          console.warn('Could not cache file:', err);")
      html.add("        }")
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

    if field.kind == ifkCustomWakeWordSlots:
      var offsetsSeq: seq[string] = @[]
      for o in field.slotOffsets: offsetsSeq.add($o)
      let offsetsJs = "[" & offsetsSeq.join(",") & "]"

      var partsSeq: seq[string] = @[]
      for p in field.slotPartitions: partsSeq.add(escapeJson(p))
      let partsJs = "[" & partsSeq.join(",") & "]"

      html.add("    const slotOffsets_" & field.name & " = " & offsetsJs & ";")
      html.add("    const slotPartitions_" & field.name & " = " & partsJs & ";")
      html.add("    const slotBuffers_" & field.name & " = [];")
      html.add("    const slotFileNames_" & field.name & " = [];")
      html.add("    for (let i = 0; i < " & $field.maxSlots & "; i++) { slotBuffers_" & field.name & ".push(null); slotFileNames_" & field.name & ".push(''); }")
      html.add("")
      html.add("    function registerWakeSlot_" & field.name & "(slotIdx) {")
      html.add("      const buf = slotBuffers_" & field.name & "[slotIdx];")
      html.add("      const partKey = '" & field.name & "_slot_' + slotIdx;")
      html.add("      const statusEl = document.getElementById('slotStatus_" & field.name & "_' + slotIdx);")
      html.add("      const fileInp = document.getElementById('slotFile_" & field.name & "_' + slotIdx);")
      html.add("      const phraseInp = document.getElementById('slotPhrase_" & field.name & "_' + slotIdx);")
      html.add("      const cutoffInp = document.getElementById('slotCutoff_" & field.name & "_' + slotIdx);")
      html.add("      if (!buf) {")
      html.add("        uploadedParts.delete(partKey);")
      html.add("        delete cachedFileStore[partKey];")
      html.add("        if (statusEl) statusEl.style.display = 'none';")
      html.add("        updateDynamicManifest();")
      html.add("        checkInstallReadiness();")
      html.add("        saveInstallerState();")
      html.add("        return;")
      html.add("      }")
      html.add("      const phrase = phraseInp ? phraseInp.value.trim() : '';")
      html.add("      if (!phrase) {")
      html.add("        uploadedParts.delete(partKey);")
      html.add("        if (statusEl) {")
      html.add("          statusEl.style.display = 'block';")
      html.add("          statusEl.innerHTML = '<span style=\"color: #f59e0b;\">Model loaded: ' + (slotFileNames_" & field.name & "[slotIdx] || 'model.tflite') + '. Please enter the wake word phrase above (or select companion .json).</span> <button type=\"button\" class=\"btn-clear-slot\" style=\"margin-left: 8px; background: transparent; border: 1px solid #64748b; color: #94a3b8; border-radius: 4px; padding: 2px 6px; font-size: 0.72rem; cursor: pointer;\">Remove</button>';")
      html.add("          const rmBtn = statusEl.querySelector('.btn-clear-slot');")
      html.add("          if (rmBtn) {")
      html.add("            rmBtn.addEventListener('click', () => {")
      html.add("              slotBuffers_" & field.name & "[slotIdx] = null;")
      html.add("              slotFileNames_" & field.name & "[slotIdx] = '';")
      html.add("              if (fileInp) fileInp.value = '';")
      html.add("              registerWakeSlot_" & field.name & "(slotIdx);")
      html.add("            });")
      html.add("          }")
      html.add("        }")
      html.add("        updateDynamicManifest();")
      html.add("        checkInstallReadiness();")
      html.add("        saveInstallerState();")
      html.add("        return;")
      html.add("      }")
      html.add("      const cutoff = (cutoffInp ? cutoffInp.value : '0.40');")
      html.add("      const offset = slotOffsets_" & field.name & "[slotIdx];")
      html.add("      const partName = slotPartitions_" & field.name & "[slotIdx];")
      html.add("      const combined = packWakeModelHeader(buf, phrase, cutoff);")
      html.add("      const blob = new Blob([combined], { type: 'application/octet-stream' });")
      html.add("      const blobUrl = URL.createObjectURL(blob);")
      html.add("      uploadedParts.set(partKey, { url: blobUrl, offset: offset, name: slotFileNames_" & field.name & "[slotIdx] || (partName + '.bin'), size: combined.byteLength });")
      html.add("      if (statusEl) {")
      html.add("        statusEl.style.display = 'block';")
      html.add("        statusEl.innerHTML = ICONS.check + ' <span>Ready to flash: ' + (slotFileNames_" & field.name & "[slotIdx] || 'model.tflite') + ' (&ldquo;' + phrase + '&rdquo;) to ' + partName + ' (0x' + offset.toString(16).toUpperCase() + ')</span> <button type=\"button\" class=\"btn-clear-slot\" style=\"margin-left: 8px; background: transparent; border: 1px solid #64748b; color: #94a3b8; border-radius: 4px; padding: 2px 6px; font-size: 0.72rem; cursor: pointer;\">Remove</button>';")
      html.add("        const rmBtn = statusEl.querySelector('.btn-clear-slot');")
      html.add("        if (rmBtn) {")
      html.add("          rmBtn.addEventListener('click', () => {")
      html.add("            slotBuffers_" & field.name & "[slotIdx] = null;")
      html.add("            slotFileNames_" & field.name & "[slotIdx] = '';")
      html.add("            if (fileInp) fileInp.value = '';")
      html.add("            registerWakeSlot_" & field.name & "(slotIdx);")
      html.add("          });")
      html.add("        }")
      html.add("      }")
      html.add("      updateDynamicManifest();")
      html.add("      checkInstallReadiness();")
      html.add("      saveInstallerState();")
      html.add("    }")
      html.add("")
      for i in 0 ..< field.maxSlots:
        html.add("    const sFile_" & field.name & "_" & $i & " = document.getElementById('slotFile_" & field.name & "_" & $i & "');")
        html.add("    const sPhrase_" & field.name & "_" & $i & " = document.getElementById('slotPhrase_" & field.name & "_" & $i & "');")
        html.add("    const sCutoff_" & field.name & "_" & $i & " = document.getElementById('slotCutoff_" & field.name & "_" & $i & "');")
        html.add("    if (sFile_" & field.name & "_" & $i & ") {")
        html.add("      sFile_" & field.name & "_" & $i & ".addEventListener('change', async (e) => {")
        html.add("        const files = Array.from(e.target.files);")
        html.add("        if (!files.length) {")
        html.add("          slotBuffers_" & field.name & "[" & $i & "] = null;")
        html.add("          slotFileNames_" & field.name & "[" & $i & "] = '';")
        html.add("          registerWakeSlot_" & field.name & "(" & $i & ");")
        html.add("          return;")
        html.add("        }")
        html.add("        const jsonFile = files.find(f => f.name.toLowerCase().endsWith('.json'));")
        html.add("        const tfliteFile = files.find(f => f.name.toLowerCase().endsWith('.tflite') || f.name.toLowerCase().endsWith('.bin'));")
        html.add("        if (jsonFile) {")
        html.add("          try {")
        html.add("            const jsonText = await jsonFile.text();")
        html.add("            const meta = JSON.parse(jsonText);")
        html.add("            if (meta.wake_word && sPhrase_" & field.name & "_" & $i & ") {")
        html.add("              sPhrase_" & field.name & "_" & $i & ".value = meta.wake_word;")
        html.add("            }")
        html.add("            if (meta.micro && meta.micro.probability_cutoff && sCutoff_" & field.name & "_" & $i & ") {")
        html.add("              sCutoff_" & field.name & "_" & $i & ".value = meta.micro.probability_cutoff;")
        html.add("            }")
        html.add("          } catch (err) {")
        html.add("            console.warn('Error parsing wake word json:', err);")
        html.add("          }")
        html.add("        }")
        html.add("        if (tfliteFile) {")
        html.add("          const maxBytes = parseInt(sFile_" & field.name & "_" & $i & ".dataset.maxsize || '" & $field.maxSize & "', 10);")
        html.add("          if (tfliteFile.size > maxBytes) {")
        html.add("            alert('Model exceeds maximum allowed size of ' + Math.round(maxBytes / 1024) + ' KB');")
        html.add("            sFile_" & field.name & "_" & $i & ".value = '';")
        html.add("            return;")
        html.add("          }")
        html.add("          slotFileNames_" & field.name & "[" & $i & "] = tfliteFile.name;")
        html.add("          const rawBuf = await tfliteFile.arrayBuffer();")
        html.add("          slotBuffers_" & field.name & "[" & $i & "] = rawBuf;")
        html.add("          registerWakeSlot_" & field.name & "(" & $i & ");")
        html.add("        } else if (jsonFile && !slotBuffers_" & field.name & "[" & $i & "]) {")
        html.add("          const statusEl = document.getElementById('slotStatus_" & field.name & "_" & $i & "');")
        html.add("          if (statusEl) {")
        html.add("            statusEl.style.display = 'block';")
        html.add("            statusEl.innerHTML = '<span style=\"color: #60a5fa;\">Loaded configuration for &ldquo;' + (sPhrase_" & field.name & "_" & $i & " ? sPhrase_" & field.name & "_" & $i & ".value : 'Custom Wake Word') + '&rdquo;. Please also select the companion .tflite model file.</span>';")
        html.add("          }")
        html.add("          checkInstallReadiness();")
        html.add("        }")
        html.add("      });")
        html.add("    }")
        html.add("    if (sPhrase_" & field.name & "_" & $i & ") sPhrase_" & field.name & "_" & $i & ".addEventListener('input', () => registerWakeSlot_" & field.name & "(" & $i & "));")
        html.add("    if (sCutoff_" & field.name & "_" & $i & ") sCutoff_" & field.name & "_" & $i & ".addEventListener('input', () => registerWakeSlot_" & field.name & "(" & $i & "));")

    if field.kind == ifkMultiAudio:
      html.add("    const multiAudioStore_" & field.name & " = [];")
      html.add("    const addAudioInp_" & field.name & " = document.getElementById('addAudioInput_" & field.name & "');")
      html.add("    const listEl_" & field.name & " = document.getElementById('audioList_" & field.name & "');")
      html.add("    const usageEl_" & field.name & " = document.getElementById('usage_" & field.name & "');")
      html.add("    const errEl_" & field.name & " = document.getElementById('error_" & field.name & "');")
      html.add("    const maxSizeBytes_" & field.name & " = parseInt('" & $field.maxSize & "', 10);")
      html.add("    const offset_" & field.name & " = parseInt('" & $field.flashOffset & "', 10);")
      html.add("")
      html.add("    function renderAudioList_" & field.name & "() {")
      html.add("      if (!listEl_" & field.name & ") return;")
      html.add("      listEl_" & field.name & ".innerHTML = '';")
      html.add("      multiAudioStore_" & field.name & ".forEach((item, idx) => {")
      html.add("        const itemEl = document.createElement('div');")
      html.add("        itemEl.className = 'multi-audio-item';")
      html.add("        itemEl.innerHTML = '<div class=\"multi-audio-info\">' +")
      html.add("          '<input type=\"text\" class=\"audio-name-input\" value=\"' + item.name.replace(/\"/g, '&quot;') + '\" placeholder=\"Sound Name\" maxlength=\"31\">' +")
      html.add("          '<span class=\"audio-badge\">16kHz Mono &bull; Compressed &bull; Normalized</span>' +")
      html.add("          '<span class=\"audio-size-badge\">' + Math.round(item.buffer.byteLength / 1024) + ' KB</span>' +")
      html.add("          '</div><button type=\"button\" class=\"btn-remove-audio\">Remove</button>';")
      html.add("        const nameInp = itemEl.querySelector('.audio-name-input');")
      html.add("        if (nameInp) {")
      html.add("          nameInp.addEventListener('input', () => {")
      html.add("            item.name = nameInp.value.trim() || ('Sound ' + (idx + 1));")
      html.add("            updateMultiArchive_" & field.name & "();")
      html.add("          });")
      html.add("        }")
      html.add("        const rmBtn = itemEl.querySelector('.btn-remove-audio');")
      html.add("        if (rmBtn) {")
      html.add("          rmBtn.addEventListener('click', () => {")
      html.add("            multiAudioStore_" & field.name & ".splice(idx, 1);")
      html.add("            renderAudioList_" & field.name & "();")
      html.add("            updateMultiArchive_" & field.name & "();")
      html.add("          });")
      html.add("        }")
      html.add("        listEl_" & field.name & ".appendChild(itemEl);")
      html.add("      });")
      html.add("    }")
      html.add("")
      html.add("    function updateMultiArchive_" & field.name & "() {")
      html.add("      if (multiAudioStore_" & field.name & ".length === 0) {")
      html.add("        uploadedParts.delete('" & field.name & "');")
      html.add("        if (usageEl_" & field.name & ") usageEl_" & field.name & ".textContent = '0 KB / ' + Math.round(maxSizeBytes_" & field.name & " / 1024) + ' KB used';")
      html.add("        if (errEl_" & field.name & ") errEl_" & field.name & ".style.display = 'none';")
      html.add("        updateDynamicManifest();")
      html.add("        checkInstallReadiness();")
      html.add("        saveInstallerState();")
      html.add("        return;")
      html.add("      }")
      html.add("      const packed = packCustomAudioArchive(multiAudioStore_" & field.name & ");")
      html.add("      const packedKb = Math.round(packed.byteLength / 1024);")
      html.add("      const maxKb = Math.round(maxSizeBytes_" & field.name & " / 1024);")
      html.add("      if (usageEl_" & field.name & ") usageEl_" & field.name & ".textContent = packedKb + ' KB / ' + maxKb + ' KB used (' + multiAudioStore_" & field.name & ".length + ' sound' + (multiAudioStore_" & field.name & ".length > 1 ? 's' : '') + ')';")
      html.add("      if (packed.byteLength > maxSizeBytes_" & field.name & ") {")
      html.add("        if (errEl_" & field.name & ") {")
      html.add("          errEl_" & field.name & ".textContent = 'Total archive size (' + packedKb + ' KB) exceeds partition capacity (' + maxKb + ' KB). Please remove or trim sounds.';")
      html.add("          errEl_" & field.name & ".style.display = 'block';")
      html.add("        }")
      html.add("        uploadedParts.delete('" & field.name & "');")
      html.add("      } else {")
      html.add("        if (errEl_" & field.name & ") errEl_" & field.name & ".style.display = 'none';")
      html.add("        const blob = new Blob([packed], { type: 'application/octet-stream' });")
      html.add("        const blobUrl = URL.createObjectURL(blob);")
      html.add("        uploadedParts.set('" & field.name & "', { url: blobUrl, offset: offset_" & field.name & ", name: '" & field.name & ".bin', size: packed.byteLength });")
      html.add("      }")
      html.add("      updateDynamicManifest();")
      html.add("      checkInstallReadiness();")
      html.add("      saveInstallerState();")
      html.add("    }")
      html.add("")
      html.add("    if (addAudioInp_" & field.name & ") {")
      html.add("      addAudioInp_" & field.name & ".addEventListener('change', async (e) => {")
      html.add("        const files = Array.from(e.target.files);")
      html.add("        if (!files.length) return;")
      html.add("        for (const file of files) {")
      html.add("          try {")
      html.add("            if (usageEl_" & field.name & ") usageEl_" & field.name & ".textContent = 'Processing ' + file.name + '...';")
      html.add("            const rawBuf = await file.arrayBuffer();")
      html.add("            const wavBuf = await processCustomAudio(rawBuf, 16000);")
      html.add("            const baseName = file.name.replace(/\\.[^/.]+$/, '').replace(/[_-]/g, ' ').slice(0, 31);")
      html.add("            const soundName = baseName.replace(/\\b\\w/g, l => l.toUpperCase());")
      html.add("            multiAudioStore_" & field.name & ".push({ name: soundName, buffer: wavBuf });")
      html.add("          } catch (err) {")
      html.add("            console.error('Audio processing error for file ' + file.name + ':', err);")
      html.add("            alert('Failed to process audio file ' + file.name + ': ' + (err.message || err));")
      html.add("          }")
      html.add("        }")
      html.add("        addAudioInp_" & field.name & ".value = '';")
      html.add("        renderAudioList_" & field.name & "();")
      html.add("        updateMultiArchive_" & field.name & "();")
      html.add("      });")
      html.add("    }")

  html.add("    document.querySelectorAll('select, input').forEach(el => {")
  html.add("      el.addEventListener('change', () => { updateFieldDependencies(); checkInstallReadiness(); saveInstallerState(); });")
  html.add("      el.addEventListener('input', () => { updateFieldDependencies(); checkInstallReadiness(); saveInstallerState(); });")
  html.add("    });")
  html.add("    updateFieldDependencies();")
  html.add("    checkInstallReadiness();")
  html.add("    updateDynamicManifest();")
  html.add("    // Dynamically synchronize version with manifest.json / version.json")
  html.add("    async function syncDynamicManifestVersion() {")
  html.add("      try {")
  html.add("        const resp = await fetch('manifest.json?_=' + Date.now());")
  html.add("        if (resp.ok) {")
  html.add("          const remoteManifest = await resp.json();")
  html.add("          if (remoteManifest && remoteManifest.version && remoteManifest.version !== BASE_MANIFEST.version) {")
  html.add("            BASE_MANIFEST.version = remoteManifest.version;")
  html.add("            const fwEl = document.getElementById('devInfoFirmware');")
  html.add("            if (fwEl) fwEl.textContent = (BASE_MANIFEST.name || " & escapeJson(installer.name) & ") + ' v' + remoteManifest.version;")
  html.add("            updateDynamicManifest();")
  html.add("          }")
  html.add("        }")
  html.add("      } catch (e) {")
  html.add("        // Static manifest fallback when offline or running locally without server")
  html.add("      }")
  html.add("    }")
  html.add("    syncDynamicManifestVersion();")
  html.add("")
  if installer.enableSuccessModal:
    html.add("    // Success Modal Logic")
    html.add("    const installBtnEl = document.getElementById('installBtn');")
    html.add("    const successModal = document.getElementById('installSuccessModal');")
    html.add("    const btnCloseModal = document.getElementById('btnCloseSuccessModal');")
    html.add("    if (installBtnEl && successModal) {")
    html.add("      installBtnEl.addEventListener('state-changed', (ev) => {")
    html.add("        const st = (ev && ev.detail && ev.detail.state ? String(ev.detail.state).toLowerCase() : '');")
    html.add("        if ((st.includes('success') || st.includes('done') || st.includes('installed') || st.includes('finish')) && st !== 'installing') {")
    html.add("          successModal.style.display = 'flex';")
    html.add("        }")
    html.add("      });")
    html.add("    }")
    html.add("    if (btnCloseModal && successModal) {")
    html.add("      btnCloseModal.addEventListener('click', () => { successModal.style.display = 'none'; });")
    html.add("      successModal.addEventListener('click', (e) => { if (e.target === successModal) successModal.style.display = 'none'; });")
    html.add("    }")
    html.add("")
  if installer.enableEraseButton:
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
    html.add("        let transport = null;")
    html.add("        let port = null;")
    html.add("        try {")
    html.add("          if (typeof disconnectTerminal === 'function') await disconnectTerminal();")
    html.add("          port = await navigator.serial.requestPort();")
    html.add("          eraseStatus.innerHTML = '<span class=\"spinner\"></span> Loading WebSerial flasher engine...';")
    html.add("          const { ESPLoader, Transport } = await import('https://unpkg.com/esptool-js@0.6.1/bundle.js');")
    html.add("          transport = new Transport(port, true);")
    html.add("          const esploader = new ESPLoader({")
    html.add("            transport: transport,")
    html.add("            baudrate: 115200,")
    html.add("            terminal: { clean() {}, writeLine(d) { console.log('[esptool]', d); }, write(d) { console.log('[esptool]', d); } }")
    html.add("          });")
    html.add("          eraseStatus.innerHTML = '<span class=\"spinner\"></span> Connecting to ESP32 bootloader...';")
    html.add("          await esploader.main();")
    html.add("          eraseStatus.innerHTML = '<span class=\"spinner\"></span> Erasing entire flash memory (wiping NVS, credentials, partitions)...';")
    html.add("          await esploader.eraseFlash();")
    html.add("          eraseStatus.className = 'erase-status success';")
    html.add("          eraseStatus.innerHTML = ICONS.check + ' <strong>Flash erased successfully!</strong> All flash partitions and settings wiped.<br/><small style=\"display:block; margin-top:6px; opacity:0.85;\"><em>Note: If you connect serial logs now, you will see <code>invalid header: 0xffffffff</code> repeating—this is normal when flash memory is empty!</em> If flashing does not start immediately, hold the <strong>BOOT</strong> button, tap <strong>RST</strong>, then release BOOT.</small><br/>You can now click <strong>Install Firmware</strong> above to flash clean firmware.';")
    html.add("        } catch (err) {")
    html.add("          console.error('Erase error:', err);")
    html.add("          eraseStatus.className = 'erase-status error';")
    html.add("          eraseStatus.innerHTML = ICONS.alert + ' <strong>Erase failed:</strong> ' + (err.message || err) + '. If the port was busy, unplug and replug the USB cable and try again.';")
    html.add("        } finally {")
    html.add("          if (transport) {")
    html.add("            try { await transport.disconnect(); } catch (_) {}")
    html.add("          } else if (port) {")
    html.add("            try { await port.close(); } catch (_) {}")
    html.add("          }")
    html.add("        }")
    html.add("      });")
    html.add("    }")
  if installer.enableTerminalConsole:
    html.add("    // Terminal & Connected Device Inspector Logic")
    html.add("    let termPort = null;")
    html.add("    let termReader = null;")
    html.add("    let termKeepReading = false;")
    html.add("    let termReadPromise = null;")
    html.add("    let isDisconnecting = false;")
    html.add("")
    html.add("    async function disconnectTerminal() {")
    html.add("      if (isDisconnecting) return;")
    html.add("      isDisconnecting = true;")
    html.add("      termKeepReading = false;")
    html.add("      if (termReader) {")
    html.add("        try { await termReader.cancel(); } catch (_) {}")
    html.add("      }")
    html.add("      if (termReadPromise) {")
    html.add("        try { await termReadPromise; } catch (_) {}")
    html.add("        termReadPromise = null;")
    html.add("      }")
    html.add("      if (termPort) {")
    html.add("        try { await termPort.close(); } catch (_) {}")
    html.add("        termPort = null;")
    html.add("      }")
    html.add("      const badge = document.getElementById('termStatusBadge');")
    html.add("      if (badge) { badge.className = 'term-badge disconnected'; badge.textContent = 'Disconnected'; }")
    html.add("      const connectBtn = document.getElementById('btnTermConnect');")
    html.add("      if (connectBtn) {")
    html.add("        connectBtn.className = 'term-btn connect';")
    html.add("        connectBtn.innerHTML = '<svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"12\" height=\"12\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6\"></path></svg> <span>Connect Logs</span>';")
    html.add("      }")
    html.add("      isDisconnecting = false;")
    html.add("    }")
    html.add("")
    html.add("    function appendTermLine(text, type) {")
    html.add("      const output = document.getElementById('termOutput');")
    html.add("      if (!output) return;")
    html.add("      const lineSpan = document.createElement('div');")
    html.add("      let cls = '';")
    html.add("      if (type === 'err' || /\\[E\\]|ERROR|ERR|Failed|panic|abort/i.test(text)) cls = 'term-line-err';")
    html.add("      else if (type === 'warn' || /\\[W\\]|WARN|warning/i.test(text)) cls = 'term-line-warn';")
    html.add("      else if (type === 'dbg' || /\\[D\\]|DEBUG/i.test(text)) cls = 'term-line-dbg';")
    html.add("      else if (type === 'info' || /\\[I\\]|INFO|Connected|Ready/i.test(text)) cls = 'term-line-info';")
    html.add("      if (cls) lineSpan.className = cls;")
    html.add("      lineSpan.textContent = text;")
    html.add("      output.appendChild(lineSpan);")
    html.add("      while (output.childNodes.length > 1000) output.removeChild(output.firstChild);")
    html.add("      output.scrollTop = output.scrollHeight;")
    html.add("    }")
    html.add("")
    html.add("    function parseDeviceLogLine(line) {")
    html.add("      const espMatch = line.match(/ESPHome version ([\\w\\.-]+)/i);")
    html.add("      if (espMatch) {")
    html.add("        const el = document.getElementById('devInfoEspHome');")
    html.add("        if (el) el.textContent = 'v' + espMatch[1];")
    html.add("      }")
    html.add("      const wifiMatch = line.match(/Connected to '([^']+)'/i) || line.match(/WiFi connected! SSID: ([\\w\\.-]+)/i);")
    html.add("      if (wifiMatch) {")
    html.add("        const el = document.getElementById('devInfoWifi');")
    html.add("        if (el) el.textContent = wifiMatch[1];")
    html.add("      }")
    html.add("      const ipMatch = line.match(/IP Address: ([\\d\\.]+)/i) || line.match(/Local IP: ([\\d\\.]+)/i) || line.match(/IP: ([\\d\\.]+)/i);")
    html.add("      if (ipMatch) {")
    html.add("        const el = document.getElementById('devInfoIp');")
    html.add("        if (el) el.textContent = ipMatch[1];")
    html.add("      }")
    html.add("      const macMatch = line.match(/MAC: ([0-9A-Fa-f:]{17})/i) || line.match(/MAC address: ([0-9A-Fa-f:]{17})/i);")
    html.add("      if (macMatch) {")
    html.add("        const el = document.getElementById('devInfoMac');")
    html.add("        if (el) el.textContent = macMatch[1];")
    html.add("      }")
    html.add("    }")
    html.add("")
    html.add("    async function readSerialLoop() {")
    html.add("      const decoder = new TextDecoder();")
    html.add("      let buffer = '';")
    html.add("      try {")
    html.add("        while (termKeepReading && termPort && termPort.readable) {")
    html.add("          termReader = termPort.readable.getReader();")
    html.add("          try {")
    html.add("            while (termKeepReading) {")
    html.add("              const { value, done } = await termReader.read();")
    html.add("              if (done) break;")
    html.add("              if (value) {")
    html.add("                buffer += decoder.decode(value, { stream: true });")
    html.add("                const lines = buffer.split(/\\r?\\n/);")
    html.add("                buffer = lines.pop();")
    html.add("                for (const line of lines) {")
    html.add("                  appendTermLine(line);")
    html.add("                  parseDeviceLogLine(line);")
    html.add("                }")
    html.add("              }")
    html.add("            }")
    html.add("          } finally {")
    html.add("            try { termReader.releaseLock(); } catch (_) {}")
    html.add("            termReader = null;")
    html.add("          }")
    html.add("          break;")
    html.add("        }")
    html.add("      } catch (err) {")
    html.add("        if (termKeepReading) appendTermLine('[Stream closed: ' + (err.message || err) + ']', 'warn');")
    html.add("      } finally {")
    html.add("        if (buffer.length > 0) {")
    html.add("          appendTermLine(buffer);")
    html.add("          parseDeviceLogLine(buffer);")
    html.add("          buffer = '';")
    html.add("        }")
    html.add("        if (!isDisconnecting) {")
    html.add("          await disconnectTerminal();")
    html.add("        }")
    html.add("      }")
    html.add("    }")
    html.add("")
    html.add("    async function connectTerminal() {")
    html.add("      if (!navigator.serial) {")
    html.add("        alert('WebSerial is not supported in this browser. Please use Google Chrome or Microsoft Edge on desktop.');")
    html.add("        return;")
    html.add("      }")
    html.add("      await disconnectTerminal();")
    html.add("      const badge = document.getElementById('termStatusBadge');")
    html.add("      const connectBtn = document.getElementById('btnTermConnect');")
    html.add("      const banner = document.getElementById('deviceInfoBanner');")
    html.add("      try {")
    html.add("        if (badge) { badge.className = 'term-badge connecting'; badge.textContent = 'Connecting...'; }")
    html.add("        termPort = await navigator.serial.requestPort();")
    html.add("        if (!termPort.readable) {")
    html.add("          await termPort.open({ baudRate: 115200 });")
    html.add("        }")
    html.add("        termKeepReading = true;")
    html.add("        try {")
    html.add("          await termPort.setSignals({ dataTerminalReady: true, requestToSend: false });")
    html.add("        } catch (_) {}")
    html.add("        if (badge) { badge.className = 'term-badge connected'; badge.textContent = 'Connected (115200)'; }")
    html.add("        if (banner) banner.style.display = 'flex';")
    html.add("        if (connectBtn) {")
    html.add("          connectBtn.className = 'term-btn disconnect';")
    html.add("          connectBtn.innerHTML = '<svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"12\" height=\"12\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"10\"></circle><line x1=\"15\" y1=\"9\" x2=\"9\" y2=\"15\"></line><line x1=\"9\" y1=\"9\" x2=\"15\"></line></svg> <span>Disconnect</span>';")
    html.add("        }")
    html.add("        appendTermLine('--- Connected to Serial Console (115200 baud) ---', 'dbg');")
    html.add("        termReadPromise = readSerialLoop();")
    html.add("      } catch (err) {")
    html.add("        console.error('Terminal connection failed:', err);")
    html.add("        await disconnectTerminal();")
    html.add("        appendTermLine('Connection cancelled or failed: ' + (err.message || err), 'err');")
    html.add("      }")
    html.add("    }")
    html.add("")
    html.add("    const btnTermConnect = document.getElementById('btnTermConnect');")
    html.add("    if (btnTermConnect) {")
    html.add("      btnTermConnect.addEventListener('click', async () => {")
    html.add("        if (termPort) await disconnectTerminal();")
    html.add("        else await connectTerminal();")
    html.add("      });")
    html.add("    }")
    html.add("")
    html.add("    const btnTermReset = document.getElementById('btnTermReset');")
    html.add("    if (btnTermReset) {")
    html.add("      btnTermReset.addEventListener('click', async () => {")
    html.add("        if (!termPort) {")
    html.add("          appendTermLine('Please click [Connect Logs] first to send reset pulse.', 'warn');")
    html.add("          return;")
    html.add("        }")
    html.add("        try {")
    html.add("          appendTermLine('--- Sending hardware reset pulse (RTS/DTR) ---', 'dbg');")
    html.add("          await termPort.setSignals({ dataTerminalReady: false, requestToSend: true });")
    html.add("          await new Promise(r => setTimeout(r, 120));")
    html.add("          await termPort.setSignals({ dataTerminalReady: true, requestToSend: false });")
    html.add("        } catch (e) {")
    html.add("          appendTermLine('Reset signal failed: ' + (e.message || e), 'err');")
    html.add("        }")
    html.add("      });")
    html.add("    }")
    html.add("")
    html.add("    const btnTermClear = document.getElementById('btnTermClear');")
    html.add("    if (btnTermClear) {")
    html.add("      btnTermClear.addEventListener('click', () => {")
    html.add("        const output = document.getElementById('termOutput');")
    html.add("        if (output) output.innerHTML = '';")
    html.add("      });")
    html.add("    }")
    html.add("")
    html.add("    const btnTermToggle = document.getElementById('btnTermToggle');")
    html.add("    if (btnTermToggle) {")
    html.add("      btnTermToggle.addEventListener('click', () => {")
    html.add("        const output = document.getElementById('termOutput');")
    html.add("        if (!output) return;")
    html.add("        if (output.classList.contains('collapsed')) {")
    html.add("          output.classList.remove('collapsed');")
    html.add("          output.classList.add('expanded');")
    html.add("          btnTermToggle.textContent = 'Collapse ▲';")
    html.add("        } else {")
    html.add("          output.classList.remove('expanded');")
    html.add("          output.classList.add('collapsed');")
    html.add("          btnTermToggle.textContent = 'Expand ▼';")
    html.add("        }")
    html.add("      });")
    html.add("    }")
    html.add("")
    html.add("    // Disconnect terminal before any flashing or Improv operations")
    html.add("    const improvBtn = document.querySelector('improv-wifi-serial-launch-button');")
    html.add("    if (improvBtn) improvBtn.addEventListener('click', () => { disconnectTerminal(); }, true);")
    html.add("    const instBtnWrap = document.getElementById('installBtn');")
    html.add("    if (instBtnWrap) instBtnWrap.addEventListener('click', () => { disconnectTerminal(); }, true);")
  html.add("  </script>")
  html.add("")

  if installer.enableSuccessModal:
    let initialNative = if installer.targets.len > 0: installer.targets[0].nativeUsb else: installer.nativeUsb
    let nativeWarningStyle = if initialNative: "" else: " style=\"display: none;\""
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
    html.add("        <p class=\"modal-intro\">Your " & installer.chipFamily & " firmware has been flashed.</p>")
    html.add("        <div class=\"native-usb-warning\"" & nativeWarningStyle & " style=\"background: rgba(234, 179, 8, 0.15); border: 1px solid rgba(234, 179, 8, 0.35); border-radius: 8px; padding: 10px 14px; margin-bottom: 14px; font-size: 13px; line-height: 1.45; color: #fef08a;\">")
    html.add("          <strong>Action Required (ESP32-S3):</strong><br/>")
    html.add("          Because this board uses native USB, it stays in bootloader mode after flashing. <strong>Unplug and re-plug the USB-C cable</strong> (or press the board's <strong>RST</strong> button) right now to start ESPHome before clicking <em>Configure Wi-Fi</em>.")
    html.add("        </div>")
    html.add("        <div class=\"next-steps-list\">")
    html.add("          <div class=\"next-step-item\">")
    html.add("            <span class=\"num\">1</span>")
    html.add("            <div>")
    html.add("              <strong>Connect Wi-Fi:</strong> Once power-cycled, connect your device:")
    if installer.enableImprovWifi:
      html.add("              <div style=\"margin: 6px 0;\">")
      html.add("                <improv-wifi-serial-launch-button>")
      html.add("                  <button slot=\"activate\" class=\"modal-wifi-btn\">")
      html.add("                    <svg class=\"icon\" viewBox=\"0 0 24 24\" width=\"12\" height=\"12\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M5 12.55a11 11 0 0 1 14.08 0\"></path><path d=\"M1.42 9a16 16 0 0 1 21.16 0\"></path><path d=\"M8.53 16.11a6 6 0 0 1 6.95 0\"></path><line x1=\"12\" y1=\"20\" x2=\"12.01\" y2=\"20\"></line></svg>")
      html.add("                    <span>Configure Wi-Fi via USB</span>")
      html.add("                  </button>")
      html.add("                </improv-wifi-serial-launch-button>")
      html.add("              </div>")
    if installer.fallbackApSsid.len > 0:
      html.add("              <div class=\"subtext\"><strong>Or via Hotspot:</strong> Connect your phone or PC to <code>" & installer.fallbackApSsid & "</code> and open <code>http://192.168.4.1</code>.</div>")
    html.add("            </div>")
    html.add("          </div>")
    html.add("          <div class=\"next-step-item\">")
    html.add("            <span class=\"num\">2</span>")
    html.add("            <div>")
    html.add("              <strong>Add in Home Assistant:</strong> Open Home Assistant &rarr; <strong>Settings &rarr; Devices &amp; Services</strong>. Look under <strong>Discovered</strong> for <strong>Voice Satellite</strong> (e.g. <code>Voice Satellite ba2c6c</code>) and click <strong>Configure &rarr; Submit</strong>.")
    html.add("              <div class=\"subtext\" style=\"background: rgba(59, 130, 246, 0.12); border-left: 3px solid #3b82f6; padding: 10px 12px; margin-top: 8px; border-radius: 6px; color: #cbd5e1; line-height: 1.45;\">")
    html.add("                <strong style=\"color: #60a5fa;\">No Encryption Key Needed:</strong> This firmware connects without an encryption key.<br/>")
    html.add("                <div style=\"margin-top: 4px;\"><strong>If prompted for an Encryption Key:</strong> Brand-new boards ship with Seeed's encrypted firmware. If Home Assistant saw the board before it was flashed, it cached that requirement and will reject blank entries with <em>\"not all required fields are filled in\"</em>.</div>")
    html.add("                <div style=\"margin-top: 4px;\"><strong>Quick Fix:</strong> Cancel the prompt, go to <strong>Add Integration &rarr; ESPHome</strong>, and enter your device IP (or <code>esphome-satellite-&lt;mac&gt;.local</code>) and port <code>6053</code> to connect directly!</div>")
    html.add("              </div>")
    html.add("            </div>")
    html.add("          </div>")
    html.add("          <div class=\"next-step-item\">")
    html.add("            <span class=\"num\">3</span>")
    html.add("            <div>")
    html.add("              <strong>Customize Device Settings:</strong> Configure your entity options and runtime presets directly from the device card in Home Assistant.")
    html.add("            </div>")
    html.add("          </div>")
    html.add("        </div>")
    html.add("      </div>")
    html.add("      <div class=\"modal-actions\">")
    html.add("        <a href=\"https://my.home-assistant.io/redirect/config_flow_start?domain=" & installer.homeAssistantDomain & "\" target=\"_blank\" class=\"btn-ha-link\">")
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

proc generateEsphomeSnippet*(
    installer: InstallerDefinition,
    name: string = "",
    friendlyName: string = ""
): string =
  ## Generates a verified ESPHome YAML snippet matching the installer's
  ## hardware quirks, partition table, Improv Wi-Fi, and captive portal setup.
  var lines: seq[string] = @[]
  let devName = if name.len > 0: name else: installer.name
  let fName = if friendlyName.len > 0: friendlyName else: installer.title

  lines.add("# ESPHome configuration generated by nim-esphome installer DSL")
  lines.add("esphome:")
  lines.add("  name: " & devName)
  lines.add("  friendly_name: \"" & fName & "\"")
  lines.add("  name_add_mac_suffix: true")
  lines.add("  project:")
  lines.add("    name: \"" & installer.name & "\"")
  lines.add("    version: \"" & installer.version & "\"")
  lines.add("")
  lines.add("esp32:")
  let defaultBoard = if installer.chipFamily == "ESP32-S3": "esp32-s3-devkitc-1" else: "esp32dev"
  lines.add("  board: " & defaultBoard)
  lines.add("  framework:")
  lines.add("    type: esp-idf")
  if installer.customPartitions.len > 0:
    lines.add("  partitions: partitions.csv")
  lines.add("")
  lines.add("logger:")
  let hasNative = if installer.targets.len > 0: installer.targets[0].nativeUsb else: installer.nativeUsb
  if hasNative:
    lines.add("  hardware_uart: USB_SERIAL_JTAG")
  lines.add("  level: DEBUG")
  lines.add("")
  if installer.enableImprovWifi:
    lines.add("improv_serial:")
    lines.add("")
  if installer.fallbackApSsid.len > 0:
    lines.add("wifi:")
    lines.add("  ap:")
    lines.add("    ssid: \"" & installer.fallbackApSsid & "\"")
    lines.add("    ap_timeout: 90s")
    lines.add("")
    lines.add("captive_portal:")
    lines.add("")
  lines.add("api:")
  lines.add("")
  lines.add("ota:")
  lines.add("  - platform: esphome")
  lines.add("")

  result = lines.join("\n")

template esphomeInstaller*(installerName: string, body: untyped): untyped =
  ## Declarative builder template for an ESP-Web-Tools web installer.
  block:
    var installer {.inject.} = newInstallerDefinition(installerName)
    body
    installer

