## C++ interop bridge to ESPHome runtime APIs

when defined(esphome):
  proc nim_esp_log_i*(tag, msg: cstring) {.importc: "nim_esp_log_i", cdecl.}
  proc nim_esp_log_w*(tag, msg: cstring) {.importc: "nim_esp_log_w", cdecl.}
  proc nim_esp_log_e*(tag, msg: cstring) {.importc: "nim_esp_log_e", cdecl.}
  proc nim_esp_log_d*(tag, msg: cstring) {.importc: "nim_esp_log_d", cdecl.}

  proc millis*(): uint32 {.importc: "nim_esp_millis", cdecl.}
  proc micros*(): uint32 {.importc: "nim_esp_micros", cdecl.}
  proc delayMs*(ms: uint32) {.importc: "nim_esp_delay", cdecl.}
else:
  import std/times
  import std/os

  proc nim_esp_log_i*(tag, msg: cstring) =
    echo "[INFO]  [", tag, "] ", msg

  proc nim_esp_log_w*(tag, msg: cstring) =
    echo "[WARN]  [", tag, "] ", msg

  proc nim_esp_log_e*(tag, msg: cstring) =
    echo "[ERROR] [", tag, "] ", msg

  proc nim_esp_log_d*(tag, msg: cstring) =
    echo "[DEBUG] [", tag, "] ", msg

  proc millis*(): uint32 =
    uint32(epochTime() * 1000.0)

  proc micros*(): uint32 =
    uint32(epochTime() * 1000000.0)

  proc delayMs*(ms: uint32) =
    os.sleep(int(ms))

template info*(tag: string, msg: string) =
  nim_esp_log_i(cstring(tag), cstring(msg))

template warn*(tag: string, msg: string) =
  nim_esp_log_w(cstring(tag), cstring(msg))

template error*(tag: string, msg: string) =
  nim_esp_log_e(cstring(tag), cstring(msg))

template debug*(tag: string, msg: string) =
  nim_esp_log_d(cstring(tag), cstring(msg))
