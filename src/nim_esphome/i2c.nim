type
  I2CDevice* = object
    address*: uint8

proc newI2CDevice*(address: uint8): I2CDevice {.inline.} =
  I2CDevice(address: address)

when defined(esphome):
  proc nim_i2c_write(address: uint8, data: ptr uint8, len: csize_t): bool {.importc, cdecl.}
  proc nim_i2c_read(address: uint8, data: ptr uint8, len: csize_t): bool {.importc, cdecl.}
  proc nim_i2c_write_read(address: uint8, writeData: ptr uint8, writeLen: csize_t, readData: ptr uint8, readLen: csize_t): bool {.importc, cdecl.}

  proc write*(dev: I2CDevice, data: openArray[uint8]): bool =
    if data.len == 0: return true
    nim_i2c_write(dev.address, unsafeAddr data[0], csize_t(data.len))

  proc writeRegister*(dev: I2CDevice, reg: uint8, data: openArray[uint8]): bool =
    var buf = newSeq[uint8](data.len + 1)
    buf[0] = reg
    if data.len > 0:
      copyMem(addr buf[1], unsafeAddr data[0], data.len)
    dev.write(buf)

  proc writeByte*(dev: I2CDevice, reg: uint8, val: uint8): bool =
    dev.writeRegister(reg, [val])

  proc read*(dev: I2CDevice, len: int): seq[uint8] =
    result = newSeq[uint8](len)
    if len > 0:
      let ok = nim_i2c_read(dev.address, addr result[0], csize_t(len))
      if not ok:
        result.setLen(0)

  proc readRegister*(dev: I2CDevice, reg: uint8, len: int): seq[uint8] =
    result = newSeq[uint8](len)
    var regByte = reg
    let ok = nim_i2c_write_read(dev.address, addr regByte, 1, if len > 0: addr result[0] else: nil, csize_t(len))
    if not ok:
      result.setLen(0)

  proc readByte*(dev: I2CDevice, reg: uint8): uint8 =
    let res = dev.readRegister(reg, 1)
    if res.len > 0: res[0] else: 0'u8
else:
  import std/tables
  var
    i2cRegisters* = initTable[string, seq[uint8]]()

  proc regKey(addrNum, reg: uint8): string = $addrNum & ":" & $reg

  proc write*(dev: I2CDevice, data: openArray[uint8]): bool =
    if data.len >= 1:
      let reg = data[0]
      var vals = newSeq[uint8](data.len - 1)
      for i in 1 ..< data.len:
        vals[i - 1] = data[i]
      i2cRegisters[regKey(dev.address, reg)] = vals
    true

  proc writeRegister*(dev: I2CDevice, reg: uint8, data: openArray[uint8]): bool =
    var vals = newSeq[uint8](data.len)
    for i in 0 ..< data.len:
      vals[i] = data[i]
    i2cRegisters[regKey(dev.address, reg)] = vals
    true

  proc writeByte*(dev: I2CDevice, reg: uint8, val: uint8): bool =
    dev.writeRegister(reg, [val])

  proc read*(dev: I2CDevice, len: int): seq[uint8] =
    newSeq[uint8](len)

  proc readRegister*(dev: I2CDevice, reg: uint8, len: int): seq[uint8] =
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
    let res = dev.readRegister(reg, 1)
    if res.len > 0: res[0] else: 0'u8
