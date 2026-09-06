proc fnv1a*(s: string): uint32 =
  var hash = 2166136261'u32
  for c in s:
    hash = (hash xor uint32(ord(c))) * 16777619'u32
  hash

when defined(esphome):
  proc nim_esp_save_preference(key: uint32, data: pointer, len: csize_t): bool {.importc, cdecl.}
  proc nim_esp_load_preference(key: uint32, data: pointer, len: csize_t): bool {.importc, cdecl.}

  proc savePreference*[T](key: uint32, val: T): bool =
    var copyVal = val
    nim_esp_save_preference(key, addr copyVal, csize_t(sizeof(T)))

  proc savePreference*[T](key: string, val: T): bool =
    savePreference(fnv1a(key), val)

  proc loadPreference*[T](key: uint32, defaultVal: T): T =
    var val: T
    if nim_esp_load_preference(key, addr val, csize_t(sizeof(T))):
      val
    else:
      defaultVal

  proc loadPreference*[T](key: string, defaultVal: T): T =
    loadPreference(fnv1a(key), defaultVal)

  proc savePreference*(key: uint32, val: string): bool =
    var buf = newSeq[uint8](val.len + 1)
    if val.len > 0:
      copyMem(addr buf[0], unsafeAddr val[0], val.len)
    buf[val.len] = 0'u8
    nim_esp_save_preference(key, addr buf[0], csize_t(buf.len))

  proc savePreference*(key: string, val: string): bool =
    savePreference(fnv1a(key), val)

  proc loadPreference*(key: uint32, defaultVal: string, maxLen: int = 128): string =
    var buf = newSeq[uint8](maxLen + 1)
    if nim_esp_load_preference(key, addr buf[0], csize_t(buf.len)):
      var strLen = 0
      while strLen < maxLen and buf[strLen] != 0'u8:
        inc strLen
      var res = newString(strLen)
      if strLen > 0:
        copyMem(addr res[0], addr buf[0], strLen)
      res
    else:
      defaultVal

  proc loadPreference*(key: string, defaultVal: string, maxLen: int = 128): string =
    loadPreference(fnv1a(key), defaultVal, maxLen)
else:
  import std/tables
  var mockPreferences* = initTable[uint32, seq[byte]]()

  proc savePreference*[T](key: uint32, val: T): bool =
    var buf = newSeq[byte](sizeof(T))
    if sizeof(T) > 0:
      var copyVal = val
      copyMem(addr buf[0], addr copyVal, sizeof(T))
    mockPreferences[key] = buf
    true

  proc savePreference*[T](key: string, val: T): bool =
    savePreference(fnv1a(key), val)

  proc loadPreference*[T](key: uint32, defaultVal: T): T =
    if mockPreferences.hasKey(key):
      let buf = mockPreferences[key]
      if buf.len == sizeof(T) and sizeof(T) > 0:
        var res: T
        copyMem(addr res, unsafeAddr buf[0], sizeof(T))
        return res
    defaultVal

  proc loadPreference*[T](key: string, defaultVal: T): T =
    loadPreference(fnv1a(key), defaultVal)

  proc savePreference*(key: uint32, val: string): bool =
    var buf = newSeq[byte](val.len)
    if val.len > 0:
      copyMem(addr buf[0], unsafeAddr val[0], val.len)
    mockPreferences[key] = buf
    true

  proc savePreference*(key: string, val: string): bool =
    savePreference(fnv1a(key), val)

  proc loadPreference*(key: uint32, defaultVal: string, maxLen: int = 128): string =
    if mockPreferences.hasKey(key):
      let buf = mockPreferences[key]
      var res = newString(buf.len)
      if buf.len > 0:
        copyMem(addr res[0], unsafeAddr buf[0], buf.len)
      res
    else:
      defaultVal

  proc loadPreference*(key: string, defaultVal: string, maxLen: int = 128): string =
    loadPreference(fnv1a(key), defaultVal, maxLen)
