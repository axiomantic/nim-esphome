## `nim_esphome/ota`: Over-The-Air (OTA) firmware download and partition writing.
##
## Provides robust, high-level abstractions for streaming remote firmware binaries
## over HTTP/HTTPS into ESP32 OTA app partitions with verification and rollback protection.

import std/strutils
import api
import preferences

proc isValidOtaUrl*(url: string): bool =
  ## Validates that an OTA URL begins with http:// or https:// and has a reasonable length.
  if url.len < 10: return false
  if not (url.startsWith("http://") or url.startsWith("https://")): return false
  true

when defined(esp32) or defined(freertos):
  type
    esp_err_t = cint
    esp_ota_handle_t = uint32
    esp_partition_t {.importc: "const esp_partition_t*", header: "<esp_partition.h>".} = pointer
    esp_http_client_handle_t {.importc: "esp_http_client_handle_t", header: "<esp_http_client.h>".} = pointer

    esp_http_client_config_t {.importc: "esp_http_client_config_t", header: "<esp_http_client.h>", bycopy.} = object
      url: cstring
      timeout_ms: cint
      keep_alive_enable: bool
      buffer_size: cint
      buffer_size_tx: cint
      crt_bundle_attach: pointer
      skip_cert_common_name_check: bool
      max_redirection_count: cint

  const
    ESP_OK = 0.cint
    OTA_WITH_SEQUENTIAL_WRITES = 0xFFFFFFFF'u32

  proc esp_ota_get_next_update_partition(start_from: esp_partition_t): esp_partition_t {.importc: "esp_ota_get_next_update_partition", header: "<esp_ota_ops.h>", cdecl.}
  proc esp_ota_begin(partition: esp_partition_t, image_size: csize_t, out_handle: ptr esp_ota_handle_t): esp_err_t {.importc: "esp_ota_begin", header: "<esp_ota_ops.h>", cdecl.}
  proc esp_ota_write(handle: esp_ota_handle_t, data: pointer, size: csize_t): esp_err_t {.importc: "esp_ota_write", header: "<esp_ota_ops.h>", cdecl.}
  proc esp_ota_end(handle: esp_ota_handle_t): esp_err_t {.importc: "esp_ota_end", header: "<esp_ota_ops.h>", cdecl.}
  proc esp_ota_abort(handle: esp_ota_handle_t): esp_err_t {.importc: "esp_ota_abort", header: "<esp_ota_ops.h>", cdecl.}
  proc esp_ota_set_boot_partition(partition: esp_partition_t): esp_err_t {.importc: "esp_ota_set_boot_partition", header: "<esp_ota_ops.h>", cdecl.}

  proc esp_http_client_init(config: ptr esp_http_client_config_t): esp_http_client_handle_t {.importc: "esp_http_client_init", header: "<esp_http_client.h>", cdecl.}
  proc esp_http_client_open(client: esp_http_client_handle_t, write_len: cint): esp_err_t {.importc: "esp_http_client_open", header: "<esp_http_client.h>", cdecl.}
  proc esp_http_client_fetch_headers(client: esp_http_client_handle_t): cint {.importc: "esp_http_client_fetch_headers", header: "<esp_http_client.h>", cdecl.}
  proc esp_http_client_get_status_code(client: esp_http_client_handle_t): cint {.importc: "esp_http_client_get_status_code", header: "<esp_http_client.h>", cdecl.}
  proc esp_http_client_read(client: esp_http_client_handle_t, buffer: pointer, len: cint): cint {.importc: "esp_http_client_read", header: "<esp_http_client.h>", cdecl.}
  proc esp_http_client_close(client: esp_http_client_handle_t): esp_err_t {.importc: "esp_http_client_close", header: "<esp_http_client.h>", cdecl.}
  proc esp_http_client_cleanup(client: esp_http_client_handle_t): esp_err_t {.importc: "esp_http_client_cleanup", header: "<esp_http_client.h>", cdecl.}
  proc esp_crt_bundle_attach(conf: pointer): esp_err_t {.importc: "esp_crt_bundle_attach", header: "<esp_crt_bundle.h>", cdecl.}

  proc flashOtaPartition*(url: string): bool =
    ## Downloads firmware binary from `url` and writes it to the next available OTA partition.
    if not isValidOtaUrl(url):
      error("OTA", "Invalid OTA URL: " & url)
      return false

    let updatePartition = esp_ota_get_next_update_partition(nil)
    if updatePartition == nil:
      error("OTA", "Failed to find available OTA partition!")
      return false

    var config: esp_http_client_config_t
    config.url = url.cstring
    config.timeout_ms = 15000
    config.keep_alive_enable = true
    config.buffer_size = 4096
    config.buffer_size_tx = 1024
    config.crt_bundle_attach = cast[pointer](esp_crt_bundle_attach)
    config.skip_cert_common_name_check = true
    config.max_redirection_count = 5

    let client = esp_http_client_init(addr config)
    if client == nil:
      error("OTA", "Failed to initialize HTTP client for OTA!")
      return false

    var err = esp_http_client_open(client, 0)
    if err != ESP_OK:
      error("OTA", "Failed to open HTTP connection to " & url)
      discard esp_http_client_cleanup(client)
      return false

    discard esp_http_client_fetch_headers(client)
    let statusCode = esp_http_client_get_status_code(client)
    if statusCode != 200:
      error("OTA", "HTTP server returned error status code: " & $statusCode)
      discard esp_http_client_close(client)
      discard esp_http_client_cleanup(client)
      return false

    discard syncPreferences()

    var otaHandle: esp_ota_handle_t = 0
    err = esp_ota_begin(updatePartition, OTA_WITH_SEQUENTIAL_WRITES, addr otaHandle)
    if err != ESP_OK:
      error("OTA", "esp_ota_begin failed with error code: " & $int(err))
      discard esp_http_client_close(client)
      discard esp_http_client_cleanup(client)
      return false

    var buffer = newSeq[uint8](4096)
    var totalBytes = 0
    var lastProgressBytes = 0
    var writeFailed = false

    while true:
      let readBytes = esp_http_client_read(client, addr buffer[0], cint(buffer.len))
      if readBytes < 0:
        error("OTA", "HTTP read failed during OTA streaming!")
        writeFailed = true
        break
      elif readBytes == 0:
        break

      err = esp_ota_write(otaHandle, addr buffer[0], csize_t(readBytes))
      if err != ESP_OK:
        error("OTA", "esp_ota_write failed with error code: " & $int(err))
        writeFailed = true
        break

      totalBytes += readBytes
      if totalBytes - lastProgressBytes >= 102400:
        info("OTA", "Flashed " & $(totalBytes div 1024) & " KB...")
        lastProgressBytes = totalBytes

    discard esp_http_client_close(client)
    discard esp_http_client_cleanup(client)

    if writeFailed or totalBytes == 0:
      discard esp_ota_abort(otaHandle)
      return false

    err = esp_ota_end(otaHandle)
    if err != ESP_OK:
      error("OTA", "esp_ota_end validation failed with error code: " & $int(err))
      return false

    err = esp_ota_set_boot_partition(updatePartition)
    if err != ESP_OK:
      error("OTA", "esp_ota_set_boot_partition failed with error code: " & $int(err))
      return false

    info("OTA", "OTA successfully flashed (" & $totalBytes & " bytes)!")
    discard syncPreferences()
    return true

else:
  proc flashOtaPartition*(url: string): bool =
    ## Host simulation of OTA partition flashing.
    if not isValidOtaUrl(url):
      error("OTA", "Invalid OTA URL: " & url)
      return false
    info("OTA", "Host simulated: successfully flashed OTA from " & url)
    discard syncPreferences()
    true
