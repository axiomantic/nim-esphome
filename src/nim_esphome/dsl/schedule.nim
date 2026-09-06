## `nim_esphome/dsl/schedule`: RTOS Background Task & Schedule DSL.
##
## This module provides cooperative, non-blocking periodic task scheduling and one-shot
## delays designed specifically for embedded microcontrollers running in the ESPHome loop.
##
## Features:
## - Ergonomic duration helpers: `50.ms`, `2.seconds`, `10.minutes`, `1.hours`.
## - Zero dynamic thread allocation; runs cooperatively within ESPHome's main loop.
## - Full cancellation and reset support for timers.
## - Host testable via manual timestamp advancing (`tickSchedules`).
##
## ## Example
##
## ```nim
## import nim_esphome/dsl/schedule
##
## haSchedule:
##   every 100.ms:
##     # Audio processing loop tick
##     stepAudioPipeline()
##
##   every 5.seconds:
##     # Periodic telemetry heartbeat
##     sendHeartbeat()
##
##   after 30.seconds:
##     # One-shot calibration timeout
##     finishCalibration()
## ```


type
  DurationUnit* = enum
    ## Supported time duration units.
    duMilliseconds
    duSeconds
    duMinutes
    duHours

  ScheduleDuration* = object
    ## Representation of a typed time interval.
    amount*: uint64
    unit*: DurationUnit

  ScheduleType* = enum
    ## Distinguishes recurring periodic tasks from one-shot timeouts.
    stPeriodic
    stOneShot

  ScheduleTask* = ref object
    ## An active or scheduled background task.
    id*: string
    schedType*: ScheduleType
    intervalMs*: uint64
    lastRunMs*: uint64
    delayMs*: uint64
    startMs*: uint64
    active*: bool
    hasRun*: bool
    initialized*: bool
    action*: proc() {.closure.}

  ScheduleRegistry* = ref object
    ## Holds all registered background tasks.
    tasks*: seq[ScheduleTask]

var defaultScheduleRegistry* = ScheduleRegistry(tasks: @[])

proc toMs*(d: ScheduleDuration): uint64 =
  ## Converts any ScheduleDuration into absolute milliseconds.
  case d.unit
  of duMilliseconds: d.amount
  of duSeconds: d.amount * 1000'u64
  of duMinutes: d.amount * 60_000'u64
  of duHours: d.amount * 3_600_000'u64

proc ms*(n: int or uint64): ScheduleDuration =
  ## Milliseconds duration helper (e.g. `50.ms`).
  ScheduleDuration(amount: uint64(n), unit: duMilliseconds)

proc milliseconds*(n: int or uint64): ScheduleDuration =
  ## Milliseconds duration helper (e.g. `500.milliseconds`).
  ScheduleDuration(amount: uint64(n), unit: duMilliseconds)

proc seconds*(n: int or uint64): ScheduleDuration =
  ## Seconds duration helper (e.g. `5.seconds`).
  ScheduleDuration(amount: uint64(n), unit: duSeconds)

proc minutes*(n: int or uint64): ScheduleDuration =
  ## Minutes duration helper (e.g. `10.minutes`).
  ScheduleDuration(amount: uint64(n), unit: duMinutes)

proc hours*(n: int or uint64): ScheduleDuration =
  ## Hours duration helper (e.g. `1.hours`).
  ScheduleDuration(amount: uint64(n), unit: duHours)

proc cancel*(task: ScheduleTask) =
  ## Cancels future executions of this task.
  task.active = false

proc reset*(task: ScheduleTask, currentMs: uint64 = 0) =
  ## Reactivates a task and resets its reference timestamp.
  task.active = true
  task.lastRunMs = currentMs
  task.startMs = currentMs
  task.hasRun = false
  task.initialized = (currentMs > 0)

proc every*(
    interval: ScheduleDuration,
    action: proc() {.closure.},
    registry: ScheduleRegistry = defaultScheduleRegistry,
    id: string = ""
): ScheduleTask {.discardable.} =
  ## Registers a recurring periodic task executed at the specified interval.
  let task = ScheduleTask(
    id: id,
    schedType: stPeriodic,
    intervalMs: interval.toMs(),
    lastRunMs: 0,
    delayMs: 0,
    startMs: 0,
    active: true,
    hasRun: false,
    initialized: false,
    action: action
  )
  registry.tasks.add(task)
  task

proc every*(
    registry: ScheduleRegistry,
    interval: ScheduleDuration,
    action: proc() {.closure.},
    id: string = ""
): ScheduleTask {.discardable.} =
  ## Registers a recurring periodic task executed at the specified interval against the registry.
  every(interval, action, registry, id)

proc after*(
    delay: ScheduleDuration,
    action: proc() {.closure.},
    registry: ScheduleRegistry = defaultScheduleRegistry,
    id: string = ""
): ScheduleTask {.discardable.} =
  ## Registers a one-shot timeout executed once after the specified delay.
  let task = ScheduleTask(
    id: id,
    schedType: stOneShot,
    intervalMs: 0,
    lastRunMs: 0,
    delayMs: delay.toMs(),
    startMs: 0,
    active: true,
    hasRun: false,
    initialized: false,
    action: action
  )
  registry.tasks.add(task)
  task

proc after*(
    registry: ScheduleRegistry,
    delay: ScheduleDuration,
    action: proc() {.closure.},
    id: string = ""
): ScheduleTask {.discardable.} =
  ## Registers a one-shot timeout executed once after the specified delay against the registry.
  after(delay, action, registry, id)

proc tickSchedules*(currentMs: uint64, registry: ScheduleRegistry = defaultScheduleRegistry) =
  ## Advances time and evaluates all active tasks. Call this inside the ESPHome loop.
  for task in registry.tasks:
    if not task.active:
      continue

    case task.schedType
    of stPeriodic:
      if not task.initialized:
        task.initialized = true
        task.lastRunMs = currentMs
      elif currentMs >= task.lastRunMs + task.intervalMs:
        task.lastRunMs = currentMs
        task.action()
    of stOneShot:
      if not task.initialized:
        task.initialized = true
        task.startMs = currentMs
      elif not task.hasRun and currentMs >= task.startMs + task.delayMs:
        task.hasRun = true
        task.active = false
        task.action()

template haSchedule*(registry: ScheduleRegistry, body: untyped): untyped =
  ## Block syntax for registering multiple tasks against a specific schedule registry.
  let schedReg {.inject.} = registry
  template every(d: ScheduleDuration, act: untyped) {.used.} =
    schedReg.every(d, proc() = (act))
  template after(d: ScheduleDuration, act: untyped) {.used.} =
    schedReg.after(d, proc() = (act))
  body

template haSchedule*(body: untyped): untyped =
  ## Block syntax for registering multiple tasks against the default schedule registry.
  haSchedule(defaultScheduleRegistry, body)
