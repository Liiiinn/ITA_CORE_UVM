#!/usr/bin/env python3
# Copyright 2026
# SPDX-License-Identifier: Apache-2.0

"""Adapt PyITA standalone Q projection vectors to the tbak MHA8 UVM CSV flow.

This is intentionally an adapter, not a PyITA generator. It consumes an existing
standalone directory containing Q.txt, Wq_<head>.txt, Bq_<head>.txt, and
Qp_<head>.txt, then emits:

  - sim/logger/uvm_pyita_q_mha8_stream.csv
  - sim/logger/uvm_pyita_q_mha8_manifest.json
  - sim/logger/expected_q_head<N>.txt

The current UVM directed test still runs the DUT through the Linear/MatMul
single-step path. The manifest records source.step=Q and compare.actual_step=MatMul
so the source of the data remains explicit.
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


def rel_to_core(path: Path, root: Path) -> str:
    try:
        return str(path.resolve().relative_to(root.resolve()))
    except ValueError:
        return str(path)


def read_values(path: Path) -> list[int]:
    if not path.is_file():
        raise FileNotFoundError(f"Required PyITA vector file not found: {path}")

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


def require_count(path: Path, values: list[int], count: int) -> None:
    if len(values) < count:
        raise ValueError(f"{path} contains {len(values)} value(s), but {count} are required")


def twos(value: int, bits: int) -> int:
    return value & ((1 << bits) - 1)


def pack_lanes(values: list[int], bits: int) -> int:
    packed = 0
    for index, value in enumerate(values):
        packed |= twos(value, bits) << (bits * index)
    return packed


def hex_payload(value: int) -> str:
    return f"0x{value:x}"


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


def write_manifest(path: Path, manifest: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write("\n")


def make_row(kind: str, head: int, beat: int, step: str, payload: int) -> dict[str, Any]:
    return {
        "kind": kind,
        "head_id": head,
        "tile_id": 0,
        "inner_tile_id": 0,
        "beat_id": beat,
        "step": step,
        "is_lockstep": 1,
        "payload": hex_payload(payload),
    }


def main() -> int:
    root = core_root()
    default_out_dir = root / "sim" / "logger"

    parser = argparse.ArgumentParser(description="Adapt PyITA Q vectors into tbak MHA8 UVM stream/manifest files.")
    parser.add_argument("--pyita-dir", required=True, type=Path, help="PyITA standalone vector directory.")
    parser.add_argument("--out-dir", type=Path, default=default_out_dir, help="Directory for generated UVM files.")
    parser.add_argument("--heads", type=int, default=8, help="Number of MHA heads to adapt, starting at head 0.")
    parser.add_argument("--input-lanes", type=int, default=64, help="Number of int8 lanes in one inp_t payload.")
    parser.add_argument("--weight-lanes", type=int, default=16, help="Number of int8 lanes in one inp_weight_t payload.")
    parser.add_argument("--bias-lanes", type=int, default=16, help="Number of bias lanes in one bias_t payload.")
    parser.add_argument("--bias-bits", type=int, default=24, help="Bit width used to pack each bias lane.")
    parser.add_argument("--output-lanes", type=int, default=16, help="Number of int8 lanes in one requant_oup_t payload.")
    parser.add_argument("--weight-beats", type=int, default=64, help="Number of weight beats emitted per head.")
    parser.add_argument("--input-beats", type=int, default=1, help="Number of input beats emitted per head.")
    parser.add_argument("--bias-beats", type=int, default=1, help="Number of bias beats emitted per head.")
    parser.add_argument("--expected-beats", type=int, default=1, help="Number of expected output beats emitted per head.")
    parser.add_argument("--source-step", default="Q", help="PyITA source step recorded in the manifest.")
    parser.add_argument("--dut-step", default="MatMul", help="DUT compare step used by the current UVM Linear path.")
    parser.add_argument("--stream-name", default="uvm_pyita_q_mha8_stream.csv")
    parser.add_argument("--manifest-name", default="uvm_pyita_q_mha8_manifest.json")
    parser.add_argument("--expected-prefix", default="expected_q_head")
    parser.add_argument("--actual-prefix", default="actual_q_head")
    parser.add_argument("--actual-csv-name", default="ita_mha8_output.csv")
    args = parser.parse_args()

    if args.heads <= 0 or args.heads > 8:
        raise ValueError("--heads must be in the range 1..8")
    for name in ("input_lanes", "weight_lanes", "bias_lanes", "bias_bits", "output_lanes"):
        if getattr(args, name) <= 0:
            raise ValueError(f"--{name.replace('_', '-')} must be greater than zero")
    for name in ("weight_beats", "input_beats", "bias_beats", "expected_beats"):
        if getattr(args, name) <= 0:
            raise ValueError(f"--{name.replace('_', '-')} must be greater than zero")

    pyita_dir = args.pyita_dir
    if not pyita_dir.is_absolute():
        pyita_dir = Path.cwd() / pyita_dir
    pyita_dir = pyita_dir.resolve()
    if not pyita_dir.is_dir():
        raise FileNotFoundError(f"PyITA standalone directory not found: {pyita_dir}")

    out_dir = args.out_dir
    stream_path = out_dir / args.stream_name
    manifest_path = out_dir / args.manifest_name
    actual_csv_path = out_dir / args.actual_csv_name

    input_path = pyita_dir / "Q.txt"
    input_values = read_values(input_path)
    require_count(input_path, input_values, args.input_lanes * args.input_beats)

    rows: list[dict[str, Any]] = []
    per_head: list[dict[str, Any]] = []

    for head in range(args.heads):
        weight_path = pyita_dir / f"Wq_{head}.txt"
        bias_path = pyita_dir / f"Bq_{head}.txt"
        expected_source_path = pyita_dir / f"Qp_{head}.txt"

        weight_values = read_values(weight_path)
        bias_values = read_values(bias_path)
        expected_values = read_values(expected_source_path)

        require_count(weight_path, weight_values, args.weight_lanes * args.weight_beats)
        require_count(bias_path, bias_values, args.bias_lanes * args.bias_beats)
        require_count(expected_source_path, expected_values, args.output_lanes * args.expected_beats)

        for beat in range(args.weight_beats):
            start = beat * args.weight_lanes
            payload = pack_lanes(weight_values[start : start + args.weight_lanes], 8)
            rows.append(make_row("head_weight", head, beat, args.dut_step, payload))

        for beat in range(args.input_beats):
            start = beat * args.input_lanes
            payload = pack_lanes(input_values[start : start + args.input_lanes], 8)
            rows.append(make_row("head_input", head, beat, args.dut_step, payload))

        for beat in range(args.bias_beats):
            start = beat * args.bias_lanes
            payload = pack_lanes(bias_values[start : start + args.bias_lanes], args.bias_bits)
            rows.append(make_row("head_bias", head, beat, args.dut_step, payload))

        expected_path = out_dir / f"{args.expected_prefix}{head}.txt"
        actual_path = out_dir / f"{args.actual_prefix}{head}.txt"
        expected_payloads: list[str] = []
        expected_path.parent.mkdir(parents=True, exist_ok=True)
        with expected_path.open("w", encoding="utf-8") as f:
            for beat in range(args.expected_beats):
                start = beat * args.output_lanes
                payload = pack_lanes(expected_values[start : start + args.output_lanes], 8)
                expected_payloads.append(hex_payload(payload))
                f.write(f"{hex_payload(payload)}\n")

        per_head.append(
            {
                "head_id": head,
                "input_path": rel_to_core(input_path, root),
                "weight_path": rel_to_core(weight_path, root),
                "bias_path": rel_to_core(bias_path, root),
                "expected_source_path": rel_to_core(expected_source_path, root),
                "expected_path": rel_to_core(expected_path, root),
                "actual_path": rel_to_core(actual_path, root),
                "expected_values": expected_payloads,
            }
        )

    write_stream_csv(stream_path, rows)

    manifest = {
        "name": "pyita_q_mha8_linear_adapter",
        "layer": "Linear",
        "activation": "Identity",
        "heads": args.heads,
        "step": args.dut_step,
        "stream": "per_head",
        "source": {
            "type": "pyita",
            "step": args.source_step,
            "vector_dir": rel_to_core(pyita_dir, root),
            "input_file": "Q.txt",
            "weight_prefix": "Wq",
            "bias_prefix": "Bq",
            "expected_prefix": "Qp",
        },
        "compare": {
            "actual_step": args.dut_step,
            "stream": "per_head",
        },
        "stream_path": rel_to_core(stream_path, root),
        "actual_csv": rel_to_core(actual_csv_path, root),
        "tile_s": 1,
        "tile_e": 1,
        "tile_p": 1,
        "tile_f": 1,
        "input_lanes": args.input_lanes,
        "weight_lanes": args.weight_lanes,
        "bias_lanes": args.bias_lanes,
        "bias_bits": args.bias_bits,
        "output_lanes": args.output_lanes,
        "weight_beats": args.weight_beats,
        "input_beats": args.input_beats,
        "bias_beats": args.bias_beats,
        "expected_beats": args.expected_beats,
        "per_head": per_head,
    }
    write_manifest(manifest_path, manifest)

    print(f"Wrote {len(rows)} stream rows -> {stream_path}")
    print(f"Wrote {args.heads} PyITA-Q expected files -> {out_dir / (args.expected_prefix + '<head>.txt')}")
    print(f"Wrote manifest -> {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


