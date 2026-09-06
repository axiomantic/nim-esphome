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

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `address` | `uint8` | 7-bit peripheral slave address. |

**Returns:**
- `I2CDevice`: A new `I2CDevice` handle.

---

## Procedures

### `write`
```nim
proc write*(dev: I2CDevice, data: openArray[uint8]): bool
```
Transmits a raw buffer of bytes `data` to the I2C device.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `dev` | `I2CDevice` | Target `I2CDevice` peripheral. |
| `data` | `openArray[uint8]` | Bytes to transmit over the bus. |

**Returns:**
- `bool`: `true` if device acknowledged all transmitted bytes.

---

### `writeRegister`
```nim
proc writeRegister*(dev: I2CDevice, reg: uint8, data: openArray[uint8]): bool
```
Writes a multi-byte payload `data` into register `reg` of the I2C device.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `dev` | `I2CDevice` | Target `I2CDevice` peripheral. |
| `reg` | `uint8` | 8-bit register address. |
| `data` | `openArray[uint8]` | Bytes to write into the register. |

**Returns:**
- `bool`: `true` if write transaction succeeded.

---

### `writeByte`
```nim
proc writeByte*(dev: I2CDevice, reg: uint8, val: uint8): bool
```
Convenience helper to write a single 8-bit value `val` into register `reg`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `dev` | `I2CDevice` | Target `I2CDevice` peripheral. |
| `reg` | `uint8` | 8-bit register address. |
| `val` | `uint8` | 8-bit value to store. |

**Returns:**
- `bool`: `true` if write transaction succeeded.

---

### `read`
```nim
proc read*(dev: I2CDevice, len: int): seq[uint8]
```
Reads `len` raw bytes from the I2C device.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `dev` | `I2CDevice` | Target `I2CDevice` peripheral. |
| `len` | `int` | Number of bytes to read. |

**Returns:**
- `seq[uint8]`: Sequence containing read bytes, or empty seq on error.

---

### `readRegister`
```nim
proc readRegister*(dev: I2CDevice, reg: uint8, len: int): seq[uint8]
```
Performs a combined write-restart-read transaction: writes register `reg` and immediately reads `len` bytes back from the device.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `dev` | `I2CDevice` | Target `I2CDevice` peripheral. |
| `reg` | `uint8` | 8-bit register address to read from. |
| `len` | `int` | Number of bytes to read. |

**Returns:**
- `seq[uint8]`: Sequence containing read bytes, or empty seq on error.

---

### `readByte`
```nim
proc readByte*(dev: I2CDevice, reg: uint8): uint8
```
Convenience helper to read a single 8-bit byte from register `reg`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `dev` | `I2CDevice` | Target `I2CDevice` peripheral. |
| `reg` | `uint8` | 8-bit register address to read from. |

**Returns:**
- `uint8`: 8-bit byte read, or 0 on error.
