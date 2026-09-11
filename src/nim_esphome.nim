## `nim_esphome`: High-level Embedded Nim runtime for ESPHome.
##
## This module serves as the primary umbrella entrypoint for `nim-esphome`.
## It re-exports core subsystems:
## - `api`: ESPHome logging, timing, memory, and watchdog bindings.
## - `entities`: First-class bindings for Sensors, BinarySensors, Switches, and TextSensors.
## - `gpio`: Hardware GPIO pin mode configuration, digital read, and digital write.
## - `i2c`: I2C peripheral abstractions, register writes, and multi-byte reads.
## - `preferences`: Non-volatile flash storage persistence (NVS) for types and strings.
## - `dsp`: Embedded digital signal processing, PID controllers, moving statistics, and debouncers.
##
## It also provides the core lifecycle hooks (`esphomeSetup`, `esphomeLoop`) and
## the `{.exportEsphome.}` macro to expose Nim procedures to ESPHome C++ lambdas.

import std/macros
import nim_esphome/api
import nim_esphome/entities
import nim_esphome/gpio
import nim_esphome/i2c
import nim_esphome/preferences
import nim_esphome/dsp
import nim_esphome/dsl
import nim_esphome/freertos
import nim_esphome/ota

export api
export entities
export gpio
export i2c
export preferences
export dsp
export dsl
export freertos
export ota

template esphomeSetup*(body: untyped) =
  ## Registers initialization logic invoked once during ESPHome's setup phase.
  ##
  ## The code inside `body` executes when the ESPHome `Component::setup()` lifecycle
  ## method is called, after system hardware and peripherals are initialized.
  ##
  ## :param body: The untyped Nim code block to execute during setup.
  ##
  ## Example:
  ## ```nim
  ## esphomeSetup:
  ##   info("Main", "Initializing hardware peripherals...")
  ##   pinMode(2, Output)
  ## ```
  proc nim_on_setup() {.exportc: "nim_on_setup", cdecl.} =
    body

template esphomeLoop*(body: untyped) =
  ## Registers logic executed repeatedly during ESPHome's cooperative loop cycle.
  ##
  ## The code inside `body` executes on every iteration of ESPHome's `Component::loop()`
  ## method. Keep operations non-blocking and cooperative.
  ##
  ## :param body: The untyped Nim code block to execute on every loop cycle.
  ##
  ## Example:
  ## ```nim
  ## esphomeLoop:
  ##   let now = millis()
  ##   # perform non-blocking state machine updates
  ## ```
  proc nim_on_loop() {.exportc: "nim_on_loop", cdecl.} =
    body

macro exportEsphome*(def: untyped): untyped =
  ## Decorates a procedure with `{.exportc, cdecl.}` so that ESPHome YAML lambdas
  ## and C++ components can invoke it directly via standard C ABI linkage.
  ##
  ## :param def: The procedure definition AST node to decorate.
  ## :returns: The modified AST node with exportc and cdecl pragmas attached.
  ##
  ## Example:
  ## ```nim
  ## proc computeTargetLevel*(ambientLight: int32): int32 {.exportEsphome.} =
  ##   if ambientLight < 100: 255 else: 0
  ## ```
  ##
  ## ESPHome YAML:
  ## ```yaml
  ## lambda: |-
  ##   extern int32_t computeTargetLevel(int32_t);
  ##   return computeTargetLevel(50);
  ## ```
  result = def

  var hasExportc = false
  var hasCdecl = false
  var pragmas = result.pragma
  if pragmas.kind == nnkEmpty:
    pragmas = newNimNode(nnkPragma)
    result.pragma = pragmas

  for p in pragmas:
    if p.kind == nnkIdent:
      if p.strVal == "cdecl": hasCdecl = true
      elif p.strVal == "exportc": hasExportc = true
    elif p.kind == nnkExprColonExpr and p[0].kind == nnkIdent and p[0].strVal == "exportc":
      hasExportc = true

  let procName = if result.name.kind == nnkPostfix: result.name[1].strVal else: result.name.strVal
  if not hasExportc:
    pragmas.add(newColonExpr(ident("exportc"), newLit(procName)))
  if not hasCdecl:
    pragmas.add(ident("cdecl"))

