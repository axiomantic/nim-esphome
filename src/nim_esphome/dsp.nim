## `nim_esphome/dsp`: Embedded Digital Signal Processing and Closed-Loop Control.
##
## Provides deterministic, stack-allocated algorithms designed specifically for microcontrollers:
## - `PIDController`: Closed-loop feedback controller with anti-windup clamping.
## - `MovingAverage`: Stack-allocated O(1) circular buffer sliding mean filter.
## - `MovingMedian`: Stack-allocated sliding median filter for outlier rejection.
## - `LowPassFilter`: Single-pole exponential IIR smoothing filter.
## - `Debouncer`: Time-based edge-detecting debouncer for mechanical contacts.

import std/algorithm
import std/math

type
  PIDController* = object
    ## Closed-loop Proportional-Integral-Derivative (PID) controller.
    ## All calculations use 32-bit floating point math with anti-windup clamping.
    kp*, ki*, kd*: float32
    minOutput*, maxOutput*: float32
    integral*: float32
    prevError*: float32
    hasPrev*: bool

proc newPIDController*(
    kp, ki, kd: float32,
    minOutput: float32 = -1.0e9'f32,
    maxOutput: float32 = 1.0e9'f32
): PIDController =
  ## Initializes a new PIDController with tuning gains `kp`, `ki`, `kd`
  ## and optional saturation limits `minOutput` and `maxOutput`.
  ##
  ## :param kp: Proportional gain coefficient.
  ## :param ki: Integral gain coefficient.
  ## :param kd: Derivative gain coefficient.
  ## :param minOutput: Lower actuator saturation limit.
  ## :param maxOutput: Upper actuator saturation limit.
  ## :returns: A new initialized `PIDController` instance.
  PIDController(
    kp: kp,
    ki: ki,
    kd: kd,
    minOutput: minOutput,
    maxOutput: maxOutput,
    integral: 0.0'f32,
    prevError: 0.0'f32,
    hasPrev: false
  )

proc reset*(pid: var PIDController) =
  ## Resets accumulated integral error and previous derivative state to zero.
  ##
  ## :param pid: Target `PIDController` to reset.
  pid.integral = 0.0'f32
  pid.prevError = 0.0'f32
  pid.hasPrev = false

proc update*(pid: var PIDController, setpoint, measured, dt: float32): float32 =
  ## Computes the control effort given target `setpoint`, current `measured` value,
  ## and elapsed time `dt` in seconds. Automatically applies anti-windup clamping.
  ##
  ## :param pid: Target `PIDController` state machine.
  ## :param setpoint: Desired target reference value.
  ## :param measured: Current sensor measurement.
  ## :param dt: Elapsed delta time since previous update in seconds.
  ## :returns: Computed control effort output, clamped within [minOutput, maxOutput].
  let error = setpoint - measured
  let pTerm = pid.kp * error

  pid.integral += error * dt
  let iTerm = pid.ki * pid.integral

  var dTerm = 0.0'f32
  if pid.hasPrev and dt > 0.0'f32:
    dTerm = pid.kd * (error - pid.prevError) / dt
  pid.prevError = error
  pid.hasPrev = true

  var output = pTerm + iTerm + dTerm
  if output > pid.maxOutput:
    output = pid.maxOutput
    # Anti-windup clamping on integral
    if pid.ki != 0.0'f32 and error > 0.0'f32:
      pid.integral -= error * dt
  elif output < pid.minOutput:
    output = pid.minOutput
    if pid.ki != 0.0'f32 and error < 0.0'f32:
      pid.integral -= error * dt

  output

type
  MovingAverage*[N: static int] = object
    ## Stack-allocated moving average filter with a fixed window size of `N` samples.
    ## Performs insertions and updates in constant O(1) time without heap allocations.
    buffer: array[N, float32]
    head: int
    count: int
    sum: float32

