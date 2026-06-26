#!/usr/bin/env python3
# Copyright 2026
# SPDX-License-Identifier: Apache-2.0

"""Generate dependency-light vectors for the tbak Linear MHA8 flow.

This script emits the Stage 10 Python-to-UVM contract for a Linear MHA8 smoke
case:

  - sim/logger/uvm_linear_mha8_stream.csv
  - sim/logger/uvm_linear_mha8_manifest.json
  - sim/logger/expected_matmul_head<N>.txt

The default generates heads 0-7. Payloads vary by head so per-head routing
mistakes are easier to see.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


def core_root() -> Path:
    return Path(__file__).resolve().parents[2]


def parse_int(text: str) -> int:
    value = str(text).strip().replace("_", "")
    if value.lower().startswith("0x"):
        return int(value, 16)
    if value.lower().startswith("-0x"):
        return -int(value[1:], 16)
    return int(value, 10)


def hex_payload(value: int) -> str:
    if value < 0:
        raise ValueError("This simple generator only accepts non-negative packed payloads for now")
    return f"0x{value:x}"


def rel_to_core(path: Path, root: Path) -> str:
    try:
        return str(path.resolve().relative_to(root.resolve()))
    except ValueError:
        return str(path)


def clamp_i8(value: int) -> int:
    if value > 127:
        return 127
    if value < -128:
        return 128
    return value & 0xFF


def pack_lanes_u8(lanes: list[int]) -> int:
    packed = 0
    for index, value in enumerate(lanes):
        packed |= (value & 0xFF) << (8 * index)
    return packed


def expected_linear_payload(
    input_payload: int,
    weight_payload: int,
    bias_payload: int,
    lanes: int,
    requant_mult: int,
    requant_shift: int,
    requant_add: int,
) -> int:
    """Compute the current scalar shorthand expected packed output.

    This is not a full PyITA golden model. It is a small functional check for
    the Stage 10 Linear smoke: every lane sees input*weight, and lane 0 also
    carries the scalar bias contribution.
    """

    base = input_payload * weight_payload
    out_lanes: list[int] = []
    for lane in range(lanes):
        acc = base + (bias_payload if lane == 0 else 0)
        value = (acc * requant_mult) >> requant_shift
        value += requant_add
        out_lanes.append(clamp_i8(value))
    return pack_lanes_u8(out_lanes)


def write_expected(path: Path, value: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        f.write(f"{hex_payload(value)}\n")


def write_stream_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "kind",
        "head_id",
        "tile_id",
        "inner_tile_id",
        "beat_id",
        "step",
        "is_lockstep",
        "payload",
    ]
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def make_stream_rows(
    heads: int,
    n_write_en: int,
    input_base: int,
    weight_base: int,
    bias_base: int,
    step: str,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for head in range(heads):
        input_payload = input_base + head
        weight_payload = weight_base + head
        bias_payload = bias_base + head

        for beat in range(n_write_en):
            rows.append(
                {
                    "kind": "head_weight",
                    "head_id": head,
                    "tile_id": 0,
                    "inner_tile_id": 0,
                    "beat_id": beat,
                    "step": step,
                    "is_lockstep": 1,
                    "payload": hex_payload(weight_payload),
                }
            )

        rows.append(
            {
                "kind": "head_input",
                "head_id": head,
                "tile_id": 0,
                "inner_tile_id": 0,
                "beat_id": 0,
                "step": step,
                "is_lockstep": 1,
                "payload": hex_payload(input_payload),
            }
        )
        rows.append(
            {
                "kind": "head_bias",
                "head_id": head,
                "tile_id": 0,
                "inner_tile_id": 0,
                "beat_id": 0,
                "step": step,
                "is_lockstep": 1,
                "payload": hex_payload(bias_payload),
            }
        )
    return rows


def write_manifest(path: Path, manifest: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write("\n")


def main() -> int:
    root = core_root()
    default_out_dir = root / "sim" / "logger"

    parser = argparse.ArgumentParser(description="Generate tbak Linear MHA8 expected/stimulus files.")
    parser.add_argument("--out-dir", type=Path, default=default_out_dir, help="Directory for generated files.")
    parser.add_argument("--heads", type=int, default=8, help="Number of MHA heads to generate, starting at head 0.")
    parser.add_argument("--lanes", type=int, default=16, help="Number of u8 lanes in one output payload.")
    parser.add_argument("--n-write-en", type=int, default=64, help="Number of weight preload beats per head.")
    parser.add_argument("--input", dest="input_base", type=parse_int, default=2, help="Base packed input payload.")
    parser.add_argument("--weight", dest="weight_base", type=parse_int, default=2, help="Base packed weight payload.")
    parser.add_argument("--bias", dest="bias_base", type=parse_int, default=4, help="Base packed bias payload.")
    parser.add_argument("--requant-mult", type=parse_int, default=1, help="Expected requant multiplier.")
    parser.add_argument("--requant-shift", type=parse_int, default=0, help="Expected requant right shift.")
    parser.add_argument("--requant-add", type=parse_int, default=0, help="Expected requant add.")
    parser.add_argument("--step", default="MatMul", help="Logical DUT step stored in generated CSV metadata.")
    parser.add_argument("--expected-prefix", default="expected_matmul_head")
    parser.add_argument("--actual-prefix", default="actual_matmul_head")
    parser.add_argument("--stream-name", default="uvm_linear_mha8_stream.csv")
    parser.add_argument("--manifest-name", default="uvm_linear_mha8_manifest.json")
    parser.add_argument("--actual-csv-name", default="ita_mha8_output.csv")
    args = parser.parse_args()

    if args.heads <= 0 or args.heads > 8:
        raise ValueError("--heads must be in the range 1..8")
    if args.n_write_en <= 0:
        raise ValueError("--n-write-en must be greater than zero")
    if args.lanes <= 0:
        raise ValueError("--lanes must be greater than zero")
    if args.requant_shift < 0:
        raise ValueError("--requant-shift must be non-negative")

    out_dir = args.out_dir
    stream_path = out_dir / args.stream_name
    manifest_path = out_dir / args.manifest_name
    actual_csv_path = out_dir / args.actual_csv_name

    rows = make_stream_rows(
        heads=args.heads,
        n_write_en=args.n_write_en,
        input_base=args.input_base,
        weight_base=args.weight_base,
        bias_base=args.bias_base,
        step=args.step,
    )
    write_stream_csv(stream_path, rows)

    expected_values: list[str] = []
    per_head: list[dict[str, Any]] = []
    for head in range(args.heads):
        input_payload = args.input_base + head
        weight_payload = args.weight_base + head
        bias_payload = args.bias_base + head
        expected = expected_linear_payload(
            input_payload=input_payload,
            weight_payload=weight_payload,
            bias_payload=bias_payload,
            lanes=args.lanes,
            requant_mult=args.requant_mult,
            requant_shift=args.requant_shift,
            requant_add=args.requant_add,
        )
        expected_path = out_dir / f"{args.expected_prefix}{head}.txt"
        actual_path = out_dir / f"{args.actual_prefix}{head}.txt"
        write_expected(expected_path, expected)
        expected_values.append(hex_payload(expected))
        per_head.append(
            {
                "head_id": head,
                "input_payload": hex_payload(input_payload),
                "weight_payload": hex_payload(weight_payload),
                "bias_payload": hex_payload(bias_payload),
                "expected": hex_payload(expected),
                "expected_path": rel_to_core(expected_path, root),
                "actual_path": rel_to_core(actual_path, root),
            }
        )

    manifest = {
        "name": "linear_mha8_smoke",
        "layer": "Linear",
        "activation": "Identity",
        "heads": args.heads,
        "lanes": args.lanes,
        "step": args.step,
        "stream": "per_head",
        "stream_path": rel_to_core(stream_path, root),
        "actual_csv": rel_to_core(actual_csv_path, root),
        "tile_s": 1,
        "tile_e": 1,
        "tile_p": 1,
        "tile_f": 1,
        "n_write_en": args.n_write_en,
        "requant_mult": hex_payload(args.requant_mult),
        "requant_shift": args.requant_shift,
        "requant_add": args.requant_add,
        "expected_values": expected_values,
        "per_head": per_head,
    }
    write_manifest(manifest_path, manifest)

    print(f"Wrote {len(rows)} stream rows -> {stream_path}")
    print(f"Wrote {args.heads} expected files -> {out_dir / (args.expected_prefix + '<head>.txt')}")
    print(f"Wrote manifest -> {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
