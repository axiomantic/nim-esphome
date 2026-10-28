# nim-esphome

[![CI](https://github.com/axiomantic/nim-esphome/actions/workflows/ci.yml/badge.svg)](https://github.com/axiomantic/nim-esphome/actions/workflows/ci.yml)

[![Release](https://img.shields.io/github/v/release/axiomantic/nim-esphome)](https://github.com/axiomantic/nim-esphome/releases/latest)
[![License](https://img.shields.io/github/license/axiomantic/nim-esphome)](LICENSE)
[![Nim](https://img.shields.io/badge/Nim-2.2%2B-yellow.svg)](https://nim-lang.org)

Write ESPHome custom components, device logic, and drivers in Nim with zero-overhead C++ interop

## Quick Start

```nim
import nim_esphome

echo hello()
```

## Development

The `justfile` is the canonical command surface for common tasks:

```bash
just setup        # Install dependencies
just test         # Run test suite
just lint         # Check formatting (nph) and nimble check
just fmt          # Auto-format codebase with nph

just build        # Build release artifacts
```

## Upstream Updates

This project was initialized via [Polyform](https://github.com/axiomantic/polyform). To update boilerplate, CI workflows, and tooling from upstream:

```bash
uvx copier update --trust
```
