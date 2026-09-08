import std/unittest
import std/[options, json, strutils]
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

  test "haDashboard and haCard DSL for Lovelace surfaces":
    let myCard = haCard(ctEntities, "Voice Satellite Controls", "mdi:microphone"):
      card.addEntity("select.processing_sound", name = "Audio Feedback", icon = "mdi:progress-clock")
      card.addEntity("number.processing_sound_volume", name = "Processing Volume")
      card.addEntity("switch.wake_chime", name = "Wake Chime", icon = "mdi:bell-ring")

    check myCard.title.get() == "Voice Satellite Controls"
    check myCard.cardType == ctEntities
    check myCard.entities.len == 3
    check myCard.entities[0].entityId == "select.processing_sound"

    let jsonCard = myCard.toJson()
    check jsonCard["type"].getStr() == "entities"
    check jsonCard["title"].getStr() == "Voice Satellite Controls"
    check jsonCard["entities"].len == 3

    let yamlCard = myCard.toYaml()
    check "type: entities" in yamlCard
    check "title: \"Voice Satellite Controls\"" in yamlCard
    check "select.processing_sound" in yamlCard

    # Full Dashboard
    let myDash = haDashboard("Smart Home Dashboard"):
      var view1 = newLovelaceView("Satellite", path = "satellite", icon = "mdi:speaker")
      view1.addCard(myCard)
      dash.addView(view1)

    check myDash.views.len == 1
    check myDash.views[0].title == "Satellite"
    check myDash.views[0].cards.len == 1
    let dashYaml = myDash.toYaml()
    check "title: \"Smart Home Dashboard\"" in dashYaml
    check "path: satellite" in dashYaml

  test "haService and haAction DSL with type-safe arguments":
    var tonePlayedFreq = 0
    var toneDuration = 0
    var toneStyle = ""
    var toneSuccess = false

    haService("play_custom_tone"):
      param "frequency", pkInt, min = 100.0, max = 10000.0, defaultVal = "440"
      param "duration_ms", pkInt, min = 10.0, max = 5000.0, defaultVal = "200"
      param "style", pkString, defaultVal = "sine"
      param "active", pkBool, defaultVal = "true"
      onExecute(ctx):
        tonePlayedFreq = ctx.getInt("frequency")
        toneDuration = ctx.getInt("duration_ms")
        toneStyle = ctx.getString("style")
        toneSuccess = ctx.getBool("active")

    let serviceDef = getService("play_custom_tone")
    check serviceDef.isSome
    check serviceDef.get().name == "play_custom_tone"
    check serviceDef.get().params.len == 4

    let esphomeYaml = serviceDef.get().toEsphomeYaml()
    check "- service: play_custom_tone" in esphomeYaml
    check "frequency: int" in esphomeYaml

    # Trigger with explicit params
    let res1 = triggerServiceCall("play_custom_tone", [
      ("frequency", newParamValue(880)),
      ("duration_ms", newParamValue(350)),
      ("style", newParamValue("pulse")),
      ("active", newParamValue(true))
    ])
    check res1 == true
    check tonePlayedFreq == 880
    check toneDuration == 350
    check toneStyle == "pulse"
    check toneSuccess == true

    # Trigger relying on default fallback values
    let res2 = triggerServiceCall("play_custom_tone", [
      ("frequency", newParamValue(1000))
    ])
    check res2 == true
    check tonePlayedFreq == 1000
    check toneDuration == 200 # default
    check toneStyle == "sine" # default

  test "haSchedule and non-blocking background task timers":
    let reg = ScheduleRegistry(tasks: @[])
    var stepCount = 0
    var heartbeatCount = 0
    var timeoutFired = false

    haSchedule(reg):
      every 50.ms:
        stepCount += 1

      every 2.seconds:
        heartbeatCount += 1

      after 5.seconds:
        timeoutFired = true

    check reg.tasks.len == 3

    # Tick 0ms -> initial timestamps recorded
    tickSchedules(0, reg)
    check stepCount == 0
    check heartbeatCount == 0
    check timeoutFired == false

    # Tick 40ms -> nothing triggered yet
    tickSchedules(40, reg)
    check stepCount == 0

    # Tick 50ms -> 50ms periodic task triggers
    tickSchedules(50, reg)
    check stepCount == 1

    # Tick 100ms -> 50ms task triggers second time
    tickSchedules(100, reg)
    check stepCount == 2
    check heartbeatCount == 0

    # Tick 2000ms (2s) -> heartbeat fires
    tickSchedules(2000, reg)
    check stepCount == 3
    check heartbeatCount == 1
    check timeoutFired == false

    # Tick 5000ms (5s) -> one-shot timeout fires
    tickSchedules(5000, reg)
    check timeoutFired == true

    # Tick again -> one-shot task must NOT fire again
    tickSchedules(6000, reg)
    check reg.tasks[2].active == false

    # Test cancel
    reg.tasks[0].cancel()
    check stepCount == 5
    tickSchedules(7000, reg)
    check stepCount == 5
    tickSchedules(7050, reg)
    check stepCount == 5

  test "haSurface composite device DSL":
    let mySurface = haSurface("living_room_satellite"):
      surf.name = "Living Room Voice Satellite"
      surf.model = "ReSpeaker XVF3800"
      surf.manufacturer = "Seeed Studio"
      surf.area = "Living Room"

      surf.addControl(sekSelect, "processing_sound", name = "Processing Sound", icon = "mdi:progress-clock")
      surf.addControl(sekNumber, "volume", name = "Volume", icon = "mdi:volume-high")
      surf.addControl(sekSwitch, "wake_chime", name = "Wake Chime", icon = "mdi:bell-ring")
      surf.addTelemetry(sekSensor, "wifi_signal", name = "Wi-Fi Signal", unit = "dBm")

    check mySurface.id == "living_room_satellite"
    check mySurface.entities.len == 4

    let generatedCard = mySurface.generateDashboardCard()
    check generatedCard.title.get() == "Living Room Voice Satellite"
    check generatedCard.entities.len == 4
    check generatedCard.entities[0].entityId == "select.processing_sound"

    let lovelaceYaml = mySurface.generateLovelaceYaml()
    check "title: \"Living Room Voice Satellite\"" in lovelaceYaml
    check "select.processing_sound" in lovelaceYaml

    let esphomeYaml = mySurface.generateEsphomeYaml()
    check "Generated Hardware Surface: Living Room Voice Satellite" in esphomeYaml
    check "select:" in esphomeYaml
    check "number:" in esphomeYaml
    check "switch:" in esphomeYaml
    check "sensor:" in esphomeYaml
    check "id: processing_sound" in esphomeYaml

  test "esphomeInstaller DSL and dynamic flashing abstractions":
    let myInstaller = esphomeInstaller("voice-satellite"):
      installer.title = "Voice Satellite Web Flasher"
      installer.description = "Flash verified voice satellite firmware with custom sound assets"
      installer.chipFamily = "ESP32-S3"

      installer.addTarget(
        name = "Seeed ReSpeaker XVF3800",
        binPath = "firmware-respeaker.bin",
        chipFamily = "ESP32-S3",
        description = "4-mic array with hardware acoustic echo cancellation"
      )
      installer.addTarget(
        name = "Home Assistant Voice PE",
        binPath = "firmware-voice-pe.bin",
        chipFamily = "ESP32-S3",
        description = "Official Nabu Casa smart speaker satellite"
      )

      installer.addFileField(
        name = "custom_audio",
        label = "Custom Audio (.wav)",
        accept = ".wav,audio/wav",
        partition = "sound_data",
        maxSize = 262144,
        flashOffset = 0x370000'u32,
        description = "Optional loop audio played while thinking",
        dependsOnField = "feedback_style",
        dependsOnValue = "Custom"
      )

      installer.addSelectField(
        name = "feedback_style",
        label = "Audio Feedback Style",
        options = @["Spinner", "Pulse", "Sonar", "Tick", "Silent", "Custom"],
        defaultVal = "Spinner",
        optionDetails = @[
          optionDetail("Spinner", "120ms cadence", "Fast rhythmic progress ticking"),
          optionDetail("Pulse", "250ms cadence", "Subtle undulating heartbeat"),
          optionDetail("Sonar", "800ms cadence", "Nautical high-pitch acoustic ping"),
          optionDetail("Tick", "500ms cadence", "Mechanical clockwork tick"),
          optionDetail("Silent", "No sound", "Completely silent processing"),
          optionDetail("Custom", "User audio", "Loops custom audio from flash partition sound_data")
        ],
        hasAudioPreview = true
      )

      installer.addTextField(
        name = "custom_wake_word",
        label = "Phonetic Wake Word",
        placeholder = "okay see three pee oh",
        calloutHtml = "Spell words phonetically (e.g., <code>ok c3p0</code> &rarr; <strong>okay see three pee oh</strong>).",
        description = "Custom trained wake word phrase",
        dependsOnField = "feedback_style",
        dependsOnValue = "Custom"
      )

    check myInstaller.name == "voice-satellite"
    check myInstaller.fields.len == 3
    check myInstaller.targets.len == 2
    check myInstaller.customPartitions.len == 1

    # 1. Partition Table CSV verification
    let csv4Mb = myInstaller.generatePartitionsCsv(flashSizeMb = 4)
    check "app0,     app,  ota_0,   0x10000,  0x1B0000," in csv4Mb
    check "app1,     app,  ota_1,   0x1C0000, 0x1B0000," in csv4Mb
    check "sound_data, data, 0x82, 0x370000, 0x040000," in csv4Mb

    # 2. Manifest verification
    let manifestStr = myInstaller.generateManifest()
    let manifestJson = parseJson(manifestStr)
    check manifestJson["name"].getStr() == "voice-satellite"
    check manifestJson["builds"].len == 1
    check manifestJson["builds"][0]["chipFamily"].getStr() == "ESP32-S3"
    check manifestJson["builds"][0]["parts"].len == 1
    check manifestJson["builds"][0]["parts"][0]["path"].getStr() == "firmware-factory.bin"
    check manifestJson["builds"][0]["parts"][0]["offset"].getInt() == 0

    # 3. HTML & JavaScript client abstraction verification
    let html = myInstaller.generateHtml()
    check "<title>Voice Satellite Web Flasher</title>" in html
    check "data-offset=\"3604480\"" in html # 0x370000 in decimal
    check "data-depends-on=\"feedback_style\"" in html
    check "data-depends-val=\"Custom\"" in html
    check "presetCard_feedback_style" in html
    check "presetCadence_feedback_style" in html
    check "previewBtn_feedback_style" in html
    check "playPresetAudio" in html
    check "120ms cadence" in html
    check "esp-web-install-button" in html
    check "updateDynamicManifest" in html
    check "URL.createObjectURL" in html
    check "custom-slot" in html
    check "presetView_feedback_style" in html
    check "field_hardware_target" in html
    check "TARGET_MAP" in html
    check "Seeed ReSpeaker XVF3800" in html
    check "Home Assistant Voice PE" in html
    check "phonetic-callout" in html
    check "okay see three pee oh" in html
    check "terminal-drawer" in html
    check "deviceInfoBanner" in html
    check "btnTermConnect" in html
    check "btnTermToggle" in html
    check "btnTermClear" in html
    check "disconnectTerminal" in html
    check "FORM_STORAGE_KEY" in html
    check "esphome_installer_state_v1" in html
    check "saveInstallerState" in html
    check "restoreInstallerState" in html
    check "restoreCachedFiles" in html
    check "cachedFileStore" in html
    check "syncDynamicManifestVersion" in html

  test "esphomeInstaller with multi-slot wake words and chime sounds":
    let slotInstaller = esphomeInstaller("slot-satellite"):
      installer.title = "Multi-Slot Satellite Web Installer"
      installer.chipFamily = "ESP32-S3"

      installer.addWakeWordSlotsField(
        name = "active_wake_words",
        label = "Active Wake Word Models (Up to 3 Concurrent)",
        options = @["Okay Nabu (Default)", "Hey Jarvis", "Alexa"],
        maxSlots = 3,
        slotOffsets = @[0x3B0000'u32, 0x3F0000'u32, 0x430000'u32]
      )

      installer.addSelectField(
        name = "wake_chime_sound",
        label = "Wake Chime Sound",
        options = @["Bell Ping (Default)", "Modern Chime", "Marimba", "Subtle Beep", "Silent", "Custom Chime Audio"],
        defaultVal = "Bell Ping (Default)",
        hasAudioPreview = true,
        optionDetails = @[
          optionDetail("Bell Ping (Default)", "880Hz single tone", "Clean bell ping"),
          optionDetail("Modern Chime", "587Hz -> 880Hz", "Harmonic chime"),
          optionDetail("Marimba", "523Hz-659Hz-784Hz", "Warm acoustic marimba triad"),
          optionDetail("Subtle Beep", "600Hz 80ms", "Discreet blip"),
          optionDetail("Silent", "No sound", "Completely silent wake"),
          optionDetail("Custom Chime Audio", "User audio", "Custom audio from flash")
        ],
        presetAudios = @[
          ("Typewriter", "sounds/typewriter.mp3", "sounds/typewriter.wav")
        ]
      )

    check slotInstaller.fields.len == 2
    check slotInstaller.customPartitions.len == 3 # wake_model_1, wake_model_2, wake_model_3

    let html = slotInstaller.generateHtml()
    check "wakeSlotsContainer_active_wake_words" in html
    check "btnAddSlot_active_wake_words" in html
    check "custom-wake-guide" in html
    check "microWakeWord_model_training.ipynb" in html
    check "https://github.com/kahrendt/microWakeWord" in html
    check "BrowserWakeTrainer" notin html
    check "synthesizeAcousticFeatures" notin html
    check "checkInstallReadiness" in html
    check "installWarningNotice" in html
    check "Bell Ping" in html
    check "Modern Chime" in html
    check "Marimba" in html
    check "saveMwwCache" in html
    check "getMwwCache" in html
    check "select-cached-model" in html
    check "download-model-btn" in html
    check "upload-download-btn" in html
    check "PRESET_AUDIO" in html
    check "Typewriter" in html
    check "sounds/typewriter.mp3" in html

  test "esphomeInstaller modular toggles, hardware quirks, and ESPHome snippet generation":
    let modularInstaller = esphomeInstaller("minimal-flasher"):
      installer.title = "Minimal Flasher"
      installer.chipFamily = "ESP32-S3"
      installer.nativeUsb = true
      installer.enableEraseButton = false
      installer.enableImprovWifi = false
      installer.enableSuccessModal = false
      installer.enableSetupGuide = false
      installer.enableTerminalConsole = false
      installer.enableDeviceInspector = false
      installer.fallbackApSsid = "Custom-Fallback-AP"

      installer.addTarget(
        name = "ESP32-S3 Custom Board",
        binPath = "custom-s3.bin",
        chipFamily = "ESP32-S3",
        description = "ESP32-S3 board with native USB",
        nativeUsb = true
      )
      installer.addTarget(
        name = "ESP32-WROOM Classic",
        binPath = "classic-esp32.bin",
        chipFamily = "ESP32",
        description = "Standard UART ESP32",
        nativeUsb = false
      )

    check modularInstaller.enableEraseButton == false
    check modularInstaller.enableImprovWifi == false
    check modularInstaller.enableSuccessModal == false
    check modularInstaller.enableSetupGuide == false
    check modularInstaller.enableTerminalConsole == false
    check modularInstaller.enableDeviceInspector == false
    check modularInstaller.fallbackApSsid == "Custom-Fallback-AP"
    check modularInstaller.targets[0].nativeUsb == true
    check modularInstaller.targets[1].nativeUsb == false

    let html = modularInstaller.generateHtml()
    check "id=\"btnEraseDevice\"" notin html
    check "<improv-wifi-serial-launch-button>" notin html
    check "<div class=\"setup-guide-card\">" notin html
    check "id=\"installSuccessModal\"" notin html
    check "class=\"terminal-drawer\"" notin html
    check "id=\"deviceInfoBanner\"" notin html
    check "TARGET_MAP" in html
    check "\"nativeUsb\":true" in html
    check "\"nativeUsb\":false" in html

    # Verify ESPHome snippet generation
    let snippet = modularInstaller.generateEsphomeSnippet(
      name = "my-custom-satellite",
      friendlyName = "My Custom Satellite"
    )
    check "name: my-custom-satellite" in snippet
    check "friendly_name: \"My Custom Satellite\"" in snippet
    check "board: esp32-s3-devkitc-1" in snippet
    check "hardware_uart: USB_SERIAL_JTAG" in snippet
    check "ssid: \"Custom-Fallback-AP\"" in snippet
    check "captive_portal:" in snippet
    check "improv_serial:" notin snippet

    # Verify snippet with improv_serial enabled
    modularInstaller.enableImprovWifi = true
    let snippetWithImprov = modularInstaller.generateEsphomeSnippet()
    check "improv_serial:" in snippetWithImprov

  test "esphomeInstaller audio showcase, custom wake words, and direct asset flashing":
    let showcaseInstaller = esphomeInstaller("respeaker-flasher"):
      installer.title = "ReSpeaker Flasher"
      installer.chipFamily = "ESP32-S3"

      installer.addAudioShowcase(
        name = "wake_chimes",
        label = "Built-in Wake Chimes",
        options = @["Bell Ping", "Modern Chime"],
        optionDetails = @[
          optionDetail("Bell Ping", "Single tone (880Hz)", "Clean bell"),
          optionDetail("Modern Chime", "Two-tone chord", "Modern chord")
        ],
        presetAudios = @[
          ("Bell Ping", "sounds/bell-ping.mp3", "sounds/bell-ping.wav"),
          ("Modern Chime", "sounds/modern-chime.mp3", "sounds/modern-chime.wav")
        ]
      )

      installer.addCustomWakeWordField(
        name = "custom_wake_word",
        label = "Custom Wake Word Model (.tflite)",
        partition = "wake_model",
        flashOffset = 0x510000'u32,
        maxSize = 524288
      )

      installer.addFileField(
        name = "custom_sound",
        label = "Custom Processing Sound Loop (.wav)",
        partition = "sound_data",
        flashOffset = 0x490000'u32,
        maxSize = 262144
      )

    check showcaseInstaller.fields.len == 3
    check showcaseInstaller.customPartitions.len == 2 # wake_model and sound_data

    let html = showcaseInstaller.generateHtml()
    check "showcaseCard_wake_chimes" in html
    check "wakeBox_custom_wake_word" in html
    check "packWakeModelHeader" in html
    check "field_custom_wake_word_phrase" in html
    check "field_custom_wake_word_cutoff" in html
    check "btn-play-uploaded" in html
    check "0x510000" in html
    check "0x490000" in html

  test "esphomeInstaller discrete multi-part flashing skips NVS partition":
    let multiPartInstaller = esphomeInstaller("nvs-safe-satellite"):
      installer.title = "NVS Safe Flasher"
      installer.version = "1.0.0"
      installer.chipFamily = "ESP32-S3"
      installer.addBasePart("bootloader.bin", 0x0'u32)
      installer.addBasePart("partitions.bin", 0x8000'u32)
      installer.addBasePart("ota_data_initial.bin", 0xE000'u32)
      installer.addBasePart("firmware-ota.bin", 0x10000'u32)

    let manifestJson = parseJson(multiPartInstaller.generateManifest())
    check manifestJson["builds"][0]["parts"].len == 4
    check manifestJson["builds"][0]["parts"][0]["offset"].getInt() == 0
    check manifestJson["builds"][0]["parts"][1]["offset"].getInt() == 32768
    check manifestJson["builds"][0]["parts"][2]["offset"].getInt() == 57344
    check manifestJson["builds"][0]["parts"][3]["offset"].getInt() == 65536

    # Verify NVS (0x9000 = 36864 to 0xE000 = 57344) is not in any part
    for part in manifestJson["builds"][0]["parts"]:
      let off = part["offset"].getInt()
      check off < 36864 or off >= 57344

    let html = multiPartInstaller.generateHtml()
    check "bootloader.bin" in html
    check "partitions.bin" in html
    check "ota_data_initial.bin" in html
    check "firmware-ota.bin" in html
    check "Updating an existing device?" in html

