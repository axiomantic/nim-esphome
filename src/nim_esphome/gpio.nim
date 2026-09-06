type
  PinMode* = enum
    Input = 0
    Output = 1
    InputPullup = 2
    InputPulldown = 3

  PinState* = enum
    Low = 0
    High = 1

when defined(esphome):
  proc nim_gpio_pin_mode(pin: uint8, mode: uint8) {.importc, cdecl.}
  proc nim_gpio_digital_write(pin: uint8, val: bool) {.importc, cdecl.}
  proc nim_gpio_digital_read(pin: uint8): bool {.importc, cdecl.}

  proc pinMode*(pin: uint8, mode: PinMode) =
    nim_gpio_pin_mode(pin, uint8(ord(mode)))

  proc digitalWrite*(pin: uint8, state: PinState) =
    nim_gpio_digital_write(pin, state == High)

  proc digitalWrite*(pin: uint8, val: bool) =
    nim_gpio_digital_write(pin, val)

  proc digitalRead*(pin: uint8): PinState =
    if nim_gpio_digital_read(pin): High else: Low
else:
  import std/tables
  var
    gpioModes* = initTable[uint8, PinMode]()
    gpioStates* = initTable[uint8, PinState]()

  proc pinMode*(pin: uint8, mode: PinMode) =
    gpioModes[pin] = mode

  proc digitalWrite*(pin: uint8, state: PinState) =
    gpioStates[pin] = state

  proc digitalWrite*(pin: uint8, val: bool) =
    gpioStates[pin] = if val: High else: Low

  proc digitalRead*(pin: uint8): PinState =
    gpioStates.getOrDefault(pin, Low)
