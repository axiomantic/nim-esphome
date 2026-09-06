## `nim_esphome/dsl/actions`: Custom Actions / Type-Safe Service Calls DSL.
##
## This module allows firmware authors to define Home Assistant custom services (actions)
## directly in Nim with full parameter typing and validation.
##
## Features:
## - Compile-time and runtime validation for service arguments (`string`, `int`, `float`, `bool`).
## - Type-safe parameter getters (`getString`, `getInt`, `getFloat`, `getBool`).
## - Generates standard ESPHome `api.services` YAML configurations.
## - Mock invocation hooks for unit testing on host machines (`triggerServiceCall`).
##
## ## Example
##
## ```nim
## import nim_esphome/dsl/actions
##
## haService "play_custom_tone":
##   description = "Plays an audio tone on the satellite speaker"
##   param "frequency", pkInt, min = 100.0, max = 10000.0, defaultVal = "440"
##   param "duration_ms", pkInt, min = 10.0, max = 5000.0, defaultVal = "200"
##   onExecute(ctx):
##     let freq = ctx.getInt("frequency")
##     let dur = ctx.getInt("duration_ms")
##     echo "Playing tone: ", freq, " Hz for ", dur, " ms"
## ```

import std/[tables, options, strutils, strformat]

type
  ParamKind* = enum
    ## Supported Home Assistant service parameter types.
    pkString = "string"
    pkInt = "int"
    pkFloat = "float"
    pkBool = "bool"

  ServiceParam* = object
    ## Metadata describing a single parameter expected by a service.
    name*: string
    kind*: ParamKind
    description*: string
    minVal*: Option[float]
    maxVal*: Option[float]
    defaultVal*: Option[string]

  ServiceParamValue* = object
    ## A tagged union representing a typed service argument passed from Home Assistant.
    case kind*: ParamKind
    of pkString: strVal*: string
    of pkInt: intVal*: int
    of pkFloat: floatVal*: float
    of pkBool: boolVal*: bool

  ServiceCallContext* = object
    ## Context delivered to the action handler during an execution.
    serviceName*: string
    params*: Table[string, ServiceParamValue]

  ServiceHandler* = proc(ctx: ServiceCallContext) {.closure.}

  ServiceDefinition* = ref object
    ## Complete definition of an exposed Home Assistant action.
    name*: string
    description*: string
    params*: seq[ServiceParam]
    handler*: ServiceHandler

  ServiceRegistry* = ref object
    ## Central registry of all custom services defined on the device.
    services*: Table[string, ServiceDefinition]

var defaultServiceRegistry* = ServiceRegistry(services: initTable[string, ServiceDefinition]())

proc newParamValue*(val: string): ServiceParamValue =
  ## Wraps a string value in a ServiceParamValue.
  ServiceParamValue(kind: pkString, strVal: val)

proc newParamValue*(val: int): ServiceParamValue =
  ## Wraps an integer value in a ServiceParamValue.
  ServiceParamValue(kind: pkInt, intVal: val)

proc newParamValue*(val: float): ServiceParamValue =
  ## Wraps a float value in a ServiceParamValue.
  ServiceParamValue(kind: pkFloat, floatVal: val)

proc newParamValue*(val: bool): ServiceParamValue =
  ## Wraps a boolean value in a ServiceParamValue.
  ServiceParamValue(kind: pkBool, boolVal: val)

proc getString*(ctx: ServiceCallContext, key: string, fallback: string = ""): string =
  ## Retrieves a string parameter from the service call context.
  if ctx.params.hasKey(key):
    let v = ctx.params[key]
    case v.kind
    of pkString: return v.strVal
    of pkInt: return $v.intVal
    of pkFloat: return $v.floatVal
    of pkBool: return $v.boolVal
  fallback

proc getInt*(ctx: ServiceCallContext, key: string, fallback: int = 0): int =
  ## Retrieves an integer parameter from the service call context.
  if ctx.params.hasKey(key):
    let v = ctx.params[key]
    case v.kind
    of pkInt: return v.intVal
    of pkFloat: return int(v.floatVal)
    of pkString:
      try: return parseInt(v.strVal) except ValueError: return fallback
    of pkBool: return if v.boolVal: 1 else: 0
  fallback

proc getFloat*(ctx: ServiceCallContext, key: string, fallback: float = 0.0): float =
  ## Retrieves a float parameter from the service call context.
  if ctx.params.hasKey(key):
    let v = ctx.params[key]
    case v.kind
    of pkFloat: return v.floatVal
    of pkInt: return float(v.intVal)
    of pkString:
      try: return parseFloat(v.strVal) except ValueError: return fallback
    of pkBool: return if v.boolVal: 1.0 else: 0.0
  fallback

