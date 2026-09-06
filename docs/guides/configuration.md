# YAML Configuration Reference

This guide details all configuration options available under the `nim:` schema in your ESPHome YAML configuration file.

---

## Schema Overview

The `nim:` block configures the Nim transpiler, external package dependencies, target CPU architecture, and compilation flags.

```yaml
nim:
  # Path to entrypoint .nim source file (Required)
  source: src/main.nim

  # External Nimble packages or Git repositories (Optional)
  requires:
    - jsony
    - chroma

  # Additional include directories for manual libraries (Optional)
  nimble_paths:
    - /path/to/custom/nim_modules

  # Target CPU override: esp (Xtensa), riscv32, arm (Optional, auto-detected)
  target_cpu: esp

  # Custom flags passed directly to `nim cpp` (Optional)
  nim_flags:
    - "-d:danger"
    - "--opt:size"

  # Absolute path to nim executable (Optional, default: "nim")
  nim_path: "/usr/local/bin/nim"
```

---

## Configuration Keys

| Key | Type | Default | Description |
|---|---|---|---|
| `source` | `string` | **Required** | Path to the entrypoint `.nim` file (relative to the YAML file or absolute). |
| `requires` | `list` | `[]` | List of package names (e.g. `zippy`) or Git repository URLs automatically installed via Nimble into an isolated build cache. |
| `nimble_paths` | `list` | `[]` | List of directory paths added to Nim's module search path via `--path:...`. |
| `target_cpu` | `string` | Auto | Target architecture override. Supported values: `esp` (Xtensa 32-bit), `riscv32` (RISC-V 32-bit), `arm` (Cortex-M0+ RP2040). |
| `nim_flags` | `list` | `[]` | Extra command-line arguments passed directly to the `nim cpp` invocation. |
| `nim_path` | `string` | `"nim"` | Custom path to the `nim` compiler binary if not located in system `PATH`. |

---

## Target CPU Architecture Detection

`nim-esphome` inspects your ESPHome configuration (`esp32.board`, `esp8266.board`, or `rp2040.board`) and selects the correct 32-bit CPU architecture flag:

- **Xtensa 32-bit (`--cpu:esp`)**:
  - Used for standard ESP32, ESP32-S2, and ESP32-S3 boards (e.g. `esp32dev`, `esp32-s3-devkitc-1`).
- **RISC-V 32-bit (`--cpu:riscv32`)**:
  - Used for ESP32-C2, ESP32-C3, ESP32-C6, ESP32-H2, and ESP32-P4 boards.
- **ARM Cortex-M0+ (`--cpu:arm --os:any`)**:
  - Used for Raspberry Pi RP2040 boards (e.g. `rpi_pico`).

If your board is not automatically recognized, you can supply `target_cpu:` explicitly:
```yaml
nim:
  source: src/main.nim
  target_cpu: riscv32
```

---

## Compiler Flags & Optimization

By default, `nim-esphome` applies the following safety and optimization flags during embedded cross-compilation:

```bash
nim cpp --compileOnly --noMain:on --mm:arc -d:danger -d:useMalloc -d:esphome --exceptions:goto --panics:on
```

- `--mm:arc`: Deterministic, reference-counted memory management with zero stop-the-world pauses.
- `-d:danger`: Disables runtime overflow checks and assertions for maximum execution speed and minimal flash footprint.
- `-d:useMalloc`: Directs all allocations to standard C `malloc`/`free`, which ESP-IDF maps to FreeRTOS heap memory.
- `--exceptions:goto`: Converts exceptions to C `goto` statements, completely eliminating C++ `try/catch` and `libsupc++` code overhead on microcontrollers.
- `--panics:on`: Treats unexpected errors as unrecoverable hardware panics, saving flash memory.

You can append or override flags using `nim_flags:`:
```yaml
nim:
  source: src/main.nim
  nim_flags:
    - "--opt:size"               # Optimize for minimal binary size
    - "-d:my_custom_feature"    # Pass custom compile-time defines
```
