#!/usr/bin/env python3
# Copyright 2026
# SPDX-License-Identifier: Apache-2.0

"""Generate dependency-light vectors for the tbak Linear head0 flow.

This script is intentionally small and does not import PyITA. It emits the
first Stage 10 Python-to-UVM contract:

  - expected_matmul_head0.txt
  - uvm_linear_head0_stream.csv
  - uvm_linear_head0_manifest.json

The default values match the current tbak directed test:
  input payload  = 2
  weight payload = 2 repeated 64 times
  bias payload   = 4
  requant        = identity-like, index 0: mult=1 shift=0 add=0
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


def expected_linear_head0_payload(
    input_payload: int,
    weight_payload: int,
    bias_payload: int,
    lanes: int,
    requant_mult: int,
    requant_shift: int,
    requant_add: int,
) -> int:
    """Compute the current scalar shorthand expected packed output.

    The tbak directed stream uses packed scalar payloads. With the current DUT
    path and preload pattern, every output lane sees input*weight. Lane 0 also
    carries the packed scalar bias contribution. This is not a full PyITA golden
    model; it is a small functional check for the Stage 10 head0 Linear smoke.
    """

    base = input_payload * weight_payload
    out_lanes: list[int] = []
    for lane in range(lanes):
        acc = base + (bias_payload if lane == 0 else 0)
        value = (acc * requant_mult) >> requant_shift
        value += requant_add
        out_lanes.append(clamp_i8(value))
    return pack_lanes_u8(out_lanes)


def write_expected(path: Path, values: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for value in values:
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
    head_id: int,
    n_write_en: int,
    input_payload: int,
    weight_payload: int,
    bias_payload: int,
    step: str,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for beat in range(n_write_en):
        rows.append(
            {
                "kind": "head_weight",
                "head_id": head_id,
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
            "head_id": head_id,
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
            "head_id": head_id,
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

    parser = argparse.ArgumentParser(description="Generate tbak Linear head0 expected/stimulus files.")
    parser.add_argument("--out-dir", type=Path, default=default_out_dir, help="Directory for generated files.")
    parser.add_argument("--head", type=int, default=0, help="Target head id.")
    parser.add_argument("--lanes", type=int, default=16, help="Number of u8 lanes in one output payload.")
    parser.add_argument("--n-write-en", type=int, default=64, help="Number of weight preload beats.")
    parser.add_argument("--input", dest="input_payload", type=parse_int, default=2, help="Packed input payload.")
    parser.add_argument("--weight", dest="weight_payload", type=parse_int, default=2, help="Packed weight payload.")
    parser.add_argument("--bias", dest="bias_payload", type=parse_int, default=4, help="Packed bias payload.")
    parser.add_argument("--requant-mult", type=parse_int, default=1, help="Expected requant multiplier.")
    parser.add_argument("--requant-shift", type=parse_int, default=0, help="Expected requant right shift.")
    parser.add_argument("--requant-add", type=parse_int, default=0, help="Expected requant add.")
    parser.add_argument(
        "--expected",
        dest="expected_values",
        action="append",
        type=parse_int,
        help="Override expected output payload. May be repeated.",
    )
    parser.add_argument("--step", default="MatMul", help="Logical DUT step stored in generated CSV metadata.")
    parser.add_argument("--expected-name", default="expected_matmul_head0.txt")
    parser.add_argument("--stream-name", default="uvm_linear_head0_stream.csv")
    parser.add_argument("--manifest-name", default="uvm_linear_head0_manifest.json")
    args = parser.parse_args()

    if args.n_write_en <= 0:
        raise ValueError("--n-write-en must be greater than zero")
    if args.head < 0:
        raise ValueError("--head must be non-negative")
    if args.lanes <= 0:
        raise ValueError("--lanes must be greater than zero")
    if args.requant_shift < 0:
        raise ValueError("--requant-shift must be non-negative")

    out_dir = args.out_dir
    expected_path = out_dir / args.expected_name
    stream_path = out_dir / args.stream_name
    manifest_path = out_dir / args.manifest_name

    default_expected = expected_linear_head0_payload(
        input_payload=args.input_payload,
        weight_payload=args.weight_payload,
        bias_payload=args.bias_payload,
        lanes=args.lanes,
        requant_mult=args.requant_mult,
        requant_shift=args.requant_shift,
        requant_add=args.requant_add,
    )
    expected_values = args.expected_values if args.expected_values is not None else [default_expected]
    rows = make_stream_rows(
        head_id=args.head,
        n_write_en=args.n_write_en,
        input_payload=args.input_payload,
        weight_payload=args.weight_payload,
        bias_payload=args.bias_payload,
        step=args.step,
    )

    write_expected(expected_path, expected_values)
    write_stream_csv(stream_path, rows)

    manifest = {
        "name": "linear_head0",
        "layer": "Linear",
        "activation": "Identity",
        "head_id": args.head,
        "lanes": args.lanes,
        "step": args.step,
        "tile_s": 1,
        "tile_e": 1,
        "tile_p": 1,
        "tile_f": 1,
        "n_write_en": args.n_write_en,
        "input_payload": hex_payload(args.input_payload),
        "weight_payload": hex_payload(args.weight_payload),
        "bias_payload": hex_payload(args.bias_payload),
        "requant_mult": hex_payload(args.requant_mult),
        "requant_shift": args.requant_shift,
        "requant_add": args.requant_add,
        "expected_values": [hex_payload(value) for value in expected_values],
        "expected_path": str(expected_path),
        "stream_path": str(stream_path),
    }
    write_manifest(manifest_path, manifest)

    print(f"Wrote expected values -> {expected_path}")
    print(f"Wrote {len(rows)} stream rows -> {stream_path}")
    print(f"Wrote manifest -> {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

