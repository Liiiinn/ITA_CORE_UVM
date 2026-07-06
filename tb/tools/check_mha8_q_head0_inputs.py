#!/usr/bin/env python3
# Copyright 2026
# SPDX-License-Identifier: Apache-2.0

"""Check that UVM Q/head0 stimulus rows match PyITA standalone sources.

This is a transaction/input-side diagnostic. It does not compute Qp golden
values; it verifies that the CSV feeds Q input/weight/bias/requant data from
the expected PyITA files and applies the non-last-inner zero-bias rule.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


def core_root() -> Path:
    return Path(__file__).resolve().parents[2]


def default_manifest() -> Path:
    return core_root() / "sim" / "logger" / "uvm_pyita_attnff_mha8_manifest.json"


def resolve_user_path(path: Path) -> Path:
    if path.is_absolute():
        return path

    cwd_candidate = Path.cwd() / path
    if cwd_candidate.exists() or (path.parts and path.parts[0] == core_root().name):
        return cwd_candidate

    return core_root() / path


def parse_int(text: Any) -> int:
    value = str(text).strip().replace("_", "")
    if value.lower().startswith("0x"):
        return int(value, 16)
    if value.lower().startswith("-0x"):
        return -int(value[1:], 16)
    return int(value, 10)


def read_values(path: Path) -> list[int]:
    if not path.is_file():
        raise FileNotFoundError(f"Required vector file not found: {path}")

    values: list[int] = []
    with path.open("r", encoding="utf-8-sig", errors="replace") as f:
        for line_no, raw_line in enumerate(f, start=1):
            line = raw_line.split("#", 1)[0].strip()
            if not line:
                continue
            for token in line.split():
                try:
                    values.append(parse_int(token))
                except ValueError as exc:
                    raise ValueError(f"Invalid integer in {path} line {line_no}: {token!r}") from exc
    return values


def read_table(path: Path) -> list[list[int]]:
    rows: list[list[int]] = []
    with path.open("r", encoding="utf-8-sig", errors="replace") as f:
        for line_no, raw_line in enumerate(f, start=1):
            line = raw_line.split("#", 1)[0].strip()
            if not line:
                continue
            try:
                rows.append([parse_int(token) for token in line.split()])
            except ValueError as exc:
                raise ValueError(f"Invalid integer in {path} line {line_no}: {line!r}") from exc
    return rows


def twos(value: int, bits: int) -> int:
    return value & ((1 << bits) - 1)


def pack_lanes(values: list[int], bits: int) -> int:
    packed = 0
    for index, value in enumerate(values):
        packed |= twos(value, bits) << (bits * index)
    return packed


def source_beats(path: Path, values: list[int], lanes: int) -> int:
    beats = len(values) // lanes
    if beats == 0:
        raise ValueError(f"{path} does not contain a complete {lanes}-lane beat")
    return beats


def pack_source_beat(values: list[int], lanes: int, bits: int, beat: int, source_count: int) -> int:
    source_beat = beat % source_count
    start = source_beat * lanes
    return pack_lanes(values[start : start + lanes], bits)


def resolve_path(path_text: str | Path, manifest_path: Path) -> Path:
    path = Path(path_text)
    if path.is_absolute():
        return path

    root_candidate = core_root() / path
    if root_candidate.exists() or str(path).startswith("sim/") or str(path).startswith("sim\\"):
        return root_candidate

    return manifest_path.parent / path


def require_key(obj: dict[str, Any], key: str) -> Any:
    if key not in obj:
        raise KeyError(f"Missing required key: {key}")
    return obj[key]


def payload_int(row: dict[str, str]) -> int:
    return parse_int(row["payload"])


def fail(message: str) -> int:
    print(f"Q_HEAD_INPUT_CHECK_FAIL {message}")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Check Q/head0 UVM stimulus against PyITA source vectors.")
    parser.add_argument("--manifest", type=Path, default=default_manifest(), help="MHA8 manifest path.")
    parser.add_argument("--stream", type=Path, help="Override manifest stream_path.")
    parser.add_argument("--requant", type=Path, help="Override manifest requant_path.")
    parser.add_argument("--step", default="Q", help="Projection step to check. Default: Q.")
    parser.add_argument("--head", type=int, default=0, help="Head id to check. Default: 0.")
    parser.add_argument("--max-rows", type=int, default=0, help="Optional max rows per stream kind to check; 0 checks all.")
    args = parser.parse_args()

    manifest_path = resolve_user_path(args.manifest)
    with manifest_path.open("r", encoding="utf-8-sig") as f:
        manifest = json.load(f)

    step = args.step
    head = args.head
    tile_e = int(require_key(manifest, "tile_e"))
    input_lanes = int(require_key(manifest, "input_lanes"))
    weight_lanes = int(require_key(manifest, "weight_lanes"))
    bias_lanes = int(require_key(manifest, "bias_lanes"))
    bias_bits = int(require_key(manifest, "bias_bits"))

    per_head = require_key(manifest, "per_head")
    head_entry = next((entry for entry in per_head if int(entry["head_id"]) == head), None)
    if head_entry is None:
        raise ValueError(f"Manifest has no per_head entry for head{head}")
    step_cfg = require_key(require_key(head_entry, "steps"), step)

    stream_path = args.stream
    if stream_path is None:
        stream_path = resolve_path(require_key(manifest, "stream_path"), manifest_path)
    else:
        stream_path = resolve_user_path(stream_path)

    input_path = resolve_path(require_key(step_cfg, "input_path"), manifest_path)
    weight_path = resolve_path(require_key(step_cfg, "weight_path"), manifest_path)
    bias_path_text = str(require_key(step_cfg, "bias_path"))
    if bias_path_text == "generated:zero":
        bias_path = None
        bias_values = [0] * bias_lanes
    else:
        bias_path = resolve_path(bias_path_text, manifest_path)
        bias_values = read_values(bias_path)

    input_values = read_values(input_path)
    weight_values = read_values(weight_path)

    input_source_beats = int(step_cfg.get("input_source_beats", source_beats(input_path, input_values, input_lanes)))
    weight_source_beats = int(step_cfg.get("weight_source_beats", source_beats(weight_path, weight_values, weight_lanes)))
    bias_source_beats = int(step_cfg.get("bias_source_beats", source_beats(bias_path or Path("generated_zero"), bias_values, bias_lanes)))

    selected: dict[str, list[dict[str, str]]] = {"head_input": [], "head_weight": [], "head_bias": []}
    with stream_path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            kind = row.get("kind", "")
            if kind not in selected:
                continue
            if row.get("step", "") != step:
                continue
            if parse_int(row.get("head_id", "0")) != head:
                continue
            selected[kind].append(row)

    print(
        "Q_HEAD_INPUT_CHECK_CONTEXT "
        f"manifest={manifest_path} stream={stream_path} step={step} head={head} tile_e={tile_e}"
    )
    print(
        "Q_HEAD_INPUT_CHECK_COUNTS "
        f"input={len(selected['head_input'])} weight={len(selected['head_weight'])} bias={len(selected['head_bias'])}"
    )

    expected_counts = {
        "head_input": int(step_cfg["input_beats"]),
        "head_weight": int(step_cfg["weight_beats"]),
        "head_bias": int(step_cfg["bias_beats"]),
    }
    for kind, expected_count in expected_counts.items():
        actual_count = len(selected[kind])
        if actual_count != expected_count:
            return fail(f"{kind} count mismatch expected={expected_count} actual={actual_count}")

    limit = args.max_rows if args.max_rows > 0 else None

    def check_kind(kind: str, values: list[int], lanes: int, bits: int, source_count: int) -> int:
        rows = selected[kind][:limit]
        for index, row in enumerate(rows):
            got = payload_int(row)
            expected = pack_source_beat(values, lanes, bits, index, source_count)
            if got != expected:
                return fail(
                    f"{kind} first_mismatch index={index} tile={row['tile_id']} inner={row['inner_tile_id']} "
                    f"beat={row['beat_id']} expected=0x{expected:x} actual=0x{got:x}"
                )
        print(f"PASS {kind} rows_checked={len(rows)} source_beats={source_count}")
        return 0

    rc = check_kind("head_input", input_values, input_lanes, 8, input_source_beats)
    if rc != 0:
        return rc
    rc = check_kind("head_weight", weight_values, weight_lanes, 8, weight_source_beats)
    if rc != 0:
        return rc

    bias_rows = selected["head_bias"][:limit]
    bias_source_cursor = 0
    for index, row in enumerate(bias_rows):
        inner_tile_id = parse_int(row["inner_tile_id"])
        got = payload_int(row)
        if inner_tile_id == tile_e - 1 and bias_path is not None:
            expected = pack_source_beat(bias_values, bias_lanes, bias_bits, bias_source_cursor, bias_source_beats)
            bias_source_cursor += 1
        else:
            expected = 0
        if got != expected:
            return fail(
                f"head_bias first_mismatch index={index} tile={row['tile_id']} inner={row['inner_tile_id']} "
                f"beat={row['beat_id']} expected=0x{expected:x} actual=0x{got:x}"
            )
    print(f"PASS head_bias rows_checked={len(bias_rows)} real_bias_rows_checked={bias_source_cursor}")

    requant = require_key(step_cfg, "requant")
    print(
        "Q_HEAD_INPUT_CHECK_REQUANT_MANIFEST "
        f"step={requant['step']} head={requant['head_id']} mult={requant['mult']} "
        f"shift={requant['shift']} add={requant['add']}"
    )

    source_dir = input_path.parent
    vector_root = source_dir.parent
    mul_path = vector_root / "RQS_ATTN_MUL.txt"
    shift_path = vector_root / "RQS_ATTN_SHIFT.txt"
    add_path = vector_root / "RQS_ATTN_ADD.txt"
    if mul_path.is_file() and shift_path.is_file() and add_path.is_file():
        mul_rows = read_table(mul_path)
        shift_rows = read_table(shift_path)
        add_rows = read_table(add_path)
        expected_requant = {
            "mult": mul_rows[head][0],
            "shift": shift_rows[head][0],
            "add": add_rows[head][0],
        }
        for key, expected_value in expected_requant.items():
            actual_value = int(requant[key])
            if actual_value != expected_value:
                return fail(f"requant {key} mismatch expected={expected_value} actual={actual_value}")
        print(
            "PASS requant_vs_pyita "
            f"mult={expected_requant['mult']} shift={expected_requant['shift']} add={expected_requant['add']}"
        )
    else:
        print("WARN requant_vs_pyita skipped: RQS_ATTN_* files not found")

    print("Q_HEAD_INPUT_CHECK_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
