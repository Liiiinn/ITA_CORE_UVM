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
import datetime as _datetime
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


def core_root() -> Path:
    return Path(__file__).resolve().parents[2]


def tool_dir() -> Path:
    return Path(__file__).resolve().parent


def default_manifest() -> Path:
    return core_root() / "sim" / "logger" / "uvm_linear_mha8_manifest.json"


def default_log_dir() -> Path:
    return core_root() / "sim" / "output" / "compare_logs"


def resolve_user_output_path(path: Path) -> Path:
    if path.is_absolute():
        return path

    cwd_candidate = Path.cwd() / path
    if cwd_candidate.exists() or (path.parts and path.parts[0] == core_root().name):
        return cwd_candidate

    return core_root() / path


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


class Transcript:
    def __init__(self, path: Path | None):
        self.path = path
        self._file = None

    def __enter__(self) -> "Transcript":
        if self.path is not None:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self._file = self.path.open("w", encoding="utf-8")
        return self

    def __exit__(self, exc_type: object, exc: object, tb: object) -> None:
        if self._file is not None:
            self._file.close()

    def emit(self, text: str = "") -> None:
        print(text, flush=True)
        if self._file is not None:
            self._file.write(text + "\n")
            self._file.flush()


def run(cmd: list[str], dry_run: bool, transcript: Transcript) -> int:
    transcript.emit("PY> " + " ".join(cmd))
    if dry_run:
        return 0
    completed = subprocess.run(cmd, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if completed.stdout:
        transcript.emit(completed.stdout.rstrip("\n"))
    return completed.returncode


@dataclass(frozen=True)
class EntryResult:
    step: str
    head: int | None
    stream: str
    expected: Path
    actual: Path
    status: str
    detail: str = ""

    @property
    def passed(self) -> bool:
        return self.status == "PASS"

    def summary_line(self) -> str:
        target = f"head{self.head}" if self.head is not None else self.stream
        line = f"{self.status} {self.step}/{target}: expected={self.expected.name} actual={self.actual.name}"
        if self.detail:
            line += f" ({self.detail})"
        return line


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse and compare MHA8 actual output from a manifest.")
    parser.add_argument("--manifest", type=Path, default=default_manifest(), help="MHA8 vector/compare manifest.")
    parser.add_argument("--actual-csv", type=Path, help="Override manifest actual_csv.")
    parser.add_argument("--heads", type=int, help="Optional limit on number of heads to compare from manifest order.")
    parser.add_argument("--bit-width", type=int, help="Optional bit width forwarded to compare.py.")
    parser.add_argument("--row-words", type=int, default=1, help="Values per row forwarded to compare.py.")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without executing them.")
    parser.add_argument("--log", type=Path, help="Write full parse/compare transcript to this log file.")
    parser.add_argument("--log-dir", type=Path, default=default_log_dir(), help="Directory for timestamped compare logs.")
    parser.add_argument("--no-log", action="store_true", help="Do not write a timestamped compare log.")
    args = parser.parse_args()

    log_path: Path | None
    if args.no_log:
        log_path = None
    elif args.log is not None:
        log_path = resolve_user_output_path(args.log)
    else:
        log_dir = resolve_user_output_path(args.log_dir)
        timestamp = _datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        log_path = log_dir / f"compare_mha8_manifest_{timestamp}.log"

    manifest_path = args.manifest
    if not manifest_path.is_absolute():
        if manifest_path.is_file():
            manifest_path = manifest_path.resolve()
        else:
            manifest_path = core_root() / manifest_path
    if not manifest_path.is_file():
        raise FileNotFoundError(f"Manifest not found: {manifest_path}")

    with manifest_path.open("r", encoding="utf-8-sig") as f:
        manifest = json.load(f)

    compare_cfg = manifest.get("compare", {})
    if compare_cfg is None:
        compare_cfg = {}
    if not isinstance(compare_cfg, dict):
        raise ValueError("Manifest compare must be an object when present")

    actual_steps_obj = compare_cfg.get("actual_steps")
    if actual_steps_obj is not None:
        if not isinstance(actual_steps_obj, list) or not actual_steps_obj:
            raise ValueError("Manifest compare.actual_steps must be a non-empty list when present")
        actual_steps = [str(step) for step in actual_steps_obj]
    else:
        actual_steps = [str(compare_cfg.get("actual_step", require_key(manifest, "step")))]
    stream = str(compare_cfg.get("stream", manifest.get("stream", "per_head")))
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

    with Transcript(log_path) as transcript:
        transcript.emit("MHA8_MANIFEST_COMPARE_LOG")
        transcript.emit(f"timestamp={_datetime.datetime.now().isoformat(timespec='seconds')}")
        transcript.emit(f"manifest={manifest_path}")
        transcript.emit(f"actual_csv={actual_csv}")
        transcript.emit(f"dry_run={args.dry_run}")
        if log_path is not None:
            transcript.emit(f"log_path={log_path}")

        def run_compare_for_entry(
            step: str,
            head: int | None,
            entry_stream: str,
            expected: Path,
            actual_txt: Path,
        ) -> EntryResult:
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
                entry_stream,
                "--out",
                str(actual_txt),
            ]
            if head is not None:
                parse_cmd.extend(["--head", str(head)])

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

            parse_rc = run(parse_cmd, args.dry_run, transcript)
            if parse_rc != 0:
                return EntryResult(step, head, entry_stream, expected, actual_txt, "FAIL", f"parse_actual exit code {parse_rc}")

            compare_rc = run(compare_cmd, args.dry_run, transcript)
            if compare_rc != 0:
                return EntryResult(step, head, entry_stream, expected, actual_txt, "FAIL", f"compare exit code {compare_rc}")
            return EntryResult(step, head, entry_stream, expected, actual_txt, "PASS", "dry-run" if args.dry_run else "")

        results: list[EntryResult] = []
        for entry in per_head:
            if not isinstance(entry, dict):
                raise ValueError(f"Invalid per_head entry: {entry!r}")

            head = int(require_key(entry, "head_id"))
            if actual_steps_obj is None:
                expected = resolve_manifest_path(str(require_key(entry, "expected_path")), manifest_path)
                actual_txt = resolve_manifest_path(str(require_key(entry, "actual_path")), manifest_path)
                results.append(run_compare_for_entry(actual_steps[0], head, stream, expected, actual_txt))
            else:
                steps_cfg = require_key(entry, "steps")
                if not isinstance(steps_cfg, dict):
                    raise ValueError(f"per_head head{head} steps must be an object")
                for step in actual_steps:
                    step_cfg = require_key(steps_cfg, step)
                    if not isinstance(step_cfg, dict):
                        raise ValueError(f"per_head head{head} step {step} must be an object")
                    expected = resolve_manifest_path(str(require_key(step_cfg, "expected_path")), manifest_path)
                    actual_txt = resolve_manifest_path(str(require_key(step_cfg, "actual_path")), manifest_path)
                    results.append(run_compare_for_entry(step, head, stream, expected, actual_txt))

        extra_entries = compare_cfg.get("extra_entries", [])
        if extra_entries is None:
            extra_entries = []
        if not isinstance(extra_entries, list):
            raise ValueError("Manifest compare.extra_entries must be a list when present")

        for extra_entry in extra_entries:
            if not isinstance(extra_entry, dict):
                raise ValueError(f"Invalid compare.extra_entries entry: {extra_entry!r}")

            step = str(require_key(extra_entry, "step"))
            entry_stream = str(require_key(extra_entry, "stream"))
            head = int(extra_entry["head"]) if "head" in extra_entry and extra_entry["head"] is not None else None
            expected = resolve_manifest_path(str(require_key(extra_entry, "expected_path")), manifest_path)
            actual_txt = resolve_manifest_path(str(require_key(extra_entry, "actual_path")), manifest_path)
            results.append(run_compare_for_entry(step, head, entry_stream, expected, actual_txt))

        passed = [result for result in results if result.passed]
        failed = [result for result in results if not result.passed]

        transcript.emit(
            "MHA8_MANIFEST_COMPARE_SUMMARY "
            f"total={len(results)} passed={len(passed)} failed={len(failed)} "
            f"steps={len(actual_steps)} heads={len(per_head)} extra_entries={len(extra_entries)}"
        )
        if passed:
            transcript.emit("  PASS_ENTRIES:")
            for result in passed:
                transcript.emit(f"    {result.summary_line()}")
        if failed:
            transcript.emit("  FAIL_ENTRIES:")
            for result in failed:
                transcript.emit(f"    {result.summary_line()}")

        if failed:
            transcript.emit("MHA8_MANIFEST_COMPARE_FAIL")
            return 1

        if actual_steps_obj is None:
            transcript.emit(f"MHA8_MANIFEST_COMPARE_PASS heads={len(per_head)} extra_entries={len(extra_entries)}")
        else:
            transcript.emit(f"MHA8_MANIFEST_COMPARE_PASS steps={len(actual_steps)} heads={len(per_head)} extra_entries={len(extra_entries)}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
