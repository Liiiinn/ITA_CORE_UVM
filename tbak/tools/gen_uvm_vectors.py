#!/usr/bin/env python3
# Copyright 2026
# SPDX-License-Identifier: Apache-2.0

"""Compatibility wrapper for the historical gen_uvm_vectors.py entrypoint.

Prefer gen_mha8_vectors.py for new flows. This wrapper keeps the old default
filenames so existing commands continue to work.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main() -> int:
    script = Path(__file__).resolve().with_name("gen_mha8_vectors.py")
    cmd = [
        sys.executable,
        str(script),
        "--stream-name",
        "uvm_linear_head0_stream.csv",
        "--manifest-name",
        "uvm_linear_head0_manifest.json",
        *sys.argv[1:],
    ]
    return subprocess.run(cmd).returncode


if __name__ == "__main__":
    raise SystemExit(main())
