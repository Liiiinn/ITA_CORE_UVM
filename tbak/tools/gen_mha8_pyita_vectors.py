#!/usr/bin/env python3
# Copyright 2026
# SPDX-License-Identifier: Apache-2.0

"""Adapt PyITA standalone Q/K/V projection vectors to the tbak MHA8 UVM CSV flow.

This is intentionally an adapter, not a PyITA generator. It consumes an existing
standalone directory containing projection input, weight, bias, and expected
files such as Q.txt, Wq_<head>.txt, Bq_<head>.txt, and Qp_<head>.txt, then emits:

  - sim/logger/uvm_pyita_<projection>_mha8_stream.csv
  - sim/logger/uvm_pyita_<projection>_mha8_manifest.json
  - sim/logger/expected_<projection>_head<N>.txt

The current UVM directed test can run the DUT through the selected Attention
projection step. The manifest records both source.step and compare.actual_step
so the data source and DUT-observed step remain explicit.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from dataclasses import dataclass
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


def read_table(path: Path) -> list[list[int]]:
    if not path.is_file():
        raise FileNotFoundError(f"Required PyITA requant file not found: {path}")

    rows: list[list[int]] = []
    with path.open("r", encoding="utf-8-sig", errors="replace") as f:
        for line_no, raw_line in enumerate(f, start=1):
            line = raw_line.split("#", 1)[0].strip()
            if not line:
                continue
            row: list[int] = []
            for token in line.split():
                try:
                    row.append(parse_int(token))
                except ValueError as exc:
                    raise ValueError(f"Invalid integer in {path} line {line_no}: {token!r}") from exc
            rows.append(row)
    return rows


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


def source_beats(path: Path, values: list[int], lanes: int) -> int:
    beats = len(values) // lanes
    if beats == 0:
        raise ValueError(f"{path} does not contain a complete {lanes}-lane beat")
    return beats


def pack_source_beat(values: list[int], lanes: int, bits: int, beat: int, source_count: int) -> int:
    source_beat = beat % source_count
    start = source_beat * lanes
    return pack_lanes(values[start : start + lanes], bits)


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


def write_requant_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = ["step", "head_id", "mult", "shift", "add"]
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


def step_requant_column(step: str) -> int:
    mapping = {
        "Q": 0,
        "K": 1,
        "V": 2,
        "QK": 3,
        "AV": 4,
        "OW": 5,
        "SUM": 6,
        "OW_SUM": 6,
        "F1": 6,
        "F2": 7,
        "MatMul": 0,
    }
    try:
        return mapping[step]
    except KeyError as exc:
        raise ValueError(f"Unsupported PyITA requant step: {step}") from exc


PROJECTION_FILES = {
    "Q": {
        "input_file": "Q.txt",
        "weight_prefix": "Wq",
        "bias_prefix": "Bq",
        "expected_prefix": "Qp",
    },
    "K": {
        "input_file": "K.txt",
        "weight_prefix": "Wk",
        "bias_prefix": "Bk",
        "expected_prefix": "Kp",
    },
    "V": {
        "input_file": "V.txt",
        "weight_prefix": "Wv",
        "bias_prefix": "Bv",
        "expected_prefix": "Vp",
    },
}

MULTI_STEP_PROJECTIONS = {
    "QKV": ["Q", "K", "V"],
    "ATTN": ["Q", "K", "V", "QK", "AV", "OW"],
    "ATTNFF": ["Q", "K", "V", "QK", "AV", "OW", "F1", "F2"],
}

FF_STEPS = {"F1", "F2"}


@dataclass(frozen=True)
class StepSources:
    input_path: Path
    input_values: list[int]
    stream_input_path: Path
    stream_input_values: list[int]
    weight_path: Path
    stream_weight_path: Path
    stream_weight_values: list[int]
    bias_path: Path | None
    bias_values: list[int]
    expected_source_path: Path
    expected_values: list[int]
    generated_zero_bias: bool = False


@dataclass(frozen=True)
class FfStepSources:
    input_path: Path
    input_values: list[int]
    weight_path: Path
    weight_values: list[int]
    bias_path: Path
    bias_values: list[int]
    expected_source_path: Path
    expected_values: list[int]


def path_label(path: Path | None, root: Path) -> str:
    if path is None:
        return "generated:zero"
    return rel_to_core(path, root)


def resolve_step_sources(
    pyita_dir: Path,
    step_name: str,
    head: int,
    input_file: str | None,
    weight_prefix: str | None,
    bias_prefix: str | None,
    expected_source_prefix: str | None,
    bias_lanes: int,
) -> StepSources:
    if step_name in PROJECTION_FILES:
        step_files = PROJECTION_FILES[step_name]
        step_input_file = step_files["input_file"] if input_file is None else input_file
        step_weight_prefix = step_files["weight_prefix"] if weight_prefix is None else weight_prefix
        step_bias_prefix = step_files["bias_prefix"] if bias_prefix is None else bias_prefix
        step_expected_source_prefix = (
            step_files["expected_prefix"] if expected_source_prefix is None else expected_source_prefix
        )

        input_path = pyita_dir / step_input_file
        weight_path = pyita_dir / f"{step_weight_prefix}_{head}.txt"
        bias_path = pyita_dir / f"{step_bias_prefix}_{head}.txt"
        expected_source_path = pyita_dir / f"{step_expected_source_prefix}_{head}.txt"

        input_values = read_values(input_path)
        weight_values = read_values(weight_path)
        bias_values = read_values(bias_path)
        expected_values = read_values(expected_source_path)

        if step_name == "V":
            return StepSources(
                input_path=input_path,
                input_values=input_values,
                stream_input_path=weight_path,
                stream_input_values=weight_values,
                weight_path=weight_path,
                stream_weight_path=input_path,
                stream_weight_values=input_values,
                bias_path=bias_path,
                bias_values=bias_values,
                expected_source_path=expected_source_path,
                expected_values=expected_values,
            )

        return StepSources(
            input_path=input_path,
            input_values=input_values,
            stream_input_path=input_path,
            stream_input_values=input_values,
            weight_path=weight_path,
            stream_weight_path=weight_path,
            stream_weight_values=weight_values,
            bias_path=bias_path,
            bias_values=bias_values,
            expected_source_path=expected_source_path,
            expected_values=expected_values,
        )

    if step_name == "QK":
        input_path = pyita_dir / f"Qp_in_{head}.txt"
        weight_path = pyita_dir / f"Kp_in_{head}.txt"
        expected_source_path = pyita_dir / f"A_{head}.txt"
    elif step_name == "AV":
        input_path = pyita_dir / f"A_stream_soft_in_{head}.txt"
        weight_path = pyita_dir / f"Vp_in_{head}.txt"
        expected_source_path = pyita_dir / f"O_soft_{head}.txt"
    elif step_name == "OW":
        input_path = pyita_dir / f"O_soft_in_{head}.txt"
        weight_path = pyita_dir / f"Wo_{head}.txt"
        expected_source_path = pyita_dir / f"Out_soft_{head}.txt"
    else:
        raise ValueError(f"Unsupported ATTN projection step: {step_name}")

    input_values = read_values(input_path)
    weight_values = read_values(weight_path)
    expected_values = read_values(expected_source_path)

    if step_name in ("QK", "AV"):
        return StepSources(
            input_path=input_path,
            input_values=input_values,
            stream_input_path=input_path,
            stream_input_values=input_values,
            weight_path=weight_path,
            stream_weight_path=weight_path,
            stream_weight_values=weight_values,
            bias_path=None,
            bias_values=[0] * bias_lanes,
            expected_source_path=expected_source_path,
            expected_values=expected_values,
            generated_zero_bias=True,
        )

    bias_path = pyita_dir / f"Bo_{head}.txt"
    bias_values = read_values(bias_path)
    return StepSources(
        input_path=input_path,
        input_values=input_values,
        stream_input_path=input_path,
        stream_input_values=input_values,
        weight_path=weight_path,
        stream_weight_path=weight_path,
        stream_weight_values=weight_values,
        bias_path=bias_path,
        bias_values=bias_values,
        expected_source_path=expected_source_path,
        expected_values=expected_values,
    )


def resolve_ff_step_sources(pyita_dir: Path, step_name: str) -> FfStepSources:
    if step_name == "F1":
        input_path = pyita_dir / "FF.txt"
        weight_path = pyita_dir / "Wff_0.txt"
        bias_path = pyita_dir / "Bff_0.txt"
        expected_source_path = pyita_dir / "FFp_0.txt"
    elif step_name == "F2":
        input_path = pyita_dir / "FFp_in_0.txt"
        weight_path = pyita_dir / "Wff2_0.txt"
        bias_path = pyita_dir / "Bff2_0.txt"
        expected_source_path = pyita_dir / "FF2p_0.txt"
    else:
        raise ValueError(f"Unsupported FF step: {step_name}")

    return FfStepSources(
        input_path=input_path,
        input_values=read_values(input_path),
        weight_path=weight_path,
        weight_values=read_values(weight_path),
        bias_path=bias_path,
        bias_values=read_values(bias_path),
        expected_source_path=expected_source_path,
        expected_values=read_values(expected_source_path),
    )


def make_requant_rows(pyita_dir: Path, step: str, heads: int) -> list[dict[str, Any]]:
    vector_root = pyita_dir.parent
    mult_rows = read_table(vector_root / "RQS_ATTN_MUL.txt")
    shift_rows = read_table(vector_root / "RQS_ATTN_SHIFT.txt")
    add_rows = read_table(vector_root / "RQS_ATTN_ADD.txt")
    column = step_requant_column(step)

    if len(mult_rows) < heads or len(shift_rows) < heads or len(add_rows) < heads:
        raise ValueError(
            "PyITA requant tables do not contain enough head rows: "
            f"mul={len(mult_rows)} shift={len(shift_rows)} add={len(add_rows)} heads={heads}"
        )

    rows: list[dict[str, Any]] = []
    for head in range(heads):
        for table_name, table in (
            ("RQS_ATTN_MUL.txt", mult_rows),
            ("RQS_ATTN_SHIFT.txt", shift_rows),
            ("RQS_ATTN_ADD.txt", add_rows),
        ):
            if len(table[head]) <= column:
                raise ValueError(f"{table_name} head{head} has no column {column} for step {step}")

        rows.append(
            {
                "step": step,
                "head_id": head,
                "mult": mult_rows[head][column],
                "shift": shift_rows[head][column],
                "add": add_rows[head][column],
            }
        )
    return rows


def make_ff_requant_row(pyita_dir: Path, step: str) -> dict[str, Any]:
    vector_root = pyita_dir.parent
    mult_rows = read_table(vector_root / "RQS_FFN_MUL.txt")
    shift_rows = read_table(vector_root / "RQS_FFN_SHIFT.txt")
    add_rows = read_table(vector_root / "RQS_FFN_ADD.txt")
    column = {"F1": 0, "F2": 1}[step]

    for table_name, table in (
        ("RQS_FFN_MUL.txt", mult_rows),
        ("RQS_FFN_SHIFT.txt", shift_rows),
        ("RQS_FFN_ADD.txt", add_rows),
    ):
        if not table or len(table[0]) <= column:
            raise ValueError(f"{table_name} has no column {column} for step {step}")

    return {
        "step": step,
        "head_id": 0,
        "mult": mult_rows[0][column],
        "shift": shift_rows[0][column],
        "add": add_rows[0][column],
    }


def main() -> int:
    root = core_root()
    default_out_dir = root / "sim" / "logger"

    parser = argparse.ArgumentParser(description="Adapt PyITA Q/K/V vectors into tbak MHA8 UVM stream/manifest files.")
    parser.add_argument("--pyita-dir", required=True, type=Path, help="PyITA standalone vector directory.")
    parser.add_argument("--out-dir", type=Path, default=default_out_dir, help="Directory for generated UVM files.")
    parser.add_argument(
        "--projection",
        choices=sorted(PROJECTION_FILES) + sorted(MULTI_STEP_PROJECTIONS),
        default="Q",
        help=(
            "PyITA projection to adapt. QKV emits Q -> K -> V; ATTN emits Q -> K -> V -> QK -> AV -> OW; "
            "ATTNFF appends F1 -> F2 feed-forward streams."
        ),
    )
    parser.add_argument("--heads", type=int, default=8, help="Number of MHA heads to adapt, starting at head 0.")
    parser.add_argument("--input-lanes", type=int, default=64, help="Number of int8 lanes in one inp_t payload.")
    parser.add_argument("--weight-lanes", type=int, default=16, help="Number of int8 lanes in one inp_weight_t payload.")
    parser.add_argument("--weight-row-width", type=int, default=64, help="Logical row width of Wq_<head>.txt from PyITA tiler_QK.")
    parser.add_argument("--bias-lanes", type=int, default=16, help="Number of bias lanes in one bias_t payload.")
    parser.add_argument("--bias-bits", type=int, default=24, help="Bit width used to pack each bias lane.")
    parser.add_argument("--output-lanes", type=int, default=16, help="Number of int8 lanes in one requant_oup_t payload.")
    parser.add_argument("--weight-beats", type=int, default=0, help="Number of weight beats emitted per head; 0 uses all Wq rows.")
    parser.add_argument("--input-beats", type=int, default=0, help="Number of input beats emitted per head; 0 matches expected beats.")
    parser.add_argument("--bias-beats", type=int, default=0, help="Number of bias beats emitted per head; 0 matches expected beats.")
    parser.add_argument("--expected-beats", type=int, default=0, help="Number of expected output beats emitted per head; 0 uses all Qp rows.")
    parser.add_argument("--tile-beats", type=int, default=256, help="Handshake beats in one 64x64/16 ITA output tile.")
    parser.add_argument("--source-step", help="PyITA source step recorded in the manifest; defaults to --projection.")
    parser.add_argument("--dut-step", default="MatMul", help="DUT compare step used by the current UVM Linear path.")
    parser.add_argument("--input-file", help="Override projection input file name, e.g. Q.txt.")
    parser.add_argument("--weight-prefix", help="Override projection weight prefix, e.g. Wq.")
    parser.add_argument("--bias-prefix", help="Override projection bias prefix, e.g. Bq.")
    parser.add_argument("--expected-source-prefix", help="Override PyITA expected prefix, e.g. Qp.")
    parser.add_argument("--stream-name")
    parser.add_argument("--requant-name")
    parser.add_argument("--manifest-name")
    parser.add_argument("--expected-prefix")
    parser.add_argument("--actual-prefix")
    parser.add_argument("--actual-csv-name", default="ita_mha8_output.csv")
    args = parser.parse_args()

    projection = args.projection.upper()
    projection_lower = projection.lower()
    is_multi_step = projection in MULTI_STEP_PROJECTIONS
    projections = MULTI_STEP_PROJECTIONS[projection] if is_multi_step else [projection]
    head_projections = [step for step in projections if step not in FF_STEPS]
    ff_projections = [step for step in projections if step in FF_STEPS]
    if is_multi_step and any(
        value is not None
        for value in (args.source_step, args.input_file, args.weight_prefix, args.bias_prefix, args.expected_source_prefix)
    ):
        raise ValueError(f"{projection} mode uses fixed file conventions; do not pass source/file override arguments")

    projection_files = PROJECTION_FILES[projection] if not is_multi_step else None
    source_step = args.source_step if args.source_step is not None else projection
    if is_multi_step:
        input_file = None
        weight_prefix = None
        bias_prefix = None
        expected_source_prefix = None
    else:
        input_file = args.input_file if args.input_file is not None else projection_files["input_file"]
        weight_prefix = args.weight_prefix if args.weight_prefix is not None else projection_files["weight_prefix"]
        bias_prefix = args.bias_prefix if args.bias_prefix is not None else projection_files["bias_prefix"]
        expected_source_prefix = (
            args.expected_source_prefix if args.expected_source_prefix is not None else projection_files["expected_prefix"]
        )
    stream_name = args.stream_name if args.stream_name is not None else f"uvm_pyita_{projection_lower}_mha8_stream.csv"
    requant_name = args.requant_name if args.requant_name is not None else f"uvm_pyita_{projection_lower}_mha8_requant.csv"
    manifest_name = (
        args.manifest_name if args.manifest_name is not None else f"uvm_pyita_{projection_lower}_mha8_manifest.json"
    )
    expected_prefix = args.expected_prefix if args.expected_prefix is not None else f"expected_{projection_lower}_head"
    actual_prefix = args.actual_prefix if args.actual_prefix is not None else f"actual_{projection_lower}_head"

    if args.heads <= 0 or args.heads > 8:
        raise ValueError("--heads must be in the range 1..8")
    for name in ("input_lanes", "weight_lanes", "weight_row_width", "bias_lanes", "bias_bits", "output_lanes", "tile_beats"):
        if getattr(args, name) <= 0:
            raise ValueError(f"--{name.replace('_', '-')} must be greater than zero")
    for name in ("weight_beats", "input_beats", "bias_beats", "expected_beats"):
        if getattr(args, name) < 0:
            raise ValueError(f"--{name.replace('_', '-')} must be non-negative")

    pyita_dir = args.pyita_dir
    if not pyita_dir.is_absolute():
        pyita_dir = Path.cwd() / pyita_dir
    pyita_dir = pyita_dir.resolve()
    if not pyita_dir.is_dir():
        raise FileNotFoundError(f"PyITA standalone directory not found: {pyita_dir}")

    out_dir = args.out_dir
    stream_path = out_dir / stream_name
    requant_path = out_dir / requant_name
    manifest_path = out_dir / manifest_name
    actual_csv_path = out_dir / args.actual_csv_name

    rows: list[dict[str, Any]] = []
    requant_rows: list[dict[str, Any]] = []
    per_head: list[dict[str, Any]] = [{"head_id": head, "steps": {}} for head in range(args.heads)] if is_multi_step else []

    for step_name in head_projections:
        step_lower = step_name.lower()
        step_source_step = step_name
        step_expected_prefix = f"expected_{step_lower}_head" if is_multi_step else expected_prefix
        step_actual_prefix = f"actual_{step_lower}_head" if is_multi_step else actual_prefix

        step_requant_rows = make_requant_rows(pyita_dir, step_source_step, args.heads)
        requant_rows.extend(step_requant_rows)

        for head in range(args.heads):
            sources = resolve_step_sources(
                pyita_dir,
                step_name,
                head,
                None if is_multi_step else input_file,
                None if is_multi_step else weight_prefix,
                None if is_multi_step else bias_prefix,
                None if is_multi_step else expected_source_prefix,
                args.bias_lanes,
            )

            input_source_beats = source_beats(sources.stream_input_path, sources.stream_input_values, args.input_lanes)
            weight_source_beats = source_beats(sources.stream_weight_path, sources.stream_weight_values, args.weight_lanes)
            bias_source_beats = source_beats(
                sources.bias_path if sources.bias_path is not None else Path(f"generated_zero_bias_{step_name}"),
                sources.bias_values,
                args.bias_lanes,
            )

            expected_beats = args.expected_beats
            if expected_beats == 0:
                expected_beats = len(sources.expected_values) // args.output_lanes
            input_beats = args.input_beats
            if input_beats == 0:
                input_beats = expected_beats if is_multi_step else input_source_beats
            bias_beats = args.bias_beats
            if bias_beats == 0:
                bias_beats = expected_beats
            weight_beats = args.weight_beats
            if weight_beats == 0:
                weight_beats = expected_beats if is_multi_step else weight_source_beats

            if bias_beats < bias_source_beats:
                raise ValueError(
                    f"Requested bias beats ({bias_beats}) are fewer than source bias beats ({bias_source_beats})"
                )
            if (bias_beats % bias_source_beats) != 0:
                raise ValueError(
                    f"Bias beats ({bias_beats}) must be an integer multiple of source bias beats ({bias_source_beats})"
                )
            bias_repeat = bias_beats // bias_source_beats

            if not is_multi_step:
                require_count(sources.stream_input_path, sources.stream_input_values, args.input_lanes * input_beats)
                require_count(sources.stream_weight_path, sources.stream_weight_values, args.weight_lanes * weight_beats)
            require_count(
                sources.bias_path if sources.bias_path is not None else Path(f"generated_zero_bias_{step_name}"),
                sources.bias_values,
                args.bias_lanes * bias_source_beats,
            )
            require_count(sources.expected_source_path, sources.expected_values, args.output_lanes * expected_beats)

            for beat in range(weight_beats):
                if is_multi_step:
                    payload = pack_source_beat(
                        sources.stream_weight_values, args.weight_lanes, 8, beat, weight_source_beats
                    )
                else:
                    start = beat * args.weight_lanes
                    payload = pack_lanes(sources.stream_weight_values[start : start + args.weight_lanes], 8)
                rows.append(make_row("head_weight", head, beat, step_name, payload))

            for beat in range(input_beats):
                if is_multi_step:
                    payload = pack_source_beat(sources.stream_input_values, args.input_lanes, 8, beat, input_source_beats)
                else:
                    start = beat * args.input_lanes
                    payload = pack_lanes(sources.stream_input_values[start : start + args.input_lanes], 8)
                rows.append(make_row("head_input", head, beat, step_name, payload))

            for beat in range(bias_beats):
                if sources.generated_zero_bias:
                    source_beat = 0
                elif bias_repeat == 1:
                    source_beat = beat
                else:
                    group = beat // (args.tile_beats * bias_repeat)
                    group_offset = beat % (args.tile_beats * bias_repeat)
                    source_beat = group * args.tile_beats + (group_offset % args.tile_beats)
                    if source_beat >= bias_source_beats:
                        raise ValueError(
                            f"Expanded bias beat {beat} maps outside source beats: "
                            f"source_beat={source_beat} source_beats={bias_source_beats}"
                        )
                start = source_beat * args.bias_lanes
                payload = pack_lanes(sources.bias_values[start : start + args.bias_lanes], args.bias_bits)
                rows.append(make_row("head_bias", head, beat, step_name, payload))

            expected_path = out_dir / f"{step_expected_prefix}{head}.txt"
            actual_path = out_dir / f"{step_actual_prefix}{head}.txt"
            expected_payloads: list[str] = []
            expected_path.parent.mkdir(parents=True, exist_ok=True)
            with expected_path.open("w", encoding="utf-8") as f:
                for beat in range(expected_beats):
                    start = beat * args.output_lanes
                    payload = pack_lanes(sources.expected_values[start : start + args.output_lanes], 8)
                    expected_payloads.append(hex_payload(payload))
                    f.write(f"{hex_payload(payload)}\n")

            step_entry = {
                "input_path": rel_to_core(sources.stream_input_path, root),
                "weight_path": rel_to_core(sources.stream_weight_path, root),
                "bias_path": path_label(sources.bias_path, root),
                "generated_zero_bias": sources.generated_zero_bias,
                "pyita_input_path": rel_to_core(sources.input_path, root),
                "pyita_weight_path": rel_to_core(sources.weight_path, root),
                "expected_source_path": rel_to_core(sources.expected_source_path, root),
                "expected_path": rel_to_core(expected_path, root),
                "actual_path": rel_to_core(actual_path, root),
                "requant": step_requant_rows[head],
                "weight_source_beats": weight_source_beats,
                "input_source_beats": input_source_beats,
                "weight_beats": weight_beats,
                "input_beats": input_beats,
                "bias_beats": bias_beats,
                "bias_source_beats": bias_source_beats,
                "bias_repeat": bias_repeat,
                "expected_beats": expected_beats,
                "expected_values": expected_payloads,
            }

            if is_multi_step:
                per_head[head]["steps"][step_name] = step_entry
            else:
                per_head.append({"head_id": head, **step_entry})

    extra_compare_entries: list[dict[str, Any]] = []
    if projection in ("ATTN", "ATTNFF"):
        requant_rows.extend(make_requant_rows(pyita_dir, "SUM", args.heads))

        sum_source_path = pyita_dir / "Out_soft_sum.txt"
        sum_values = read_values(sum_source_path)
        sum_expected_beats = args.expected_beats
        if sum_expected_beats == 0:
            sum_expected_beats = len(sum_values) // args.output_lanes
        require_count(sum_source_path, sum_values, args.output_lanes * sum_expected_beats)

        expected_sum_path = out_dir / "expected_ow_sum.txt"
        actual_sum_path = out_dir / "actual_ow_sum.txt"
        expected_sum_path.parent.mkdir(parents=True, exist_ok=True)
        with expected_sum_path.open("w", encoding="utf-8") as f:
            for beat in range(sum_expected_beats):
                start = beat * args.output_lanes
                payload = pack_lanes(sum_values[start : start + args.output_lanes], 8)
                f.write(f"{hex_payload(payload)}\n")

        extra_compare_entries.append(
            {
                "step": "OW",
                "stream": "sum",
                "expected_source_path": rel_to_core(sum_source_path, root),
                "expected_path": rel_to_core(expected_sum_path, root),
                "actual_path": rel_to_core(actual_sum_path, root),
                "expected_beats": sum_expected_beats,
            }
        )

    for step_name in ff_projections:
        step_lower = step_name.lower()
        sources = resolve_ff_step_sources(pyita_dir, step_name)
        requant_rows.append(make_ff_requant_row(pyita_dir, step_name))

        input_source_beats = source_beats(sources.input_path, sources.input_values, args.input_lanes)
        weight_source_beats = source_beats(sources.weight_path, sources.weight_values, args.weight_lanes)
        bias_source_beats = source_beats(sources.bias_path, sources.bias_values, args.bias_lanes)

        expected_beats = args.expected_beats
        if expected_beats == 0:
            expected_beats = len(sources.expected_values) // args.output_lanes
        input_beats = args.input_beats
        if input_beats == 0:
            input_beats = expected_beats
        weight_beats = args.weight_beats
        if weight_beats == 0:
            weight_beats = expected_beats
        bias_beats = args.bias_beats
        if bias_beats == 0:
            bias_beats = expected_beats

        require_count(sources.expected_source_path, sources.expected_values, args.output_lanes * expected_beats)

        for beat in range(weight_beats):
            payload = pack_source_beat(sources.weight_values, args.weight_lanes, 8, beat, weight_source_beats)
            rows.append(make_row("ff_weight", 0, beat, step_name, payload))

        for beat in range(input_beats):
            payload = pack_source_beat(sources.input_values, args.input_lanes, 8, beat, input_source_beats)
            rows.append(make_row("ff_input", 0, beat, step_name, payload))

        for beat in range(bias_beats):
            payload = pack_source_beat(sources.bias_values, args.bias_lanes, args.bias_bits, beat, bias_source_beats)
            rows.append(make_row("ff_bias", 0, beat, step_name, payload))

        expected_path = out_dir / f"expected_{step_lower}.txt"
        actual_path = out_dir / f"actual_{step_lower}.txt"
        expected_path.parent.mkdir(parents=True, exist_ok=True)
        with expected_path.open("w", encoding="utf-8") as f:
            for beat in range(expected_beats):
                start = beat * args.output_lanes
                payload = pack_lanes(sources.expected_values[start : start + args.output_lanes], 8)
                f.write(f"{hex_payload(payload)}\n")

        extra_compare_entries.append(
            {
                "step": step_name,
                "stream": "ff",
                "expected_source_path": rel_to_core(sources.expected_source_path, root),
                "expected_path": rel_to_core(expected_path, root),
                "actual_path": rel_to_core(actual_path, root),
                "input_path": rel_to_core(sources.input_path, root),
                "weight_path": rel_to_core(sources.weight_path, root),
                "bias_path": rel_to_core(sources.bias_path, root),
                "requant": requant_rows[-1],
                "input_beats": input_beats,
                "weight_beats": weight_beats,
                "bias_beats": bias_beats,
                "expected_beats": expected_beats,
            }
        )

    write_stream_csv(stream_path, rows)
    write_requant_csv(requant_path, requant_rows)

    compare_cfg: dict[str, Any]
    if is_multi_step:
        compare_cfg = {"actual_steps": head_projections, "stream": "per_head"}
        if extra_compare_entries:
            compare_cfg["extra_entries"] = extra_compare_entries
    else:
        compare_cfg = {"actual_step": args.dut_step, "stream": "per_head"}

    manifest = {
        "name": f"pyita_{projection_lower}_mha8_adapter",
        "layer": "Attention" if is_multi_step or args.dut_step == source_step else "Linear",
        "activation": "Identity",
        "heads": args.heads,
        "step": projection if is_multi_step else args.dut_step,
        "stream": "per_head",
        "source": {
            "type": "pyita",
            "projection": projection,
            "step": projection if is_multi_step else source_step,
            "steps": projections,
            "vector_dir": rel_to_core(pyita_dir, root),
            "input_file": input_file if not is_multi_step else None,
            "weight_prefix": weight_prefix if not is_multi_step else None,
            "bias_prefix": bias_prefix if not is_multi_step else None,
            "expected_prefix": expected_source_prefix if not is_multi_step else None,
            "projection_files": PROJECTION_FILES if is_multi_step else None,
            "requant_mult_file": "RQS_ATTN_MUL.txt",
            "requant_shift_file": "RQS_ATTN_SHIFT.txt",
            "requant_add_file": "RQS_ATTN_ADD.txt",
            "ffn_requant_mult_file": "RQS_FFN_MUL.txt" if ff_projections else None,
            "ffn_requant_shift_file": "RQS_FFN_SHIFT.txt" if ff_projections else None,
            "ffn_requant_add_file": "RQS_FFN_ADD.txt" if ff_projections else None,
        },
        "compare": compare_cfg,
        "stream_path": rel_to_core(stream_path, root),
        "requant_path": rel_to_core(requant_path, root),
        "actual_csv": rel_to_core(actual_csv_path, root),
        "tile_s": 1,
        "tile_e": 1,
        "tile_p": 1,
        "tile_f": 1,
        "input_lanes": args.input_lanes,
        "weight_lanes": args.weight_lanes,
        "weight_row_width": args.weight_row_width,
        "bias_lanes": args.bias_lanes,
        "bias_bits": args.bias_bits,
        "output_lanes": args.output_lanes,
        "weight_beats": 0 if is_multi_step else (per_head[0]["weight_beats"] if per_head else 0),
        "input_beats": 0 if is_multi_step else (per_head[0]["input_beats"] if per_head else 0),
        "bias_beats": 0 if is_multi_step else (per_head[0]["bias_beats"] if per_head else 0),
        "expected_beats": 0 if is_multi_step else (per_head[0]["expected_beats"] if per_head else 0),
        "per_head": per_head,
    }
    if is_multi_step:
        manifest["step_order"] = projections
    write_manifest(manifest_path, manifest)

    print(f"Wrote {len(rows)} stream rows -> {stream_path}")
    print(f"Wrote {len(requant_rows)} requant rows -> {requant_path}")
    if is_multi_step:
        print(
            f"Wrote {args.heads * len(head_projections)} PyITA-{projection} per-head expected files "
            f"-> {out_dir / 'expected_<step>_head<head>.txt'}"
        )
        if extra_compare_entries:
            print(f"Wrote {len(extra_compare_entries)} extra expected file(s) for sum/ff streams")
    else:
        print(f"Wrote {args.heads} PyITA-{projection} expected files -> {out_dir / (expected_prefix + '<head>.txt')}")
    print(f"Wrote manifest -> {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


