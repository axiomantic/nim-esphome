import std/macros
import nim_esphome/api
import nim_esphome/entities
import nim_esphome/gpio
import nim_esphome/i2c
import nim_esphome/preferences

export api
export entities
export gpio
export i2c
export preferences

template esphomeSetup*(body: untyped) =
  proc nim_on_setup() {.exportc: "nim_on_setup", cdecl.} =
    body

template esphomeLoop*(body: untyped) =
  proc nim_on_loop() {.exportc: "nim_on_loop", cdecl.} =
    body

macro exportEsphome*(def: untyped): untyped =
  ## Decorates a procedure with exportc and cdecl so ESPHome lambdas and C++ can call it directly.
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
