import os
import pathlib
import shutil
import unittest
from esphome.core import CORE

from components.nim import (
    CONF_REQUIRES,
    CONF_TARGET_CPU,
    CONFIG_SCHEMA,
    detect_target_cpu,
    find_nim_binary,
    find_nimble_binary,
)


class TestNimbleManagement(unittest.TestCase):
    def setUp(self):
        CORE.config_path = pathlib.Path(__file__).resolve()

    def test_find_nim_and_nimble(self):
        nim_bin = find_nim_binary("nim")
        self.assertTrue(os.path.isfile(nim_bin))
        self.assertTrue(os.access(nim_bin, os.X_OK))

        nimble_bin = find_nimble_binary(nim_bin)
        self.assertTrue(os.path.isfile(nimble_bin))
        self.assertTrue(os.access(nimble_bin, os.X_OK))

    def test_detect_target_cpu(self):
        # Explicit configuration override
        self.assertEqual(detect_target_cpu("arm"), "arm")
        self.assertEqual(detect_target_cpu("riscv32"), "riscv32")
        self.assertEqual(detect_target_cpu("esp"), "esp")

        from unittest.mock import patch

        class DummyCore:
            def __init__(self, is_rp2040=False, is_rp2=False, is_esp8266=False, is_esp32=False, board=""):
                self.is_rp2040 = is_rp2040
                self.is_rp2 = is_rp2
                self.is_esp8266 = is_esp8266
                self.is_esp32 = is_esp32
                self.board = board

        # Auto-detection when configured_cpu is None
        # RP2040 -> arm
        with patch("components.nim.CORE", DummyCore(is_rp2040=True)):
            self.assertEqual(detect_target_cpu(None), "arm")

        with patch("components.nim.CORE", DummyCore(is_rp2=True)):
            self.assertEqual(detect_target_cpu(None), "arm")

        # ESP8266 -> esp
        with patch("components.nim.CORE", DummyCore(is_esp8266=True)):
            self.assertEqual(detect_target_cpu(None), "esp")

        # ESP32 RISC-V variants -> riscv32
        with patch("components.nim.CORE", DummyCore(is_esp32=True, board="esp32-c3-devkitm-1")):
            self.assertEqual(detect_target_cpu(None), "riscv32")

        with patch("components.nim.CORE", DummyCore(is_esp32=True, board="esp32c6-devkitc-1")):
            self.assertEqual(detect_target_cpu(None), "riscv32")

        # ESP32 Xtensa variants -> esp
        with patch("components.nim.CORE", DummyCore(is_esp32=True, board="esp32-s3-devkitc-1")):
            self.assertEqual(detect_target_cpu(None), "esp")

    def test_schema_requires(self):
        valid_cfg = {
            "source": os.path.basename(__file__),
            "requires": ["zippy", "chroma"],
            "target_cpu": "riscv32",
        }
        res = CONFIG_SCHEMA(valid_cfg)
        self.assertEqual(res[CONF_REQUIRES], ["zippy", "chroma"])
        self.assertEqual(res[CONF_TARGET_CPU], "riscv32")


if __name__ == "__main__":
    unittest.main()
