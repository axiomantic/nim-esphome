# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-09-06

### Added
- Multi-architecture auto-detection supporting Xtensa (`ESP32`, `ESP32-S2`, `ESP32-S3`), RISC-V 32-bit (`ESP32-C3`, `ESP32-C6`), and ARM Cortex-M (`RP2040`).
- Automatic Nimble dependency resolution via `requires` in ESPHome YAML configuration.
- First-class entity bindings for Home Assistant: `Sensor`, `BinarySensor`, `Switch`, and `TextSensor`.
- Pure Nim hardware peripheral abstractions for `GpioPin` (digital read/write, pullup/pulldown modes) and `I2cDevice` (byte and register reads/writes).
- Flash preferences / NVS non-volatile storage (`PreferencesStore`) with typed getters, setters, and fallback defaults.
- Embedded DSP and real-time control modules: `PidController` with anti-windup clamping, `MovingAverage`, `MovingMedian` outlier rejection, single-pole `LowPassFilter`, and time-based `Debouncer`.
- Comprehensive documentation site powered by Zensical with interactive API references, RST docstrings, and verified satellite case study.
- Multi-version documentation support using `squidfunk/mike` with automated version drop-down selection and `gh-pages` deployment.
- Automated version tagging and documentation deployment workflow triggered by version bumps in `nim_esphome.nimble`.
- Project templating and 1-click distribution architecture guide covering ESP-Web-Tools in-browser flashing, My Home Assistant dashboard import, and automated CI factory binary releases.

## [0.1.0] - 2026-09-06

### Added
- Initial release of `nim-esphome` bridge and external component.
- Zero-overhead C++ to Nim foreign function interface (`exportEsphome` macro).
- Core embedded runtime integration with ORC/ARC memory management (`-d:danger`, `-d:useMalloc`).
- Real-time millisecond/microsecond timing, logging, and reboot APIs.
- Host unit testing fallback (`when not defined(esphome)`) enabling native simulation and test suite execution.

[Unreleased]: https://github.com/axiomantic/nim-esphome/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/axiomantic/nim-esphome/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/axiomantic/nim-esphome/releases/tag/v0.1.0