proc newMovingAverage*[N: static int](): MovingAverage[N] =
  ## Creates a new, empty moving average filter with window size `N`.
  ##
  ## :returns: An empty `MovingAverage[N]` filter instance.
  MovingAverage[N](head: 0, count: 0, sum: 0.0'f32)

proc reset*[N: static int](ma: var MovingAverage[N]) =
  ## Clears the moving average buffer and resets the cumulative sum.
  ##
  ## :param ma: Target `MovingAverage[N]` filter to clear.
  ma.head = 0
  ma.count = 0
  ma.sum = 0.0'f32

proc update*[N: static int](ma: var MovingAverage[N], val: float32): float32 =
  ## Inserts sample `val` into the circular buffer and returns the updated average.
  ##
  ## :param ma: Target `MovingAverage[N]` filter.
  ## :param val: New sample value.
  ## :returns: Updated arithmetic mean of samples currently in the window.
  if ma.count < N:
    ma.buffer[ma.head] = val
    ma.sum += val
    inc ma.count
    ma.head = (ma.head + 1) mod N
  else:
    ma.sum -= ma.buffer[ma.head]
    ma.buffer[ma.head] = val
    ma.sum += val
    ma.head = (ma.head + 1) mod N
  ma.sum / float32(ma.count)

proc value*[N: static int](ma: MovingAverage[N]): float32 =
  ## Returns the current arithmetic average of samples in the buffer without modifying state.
  ##
  ## :param ma: Target `MovingAverage[N]` filter.
  ## :returns: Current arithmetic mean of samples.
  if ma.count == 0: 0.0'f32
  else: ma.sum / float32(ma.count)


type
  MovingMedian*[N: static int] = object
    ## Stack-allocated moving median filter with a fixed window of `N` samples.
    ## Excellent for rejecting impulse noise and outliers from ultrasonic or ADC sensors.
    buffer: array[N, float32]
    head: int
    count: int

proc newMovingMedian*[N: static int](): MovingMedian[N] =
  ## Creates a new, empty moving median filter with window size `N`.
  ##
  ## :returns: An empty `MovingMedian[N]` filter instance.
  MovingMedian[N](head: 0, count: 0)

proc reset*[N: static int](mm: var MovingMedian[N]) =
  ## Clears all samples in the moving median buffer.
  ##
  ## :param mm: Target `MovingMedian[N]` filter to clear.
  mm.head = 0
  mm.count = 0

proc value*[N: static int](mm: MovingMedian[N]): float32 =
  ## Computes and returns the median of the current samples using an in-place stack sort.
  ## Does not allocate heap memory.
  ##
  ## :param mm: Target `MovingMedian[N]` filter.
  ## :returns: Current median value of samples in the window.
  if mm.count == 0:
    return 0.0'f32
  var sortedVals: array[N, float32]
  for i in 0 ..< mm.count:
    sortedVals[i] = mm.buffer[i]
  # In-place insertion sort
  for i in 1 ..< mm.count:
    let key = sortedVals[i]
    var j = i - 1
    while j >= 0 and sortedVals[j] > key:
      sortedVals[j + 1] = sortedVals[j]
      dec j
    sortedVals[j + 1] = key

  if mm.count mod 2 == 1:
    sortedVals[mm.count div 2]
  else:
    (sortedVals[(mm.count div 2) - 1] + sortedVals[mm.count div 2]) * 0.5'f32

proc update*[N: static int](mm: var MovingMedian[N], val: float32): float32 =
  ## Inserts sample `val` into the buffer and returns the updated median value.
  ##
  ## :param mm: Target `MovingMedian[N]` filter.
  ## :param val: New sample value.
  ## :returns: Updated median value after inserting `val`.
  mm.buffer[mm.head] = val
  if mm.count < N:
    inc mm.count
  mm.head = (mm.head + 1) mod N
  mm.value()

type
  LowPassFilter* = object
    ## Single-pole exponential Infinite Impulse Response (IIR) low-pass filter.
    ## Formula: `y[n] = alpha * x[n] + (1.0 - alpha) * y[n-1]`
    alpha*: float32
    currentVal*: float32
    initialized*: bool

proc newLowPassFilter*(alpha: float32, initialVal: float32 = 0.0'f32): LowPassFilter =
  ## Initializes a low-pass filter with smoothing factor `alpha` in range `[0.0, 1.0]`.
  ## Lower `alpha` provides stronger smoothing at the cost of higher phase lag.
  ##
  ## :param alpha: Smoothing factor coefficient in [0.0, 1.0].
  ## :param initialVal: Initial baseline output value.
  ## :returns: A new initialized `LowPassFilter` instance.
  LowPassFilter(alpha: clamp(alpha, 0.0'f32, 1.0'f32), currentVal: initialVal, initialized: false)

proc reset*(lpf: var LowPassFilter, initialVal: float32 = 0.0'f32) =
  ## Resets the filter state to `initialVal` and clears the initialization flag.
  ##
  ## :param lpf: Target `LowPassFilter` to reset.
  ## :param initialVal: Value to set the filter output to.
  lpf.currentVal = initialVal
  lpf.initialized = false

proc update*(lpf: var LowPassFilter, val: float32): float32 =
  ## Applies the low-pass filter formula to sample `val` and returns the smoothed output.
  ##
  ## :param lpf: Target `LowPassFilter`.
  ## :param val: New unfiltered input sample.
  ## :returns: Filtered output value.
  if not lpf.initialized:
    lpf.currentVal = val
    lpf.initialized = true
  else:
    lpf.currentVal = lpf.alpha * val + (1.0'f32 - lpf.alpha) * lpf.currentVal
  lpf.currentVal

proc value*(lpf: LowPassFilter): float32 =
  ## Returns the most recent smoothed output value.
  ##
  ## :param lpf: Target `LowPassFilter`.
  ## :returns: Most recent output value without updating state.
  lpf.currentVal

type
  Debouncer* = object
    ## Time-based software debouncer for mechanical buttons, switches, and reed sensors.
    debounceTimeMs*: uint32
    stableState*: bool
    lastRawState*: bool
    lastDebounceTime*: uint32
    justRose*: bool
    justFell*: bool

proc newDebouncer*(debounceTimeMs: uint32, initialVal: bool = false): Debouncer =
  ## Initializes a new Debouncer requiring input to stay stable for `debounceTimeMs`
  ## milliseconds before switching states.
  ##
  ## :param debounceTimeMs: Minimum stability duration in milliseconds.
  ## :param initialVal: Initial boolean state.
  ## :returns: A new `Debouncer` instance.
  Debouncer(
    debounceTimeMs: debounceTimeMs,
    stableState: initialVal,
    lastRawState: initialVal,
    lastDebounceTime: 0,
    justRose: false,
    justFell: false
  )

proc update*(d: var Debouncer, rawVal: bool, nowMs: uint32): bool =
  ## Updates the debouncer with the latest `rawVal` and current timestamp `nowMs`.
  ## Returns the debounced stable state.
  ##
  ## :param d: Target `Debouncer` state machine.
  ## :param rawVal: Instantaneous raw digital input state.
  ## :param nowMs: Current monotonic timestamp in milliseconds (e.g. from `millis()`).
  ## :returns: Stable debounced state.
  d.justRose = false
  d.justFell = false

  if rawVal != d.lastRawState:
    d.lastDebounceTime = nowMs
    d.lastRawState = rawVal

  if (nowMs - d.lastDebounceTime) >= d.debounceTimeMs:
    if rawVal != d.stableState:
      d.stableState = rawVal
      if d.stableState:
        d.justRose = true
      else:
        d.justFell = true

  d.stableState

proc state*(d: Debouncer): bool =
  ## Returns the current stable debounced state.
  ##
  ## :param d: Target `Debouncer`.
  ## :returns: Stable boolean state.
  d.stableState

proc rose*(d: Debouncer): bool =
  ## Returns `true` if the signal had a rising edge (Low -> High) on the most recent `update`.
  ##
  ## :param d: Target `Debouncer`.
  ## :returns: `true` if rising edge occurred on last update.
  d.justRose

proc fell*(d: Debouncer): bool =
  ## Returns `true` if the signal had a falling edge (High -> Low) on the most recent `update`.
  ##
  ## :param d: Target `Debouncer`.
  ## :returns: `true` if falling edge occurred on last update.
  d.justFell

type
  AudioCompressor* = object
    ## Real-time dynamic range compressor, vocal loudness booster, and limiter
    ## designed for embedded audio output and speech synthesis.
    sampleRate*: float32
    thresholdDb*: float32
    thresholdLinear*: float32
    ratio*: float32
    attackCoeff*: float32
    releaseCoeff*: float32
    makeupGainDb*: float32
    makeupGain*: float32
    envelope*: float32

proc newAudioCompressor*(
    sampleRate: float32 = 16000.0'f32,
    thresholdDb: float32 = -14.0'f32,
    ratio: float32 = 3.0'f32,
    attackMs: float32 = 4.0'f32,
    releaseMs: float32 = 75.0'f32,
    makeupGainDb: float32 = 5.0'f32
): AudioCompressor =
  ## Initializes a new real-time `AudioCompressor` with peak follower envelope detection,
  ## dynamic compression curve, and makeup vocal boost.
  result.sampleRate = sampleRate
  result.thresholdDb = thresholdDb
  result.thresholdLinear = pow(10.0'f32, thresholdDb / 20.0'f32)
  result.ratio = ratio
  result.attackCoeff = exp(-1.0'f32 / (sampleRate * (attackMs / 1000.0'f32)))
  result.releaseCoeff = exp(-1.0'f32 / (sampleRate * (releaseMs / 1000.0'f32)))
  result.makeupGainDb = makeupGainDb
  result.makeupGain = pow(10.0'f32, makeupGainDb / 20.0'f32)
  result.envelope = 0.0'f32

