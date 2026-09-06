## `nim_esphome/dsl/entities`: Declarative DSL for Home Assistant entities and controls.
##
## Provides the `esphomeControls` macro to define Home Assistant UI controls
## (`select`, `number`, `switch`, `button`) with type safety, default values,
## reactive callbacks, and optional Flash NVS persistence.

import std/macros
import nim_esphome/entities
import nim_esphome/preferences

macro esphomeControls*(body: untyped): untyped =
  ## Declarative block defining Home Assistant entities and callbacks.
  result = newStmtList()

  for item in body:
    if item.kind notin {nnkCall, nnkCommand}:
      continue

    let head = item[0]
    let entityId = item[1]
    let blockBody = item[2]

    var defaultVal: NimNode = nil
    var minVal = newLit(0.0'f32)
    var maxVal = newLit(100.0'f32)
    var stepVal = newLit(1.0'f32)
    var persistVal = false
    var callbackParam: NimNode = nil
    var callbackBody: NimNode = nil

    for stmt in blockBody:
      var fieldName = ""
      var fieldVal: NimNode = nil

      if stmt.kind == nnkAsgn:
        fieldName = stmt[0].strVal
        fieldVal = stmt[1]
      elif stmt.kind in {nnkCall, nnkCommand} and stmt.len == 3 and stmt[0].kind == nnkIdent and stmt[0].strVal == "=":
        fieldName = stmt[1].strVal
        fieldVal = stmt[2]

      if fieldName != "":
        if fieldName == "default":
          defaultVal = fieldVal
        elif fieldName == "min":
          minVal = fieldVal
        elif fieldName == "max":
          maxVal = fieldVal
        elif fieldName == "step":
          stepVal = fieldVal
        elif fieldName == "persist":
          if fieldVal.kind == nnkIdent:
            persistVal = (fieldVal.strVal == "true")
          elif fieldVal.kind == nnkIntLit:
            persistVal = (fieldVal.intVal == 1)
      elif stmt.kind in {nnkCall, nnkCommand}:
        let cbName = stmt[0].strVal
        if cbName in ["onSelect", "onChange", "onToggle"]:
          callbackParam = stmt[1]
          callbackBody = stmt[2]
        elif cbName == "onPress":
          callbackBody = stmt[1]

    # Generate code depending on entity type
    if head.kind == nnkBracketExpr and head[0].strVal == "select":
      let enumType = head[1]
      let entityVar = genSym(nskLet, "selectEntity")
      let cbProc = genSym(nskProc, "onSelectCb")
      
      var setupCode = newStmtList()
      setupCode.add quote do:
        let `entityVar` = newSelect[`enumType`](`entityId`)

      if callbackBody != nil:
        if persistVal and defaultVal != nil:
          setupCode.add quote do:
            proc `cbProc`(`callbackParam`: `enumType`) =
              discard savePreference(`entityId`, `callbackParam`)
              `callbackBody`
            `entityVar`.onState(`cbProc`)
            let initialVal = loadPreference(`entityId`, `defaultVal`)
            `entityVar`.publishState(initialVal)
            `cbProc`(initialVal)
        else:
          setupCode.add quote do:
            `entityVar`.onState(proc(`callbackParam`: `enumType`) =
              `callbackBody`
            )
          if defaultVal != nil:
            setupCode.add quote do:
              `entityVar`.publishState(`defaultVal`)
      result.add(setupCode)

    elif head.kind == nnkIdent and head.strVal == "number":
      let entityVar = genSym(nskLet, "numberEntity")
      let cbProc = genSym(nskProc, "onChangeCb")
      
      var setupCode = newStmtList()
      setupCode.add quote do:
        let `entityVar` = newNumber(`entityId`, float32(`minVal`), float32(`maxVal`), float32(`stepVal`))

      if callbackBody != nil:
        if persistVal and defaultVal != nil:
          setupCode.add quote do:
            proc `cbProc`(`callbackParam`: float32) =
              discard savePreference(`entityId`, `callbackParam`)
              `callbackBody`
            `entityVar`.onState(`cbProc`)
            let initialVal = loadPreference(`entityId`, float32(`defaultVal`))
            `entityVar`.publishState(initialVal)
            `cbProc`(initialVal)
        else:
          setupCode.add quote do:
            `entityVar`.onState(proc(`callbackParam`: float32) =
              `callbackBody`
            )
          if defaultVal != nil:
            setupCode.add quote do:
              `entityVar`.publishState(float32(`defaultVal`))
      result.add(setupCode)

    elif head.kind == nnkIdent and head.strVal == "switch":
      let entityVar = genSym(nskLet, "switchEntity")
      let cbProc = genSym(nskProc, "onToggleCb")
      
      var setupCode = newStmtList()
      setupCode.add quote do:
        let `entityVar` = newSwitch(`entityId`)

      if callbackBody != nil:
        if persistVal and defaultVal != nil:
          setupCode.add quote do:
            proc `cbProc`(`callbackParam`: bool) =
              discard savePreference(`entityId`, `callbackParam`)
              `callbackBody`
            `entityVar`.onState(`cbProc`)
            let initialVal = loadPreference(`entityId`, bool(`defaultVal`))
            `entityVar`.publishState(initialVal)
            `cbProc`(initialVal)
        else:
          setupCode.add quote do:
            `entityVar`.onState(proc(`callbackParam`: bool) =
              `callbackBody`
            )
          if defaultVal != nil:
            setupCode.add quote do:
              `entityVar`.publishState(bool(`defaultVal`))
      result.add(setupCode)

    elif head.kind == nnkIdent and head.strVal == "button":
      let entityVar = genSym(nskLet, "buttonEntity")
      var setupCode = newStmtList()
      setupCode.add quote do:
        let `entityVar` = newButton(`entityId`)

      if callbackBody != nil:
        setupCode.add quote do:
          `entityVar`.onPress(proc() =
            `callbackBody`
          )
      result.add(setupCode)
