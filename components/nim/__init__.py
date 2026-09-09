import os
import shutil
import subprocess
import esphome.codegen as cg
import esphome.config_validation as cv
from esphome.const import CONF_ID
from esphome.core import CORE, EsphomeError

CONF_SOURCE = "source"
CONF_NIM_FLAGS = "nim_flags"
CONF_NIM_PATH = "nim_path"
CONF_NIMBLE_PATHS = "nimble_paths"
CONF_TARGET_CPU = "target_cpu"
CONF_REQUIRES = "requires"

DEPENDENCIES = []
AUTO_LOAD = []

nim_ns = cg.esphome_ns.namespace("nim")
NimComponent = nim_ns.class_("NimComponent", cg.Component)

CONFIG_SCHEMA = cv.Schema(
    {
        cv.GenerateID(): cv.declare_id(NimComponent),
        cv.Required(CONF_SOURCE): cv.file_,
        cv.Optional(CONF_NIM_FLAGS, default=[]): cv.ensure_list(cv.string),
        cv.Optional(CONF_NIM_PATH, default="nim"): cv.string,
        cv.Optional(CONF_NIMBLE_PATHS, default=[]): cv.ensure_list(cv.directory),
        cv.Optional(CONF_TARGET_CPU): cv.string,
        cv.Optional(CONF_REQUIRES, default=[]): cv.ensure_list(cv.string),
    }
).extend(cv.COMPONENT_SCHEMA)


def find_nim_binary(configured_path: str) -> str:
    if configured_path and shutil.which(configured_path):
        return shutil.which(configured_path)

    # Common search paths (mise, homebrew, standard unix)
    candidates = [
        os.path.expanduser("~/.local/share/mise/shims/nim"),
        os.path.expanduser("~/.nimble/bin/nim"),
        "/opt/homebrew/bin/nim",
        "/usr/local/bin/nim",
        "/usr/bin/nim",
    ]
    for candidate in candidates:
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate

    raise EsphomeError(
        f"Nim compiler not found. Please ensure 'nim' is in your PATH or specify '{CONF_NIM_PATH}'."
    )


