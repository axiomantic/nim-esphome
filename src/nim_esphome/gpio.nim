## `nim_esphome/gpio`: Direct GPIO pin manipulation for microcontrollers.
##
## Provides type-safe hardware abstraction for configuring microcontroller pins
## and performing digital reads/writes with zero runtime overhead.

type
  PinMode* = enum
    ## Operating mode for a microcontroller GPIO pin.
    Input = 0          ## High-impedance digital input.
    Output = 1         ## Push-pull digital output.
    InputPullup = 2    ## Digital input with internal pull-up resistor enabled.
    InputPulldown = 3  ## Digital input with internal pull-down resistor enabled.

  PinState* = enum
    ## Digital logic level of a GPIO pin.
    Low = 0   ## 0V / GND logic low.
    High = 1  ## VCC / 3.3V logic high.

when defined(esphome):
  proc nim_gpio_pin_mode(pin: uint8, mode: uint8) {.importc, cdecl.}
  proc nim_gpio_digital_write(pin: uint8, val: bool) {.importc, cdecl.}
  proc nim_gpio_digital_read(pin: uint8): bool {.importc, cdecl.}

  proc pinMode*(pin: uint8, mode: PinMode) =
    ## Configures the electrical mode (`Input`, `Output`, `InputPullup`, `InputPulldown`)
    ## of the specified GPIO `pin`.
    nim_gpio_pin_mode(pin, uint8(ord(mode)))

  proc digitalWrite*(pin: uint8, state: PinState) =
    ## Writes a digital logic level (`High` or `Low`) to the specified GPIO `pin`.
    nim_gpio_digital_write(pin, state == High)

  proc digitalWrite*(pin: uint8, val: bool) =
    ## Convenience overload writing a boolean state (`true` -> `High`, `false` -> `Low`)
    ## to the specified GPIO `pin`.
    nim_gpio_digital_write(pin, val)

  proc digitalRead*(pin: uint8): PinState =
    ## Reads and returns the current digital logic level (`High` or `Low`) of `pin`.
    if nim_gpio_digital_read(pin): High else: Low
else:
  import std/tables
  var
    gpioModes* = initTable[uint8, PinMode]()
    gpioStates* = initTable[uint8, PinState]()

  proc pinMode*(pin: uint8, mode: PinMode) =
    ## Configures GPIO mode in host mock table.
    gpioModes[pin] = mode

  proc digitalWrite*(pin: uint8, state: PinState) =
    ## Writes GPIO state to host mock table.
    gpioStates[pin] = state

  proc digitalWrite*(pin: uint8, val: bool) =
    ## Writes boolean GPIO state to host mock table.
    gpioStates[pin] = if val: High else: Low

  proc digitalRead*(pin: uint8): PinState =
    ## Reads GPIO state from host mock table.
    gpioStates.getOrDefault(pin, Low)

