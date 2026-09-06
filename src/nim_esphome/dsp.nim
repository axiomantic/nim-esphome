import std/algorithm

type
  PIDController* = object
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
  pid.integral = 0.0'f32
  pid.prevError = 0.0'f32
  pid.hasPrev = false

proc update*(pid: var PIDController, setpoint, measured, dt: float32): float32 =
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
    buffer: array[N, float32]
    head: int
    count: int
    sum: float32

proc newMovingAverage*[N: static int](): MovingAverage[N] =
  MovingAverage[N](head: 0, count: 0, sum: 0.0'f32)

proc reset*[N: static int](ma: var MovingAverage[N]) =
  ma.head = 0
  ma.count = 0
  ma.sum = 0.0'f32

proc update*[N: static int](ma: var MovingAverage[N], val: float32): float32 =
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
  if ma.count == 0: 0.0'f32
  else: ma.sum / float32(ma.count)

type
  MovingMedian*[N: static int] = object
    buffer: array[N, float32]
    head: int
    count: int

proc newMovingMedian*[N: static int](): MovingMedian[N] =
  MovingMedian[N](head: 0, count: 0)

proc reset*[N: static int](mm: var MovingMedian[N]) =
  mm.head = 0
  mm.count = 0

proc value*[N: static int](mm: MovingMedian[N]): float32 =
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
  mm.buffer[mm.head] = val
  if mm.count < N:
    inc mm.count
  mm.head = (mm.head + 1) mod N
  mm.value()

type
  LowPassFilter* = object
    alpha*: float32
    currentVal*: float32
    initialized*: bool

proc newLowPassFilter*(alpha: float32, initialVal: float32 = 0.0'f32): LowPassFilter =
  LowPassFilter(alpha: clamp(alpha, 0.0'f32, 1.0'f32), currentVal: initialVal, initialized: false)

proc reset*(lpf: var LowPassFilter, initialVal: float32 = 0.0'f32) =
  lpf.currentVal = initialVal
  lpf.initialized = false

proc update*(lpf: var LowPassFilter, val: float32): float32 =
  if not lpf.initialized:
    lpf.currentVal = val
    lpf.initialized = true
  else:
    lpf.currentVal = lpf.alpha * val + (1.0'f32 - lpf.alpha) * lpf.currentVal
  lpf.currentVal

proc value*(lpf: LowPassFilter): float32 =
  lpf.currentVal

type
  Debouncer* = object
    debounceTimeMs*: uint32
    stableState*: bool
    lastRawState*: bool
    lastDebounceTime*: uint32
    justRose*: bool
    justFell*: bool

proc newDebouncer*(debounceTimeMs: uint32, initialVal: bool = false): Debouncer =
  Debouncer(
    debounceTimeMs: debounceTimeMs,
    stableState: initialVal,
    lastRawState: initialVal,
    lastDebounceTime: 0,
    justRose: false,
    justFell: false
  )

proc update*(d: var Debouncer, rawVal: bool, nowMs: uint32): bool =
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
  d.stableState

proc rose*(d: Debouncer): bool =
  d.justRose

proc fell*(d: Debouncer): bool =
  d.justFell