def find_nimbase_h(nim_bin: str) -> str:
    try:
        res = subprocess.run(
            [nim_bin, "dump"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
        )
        for line in res.stderr.splitlines():
            line = line.strip()
            candidate = os.path.join(line, "nimbase.h")
            if os.path.isfile(candidate):
                return candidate
    except Exception:
        pass

    # Fallback to standard locations relative to binary
    bin_real = os.path.realpath(nim_bin)
    bin_dir = os.path.dirname(bin_real)
    candidate = os.path.join(os.path.dirname(bin_dir), "lib", "nimbase.h")
    if os.path.isfile(candidate):
        return candidate


def find_nimble_binary(nim_bin: str) -> str:
    bin_dir = os.path.dirname(os.path.realpath(nim_bin))
    candidate = os.path.join(bin_dir, "nimble")
    if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
        return candidate
    which_nimble = shutil.which("nimble")
    if which_nimble:
        return which_nimble
    candidates = [
        os.path.expanduser("~/.local/share/mise/shims/nimble"),
        os.path.expanduser("~/.nimble/bin/nimble"),
        "/opt/homebrew/bin/nimble",
        "/usr/local/bin/nimble",
        "/usr/bin/nimble",
    ]
    for c in candidates:
        if os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    raise EsphomeError(
        "Nimble package manager executable not found. Please install nimble or ensure it is in your PATH."
    )

def detect_target_cpu(configured_cpu: str = None) -> str:
    if configured_cpu:
        return configured_cpu
    try:
        if getattr(CORE, "is_rp2040", False) or getattr(CORE, "is_rp2", False):
            return "arm"
        if getattr(CORE, "is_esp8266", False):
            return "esp"
        if getattr(CORE, "is_esp32", False):
            board = str(getattr(CORE, "board", "")).lower()
            riscv_boards = ["-c2", "-c3", "-c6", "-h2", "-p4", "esp32c2", "esp32c3", "esp32c6", "esp32h2", "esp32p4"]
            if any(r in board for r in riscv_boards):
                return "riscv32"
            return "esp"
    except Exception:
        pass
    return "esp"


async def to_code(config):
    var = cg.new_Pvariable(config[CONF_ID])
    await cg.register_component(var, config)

    source_path = CORE.relative_config_path(config[CONF_SOURCE])
    if not os.path.isfile(source_path):
        raise EsphomeError(f"Nim source file not found: {source_path}")

    nim_bin = find_nim_binary(config[CONF_NIM_PATH])
    nimbase_path = find_nimbase_h(nim_bin)

    # Output directory inside the PlatformIO src tree
    out_dir = CORE.relative_build_path("src", "nim_gen")
    if os.path.exists(out_dir):
        for old_f in os.listdir(out_dir):
            if old_f.endswith((".cpp", ".h", ".json")):
                try:
                    os.remove(os.path.join(out_dir, old_f))
                except OSError:
                    pass
    os.makedirs(out_dir, exist_ok=True)

    # Copy nimbase.h into the generated src directory
    if nimbase_path and os.path.isfile(nimbase_path):
        shutil.copy(nimbase_path, os.path.join(out_dir, "nimbase.h"))

    this_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(this_dir, "..", ".."))
    nim_esphome_src = os.path.join(repo_root, "src")

    # Ensure component files are kept fresh in build tree
    comp_build_dir = CORE.relative_build_path("src", "esphome", "components", "nim")
    os.makedirs(comp_build_dir, exist_ok=True)
    for fname in ["nim_component.h", "nim_component.cpp", "nim_esphome_bridge.h"]:
        src_f = os.path.join(this_dir, fname)
        if os.path.isfile(src_f):
            shutil.copy(src_f, os.path.join(comp_build_dir, fname))

    has_cpu_flag = any(flag.startswith("--cpu:") for flag in config[CONF_NIM_FLAGS])
    target_cpu = detect_target_cpu(config.get(CONF_TARGET_CPU))

    cmd = [
        nim_bin,
        "cpp",
        "--compileOnly",
        "--noMain:on",
        "--mm:arc",
        "-d:danger",
        "-d:useMalloc",
        "-d:esphome",
        "-d:noSignalHandler",
        "--os:any",
        "--exceptions:goto",
        "--panics:on",
        f"--nimcache:{out_dir}",
        f"--path:{nim_esphome_src}",
    ]

    if not has_cpu_flag:
        cmd.append(f"--cpu:{target_cpu}")

    requires = config.get(CONF_REQUIRES, [])
    if requires:
        nimble_bin = find_nimble_binary(nim_bin)
        nimble_dir = CORE.relative_build_path(".nimble")
        os.makedirs(nimble_dir, exist_ok=True)
        for pkg in requires:
            res = subprocess.run(
                [nimble_bin, "install", "-y", f"--nimbleDir:{nimble_dir}", pkg],
                cwd=nimble_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                check=False,
            )
            if res.returncode != 0:
                raise EsphomeError(
                    f"Nimble package installation failed for '{pkg}' (exit code {res.returncode}):\n{res.stdout}"
                )

        for psub in ["pkgs2", "pkgs"]:
            pdir = os.path.join(nimble_dir, psub)
            if os.path.isdir(pdir):
                cmd.append(f"--nimblePath:{pdir}")
                for entry in sorted(os.listdir(pdir)):
                    entry_path = os.path.join(pdir, entry)
                    if os.path.isdir(entry_path):
                        cmd.append(f"--path:{entry_path}")
                        entry_src = os.path.join(entry_path, "src")
                        if os.path.isdir(entry_src):
                            cmd.append(f"--path:{entry_src}")

    for p in config[CONF_NIMBLE_PATHS]:
        cmd.append(f"--path:{p}")

    for flag in config[CONF_NIM_FLAGS]:
        cmd.append(flag)

    cmd.append(source_path)

    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        if proc.returncode != 0:
            raise EsphomeError(
                f"Nim compilation failed (exit code {proc.returncode}):\n{proc.stdout}"
            )
    except FileNotFoundError as e:
        raise EsphomeError(f"Failed to execute {cmd}: {e}")

    # Ensure build system includes the generated headers and component bridge
    cg.add_build_flag(f"-I{out_dir}")
    cg.add_build_flag(f"-I{this_dir}")
    cg.add_build_flag("-Wno-write-strings")
