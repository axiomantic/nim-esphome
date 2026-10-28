#!/usr/bin/env python3
"""Regenerate Nim bindings using HeaderKit from C/C++ headers."""

from pathlib import Path
import subprocess
import sys

def main() -> int:
    repo_root = Path(__file__).parent.parent
    header_path = repo_root / "include" / "nim_esphome.h"
    out_path = repo_root / "src" / "nim_esphome.nim"

    print(f"Generating Nim bindings for {header_path} -> {out_path}...")
    cmd = [
        "headerkit",
        str(header_path),
        "-w", "nim",
        "-o", f"nim:{out_path}",
    ]
    try:
        subprocess.run(cmd, check=True)
        print("Bindings successfully generated.")
        return 0
    except FileNotFoundError:
        print("Error: 'headerkit' CLI not found. Install via 'pip install headerkit'.", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as e:
        print(f"Error during binding generation: {e}", file=sys.stderr)
        return e.returncode

if __name__ == "__main__":
    sys.exit(main())
