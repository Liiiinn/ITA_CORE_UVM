#!/usr/bin/env python3
"""Generate directed MHA8 regression case manifests."""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


PROJECTION = "ATTNFF"
ACTIVATION = "Relu"
NUMERICAL_PATTERNS = (
    "requant_rounding",
    "requant_saturation",
    "bias_zero",
    "bias_minmax",
    "softmax_all_equal",
    "softmax_dominant",
    "sparse",
    "zero",
)
NEGATIVE_ERROR_RE = r"(UVM_ERROR|UVM_FATAL|CORE CSV|ITA_SCB|SVA|timeout|mismatch|illegal|failed|FAIL)"
NATIVE_VR_ERROR_RE = r"\[ITA_NATIVE_VR\]"


@dataclass(frozen=True)
class Shape:
    s: int
    e: int
    p: int
    f: int

    @property
    def tile_s(self) -> int:
        return self.s // 64

    @property
    def tile_e(self) -> int:
        return self.e // 64

    @property
    def tile_p(self) -> int:
        return self.p // 64

    @property
    def tile_f(self) -> int:
        return self.f // 64


def core_root() -> Path:
    return Path(__file__).resolve().parents[2]


def workspace_root() -> Path:
    return core_root().parent


def ita_root() -> Path:
    return workspace_root() / "ITA"


def logger_dir() -> Path:
    return core_root() / "sim" / "logger"


