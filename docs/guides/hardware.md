# Hardware Buses (GPIO & I2C)

This guide covers direct microcontroller pin control and I2C peripheral bus communication using `nim-esphome`.

---

## GPIO Pin Manipulation

The `nim_esphome/gpio` module provides hardware pin control without needing external C++ libraries.

### Pin Modes
Microcontroller pins can be configured into four standard electrical modes:
- `Input`: High-impedance floating digital input.
- `Output`: Low-impedance push-pull digital output.
- `InputPullup`: Input with internal weak pull-up resistor connected to 3.3V.
- `InputPulldown`: Input with internal weak pull-down resistor connected to GND.

### Basic GPIO Example
```nim
import nim_esphome

const
  ButtonPin = 0'u8
  RelayPin = 18'u8

esphomeSetup:
  # Configure button as input with pullup
  pinMode(ButtonPin, InputPullup)

  # Configure relay as push-pull output
  pinMode(RelayPin, Output)
  digitalWrite(RelayPin, Low)

esphomeLoop:
  let buttonVal: PinState = digitalRead(ButtonPin)
  if buttonVal == Low: # Pressed (active-low)
    digitalWrite(RelayPin, High)
  else:
    digitalWrite(RelayPin, Low)
```

---

## I2C Bus Transfers

The `nim_esphome/i2c` module provides communication with peripheral ICs over the microcontroller's I2C bus (accelerometers, barometers, DACs, displays, cryptographic chips).

### Instantiating an I2C Device
Create an `I2CDevice` handle by passing its 7-bit bus address:

```nim
import nim_esphome

# 0x68 is the standard I2C address for MPU6050 accelerometer
let imu = newI2CDevice(0x68'u8)
```

### Writing to Registers
You can write single configuration bytes or multi-byte buffers:

```nim
# Wake up sensor by clearing SLEEP bit in power management register 0x6B
discard imu.writeByte(0x6B'u8, 0x00'u8)

# Configure gyro range register 0x1B with a 2-byte sequence
discard imu.writeRegister(0x1B'u8, [0x08'u8, 0x00'u8])
```

### Reading from Registers
Read raw bytes or register contents via combined write-read restart transactions:

```nim
# Read WHO_AM_I register (0x75)
let whoAmI: uint8 = imu.readByte(0x75'u8)
info("IMU", "Device WHO_AM_I signature: 0x" & whoAmI.toHex(2))

# Read 6 consecutive bytes (X, Y, Z accelerometer registers starting at 0x3B)
let rawBytes = imu.readRegister(0x3B'u8, 6)
if rawBytes.len == 6:
  let rawAccelX = (int16(rawBytes[0]) shl 8) or int16(rawBytes[1])
  let rawAccelY = (int16(rawBytes[2]) shl 8) or int16(rawBytes[3])
  let rawAccelZ = (int16(rawBytes[4]) shl 8) or int16(rawBytes[5])
  info("IMU", "Accel X: " & $rawAccelX & " Y: " & $rawAccelY & " Z: " & $rawAccelZ)
```

### Host Mocking for Unit Tests
When running tests on your host development machine (`nim c -r tests/test_peripherals.nim`), `nim-esphome` routes all I2C calls to an in-memory hash table. You can simulate sensor register responses without attaching hardware.
