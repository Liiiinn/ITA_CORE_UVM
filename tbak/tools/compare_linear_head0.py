#!/usr/bin/env python3
# Copyright 2026
# SPDX-License-Identifier: Apache-2.0

"""Compatibility wrapper for the historical compare_linear_head0.py entrypoint.

Prefer compare_mha8_manifest.py for new flows. This wrapper keeps the old
manifest filename as its default so existing commands continue to work.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def core_root() -> Path:
    return Path(__file__).resolve().parents[2]


def main() -> int:
    script = Path(__file__).resolve().with_name("compare_mha8_manifest.py")
    default_manifest = core_root() / "sim" / "logger" / "uvm_linear_head0_manifest.json"
    cmd = [sys.executable, str(script), "--manifest", str(default_manifest), *sys.argv[1:]]
    return subprocess.run(cmd).returncode


if __name__ == "__main__":
    raise SystemExit(main())
