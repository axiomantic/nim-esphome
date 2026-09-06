## `nim_esphome/api`: Core ESPHome C++ runtime bindings and hardware utilities.
##
## Provides low-overhead access to ESPHome's logging macros, high-resolution hardware timers,
## RTOS task scheduling, watchdog feeding, heap inspection, and system restart.

type ConstCString* {.importc: "const char*".} = cstring
  ## Immutable C string pointer mapped directly to C++ `const char*`.
  ## Prevents `-Wwrite-strings` compiler warnings when passing string literals to C++ APIs.

when defined(esphome):
  proc nim_esp_log_i*(tag, msg: ConstCString) {.importc: "nim_esp_log_i", cdecl.}
  proc nim_esp_log_w*(tag, msg: ConstCString) {.importc: "nim_esp_log_w", cdecl.}
  proc nim_esp_log_e*(tag, msg: ConstCString) {.importc: "nim_esp_log_e", cdecl.}
  proc nim_esp_log_d*(tag, msg: ConstCString) {.importc: "nim_esp_log_d", cdecl.}

  proc millis*(): uint32 {.importc: "nim_esp_millis", cdecl.}
    ## Returns the number of milliseconds elapsed since microcontroller boot.
  proc micros*(): uint32 {.importc: "nim_esp_micros", cdecl.}
    ## Returns the number of microseconds elapsed since microcontroller boot.
  proc delayMs*(ms: uint32) {.importc: "nim_esp_delay", cdecl.}
    ## Delays execution for `ms` milliseconds.
  proc yieldToScheduler*() {.importc: "nim_esp_yield", cdecl.}
    ## Yields execution to FreeRTOS and other cooperative background tasks.
  proc feedWatchdog*() {.importc: "nim_esp_feed_wdt", cdecl.}
    ## Feeds the hardware / task watchdog timer to prevent spurious reboot during long loops.
  proc getFreeHeap*(): uint32 {.importc: "nim_esp_get_free_heap", cdecl.}
    ## Returns the currently available free heap memory in bytes.
  proc reboot*() {.importc: "nim_esp_reboot", cdecl.}
    ## Triggers an immediate hardware reboot of the microcontroller.
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
    ## Returns the number of milliseconds elapsed since process start (mocked on host).
    uint32(epochTime() * 1000.0)

  proc micros*(): uint32 =
    ## Returns the number of microseconds elapsed since process start (mocked on host).
    uint32(epochTime() * 1000000.0)

  proc delayMs*(ms: uint32) =
    ## Delays execution for `ms` milliseconds (mocked on host via os.sleep).
    os.sleep(int(ms))

  proc yieldToScheduler*() =
    ## Yields execution to scheduler (no-op on host).
    discard

  proc feedWatchdog*() =
    ## Feeds watchdog timer (no-op on host).
    discard

  proc getFreeHeap*(): uint32 =
    ## Returns simulated free heap memory (1MB on host).
    1024'u32 * 1024'u32 # 1MB mock heap

  proc reboot*() =
    ## Simulates reboot request on host.
    echo "[SYSTEM] Reboot requested"

template info*(tag: string, msg: string) =
  ## Logs an informational message with the given `tag` using ESPHome's `ESP_LOGI`.
  nim_esp_log_i(cstring(tag), cstring(msg))

template warn*(tag: string, msg: string) =
  ## Logs a warning message with the given `tag` using ESPHome's `ESP_LOGW`.
  nim_esp_log_w(cstring(tag), cstring(msg))

template error*(tag: string, msg: string) =
  ## Logs an error message with the given `tag` using ESPHome's `ESP_LOGE`.
  nim_esp_log_e(cstring(tag), cstring(msg))

template debug*(tag: string, msg: string) =
  ## Logs a debug message with the given `tag` using ESPHome's `ESP_LOGD`.
  nim_esp_log_d(cstring(tag), cstring(msg))

