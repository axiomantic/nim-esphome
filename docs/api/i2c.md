# Module: `nim_esphome/i2c`

Hardware I2C bus transactions, register reads/writes, and multi-byte sensor transfers.

---

## Types

### `I2CDevice`
```nim
type
  I2CDevice* = object
    address*: uint8
```
Handle to an I2C peripheral slave device identified by its 7-bit bus address.

---

## Constructors

### `newI2CDevice`
```nim
proc newI2CDevice*(address: uint8): I2CDevice
```
Creates a handle to an I2C slave device at the given 7-bit bus `address`.

---

## Procedures

### `write`
```nim
proc write*(dev: I2CDevice, data: openArray[uint8]): bool
```
Transmits a raw buffer of bytes `data` to the I2C device. Returns `true` if all bytes were acknowledged (ACK) by the device.

---

### `writeRegister`
```nim
proc writeRegister*(dev: I2CDevice, reg: uint8, data: openArray[uint8]): bool
```
Writes a multi-byte payload `data` into register `reg` of the I2C device.

---

### `writeByte`
```nim
proc writeByte*(dev: I2CDevice, reg: uint8, val: uint8): bool
```
Convenience helper to write a single 8-bit value `val` into register `reg`.

---

### `read`
```nim
proc read*(dev: I2CDevice, len: int): seq[uint8]
```
Reads `len` raw bytes from the I2C device. Returns an empty sequence if communication fails.

---

### `readRegister`
```nim
proc readRegister*(dev: I2CDevice, reg: uint8, len: int): seq[uint8]
```
Performs a combined write-restart-read transaction: writes register `reg` and immediately reads `len` bytes back from the device.

---

### `readByte`
```nim
proc readByte*(dev: I2CDevice, reg: uint8): uint8
```
Convenience helper to read a single 8-bit byte from register `reg`. Returns 0 on read failure.
