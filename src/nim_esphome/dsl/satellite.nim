## `nim_esphome/dsl/satellite`: Voice Assistant Satellite Lifecycle and Audio Feedback DSL.
##
## Models the complete Assist Satellite state machine:
##   `Idle` -> `Listening` -> `Processing` -> `Speaking` -> `Idle` (or `Error`)
##
## Manages audio progress cues (e.g. `processing_sound` / `startProcessingLoop`)
## while Home Assistant's LLM pipeline processes user speech.

type
  SatelliteState* = enum
    ssIdle = "idle"
    ssListening = "listening"
    ssProcessing = "processing"
    ssSpeaking = "speaking"
    ssError = "error"

  ProcessingSoundStyle* = enum
    psSilent = "Silent"
    psSpinner = "Spinner"
    psPulse = "Pulse"
    psSonar = "Sonar"
    psTick = "Tick"
    psCustom = "Custom"

  ProcessingTickCallback* = proc(style: ProcessingSoundStyle, volume: float32, tickCount: int)
  StateChangeCallback* = proc(oldState, newState: SatelliteState)

  ProcessingLoop* = ref object
    active*: bool
    style*: ProcessingSoundStyle
    intervalMs*: uint32
    lastTickMs*: uint32
    volume*: float32
    tickCount*: int
    onTick*: ProcessingTickCallback

  SatellitePipeline* = ref object
    state*: SatelliteState
    processingLoop*: ProcessingLoop
    wakeChimeEnabled*: bool
    wakeChimeVolume*: float32
    lastDoaAngle*: float32
    lastWakeWord*: string

    # Lifecycle Callbacks
    onStateChange*: StateChangeCallback
    onWakeWord*: proc(wakeWord: string, doaAngle: float32)
    onProcessingStart*: proc()
    onSpeakingStart*: proc()
    onSpeakingEnd*: proc()
    onError*: proc(code: string)
    onPlayWakeChime*: proc(volume: float32)
    onPlayErrorSound*: proc(code: string)

proc newProcessingLoop*(): ProcessingLoop =
  ProcessingLoop(
    active: false,
    style: psSpinner,
    intervalMs: 120,
    lastTickMs: 0,
    volume: 0.75'f32,
    tickCount: 0,
    onTick: nil
  )

proc newSatellitePipeline*(): SatellitePipeline =
  SatellitePipeline(
    state: ssIdle,
    processingLoop: newProcessingLoop(),
    wakeChimeEnabled: true,
    wakeChimeVolume: 0.8'f32,
    lastDoaAngle: 0.0'f32,
    lastWakeWord: "",
    onStateChange: nil,
    onWakeWord: nil,
    onProcessingStart: nil,
    onSpeakingStart: nil,
    onSpeakingEnd: nil,
    onError: nil,
    onPlayWakeChime: nil,
    onPlayErrorSound: nil
  )

proc setState*(pipeline: SatellitePipeline, newState: SatelliteState) =
  let old = pipeline.state
  if old != newState:
    pipeline.state = newState
    if pipeline.onStateChange != nil:
      pipeline.onStateChange(old, newState)

proc startProcessingLoop*(pipeline: SatellitePipeline, style: ProcessingSoundStyle = psSpinner, intervalMs: uint32 = 120) =
  pipeline.processingLoop.style = style
  pipeline.processingLoop.intervalMs = intervalMs
  pipeline.processingLoop.active = (style != psSilent)
  pipeline.processingLoop.tickCount = 0
  pipeline.processingLoop.lastTickMs = 0

proc stopProcessingLoop*(pipeline: SatellitePipeline) =
  pipeline.processingLoop.active = false
  pipeline.processingLoop.tickCount = 0

proc isProcessing*(pipeline: SatellitePipeline): bool =
  pipeline.processingLoop.active

proc tick*(pipeline: SatellitePipeline, nowMs: uint32) =
  ## Advances the audio spinner / processing sound loop if active.
  let loop = pipeline.processingLoop
  if not loop.active or loop.style == psSilent:
    return

  if loop.lastTickMs == 0 or (nowMs - loop.lastTickMs) >= loop.intervalMs:
    loop.lastTickMs = nowMs
    inc loop.tickCount
    if loop.onTick != nil:
      loop.onTick(loop.style, loop.volume, loop.tickCount)

# --- Standard Voice Pipeline Event Handlers ---

proc handleWakeWord*(pipeline: SatellitePipeline, wakeWord: string, doaAngle: float32 = 0.0) =
  pipeline.lastWakeWord = wakeWord
  pipeline.lastDoaAngle = doaAngle
  pipeline.stopProcessingLoop()

  if pipeline.wakeChimeEnabled and pipeline.onPlayWakeChime != nil:
    pipeline.onPlayWakeChime(pipeline.wakeChimeVolume)

  pipeline.setState(ssListening)
  if pipeline.onWakeWord != nil:
    pipeline.onWakeWord(wakeWord, doaAngle)

proc handleSpeechEnded*(pipeline: SatellitePipeline) =
  pipeline.setState(ssProcessing)
  pipeline.startProcessingLoop(pipeline.processingLoop.style, pipeline.processingLoop.intervalMs)
  if pipeline.onProcessingStart != nil:
    pipeline.onProcessingStart()

proc handleTtsStart*(pipeline: SatellitePipeline) =
  pipeline.stopProcessingLoop()
  pipeline.setState(ssSpeaking)
  if pipeline.onSpeakingStart != nil:
    pipeline.onSpeakingStart()

proc handleTtsEnd*(pipeline: SatellitePipeline) =
  pipeline.stopProcessingLoop()
  pipeline.setState(ssIdle)
  if pipeline.onSpeakingEnd != nil:
    pipeline.onSpeakingEnd()

proc handleError*(pipeline: SatellitePipeline, code: string) =
  pipeline.stopProcessingLoop()
  pipeline.setState(ssError)
  if pipeline.onPlayErrorSound != nil:
    pipeline.onPlayErrorSound(code)
  if pipeline.onError != nil:
    pipeline.onError(code)
  pipeline.setState(ssIdle)
