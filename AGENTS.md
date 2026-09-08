# AGENTS.md - Developer & Agent Guide for nim-esphome

This document defines architecture invariants, development conventions, and interop patterns for human contributors and AI agents working on `nim-esphome`.

---

## 1. Project Purpose & Architecture

`nim-esphome` provides high-level, type-safe Nim bindings, embedded domain-specific languages (DSLs), and runtime utilities for ESPHome devices:
- **`src/nim_esphome/`**: Core library modules.
  - `i2c.nim`: High-efficiency hardware I2C bus transactions.
  - `gpio.nim`: Hardware GPIO pin configuration and interrupt handling.
  - `dsp.nim`: Real-time embedded audio DSP (compression, limiting, makeup gain).
  - `entities.nim`: Typed Home Assistant entity declarations (sensors, binary sensors, switches, selects).
  - `preferences.nim`: Non-volatile flash storage persistence.
  - `dsl/`: Declarative DSL engines (`actions.nim`, `satellite.nim`, `installer.nim`, `surface.nim`, `dashboard.nim`).
- **`components/nim/`**: Minimal C++ runtime bridge for PlatformIO and ESP-IDF compilation.
- **`tests/`**: Unit and regression test suites for all pure Nim modules.

---

## 2. Invariants & Implementation Standards

### A. Nim-First Policy
- All driver logic, peripherals, domain logic, DSP, and features must be implemented in **Nim**.
- Do not introduce custom C++ code into this repository. The only permitted C++ is the existing `components/nim/` bridge (`nim_component.cpp`, `nim_component.h`, `nim_esphome_bridge.h`) which connects ESPHome's component lifecycle to Nim.

### B. Wrapping C/C++ Libraries with headerkit
- When interfacing with ESPHome C++ classes or third-party ESP-IDF C headers, use `headerkit` (`pip install headerkit`) to parse the C/C++ headers and generate Nim FFI bindings automatically.
- Avoid writing brittle, unverified manual `{.importcpp.}` or `{.importc.}` definitions by hand when a header is available.

### C. Zero Emojis Invariant
- Never use emojis anywhere in the codebase: no emojis in documentation, markdown files, code comments, commit messages, or pull request descriptions. Keep all language clear, technical, and human.

### D. Embedded Performance & Memory Safety
- Voice and sensor processing loops run on microcontrollers (ESP32-S3) with strict timing and memory limits.
- Avoid heap allocations (`alloc`, dynamic seq growth) inside real-time callbacks and DSP processing loops.
- Use Nim's ARC memory management (`--mm:arc`), pointer slicing, and unchecked arrays for high-throughput streaming.

### E. Test-Driven Development & Anti-Green-Mirage
- Every new module or algorithm must be accompanied by unit tests in `tests/`.
- Verify every test against "green mirages": deliberately mutate code or conditions to ensure the test fails with clear diagnostics before marking it green.

### F. Commit and Push Invariant
- All changes must be committed and pushed once reviewed. Implementations and fixes are never left uncommitted in the working tree or unpushed to the remote repository. Always rebase on the latest remote before pushing.

---

## 3. Verification Commands

Before committing changes:

```bash
# Run all unit tests
nim r tests/test_dsp.nim

# Build documentation if modified
nimble docs
```
