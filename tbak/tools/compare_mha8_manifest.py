#!/usr/bin/env python3
# Copyright 2026
# SPDX-License-Identifier: Apache-2.0

"""Compare MHA8 actual output using a generated manifest.

The manifest is the contract between vector generation, UVM logging, parsing,
and compare. It provides the actual CSV path, step/stream metadata, and each
per-head expected/actual txt path.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


def core_root() -> Path:
    return Path(__file__).resolve().parents[2]


def tool_dir() -> Path:
    return Path(__file__).resolve().parent


def default_manifest() -> Path:
    return core_root() / "sim" / "logger" / "uvm_linear_mha8_manifest.json"


def resolve_manifest_path(path_text: str | Path, manifest_path: Path) -> Path:
    path = Path(path_text)
    if path.is_absolute():
        return path

    root_candidate = core_root() / path
    if root_candidate.exists() or str(path).startswith("sim/") or str(path).startswith("sim\\"):
        return root_candidate

    return manifest_path.parent / path


def require_key(obj: dict[str, Any], key: str) -> Any:
    if key not in obj:
        raise KeyError(f"Manifest is missing required key: {key}")
    return obj[key]


def run(cmd: list[str], dry_run: bool) -> None:
    print("PY> " + " ".join(cmd), flush=True)
    if not dry_run:
        subprocess.run(cmd, check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse and compare MHA8 actual output from a manifest.")
    parser.add_argument("--manifest", type=Path, default=default_manifest(), help="MHA8 vector/compare manifest.")
    parser.add_argument("--actual-csv", type=Path, help="Override manifest actual_csv.")
    parser.add_argument("--heads", type=int, help="Optional limit on number of heads to compare from manifest order.")
    parser.add_argument("--bit-width", type=int, help="Optional bit width forwarded to compare.py.")
    parser.add_argument("--row-words", type=int, default=1, help="Values per row forwarded to compare.py.")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without executing them.")
    args = parser.parse_args()

    manifest_path = args.manifest
    if not manifest_path.is_absolute():
        manifest_path = core_root() / manifest_path
    if not manifest_path.is_file():
        raise FileNotFoundError(f"Manifest not found: {manifest_path}")

    with manifest_path.open("r", encoding="utf-8") as f:
        manifest = json.load(f)

    step = str(require_key(manifest, "step"))
    stream = str(manifest.get("stream", "per_head"))
    per_head = require_key(manifest, "per_head")
    if not isinstance(per_head, list) or not per_head:
        raise ValueError("Manifest per_head must be a non-empty list")

    if args.heads is not None:
        if args.heads <= 0:
            raise ValueError("--heads must be greater than zero")
        per_head = per_head[: args.heads]

    actual_csv = args.actual_csv
    if actual_csv is None:
        actual_csv = resolve_manifest_path(str(require_key(manifest, "actual_csv")), manifest_path)
    elif not actual_csv.is_absolute():
        actual_csv = core_root() / actual_csv

    for entry in per_head:
        if not isinstance(entry, dict):
            raise ValueError(f"Invalid per_head entry: {entry!r}")

        head = int(require_key(entry, "head_id"))
        expected = resolve_manifest_path(str(require_key(entry, "expected_path")), manifest_path)
        actual_txt = resolve_manifest_path(str(require_key(entry, "actual_path")), manifest_path)

        parse_cmd = [
            sys.executable,
            str(tool_dir() / "parse_actual.py"),
            "--input",
            str(actual_csv),
            "--format",
            "uvm-csv",
            "--phase",
            step,
            "--stream",
            stream,
            "--head",
            str(head),
            "--out",
            str(actual_txt),
        ]

        compare_cmd = [
            sys.executable,
            str(tool_dir() / "compare.py"),
            "--expected",
            str(expected),
            "--actual",
            str(actual_txt),
            "--row-words",
            str(args.row_words),
        ]
        if args.bit_width is not None:
            compare_cmd.extend(["--bit-width", str(args.bit_width)])

        run(parse_cmd, args.dry_run)
        run(compare_cmd, args.dry_run)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
