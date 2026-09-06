## Satellite Voice Assistant State Machine using nim-esphome + nim-typestates
##
## Guarantees at compile time:
## 1. Speech cannot end unless the satellite is in Listening state.
## 2. TTS cannot start unless the satellite is in Thinking state.
## 3. Chime must complete before entering Listening state.
## 4. Unhandled/illegal transitions fail at compile time.

import nim_esphome
import typestates

type
  SatelliteContext* = object
    wakeWord*: string
    beamAngle*: int

  Idle* = distinct SatelliteContext
  Woken* = distinct SatelliteContext
  Listening* = distinct SatelliteContext
  Thinking* = distinct SatelliteContext
  Replying* = distinct SatelliteContext
  ErrorState* = distinct SatelliteContext

typestate SatelliteFSM:
  consumeOnTransition = false
  states Idle, Woken, Listening, Thinking, Replying, ErrorState
  transitions:
    Idle -> Woken
    Woken -> (Listening | Idle) as ChimeResult
    Listening -> (Thinking | ErrorState | Idle) as SpeechResult
    Thinking -> (Replying | ErrorState | Idle) as TtsResult
    Replying -> (Listening | Idle) as ReplyResult
    ErrorState -> Idle

proc onWakeWord*(s: Idle, word: string, angle: int): Woken {.transition.} =
  var ctx = SatelliteContext(wakeWord: word, beamAngle: angle)
  info("SatelliteFSM", "State: IDLE -> WOKEN (wake_word: " & word & ")")
  result = Woken(ctx)

proc onChimeFinished*(s: Woken): Listening {.transition.} =
  info("SatelliteFSM", "State: WOKEN -> LISTENING (chime finished, mic active)")
  result = Listening(SatelliteContext(s))

proc onChimeFailed*(s: Woken): Idle {.transition.} =
  warn("SatelliteFSM", "State: WOKEN -> IDLE (chime playback failed)")
  result = Idle(SatelliteContext())

proc onSpeechEnded*(s: Listening): Thinking {.transition.} =
  info("SatelliteFSM", "State: LISTENING -> THINKING (VAD speech ended)")
  result = Thinking(SatelliteContext(s))

proc onStopDuringListening*(s: Listening): Idle {.transition.} =
  info("SatelliteFSM", "State: LISTENING -> IDLE (Stop command received)")
  result = Idle(SatelliteContext())

proc onTtsStarted*(s: Thinking): Replying {.transition.} =
  info("SatelliteFSM", "State: THINKING -> REPLYING (TTS playback started)")
  result = Replying(SatelliteContext(s))

proc onStopDuringThinking*(s: Thinking): Idle {.transition.} =
  info("SatelliteFSM", "State: THINKING -> IDLE (Stop command received)")
  result = Idle(SatelliteContext())

proc onTtsFinished*(s: Replying): Idle {.transition.} =
  info("SatelliteFSM", "State: REPLYING -> IDLE (TTS playback finished)")
  result = Idle(SatelliteContext())

proc onStopDuringReplying*(s: Replying): Idle {.transition.} =
  info("SatelliteFSM", "State: REPLYING -> IDLE (Stop command received during TTS)")
  result = Idle(SatelliteContext())

proc onErrorFromListening*(s: Listening): ErrorState {.transition.} =
  error("SatelliteFSM", "State: LISTENING -> ERROR")
  result = ErrorState(SatelliteContext(s))

proc onErrorFromThinking*(s: Thinking): ErrorState {.transition.} =
  error("SatelliteFSM", "State: THINKING -> ERROR")
  result = ErrorState(SatelliteContext(s))

proc onResetError*(s: ErrorState): Idle {.transition.} =
  info("SatelliteFSM", "State: ERROR -> IDLE (cleared)")
  result = Idle(SatelliteContext())

verifyTypestates()

# Runtime enum and bridge functions exposed to ESPHome C++
type
  RuntimeState* = enum
    rsIdle, rsWoken, rsListening, rsThinking, rsReplying, rsError

var
  currentState: RuntimeState = rsIdle
  ctxIdle: Idle = Idle(SatelliteContext())
  ctxWoken: Woken
  ctxListening: Listening
  ctxThinking: Thinking
  ctxReplying: Replying
  ctxError: ErrorState

proc nim_satellite_wake_word*(word: cstring, angle: cint) {.exportc, cdecl.} =
  if currentState == rsIdle:
    ctxWoken = onWakeWord(ctxIdle, $word, int(angle))
    currentState = rsWoken
  else:
    warn("SatelliteFSM", "Wake word ignored: satellite busy in state " & $currentState)

proc nim_satellite_chime_done*(ok: bool) {.exportc, cdecl.} =
  if currentState == rsWoken:
    if ok:
      ctxListening = onChimeFinished(ctxWoken)
      currentState = rsListening
    else:
      ctxIdle = onChimeFailed(ctxWoken)
      currentState = rsIdle

proc nim_satellite_speech_ended*() {.exportc, cdecl.} =
  if currentState == rsListening:
    ctxThinking = onSpeechEnded(ctxListening)
    currentState = rsThinking

proc nim_satellite_tts_start*() {.exportc, cdecl.} =
  if currentState == rsThinking:
    ctxReplying = onTtsStarted(ctxThinking)
    currentState = rsReplying

proc nim_satellite_tts_end*() {.exportc, cdecl.} =
  if currentState == rsReplying:
    ctxIdle = onTtsFinished(ctxReplying)
    currentState = rsIdle

proc nim_satellite_stop_word*() {.exportc, cdecl.} =
  case currentState
  of rsListening:
    ctxIdle = onStopDuringListening(ctxListening)
    currentState = rsIdle
  of rsThinking:
    ctxIdle = onStopDuringThinking(ctxThinking)
    currentState = rsIdle
  of rsReplying:
    ctxIdle = onStopDuringReplying(ctxReplying)
    currentState = rsIdle
  else:
    debug("SatelliteFSM", "Stop word ignored: satellite is not active")

proc nim_satellite_error*() {.exportc, cdecl.} =
  case currentState
  of rsListening:
    ctxError = onErrorFromListening(ctxListening)
    ctxIdle = onResetError(ctxError)
    currentState = rsIdle
  of rsThinking:
    ctxError = onErrorFromThinking(ctxThinking)
    ctxIdle = onResetError(ctxError)
    currentState = rsIdle
  else:
    currentState = rsIdle

esphomeSetup:
  info("SatelliteFSM", "Satellite State Machine initialized with compile-time typestates")
