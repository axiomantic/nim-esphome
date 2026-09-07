# Project Templating & Distribution

Writing expressive, statically-typed embedded logic in Nim is only half the battle. Getting your firmware into end users' hands—without forcing them to install Nim, PlatformIO, Python virtual environments, or edit fragile YAML lambdas—is critical for real-world adoption.

`nim-esphome` establishes a standardized distribution architecture that enables:

1. **In-Browser Web Flashing** via [ESP-Web-Tools](https://esphome.github.io/esp-web-tools/) (WebSerial in Chrome/Edge).
2. **Drop-in Remote Packages & Dashboard Adoption** via ESPHome `packages:` and `dashboard_import:`.
3. **Automated CI Binary Builds** that bundle partition tables, bootloader, and firmware into flashable factory binaries on release.

---

## The Standardized Project Structure

A distribution-ready Nim-ESPHome repository follows this standard layout:

```
my-nim-esphome-project/
├── src/
│   ├── my_device.nim             # Pure Nim embedded logic & C ABI bridge
│   └── my_device_bridge.h        # C/C++ weak symbol declarations
├── packages/
│   └── my_device_board.yaml      # Remote drop-in package for Home Assistant import
├── web/
│   ├── index.html                # Single-page ESP-Web-Tools browser installer
│   └── manifest.json             # Web-Tools firmware offsets & chip configuration
├── .github/workflows/
│   ├── ci.yml                    # Host unit tests & cross-compilation checks
│   ├── auto-tag.yml              # Automated release tagging on version bump
│   └── web-installer.yml         # Publishes web installer to GitHub Pages
├── scripts/
│   ├── build.sh                  # Local test & C++ transpilation runner
│   └── build_factory_binary.sh   # Assembles bootloader, partitions & firmware
└── my_device.nimble              # Package metadata and dependencies
```

---

## 1. In-Browser Web Flashing (ESP-Web-Tools)

The modern gold standard for ESPHome distribution (used by Nabu Casa, Seeed Studio, and Shelly) is browser-based flashing over WebSerial.

Users plug their device into their laptop via USB, navigate to your project's GitHub Pages site, and click **Install**. The browser flashes the ESP32 and prompts for Wi-Fi credentials—with zero command-line tools.

### Web Installer Page (`web/index.html`)

Include the official ESP-Web-Tools script and install button:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Install My Device Firmware</title>
  <script
    type="module"
    src="https://unpkg.com/esp-web-tools@10/dist/web/install-button.js?module"
  ></script>
</head>
<body>
  <h1>My Device Installer</h1>
  <p>Connect your ESP32 via USB and click Install:</p>

  <esp-web-install-button manifest="manifest.json">
    <button slot="activate">Install Firmware</button>
    <span slot="unsupported">Please use Google Chrome or Microsoft Edge.</span>
  </esp-web-install-button>
</body>
</html>
```

### Firmware Manifest (`web/manifest.json`)

Define the target chip family, binary locations, and Home Assistant auto-discovery domain:

```json
{
  "name": "My Nim Device",
  "version": "1.0.0",
  "home_assistant_domain": "esphome",
  "funding_url": "https://github.com/my-org/my-nim-device",
  "new_install_prompt_erase": true,
  "builds": [
    {
      "chipFamily": "ESP32-S3",
      "parts": [
        { "path": "firmware-factory.bin", "offset": 0 }
      ]
    }
  ]
}
```

>  Setting `"home_assistant_domain": "esphome"` prompts the user immediately after Wi-Fi configuration with a 1-click link to adopt the device into their local Home Assistant instance.

---

## 2. Drop-in Remote Packages & Dashboard Adoption

For users who configure or compile devices through the ESPHome Dashboard or CLI, provide a standalone package YAML in your repository.

### Standalone Remote Package (`packages/my_board.yaml`)

Define the device configuration such that it pulls the Nim component directly from GitHub:

```yaml
substitutions:
  name: "my-nim-device"
  friendly_name: "My Nim Device"

esphome:
  name: ${name}
  friendly_name: ${friendly_name}
  project:
    name: "my-org.my-nim-device"
    version: "1.0.0"

esp32:
  board: esp32-s3-devkitc-1
  framework:
    type: esp-idf

dashboard_import:
  package_import_url: github://my-org/my-nim-device/packages/my_board.yaml
  import_full_config: false

external_components:
  - source:
      type: git
      url: https://github.com/axiomantic/nim-esphome
      ref: main
    components: [nim]

nim:
  source: https://raw.githubusercontent.com/my-org/my-nim-device/main/src/my_device.nim
  nim_flags:
    - "-d:danger"
    - "-d:useMalloc"
    - "-d:esphome"

wifi:
  ap:
    ssid: "My-Device-Fallback"

captive_portal:
api:
ota:
  - platform: esphome
```

### Integration Methods

Users can adopt your firmware in two ways:

1. **Direct Package Inclusion**: Add your repository package to their existing ESPHome configuration:
   ```yaml
   packages:
     my_device: github://my-org/my-nim-device/packages/my_board.yaml
   ```
2. **Dashboard Adoption**: When a user flashes the device via the web installer and connects it to their Wi-Fi, the ESPHome Dashboard discovers it on the local network. The `dashboard_import:` block causes ESPHome to display an **Adopt** button, pulling the remote configuration automatically.

---

## 3. Automated CI Binary Packaging

To generate the `firmware-factory.bin` used by ESP-Web-Tools, combine the compiled bootloader, partition table, and firmware application into a single binary at offset `0x0`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# In PlatformIO / ESPHome build output:
esptool.py --chip esp32s3 merge_bin -o firmware-factory.bin \
  0x0000 .pioenvs/my-board/bootloader.bin \
  0x8000 .pioenvs/my-board/partitions.bin \
  0xe000 .pioenvs/my-board/boot_app0.bin \
  0x10000 .pioenvs/my-board/firmware.bin
```

On release tags (`v*`), your GitHub Actions workflow uploads `firmware-factory.bin` to the release assets and publishes `web/` to GitHub Pages.

---

## Reference Implementation: `esphome-satellite`

See **[`esphome-satellite`](https://github.com/axiomantic/esphome-satellite)** for a complete, live reference implementation of this architecture:
- **In-Browser Flasher**: Live at [`axiomantic.github.io/esphome-satellite`](https://axiomantic.github.io/esphome-satellite/).
- **Drop-in Packages**: [`packages/respeaker_xvf3800.yaml`](https://github.com/axiomantic/esphome-satellite/blob/main/packages/respeaker_xvf3800.yaml).