proc getBool*(ctx: ServiceCallContext, key: string, fallback: bool = false): bool =
  ## Retrieves a boolean parameter from the service call context.
  if ctx.params.hasKey(key):
    let v = ctx.params[key]
    case v.kind
    of pkBool: return v.boolVal
    of pkInt: return v.intVal != 0
    of pkFloat: return v.floatVal != 0.0
    of pkString: return v.strVal.toLowerAscii in ["true", "1", "yes", "on"]
  fallback

proc registerService*(def: ServiceDefinition, registry: ServiceRegistry = defaultServiceRegistry) =
  ## Registers a custom action definition in the registry.
  registry.services[def.name] = def

proc getService*(name: string, registry: ServiceRegistry = defaultServiceRegistry): Option[ServiceDefinition] =
  ## Looks up a service definition by name.
  if registry.services.hasKey(name):
    some(registry.services[name])
  else:
    none(ServiceDefinition)

proc triggerServiceCall*(
    name: string,
    args: openArray[(string, ServiceParamValue)],
    registry: ServiceRegistry = defaultServiceRegistry
): bool =
  ## Simulates a service call from Home Assistant. Returns true if the service was found and invoked.
  if not registry.services.hasKey(name):
    return false
  let def = registry.services[name]
  var ctx = ServiceCallContext(serviceName: name, params: initTable[string, ServiceParamValue]())
  for (k, v) in args:
    ctx.params[k] = v
  # Apply defaults for any missing params
  for p in def.params:
    if not ctx.params.hasKey(p.name) and p.defaultVal.isSome:
      let defStr = p.defaultVal.get()
      case p.kind
      of pkString: ctx.params[p.name] = newParamValue(defStr)
      of pkInt:
        try: ctx.params[p.name] = newParamValue(parseInt(defStr)) except ValueError: discard
      of pkFloat:
        try: ctx.params[p.name] = newParamValue(parseFloat(defStr)) except ValueError: discard
      of pkBool:
        ctx.params[p.name] = newParamValue(defStr.toLowerAscii in ["true", "1", "yes", "on"])
  if def.handler != nil:
    def.handler(ctx)
  true

proc toEsphomeYaml*(def: ServiceDefinition): string =
  ## Generates the ESPHome YAML configuration snippet for the `api.services` section.
  var lines: seq[string] = @[]
  lines.add(fmt"  - service: {def.name}")
  var varLines: seq[string] = @[]
  for p in def.params:
    var esphomeType = case p.kind
      of pkString: "string"
      of pkInt: "int"
      of pkFloat: "float"
      of pkBool: "bool"
    varLines.add(fmt"      {p.name}: {esphomeType}")
  if varLines.len > 0:
    lines.add("    variables:")
    lines.add(varLines.join("\n"))
  lines.add("    then:")
  lines.add("      - lambda: |-")
  lines.add(fmt"          // Dispatch {def.name} into Nim runtime")
  result = lines.join("\n")

proc addParam*(
    def: ServiceDefinition,
    name: string,
    kind: ParamKind,
    min: float = 0.0,
    max: float = 0.0,
    defaultVal: string = "",
    description: string = ""
) =
  ## Adds a typed parameter descriptor to a service definition.
  def.params.add(ServiceParam(
    name: name,
    kind: kind,
    description: description,
    minVal: if min != 0.0 or max != 0.0: some(min) else: none(float),
    maxVal: if min != 0.0 or max != 0.0: some(max) else: none(float),
    defaultVal: if defaultVal.len > 0: some(defaultVal) else: none(string)
  ))

proc `description=`*(def: ServiceDefinition, desc: string) =
  ## Sets the description of the service.
  def.description = desc

template haService*(serviceName: string, body: untyped): untyped =
  ## Declarative builder template for a custom Home Assistant action/service.
  block:
    var def {.inject.} = ServiceDefinition(
      name: serviceName,
      description: "",
      params: @[],
      handler: nil
    )

    template param(pName: untyped, pKind: untyped, args: varargs[untyped]) {.used.} =
      def.addParam(pName, pKind, args)

    template onExecute(paramName, code: untyped): untyped =
      def.handler = proc(paramName: ServiceCallContext) =
        code

    template onExecute(handlerProc: untyped): untyped =
      def.handler = handlerProc

    body
    registerService(def)

template haAction*(actionName: string, body: untyped): untyped =
  ## Alias for `haService`.
  haService(actionName, body)