def rel_to_workspace(path: Path) -> str:
    try:
        return path.resolve().relative_to(workspace_root().resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def vector_root(shape: Shape, heads: int, activation: str, pattern: str = "random", bias: bool = True) -> Path:
    name = f"data_S{shape.s}_E{shape.e}_P{shape.p}_F{shape.f}_H{heads}_B{int(bias)}_{activation}"
    if pattern != "random":
        name = f"{name}_{pattern}"
    return ita_root() / "simvectors" / name


def required_files(projection: str, heads: int) -> list[str]:
    files: list[str] = []
    for head in range(heads):
        files.extend([
            "Q.txt", "K.txt", "V.txt",
            f"Wq_{head}.txt", f"Wk_{head}.txt", f"Wv_{head}.txt", f"Wo_{head}.txt",
            f"Bq_{head}.txt", f"Bk_{head}.txt", f"Bv_{head}.txt", f"Bo_{head}.txt",
            f"Qp_{head}.txt", f"Kp_{head}.txt", f"Vp_{head}.txt",
            f"Qp_in_{head}.txt", f"Kp_in_{head}.txt", f"A_{head}.txt",
            f"A_stream_soft_in_{head}.txt", f"Vp_in_{head}.txt", f"O_soft_{head}.txt",
            f"O_soft_in_{head}.txt", f"Out_soft_{head}.txt",
        ])
    if projection == "ATTNFF":
        files.extend(["FF.txt", "Wff_0.txt", "Bff_0.txt", "FFp_0.txt", "FFp_in_0.txt", "Wff2_0.txt", "Bff2_0.txt", "FF2p_0.txt"])
    return sorted(set(files))


def has_required_vector_files(standalone: Path, projection: str, heads: int) -> bool:
    return all((standalone / name).is_file() for name in required_files(projection, heads))


def run(cmd: list[str], cwd: Path, dry_run: bool) -> None:
    print("PY> " + " ".join(cmd), file=sys.stderr)
    if not dry_run:
        subprocess.run(cmd, cwd=cwd, check=True)


def ensure_vector(
    shape: Shape,
    heads: int,
    activation: str,
    pattern: str,
    python: str,
    no_auto_generate: bool,
    dry_run: bool,
) -> Path:
    root = vector_root(shape, heads, activation, pattern)
    standalone = root / "standalone"
    if has_required_vector_files(standalone, PROJECTION, heads):
        return standalone
    if dry_run:
        return standalone
    if no_auto_generate:
        raise FileNotFoundError(f"Missing vector files for {root.name}")

    cmd = [
        python,
        str(ita_root() / "testGenerator.py"),
        "--seed",
        "0",
        "-S",
        str(shape.s),
        "-E",
        str(shape.e),
        "-P",
        str(shape.p),
        "-F",
        str(shape.f),
        "-H",
        str(heads),
        "--activation",
        activation.lower(),
        "--pattern",
        pattern,
    ]
    run(cmd, ita_root(), dry_run)
    if not dry_run and not has_required_vector_files(standalone, PROJECTION, heads):
        raise RuntimeError(f"Generated vector is incomplete: {standalone}")
    return standalone


def adapter_command(
    python: str,
    standalone: Path,
    shape: Shape,
    heads: int,
    activation: str,
    stream_name: str,
    requant_name: str,
    manifest_name: str,
) -> list[str]:
    return [
        python,
        str(core_root() / "tb" / "tools" / "gen_mha8_pyita_vectors.py"),
        "--pyita-dir",
        str(standalone),
        "--projection",
        PROJECTION,
        "--heads",
        str(heads),
        "--out-dir",
        str(logger_dir()),
        "--stream-name",
        stream_name,
        "--requant-name",
        requant_name,
        "--manifest-name",
        manifest_name,
        "--dut-step",
        PROJECTION,
        "--tile-s",
        str(shape.tile_s),
        "--tile-e",
        str(shape.tile_e),
        "--tile-p",
        str(shape.tile_p),
        "--tile-f",
        str(shape.tile_f),
        "--activation",
        activation,
    ]


def mutate_csv(src: Path, dst: Path, mutation: str) -> None:
    with src.open("r", encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
        fieldnames = f.seek(0) or next(csv.reader(f))

    if not rows:
        raise RuntimeError(f"No rows to mutate in {src}")

    if mutation == "wrong_inner_id":
        rows[0]["inner_tile_id"] = "99"
    elif mutation == "wrong_step_metadata":
        target = next((row for row in rows if row.get("step", "") == "F1"), rows[0])
        target["step"] = "OW"
    elif mutation == "missing_beat":
        rows.pop(0)
    elif mutation == "extra_beat":
        extra = dict(rows[0])
        extra["beat_id"] = "99"
        rows.insert(1, extra)
    else:
        raise ValueError(f"Unsupported CSV mutation: {mutation}")

    with dst.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def smoke_args(
    name: str,
    standalone: Path,
    heads: int,
    activation: str,
    stream_name: str,
    requant_name: str,
    manifest_name: str,
    generate_vectors: bool,
) -> list[str]:
    args = [
        "-TestName",
        "ita_mha8_attn_directed_test",
        "-VectorSource",
        "pyita-q",
        "-Projection",
        PROJECTION,
        "-Activation",
        activation,
        "-PyitaDir",
        rel_to_workspace(standalone),
        "-Heads",
        str(heads),
        "-StreamName",
        stream_name,
        "-ManifestName",
        manifest_name,
        "-RequantName",
        requant_name,
    ]
    if generate_vectors:
        args.append("-GenerateVectors")
    else:
        args.append("-NoGenerateVectors")
    return args


def case_entry(
    name: str,
    category: str,
    intent: str,
    shape: Shape,
    heads: int,
    activation: str,
    standalone: Path,
    stream_name: str,
    requant_name: str,
    manifest_name: str,
    plusargs: dict[str, int],
    generate_vectors: bool = True,
    expect_fail: bool = False,
    expected_error_regex: str = "",
    extra_smoke_args: list[str] | None = None,
) -> dict[str, Any]:
    args = smoke_args(name, standalone, heads, activation, stream_name, requant_name, manifest_name, generate_vectors)
    if extra_smoke_args:
        args.extend(extra_smoke_args)
    default_plusargs = {
        "ntb_random_seed": 1,
        "ITA_SOURCE_GAP_MAX": 0,
        "ITA_INPUT_SOURCE_GAP_MAX": 0,
        "ITA_WEIGHT_SOURCE_GAP_MAX": 0,
        "ITA_BIAS_SOURCE_GAP_MAX": 0,
        "ITA_GROUP_IDLE_GAP_MAX": 0,
        "ITA_READY_LOW_MAX": 0,
        "ITA_READY_HIGH_MAX": 1,
    }
    default_plusargs.update(plusargs)
    return {
        "name": name,
        "category": category,
        "spec_basis": "core_spec_observable",
        "intent": intent,
        "seed": default_plusargs["ntb_random_seed"],
        "target": "ita_mha8_tb_top",
        "dut": "ita_mha8",
        "H": heads,
        "S": shape.s,
        "E": shape.e,
        "P": shape.p,
        "F": shape.f,
        "layer": "AttentionFeedforward",
        "projection": PROJECTION,
        "activation": activation.lower(),
        "bias": True,
        "tile_s": shape.tile_s,
        "tile_e": shape.tile_e,
        "tile_p": shape.tile_p,
        "tile_f": shape.tile_f,
        "expect_fail": expect_fail,
        "expected_error_regex": expected_error_regex,
        "paths": {
            "standalone_dir": rel_to_workspace(standalone),
            "uvm_stream": f"ITA_CORE_UVM/sim/logger/{stream_name}",
            "uvm_manifest": f"ITA_CORE_UVM/sim/logger/{manifest_name}",
            "uvm_requant": f"ITA_CORE_UVM/sim/logger/{requant_name}",
        },
        "smoke_ps1": {
            "script": "ITA_CORE_UVM/sim/scripts/smoke.ps1",
            "args": args,
            "future_plusargs": default_plusargs,
        },
    }


def add_protocol_cases(cases: list[dict[str, Any]], heads: int, python: str, no_auto_generate: bool, dry_run: bool) -> None:
    specs = [
        ("protocol_group_idle_gap", "group_idle_gap", Shape(64, 64, 64, 64), {"ITA_GROUP_IDLE_GAP_MAX": 6}),
        ("protocol_output_backpressure", "output_backpressure", Shape(64, 64, 64, 64), {"ITA_READY_LOW_MAX": 8, "ITA_READY_HIGH_MAX": 3}),
        ("tile_min_s64_e64_p64_f64", "tile_boundary_min", Shape(64, 64, 64, 64), {}),
        ("tile_mixed_s64_e256_p128_f192", "tile_boundary_mixed", Shape(64, 256, 128, 192), {}),
        ("tile_max_s256_e256_p256_f256", "tile_boundary_max", Shape(256, 256, 256, 256), {}),
        ("debug_relu_f1_tail_mismatch", "debug_regression", Shape(64, 64, 64, 64), {"ITA_READY_LOW_MAX": 2, "ITA_READY_HIGH_MAX": 2}),
    ]
    for index, (name, intent, shape, plusargs) in enumerate(specs):
        standalone = ensure_vector(shape, heads, ACTIVATION, "random", python, no_auto_generate, dry_run)
        cases.append(case_entry(
            name,
            "protocol",
            intent,
            shape,
            heads,
            ACTIVATION,
            standalone,
            f"{name}_stream.csv",
            f"{name}_requant.csv",
            f"{name}_manifest.json",
            {"ntb_random_seed": 100 + index, **plusargs},
        ))


def add_numerical_cases(cases: list[dict[str, Any]], heads: int, python: str, no_auto_generate: bool, dry_run: bool) -> None:
    shape = Shape(64, 64, 64, 64)
    for index, pattern in enumerate(NUMERICAL_PATTERNS):
        activation = "Identity" if pattern == "zero" else ACTIVATION
        standalone = ensure_vector(shape, heads, activation, pattern, python, no_auto_generate, dry_run)
        name = f"numerical_{pattern}"
        cases.append(case_entry(
            name,
            "numerical",
            pattern,
            shape,
            heads,
            activation,
            standalone,
            f"{name}_stream.csv",
            f"{name}_requant.csv",
            f"{name}_manifest.json",
            {"ntb_random_seed": 200 + index},
        ))


def add_negative_cases(cases: list[dict[str, Any]], heads: int, python: str, no_auto_generate: bool, dry_run: bool) -> None:
    shape = Shape(64, 64, 64, 64)
    standalone = ensure_vector(shape, heads, ACTIVATION, "random", python, no_auto_generate, dry_run)

    native_vr_cases = [
        ("head_input", "drop_valid"),
        ("head_input", "mutate_payload_and_metadata"),
        ("head_weight", "drop_valid"),
        ("head_weight", "mutate_payload_and_metadata"),
        ("head_bias", "drop_valid"),
        ("head_bias", "mutate_payload_and_metadata"),
        ("ff_input", "drop_valid"),
        ("ff_input", "mutate_payload_and_metadata"),
        ("ff_weight", "drop_valid"),
        ("ff_weight", "mutate_payload_and_metadata"),
        ("ff_bias", "drop_valid"),
        ("ff_bias", "mutate_payload_and_metadata"),
    ]
    for index, (kind, mode) in enumerate(native_vr_cases):
        name = f"neg_native_vr_{kind}_{mode}"
        cases.append({
            "name": name,
            "category": "native_vr_negative",
            "spec_basis": "core_spec_observable",
            "intent": f"native_valid_ready_{kind}_{mode}",
            "seed": 290 + index,
            "target": "ita_mha8_tb_top",
            "dut": "ita_mha8",
            "H": heads,
            "S": 64,
            "E": 64,
            "P": 64,
            "F": 64,
            "layer": "AttentionFeedforward",
            "projection": "ATTNFF",
            "activation": "identity",
            "bias": True,
            "tile_s": 1,
            "tile_e": 1,
            "tile_p": 1,
            "tile_f": 1,
            "expect_fail": True,
            "expected_error_regex": NATIVE_VR_ERROR_RE,
            "paths": {},
            "smoke_ps1": {
                "script": "ITA_CORE_UVM/sim/scripts/smoke.ps1",
                "args": [
                    "-TestName", "ita_mha8_native_vr_negative_test",
                    "-NoGenerateVectors",
                    "-NoCompare",
                    "-ProtocolNumJobs", "1",
                    "-ProtocolTileMin", "1",
                    "-ProtocolTileMax", "1",
                    "-ProtocolProjection", "ATTNFF",
                    "-ReadyLowMax", "64",
                    "-ReadyHighMax", "1",
                    "-NativeVrFaultKind", kind,
                    "-NativeVrFaultMode", mode,
                    "-NativeVrFaultHead", "0",
                ],
                "future_plusargs": {
                    "ntb_random_seed": 290 + index,
                    "ITA_SOURCE_GAP_MAX": 0,
                    "ITA_INPUT_SOURCE_GAP_MAX": 0,
                    "ITA_WEIGHT_SOURCE_GAP_MAX": 0,
                    "ITA_BIAS_SOURCE_GAP_MAX": 0,
                    "ITA_GROUP_IDLE_GAP_MAX": 0,
                    "ITA_READY_LOW_MAX": 64,
                    "ITA_READY_HIGH_MAX": 1,
                },
            },
        })

    tile_cases = [
        ("neg_tile_zero", "illegal_tile_zero", ["-TileSOverride", "0"]),
        ("neg_tile_over_max", "illegal_tile_over_max", ["-TileSOverride", "5"]),
    ]
    for index, (name, intent, extra_args) in enumerate(tile_cases):
        cases.append(case_entry(
            name,
            "negative",
            intent,
            shape,
            heads,
            ACTIVATION,
            standalone,
            f"{name}_stream.csv",
            f"{name}_requant.csv",
            f"{name}_manifest.json",
            {"ntb_random_seed": 300 + index},
            expect_fail=True,
            expected_error_regex=NEGATIVE_ERROR_RE,
            extra_smoke_args=extra_args,
        ))

    mutation_base = "neg_base_attnff_relu_s64"
    base_stream = logger_dir() / f"{mutation_base}_stream.csv"
    base_requant = f"{mutation_base}_requant.csv"
    base_manifest = f"{mutation_base}_manifest.json"
    if not dry_run:
        logger_dir().mkdir(parents=True, exist_ok=True)
    run(adapter_command(
        python,
        standalone,
        shape,
        heads,
        ACTIVATION,
        base_stream.name,
        base_requant,
        base_manifest,
    ), core_root(), dry_run)

    mutations = ["wrong_inner_id", "wrong_step_metadata", "missing_beat", "extra_beat"]
    for index, mutation in enumerate(mutations):
        name = f"neg_{mutation}"
        mutated_stream = logger_dir() / f"{name}_stream.csv"
        if not dry_run:
            mutate_csv(base_stream, mutated_stream, mutation)
        cases.append(case_entry(
            name,
            "negative",
            mutation,
            shape,
            heads,
            ACTIVATION,
            standalone,
            mutated_stream.name,
            base_requant,
            base_manifest,
            {"ntb_random_seed": 310 + index},
            generate_vectors=False,
            expect_fail=True,
            expected_error_regex=NEGATIVE_ERROR_RE,
        ))

    name = "neg_output_timeout_bp"
    cases.append(case_entry(
        name,
        "output_backpressure_negative",
        "output_timeout_backpressure",
        shape,
        heads,
        ACTIVATION,
        standalone,
        f"{name}_stream.csv",
        f"{name}_requant.csv",
        f"{name}_manifest.json",
        {"ntb_random_seed": 320, "ITA_READY_LOW_MAX": 100000, "ITA_READY_HIGH_MAX": 1},
        expect_fail=True,
        expected_error_regex=r"ITA_OUTPUT_BP_TIMEOUT",
        extra_smoke_args=[
            "-ReadyLowMin", "100000",
            "-OutputBpTimeoutTest",
            "-OutputWaitTimeoutCycles", "2000",
        ],
    ))


def parse_suites(values: list[str]) -> list[str]:
    suites: list[str] = []
    for value in values:
        for item in value.split(","):
            item = item.strip().lower()
            if not item:
                continue
            if item not in {"protocol", "numerical", "negative"}:
                raise ValueError(f"Unsupported suite: {item}")
            suites.append(item)
    return suites or ["protocol", "numerical", "negative"]


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate directed MHA8 regression cases.")
    parser.add_argument("--suite", action="append")
    parser.add_argument("--python", default=sys.executable)
    parser.add_argument("--out", type=Path, default=logger_dir() / "directed_mha8_cases.json")
    parser.add_argument("--heads", type=int, default=8)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-auto-generate", action="store_true")
    args = parser.parse_args()

    if args.heads <= 0 or args.heads > 8:
        raise ValueError("--heads must be in the range 1..8")

    suites = parse_suites(args.suite or ["protocol,numerical,negative"])
    cases: list[dict[str, Any]] = []
    if "protocol" in suites:
        add_protocol_cases(cases, args.heads, args.python, args.no_auto_generate, args.dry_run)
    if "numerical" in suites:
        add_numerical_cases(cases, args.heads, args.python, args.no_auto_generate, args.dry_run)
    if "negative" in suites:
        add_negative_cases(cases, args.heads, args.python, args.no_auto_generate, args.dry_run)

    manifest = {
        "name": "directed_mha8_cases",
        "generator": "gen_directed_mha8_cases.py",
        "suites": suites,
        "cases": cases,
    }

    if args.dry_run:
        print(json.dumps(manifest, indent=2, sort_keys=True))
    else:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        with args.out.open("w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2, sort_keys=True)
            f.write("\n")
        print(f"Wrote {len(cases)} directed case(s) -> {args.out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
