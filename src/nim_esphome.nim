# nim_esphome - Write ESPHome custom components, device logic, and drivers in Nim with zero-overhead C++ interop

const projectVersion* = "0.0.1"

const greetingMsg* = "hello from nim_esphome"

proc hello*(): string =
  ## Returns standard project greeting string.
  greetingMsg

proc add*(a, b: int): int =
  ## Adds two integers.
  a + b

# HeaderKit C-ABI foreign bindings
{.compile: "../include/nim_esphome.c".}

proc nim_esphome_add*(a, b: int32): int32 {.importc: "nim_esphome_add", cdecl.}
  ## Computes sum via foreign C entrypoint.
