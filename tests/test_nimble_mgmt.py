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
        self.assertEqual(detect_target_cpu("arm"), "arm")
        self.assertEqual(detect_target_cpu("riscv32"), "riscv32")
        self.assertEqual(detect_target_cpu("esp"), "esp")

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