proc softClip*(x: float32, limit: float32 = 32767.0'f32): int16 {.inline.} =
  ## Rational soft-saturation curve: strictly bounded within [-limit, limit].
  ## Linear for small amplitudes, smoothly saturating at high levels with zero clipping buzz.
  let normalized = x / limit
  let saturated = normalized / sqrt(1.0'f32 + normalized * normalized)
  let scaled = saturated * limit
  if scaled >= 32767.0'f32:
    return 32767'i16
  elif scaled <= -32767.0'f32:
    return -32767'i16
  else:
    return int16(scaled)

proc process*(comp: var AudioCompressor, samples: ptr int16, count: int) =
  ## Processes 16-bit PCM samples in-place with zero heap allocations.
  if samples == nil or count <= 0:
    return

  let arr = cast[ptr UncheckedArray[int16]](samples)
  for i in 0 ..< count:
    let s = float32(arr[i])
    let absX = abs(s) / 32768.0'f32

    # Envelope peak follower
    if absX > comp.envelope:
      comp.envelope = comp.attackCoeff * comp.envelope + (1.0'f32 - comp.attackCoeff) * absX
    else:
      comp.envelope = comp.releaseCoeff * comp.envelope + (1.0'f32 - comp.releaseCoeff) * absX

    # Compute gain reduction
    var gainReduction: float32 = 1.0'f32
    if comp.envelope > comp.thresholdLinear and comp.envelope > 1e-6'f32:
      let envDb = 20.0'f32 * log10(comp.envelope)
      let compressedDb = comp.thresholdDb + (envDb - comp.thresholdDb) / comp.ratio
      gainReduction = pow(10.0'f32, (compressedDb - envDb) / 20.0'f32)

    # Apply compression gain reduction and makeup vocal boost
    let processed = s * gainReduction * comp.makeupGain

    # Soft-knee limiting to eliminate digital clipping
    arr[i] = softClip(processed)



