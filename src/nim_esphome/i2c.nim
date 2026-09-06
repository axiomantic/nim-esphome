## `nim_esphome/i2c`: Hardware I2C bus transactions and peripheral communication.
##
## Provides ergonomic, zero-copy wrappers around ESPHome's internal I2C bus driver
## for reading and writing peripheral registers, sensors, and DACs.

type
  I2CDevice* = object
    ## Handle to an I2C peripheral slave device identified by its 7-bit address.
    address*: uint8

proc newI2CDevice*(address: uint8): I2CDevice {.inline.} =
  ## Creates a handle to an I2C device at the specified 7-bit bus `address`.
  ##
  ## :param address: 7-bit peripheral slave address.
  ## :returns: A new `I2CDevice` handle.
  I2CDevice(address: address)

when defined(esphome):
  proc nim_i2c_write(address: uint8, data: ptr uint8, len: csize_t): bool {.importc, cdecl.}
  proc nim_i2c_read(address: uint8, data: ptr uint8, len: csize_t): bool {.importc, cdecl.}
  proc nim_i2c_write_read(address: uint8, writeData: ptr uint8, writeLen: csize_t, readData: ptr uint8, readLen: csize_t): bool {.importc, cdecl.}

  proc write*(dev: I2CDevice, data: openArray[uint8]): bool =
    ## Transmits a raw buffer of bytes `data` to the I2C device.
    ## Returns `true` if all bytes were acknowledged (ACK) by the device.
    ##
    ## :param dev: Target `I2CDevice` peripheral.
    ## :param data: Bytes to transmit over the bus.
    ## :returns: `true` if device acknowledged all transmitted bytes.
    if data.len == 0: return true
    nim_i2c_write(dev.address, unsafeAddr data[0], csize_t(data.len))

  proc writeRegister*(dev: I2CDevice, reg: uint8, data: openArray[uint8]): bool =
    ## Writes a multi-byte payload `data` into register `reg` of the I2C device.
    ##
    ## :param dev: Target `I2CDevice` peripheral.
    ## :param reg: 8-bit register address.
    ## :param data: Bytes to write into the register.
    ## :returns: `true` if write transaction succeeded.
    var buf = newSeq[uint8](data.len + 1)
    buf[0] = reg
    if data.len > 0:
      copyMem(addr buf[1], unsafeAddr data[0], data.len)
    dev.write(buf)

  proc writeByte*(dev: I2CDevice, reg: uint8, val: uint8): bool =
    ## Convenience helper to write a single 8-bit value `val` into register `reg`.
    ##
    ## :param dev: Target `I2CDevice` peripheral.
    ## :param reg: 8-bit register address.
    ## :param val: 8-bit value to store.
    ## :returns: `true` if write transaction succeeded.
    dev.writeRegister(reg, [val])

  proc read*(dev: I2CDevice, len: int): seq[uint8] =
    ## Reads `len` raw bytes from the I2C device.
    ## Returns an empty sequence if communication fails or NACK is received.
    ##
    ## :param dev: Target `I2CDevice` peripheral.
    ## :param len: Number of bytes to read.
    ## :returns: Sequence containing read bytes, or empty seq on error.
    result = newSeq[uint8](len)
    if len > 0:
      let ok = nim_i2c_read(dev.address, addr result[0], csize_t(len))
      if not ok:
        result.setLen(0)

  proc readRegister*(dev: I2CDevice, reg: uint8, len: int): seq[uint8] =
    ## Performs a combined write-restart-read transaction: writes register `reg`
    ## and immediately reads `len` bytes back from the device.
    ##
    ## :param dev: Target `I2CDevice` peripheral.
    ## :param reg: 8-bit register address to read from.
    ## :param len: Number of bytes to read.
    ## :returns: Sequence containing read bytes, or empty seq on error.
    result = newSeq[uint8](len)
    var regByte = reg
    let ok = nim_i2c_write_read(dev.address, addr regByte, 1, if len > 0: addr result[0] else: nil, csize_t(len))
    if not ok:
      result.setLen(0)

  proc readByte*(dev: I2CDevice, reg: uint8): uint8 =
    ## Convenience helper to read a single 8-bit byte from register `reg`.
    ## Returns 0 on read failure.
    ##
    ## :param dev: Target `I2CDevice` peripheral.
    ## :param reg: 8-bit register address to read from.
    ## :returns: 8-bit byte read, or 0 on error.
    let res = dev.readRegister(reg, 1)
    if res.len > 0: res[0] else: 0'u8

else:
  import std/tables
  var
    i2cRegisters* = initTable[string, seq[uint8]]()

  proc regKey(addrNum, reg: uint8): string = $addrNum & ":" & $reg

  proc write*(dev: I2CDevice, data: openArray[uint8]): bool =
    ## Simulates raw I2C write on host mock table.
    if data.len >= 1:
      let reg = data[0]
      var vals = newSeq[uint8](data.len - 1)
      for i in 1 ..< data.len:
        vals[i - 1] = data[i]
      i2cRegisters[regKey(dev.address, reg)] = vals
    true

  proc writeRegister*(dev: I2CDevice, reg: uint8, data: openArray[uint8]): bool =
    ## Simulates register write on host mock table.
    var vals = newSeq[uint8](data.len)
    for i in 0 ..< data.len:
      vals[i] = data[i]
    i2cRegisters[regKey(dev.address, reg)] = vals
    true

  proc writeByte*(dev: I2CDevice, reg: uint8, val: uint8): bool =
    ## Simulates single byte register write on host mock table.
    dev.writeRegister(reg, [val])

  proc read*(dev: I2CDevice, len: int): seq[uint8] =
    ## Simulates raw read on host mock table.
    newSeq[uint8](len)

  proc readRegister*(dev: I2CDevice, reg: uint8, len: int): seq[uint8] =
    ## Simulates register read from host mock table.
    let k = regKey(dev.address, reg)
    if i2cRegisters.hasKey(k):
      let val = i2cRegisters[k]
      if val.len >= len:
        return val[0 ..< len]
      else:
        var r = val
        r.setLen(len)
        return r
    newSeq[uint8](len)

  proc readByte*(dev: I2CDevice, reg: uint8): uint8 =
    ## Simulates single byte register read from host mock table.
    let res = dev.readRegister(reg, 1)
    if res.len > 0: res[0] else: 0'u8

