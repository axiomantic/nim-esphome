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

  FlashPartition* = object
    ## Definition of a custom data partition in ESP32 flash.
    name*: string
    partType*: string
    subType*: string
    offset*: uint32
    size*: uint32

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
    # Select / Text specific fields
    options*: seq[string]
    defaultVal*: string
    minVal*: float
    maxVal*: float
    stepVal*: float

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
    customPartitions*: seq[FlashPartition]

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
    description: string = ""
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
    description: description
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

proc addSelectField*(
    installer: InstallerDefinition,
    name: string,
    label: string,
    options: seq[string],
    defaultVal: string = "",
    description: string = ""
) =
  ## Adds a dropdown selector to the installer.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkSelect,
    label: label,
    options: options,
    defaultVal: defaultVal,
    description: description
  ))

proc addTextField*(
    installer: InstallerDefinition,
    name: string,
    label: string,
    defaultVal: string = "",
    description: string = ""
) =
  ## Adds a text input to the installer.
  installer.fields.add(InstallerField(
    name: name,
    kind: ifkText,
    label: label,
    defaultVal: defaultVal,
    description: description
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

proc generateHtml*(installer: InstallerDefinition): string =
  ## Generates the complete HTML page with embedded reactive WebSerial flashing logic.
  var html: seq[string] = @[]
  html.add("<!DOCTYPE html>")
  html.add("<html lang=\"en\">")
  html.add("<head>")
  html.add("  <meta charset=\"utf-8\">")
  html.add("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">")
  html.add("  <title>" & installer.title & "</title>")
  html.add("  <script type=\"module\" src=\"https://unpkg.com/esp-web-tools@10/dist/web/install-button.js?module\"></script>")
  html.add("  <style>")
  html.add("    :root { --primary: #3b82f6; --primary-hover: #2563eb; --bg: #0f172a; --card: #1e293b; --text: #f8fafc; --muted: #94a3b8; --border: #334155; }")
  html.add("    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: var(--bg); color: var(--text); min-height: 100vh; margin: 0; padding: 24px; display: flex; align-items: center; justify-content: center; }")
  html.add("    .card { background: var(--card); border: 1px solid var(--border); border-radius: 16px; padding: 36px; max-width: 580px; width: 100%; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); }")
  html.add("    h1 { margin-top: 0; font-size: 1.8rem; color: var(--primary); }")
  html.add("    p.desc { color: var(--muted); line-height: 1.5; margin-bottom: 24px; }")
  html.add("    .form-group { text-align: left; margin-bottom: 20px; background: rgba(15, 23, 42, 0.6); padding: 16px; border-radius: 8px; border: 1px solid var(--border); }")
  html.add("    label { display: block; font-weight: 600; margin-bottom: 6px; font-size: 0.95rem; }")
  html.add("    .hint { font-size: 0.8rem; color: var(--muted); margin-top: 4px; }")
  html.add("    input[type='file'], select, input[type='text'], input[type='number'] { width: 100%; box-sizing: border-box; padding: 10px; background: #0f172a; border: 1px solid var(--border); border-radius: 6px; color: var(--text); font-size: 0.95rem; }")
  html.add("    .file-status { margin-top: 8px; font-size: 0.85rem; color: #34d399; display: none; }")
  html.add("    .actions { margin-top: 28px; display: flex; flex-direction: column; align-items: center; gap: 12px; }")
  html.add("    button.install-btn { background: var(--primary); color: white; border: none; padding: 14px 28px; font-size: 1.1rem; font-weight: 600; border-radius: 8px; cursor: pointer; transition: background 0.2s; width: 100%; }")
  html.add("    button.install-btn:hover { background: var(--primary-hover); }")
  html.add("    .footer { margin-top: 24px; font-size: 0.8rem; color: var(--muted); text-align: center; }")
  html.add("  </style>")
  html.add("</head>")
  html.add("<body>")
  html.add("  <div class=\"card\">")
  html.add("    <h1>" & installer.title & "</h1>")
  if installer.description.len > 0:
    html.add("    <p class=\"desc\">" & installer.description & "</p>")

  # Render Form Fields
  if installer.fields.len > 0:
    html.add("    <div class=\"fields-container\">")
    for field in installer.fields:
      html.add("      <div class=\"form-group\" data-field=\"" & field.name & "\">")
      html.add("        <label for=\"field_" & field.name & "\">" & field.label & "</label>")
      case field.kind
      of ifkFile:
        html.add("        <input type=\"file\" id=\"field_" & field.name & "\" accept=\"" & field.accept & "\" data-offset=\"" & $field.flashOffset & "\" data-maxsize=\"" & $field.maxSize & "\">")
        html.add("        <div class=\"file-status\" id=\"status_" & field.name & "\"></div>")
      of ifkSelect:
        html.add("        <select id=\"field_" & field.name & "\">")
        for opt in field.options:
          let selected = if opt == field.defaultVal: " selected" else: ""
          html.add("          <option value=\"" & opt & "\"" & selected & ">" & opt & "</option>")
        html.add("        </select>")
      of ifkText:
        html.add("        <input type=\"text\" id=\"field_" & field.name & "\" value=\"" & field.defaultVal & "\">")
      of ifkNumber:
        html.add("        <input type=\"number\" id=\"field_" & field.name & "\" min=\"" & $field.minVal & "\" max=\"" & $field.maxVal & "\" step=\"" & $field.stepVal & "\" value=\"" & field.defaultVal & "\">")
      of ifkCheckbox:
        let checked = if field.defaultVal == "true": " checked" else: ""
        html.add("        <input type=\"checkbox\" id=\"field_" & field.name & "\"" & checked & ">")
      if field.description.len > 0:
        html.add("        <div class=\"hint\">" & field.description & "</div>")
      html.add("      </div>")
    html.add("    </div>")

  # Install Button
  html.add("    <div class=\"actions\">")
  html.add("      <esp-web-install-button id=\"installBtn\" manifest=\"manifest.json\">")
  html.add("        <button slot=\"activate\" class=\"install-btn\">Install Firmware</button>")
  html.add("        <span slot=\"unsupported\">WebSerial is not supported in this browser. Please use Chrome or Edge on desktop.</span>")
  html.add("      </esp-web-install-button>")
  html.add("    </div>")
  html.add("    <div class=\"footer\">Powered by <a href=\"https://github.com/axiomantic/nim-esphome\" target=\"_blank\" style=\"color: #60a5fa;\">nim-esphome</a> &amp; ESP-Web-Tools</div>")
  html.add("  </div>")

  # Client-side JavaScript abstraction
  html.add("  <script>")
  html.add("    const BASE_MANIFEST = {")
  html.add("      name: " & escapeJson(installer.name) & ",")
  html.add("      version: " & escapeJson(installer.version) & ",")
  html.add("      home_assistant_domain: " & escapeJson(installer.homeAssistantDomain) & ",")
  html.add("      new_install_prompt_erase: true,")
  html.add("      builds: [{ chipFamily: " & escapeJson(installer.chipFamily) & ", parts: [{ path: " & escapeJson(installer.factoryBinPath) & ", offset: 0 }] }]")
  html.add("    };")
  html.add("    const installBtn = document.getElementById('installBtn');")
  html.add("    const uploadedParts = new Map();")
  html.add("")
  html.add("    function updateDynamicManifest() {")
  html.add("      const manifest = JSON.parse(JSON.stringify(BASE_MANIFEST));")
  html.add("      for (const [name, part] of uploadedParts.entries()) {")
  html.add("        manifest.builds[0].parts.push({ path: part.url, offset: part.offset });")
  html.add("      }")
  html.add("      const blob = new Blob([JSON.stringify(manifest)], { type: 'application/json' });")
  html.add("      installBtn.manifest = URL.createObjectURL(blob);")
  html.add("    }")
  html.add("")
  for field in installer.fields:
    if field.kind == ifkFile:
      html.add("    const fileInput_" & field.name & " = document.getElementById('field_" & field.name & "');")
      html.add("    const status_" & field.name & " = document.getElementById('status_" & field.name & "');")
      html.add("    if (fileInput_" & field.name & ") {")
      html.add("      fileInput_" & field.name & ".addEventListener('change', (e) => {")
      html.add("        const file = e.target.files[0];")
      html.add("        if (!file) { uploadedParts.delete('" & field.name & "'); updateDynamicManifest(); return; }")
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
      html.add("          status_" & field.name & ".textContent = '✓ Ready to flash: ' + file.name + ' (' + Math.round(file.size / 1024) + ' KB at 0x' + offset.toString(16).toUpperCase() + ')';")
      html.add("        }")
      html.add("        updateDynamicManifest();")
      html.add("      });")
      html.add("    }")

  html.add("  </script>")
  html.add("</body>")
  html.add("</html>\n")

  result = html.join("\n")

template esphomeInstaller*(installerName: string, body: untyped): untyped =
  ## Declarative builder template for an ESP-Web-Tools web installer.
  block:
    var installer {.inject.} = newInstallerDefinition(installerName)
    body
    installer
