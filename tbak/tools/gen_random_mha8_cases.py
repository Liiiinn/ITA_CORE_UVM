#!/usr/bin/env python3
"""Generate constrained-random MHA8 regression case manifests.

This tool samples constrained-random MHA8 shapes and emits a JSON manifest that
a runner can use to call sim/scripts/smoke.ps1. Missing ITA/simvectors/data_*
directories are generated on demand through ITA/testGenerator.py unless
--no-auto-generate is used.
"""

from __future__ import annotations

import argparse
import json
import random
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CASE_RE = re.compile(
    r"^data_S(?P<S>\d+)_E(?P<E>\d+)_P(?P<P>\d+)_F(?P<F>\d+)_H(?P<H>\d+)_B(?P<B>[01])_(?P<activation>[A-Za-z]+)$"
)

PROJECTION_STEPS: dict[str, list[str]] = {
    "Q": ["Q"],
    "K": ["K"],
    "V": ["V"],
    "QKV": ["Q", "K", "V"],
    "ATTN": ["Q", "K", "V", "QK", "AV", "OW"],
    "ATTNFF": ["Q", "K", "V", "QK", "AV", "OW", "F1", "F2"],
}

SUPPORTED_PROJECTIONS = tuple(PROJECTION_STEPS.keys())
SUPPORTED_ACTIVATIONS = ("Identity", "Relu", "Gelu")
DEFAULT_SHAPE_VALUES = (64, 128, 192, 256)


@dataclass(frozen=True)
class VectorCase:
    name: str
    vector_root: Path
    standalone_dir: Path
    s: int
    e: int
    p: int
    f: int
    heads: int
    bias: bool
    activation: str

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


@dataclass(frozen=True)
class VectorSpec:
    s: int
    e: int
    p: int
    f: int
    heads: int
    bias: bool
    activation: str


def core_root() -> Path:
    return Path(__file__).resolve().parents[2]


def workspace_root() -> Path:
    return core_root().parent


def default_simvectors_root() -> Path:
    return workspace_root() / "ITA" / "simvectors"


def ita_root() -> Path:
    return workspace_root() / "ITA"


def default_test_generator() -> Path:
    return ita_root() / "testGenerator.py"


def rel_to_workspace(path: Path) -> str:
    try:
        return path.resolve().relative_to(workspace_root().resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def normalize_activation(text: str) -> str:
    lowered = text.lower()
    if lowered == "identity":
        return "Identity"
    if lowered == "relu":
        return "Relu"
    if lowered == "gelu":
        return "Gelu"
    raise ValueError(f"Unsupported activation: {text}")


def activation_dir_name(activation: str) -> str:
    return normalize_activation(activation)


def parse_csv_choices(values: list[str], allowed: tuple[str, ...], label: str) -> list[str]:
    parsed: list[str] = []
    for value in values:
        for item in value.split(","):
            item = item.strip()
            if not item:
                continue
            if label == "activation":
                item = normalize_activation(item)
            else:
                item = item.upper()
            if item not in allowed:
                raise ValueError(f"Unsupported {label} '{item}'. Allowed: {', '.join(allowed)}")
            parsed.append(item)
    return parsed


def parse_shape_values(values: list[str] | None) -> list[int]:
    raw_values = values or [",".join(str(value) for value in DEFAULT_SHAPE_VALUES)]
    parsed: list[int] = []
    for value in raw_values:
        for item in value.split(","):
            item = item.strip()
            if not item:
                continue
            dim = int(item)
            if dim <= 0 or dim % 64 != 0:
                raise ValueError(f"Shape value must be a positive multiple of 64: {dim}")
            parsed.append(dim)
    if not parsed:
        raise ValueError("--shape-values did not contain any values")
    return sorted(set(parsed))


def required_files_for_step(step: str, heads: int) -> list[str]:
    files: list[str] = []

    if step == "Q":
        for head in range(heads):
            files += ["Q.txt", f"Wq_{head}.txt", f"Bq_{head}.txt", f"Qp_{head}.txt"]
    elif step == "K":
        for head in range(heads):
            files += ["K.txt", f"Wk_{head}.txt", f"Bk_{head}.txt", f"Kp_{head}.txt"]
    elif step == "V":
        for head in range(heads):
            files += [f"Wv_{head}.txt", "V.txt", f"Bv_{head}.txt", f"Vp_{head}.txt"]
    elif step == "QK":
        for head in range(heads):
            files += [f"Qp_in_{head}.txt", f"Kp_in_{head}.txt", f"A_{head}.txt"]
    elif step == "AV":
        for head in range(heads):
            files += [f"A_stream_soft_in_{head}.txt", f"Vp_in_{head}.txt", f"O_soft_{head}.txt"]
    elif step == "OW":
        for head in range(heads):
            files += [f"O_soft_in_{head}.txt", f"Wo_{head}.txt", f"Bo_{head}.txt", f"Out_soft_{head}.txt"]
    elif step == "F1":
        files += ["FF.txt", "Wff_0.txt", "Bff_0.txt", "FFp_0.txt"]
    elif step == "F2":
        files += ["FFp_in_0.txt", "Wff2_0.txt", "Bff2_0.txt", "FF2p_0.txt"]
    else:
        raise ValueError(f"Unsupported step: {step}")

    return sorted(set(files))


def required_files_for_projection(projection: str, heads: int) -> list[str]:
    files: list[str] = []
    for step in PROJECTION_STEPS[projection]:
        files.extend(required_files_for_step(step, heads))
    return sorted(set(files))


def has_required_files(standalone_dir: Path, projection: str, heads: int) -> bool:
    return all((standalone_dir / name).is_file() for name in required_files_for_projection(projection, heads))


def vector_dir_name(spec: VectorSpec) -> str:
    return (
        f"data_S{spec.s}_E{spec.e}_P{spec.p}_F{spec.f}_H{spec.heads}_"
        f"B{int(spec.bias)}_{activation_dir_name(spec.activation)}"
    )


def vector_case_from_spec(simvectors_root: Path, spec: VectorSpec) -> VectorCase:
    vector_root = simvectors_root / vector_dir_name(spec)
    return VectorCase(
        name=vector_root.name,
        vector_root=vector_root,
        standalone_dir=vector_root / "standalone",
        s=spec.s,
        e=spec.e,
        p=spec.p,
        f=spec.f,
        heads=spec.heads,
        bias=spec.bias,
        activation=normalize_activation(spec.activation),
    )


def spec_from_vector_case(vector: VectorCase) -> VectorSpec:
    return VectorSpec(
        s=vector.s,
        e=vector.e,
        p=vector.p,
        f=vector.f,
        heads=vector.heads,
        bias=vector.bias,
        activation=vector.activation,
    )


def build_specs(
    shape_values: list[int],
    heads: int,
    activations: list[str],
    allow_bias: bool,
    allow_no_bias: bool,
    min_tile: int,
    max_tile: int,
) -> list[VectorSpec]:
    specs: list[VectorSpec] = []
    bias_values: list[bool] = []
    if allow_bias:
        bias_values.append(True)
    if allow_no_bias:
        bias_values.append(False)

    for s in shape_values:
        for e in shape_values:
            for p in shape_values:
                for f in shape_values:
                    if not all(min_tile <= (dim // 64) <= max_tile for dim in (s, e, p, f)):
                        continue
                    for activation in activations:
                        for bias in bias_values:
                            specs.append(
                                VectorSpec(
                                    s=s,
                                    e=e,
                                    p=p,
                                    f=f,
                                    heads=heads,
                                    bias=bias,
                                    activation=activation,
                                )
                            )
    return specs


def test_generator_command(python: str, test_generator: Path, spec: VectorSpec, vector_seed: int) -> list[str]:
    cmd = [
        python,
        str(test_generator),
        "--seed",
        str(vector_seed),
        "-S",
        str(spec.s),
        "-E",
        str(spec.e),
        "-P",
        str(spec.p),
        "-F",
        str(spec.f),
        "-H",
        str(spec.heads),
        "--activation",
        spec.activation.lower(),
    ]
    if not spec.bias:
        cmd.append("--no-bias")
    return cmd


def ensure_vector_case(
    simvectors_root: Path,
    spec: VectorSpec,
    projection: str,
    python: str,
    test_generator: Path,
    vector_seed: int,
    dry_run: bool,
) -> tuple[VectorCase, bool]:
    vector = vector_case_from_spec(simvectors_root, spec)
    if has_required_files(vector.standalone_dir, projection, vector.heads):
        return vector, False

    cmd = test_generator_command(python, test_generator, spec, vector_seed)
    print("PY> " + " ".join(cmd), file=sys.stderr)
    if dry_run:
        return vector, True

    subprocess.run(cmd, cwd=ita_root(), check=True)
    if not has_required_files(vector.standalone_dir, projection, vector.heads):
        raise RuntimeError(
            f"testGenerator.py completed but required {projection} files are still missing under {vector.standalone_dir}"
        )
    return vector, True


def discover_vectors(simvectors_root: Path) -> list[VectorCase]:
    cases: list[VectorCase] = []
    if not simvectors_root.is_dir():
        raise FileNotFoundError(f"simvectors root not found: {simvectors_root}")

    for vector_root in sorted(path for path in simvectors_root.iterdir() if path.is_dir()):
        match = CASE_RE.match(vector_root.name)
        if match is None:
            continue

        standalone_dir = vector_root / "standalone"
        if not standalone_dir.is_dir():
            continue

        s = int(match.group("S"))
        e = int(match.group("E"))
        p = int(match.group("P"))
        f = int(match.group("F"))
        if any(dim % 64 != 0 for dim in (s, e, p, f)):
            continue

        cases.append(
            VectorCase(
                name=vector_root.name,
                vector_root=vector_root,
                standalone_dir=standalone_dir,
                s=s,
                e=e,
                p=p,
                f=f,
                heads=int(match.group("H")),
                bias=bool(int(match.group("B"))),
                activation=normalize_activation(match.group("activation")),
            )
        )

    return cases


def test_name_for_projection(projection: str) -> str:
    if projection in {"Q", "K", "V"}:
        return "ita_mha8_q_directed_test"
    if projection == "QKV":
        return "ita_mha8_qkv_directed_test"
    if projection in {"ATTN", "ATTNFF"}:
        return "ita_mha8_attn_directed_test"
    raise ValueError(f"Unsupported projection: {projection}")


def case_name(vector: VectorCase, projection: str, seed: int, index: int) -> str:
    act = vector.activation.lower()
    bias = int(vector.bias)
    return (
        f"cr_{index:03d}_{projection.lower()}_{act}_"
        f"s{vector.s}_e{vector.e}_p{vector.p}_f{vector.f}_h{vector.heads}_b{bias}_seed{seed}"
    )


def build_case_entry(
    vector: VectorCase,
    projection: str,
    seed: int,
    index: int,
    source_gap_max: int,
    ready_low_max: int,
    ready_high_max: int,
    generated_vector: bool = False,
) -> dict[str, Any]:
    name = case_name(vector, projection, seed, index)
    stream_name = f"{name}_stream.csv"
    manifest_name = f"{name}_manifest.json"
    requant_name = f"{name}_requant.csv"
    pyita_dir = rel_to_workspace(vector.standalone_dir)

    smoke_args = [
        "-TestName",
        test_name_for_projection(projection),
        "-VectorSource",
        "pyita-q",
        "-Projection",
        projection,
        "-Activation",
        vector.activation,
        "-PyitaDir",
        pyita_dir,
        "-Heads",
        str(vector.heads),
        "-StreamName",
        stream_name,
        "-ManifestName",
        manifest_name,
        "-RequantName",
        requant_name,
        "-GenerateVectors",
    ]

    plusargs = {
        "ntb_random_seed": seed,
        "ITA_SOURCE_GAP_ENABLE": int(source_gap_max > 0),
        "ITA_SOURCE_GAP_MIN": 0,
        "ITA_SOURCE_GAP_MAX": source_gap_max,
        "ITA_SINK_BP_ENABLE": int(ready_low_max > 0),
        "ITA_READY_LOW_MIN": 0,
        "ITA_READY_LOW_MAX": ready_low_max,
        "ITA_READY_HIGH_MIN": 1,
        "ITA_READY_HIGH_MAX": ready_high_max,
    }

    return {
        "name": name,
        "seed": seed,
        "target": "ita_mha8_tb_top",
        "dut": "ita_mha8",
        "H": vector.heads,
        "S": vector.s,
        "E": vector.e,
        "P": vector.p,
        "F": vector.f,
        "layer": "AttentionFeedforward" if projection == "ATTNFF" else "Attention",
        "projection": projection,
        "activation": vector.activation.lower(),
        "bias": vector.bias,
        "tile_s": vector.tile_s,
        "tile_e": vector.tile_e,
        "tile_p": vector.tile_p,
        "tile_f": vector.tile_f,
        "flow": {
            "vector_source": "pyita-q",
            "test_name": test_name_for_projection(projection),
            "generate_vectors": True,
            "compare": True,
            "generated_simvectors": generated_vector,
            "source_gap": {
                "enable": source_gap_max > 0,
                "min": 0,
                "max": source_gap_max,
            },
            "sink_backpressure": {
                "enable": ready_low_max > 0,
                "ready_low_min": 0,
                "ready_low_max": ready_low_max,
                "ready_high_min": 1,
                "ready_high_max": ready_high_max,
            },
        },
        "paths": {
            "vector_root": rel_to_workspace(vector.vector_root),
            "standalone_dir": pyita_dir,
            "uvm_stream": f"ITA_CORE_UVM/sim/logger/{stream_name}",
            "uvm_manifest": f"ITA_CORE_UVM/sim/logger/{manifest_name}",
            "uvm_requant": f"ITA_CORE_UVM/sim/logger/{requant_name}",
        },
        "smoke_ps1": {
            "script": "ITA_CORE_UVM/sim/scripts/smoke.ps1",
            "args": smoke_args,
            "future_plusargs": plusargs,
        },
    }


def write_manifest(path: Path, manifest: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate constrained-random MHA8 regression case manifests.")
    parser.add_argument("--out", type=Path, default=core_root() / "sim" / "logger" / "random_mha8_cases.json")
    parser.add_argument("--simvectors-root", type=Path, default=default_simvectors_root())
    parser.add_argument("--count", type=int, default=8)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--projections", action="append", help="Comma-separated subset of Q,K,V,QKV,ATTN,ATTNFF.")
    parser.add_argument("--activations", action="append", help="Comma-separated subset of Identity,Relu,Gelu.")
    parser.add_argument("--heads", type=int, default=8)
    parser.add_argument("--shape-values", action="append", help="Comma-separated S/E/P/F values. Defaults to 64,128,192,256.")
    parser.add_argument("--min-tile", type=int, default=1)
    parser.add_argument("--max-tile", type=int, default=4)
    parser.add_argument("--include-bias", action="store_true", help="Allow B1 vector cases.")
    parser.add_argument("--include-no-bias", action="store_true", help="Allow B0 vector cases.")
    parser.add_argument("--python", default=sys.executable, help="Python executable used to call ITA/testGenerator.py.")
    parser.add_argument("--test-generator", type=Path, default=default_test_generator())
    parser.add_argument("--vector-seed", type=int, default=0, help="Seed passed to testGenerator.py for generated simvectors.")
    parser.add_argument("--no-auto-generate", action="store_true", help="Only sample existing simvectors; do not call testGenerator.py.")
    parser.add_argument("--source-gap-max", type=int, default=0)
    parser.add_argument("--ready-low-max", type=int, default=0)
    parser.add_argument("--ready-high-max", type=int, default=1)
    parser.add_argument("--dry-run", action="store_true", help="Print manifest JSON instead of writing --out.")
    args = parser.parse_args()

    if args.count <= 0:
        raise ValueError("--count must be positive")
    if args.heads <= 0 or args.heads > 8:
        raise ValueError("--heads must be in range 1..8")
    if args.min_tile <= 0 or args.max_tile < args.min_tile:
        raise ValueError("--min-tile/--max-tile are invalid")
    if args.source_gap_max < 0 or args.ready_low_max < 0 or args.ready_high_max <= 0:
        raise ValueError("stall/backpressure max values are invalid")

    projections = parse_csv_choices(args.projections or ["ATTNFF"], SUPPORTED_PROJECTIONS, "projection")
    activations = parse_csv_choices(args.activations or ["Identity,Relu,Gelu"], SUPPORTED_ACTIVATIONS, "activation")

    allow_bias = args.include_bias
    allow_no_bias = args.include_no_bias
    if not allow_bias and not allow_no_bias:
        allow_bias = True
        allow_no_bias = True

    shape_values = parse_shape_values(args.shape_values)
    simvectors_root = args.simvectors_root
    if not simvectors_root.is_absolute():
        simvectors_root = (workspace_root() / simvectors_root).resolve()
    test_generator = args.test_generator
    if not test_generator.is_absolute():
        test_generator = (workspace_root() / test_generator).resolve()

    if not args.no_auto_generate:
        if simvectors_root.resolve() != default_simvectors_root().resolve():
            raise ValueError("--simvectors-root must be the default ITA/simvectors when auto-generation is enabled")
        if not args.dry_run and not test_generator.is_file():
            raise FileNotFoundError(f"testGenerator.py not found: {test_generator}")

    candidates: list[tuple[VectorSpec, str]] = []
    if args.no_auto_generate:
        vectors = discover_vectors(simvectors_root)
        for vector in vectors:
            if vector.heads != args.heads:
                continue
            if vector.activation not in activations:
                continue
            if vector.bias and not allow_bias:
                continue
            if not vector.bias and not allow_no_bias:
                continue
            if vector.s not in shape_values or vector.e not in shape_values or vector.p not in shape_values or vector.f not in shape_values:
                continue
            if not all(args.min_tile <= tile <= args.max_tile for tile in (vector.tile_s, vector.tile_e, vector.tile_p, vector.tile_f)):
                continue
            for projection in projections:
                if has_required_files(vector.standalone_dir, projection, vector.heads):
                    candidates.append((spec_from_vector_case(vector), projection))
    else:
        specs = build_specs(
            shape_values=shape_values,
            heads=args.heads,
            activations=activations,
            allow_bias=allow_bias,
            allow_no_bias=allow_no_bias,
            min_tile=args.min_tile,
            max_tile=args.max_tile,
        )
        for spec in specs:
            for projection in projections:
                candidates.append((spec, projection))

    if not candidates:
        raise RuntimeError("No usable vector/projection candidates found with the selected constraints")

    rng = random.Random(args.seed)
    entries: list[dict[str, Any]] = []
    generated_vector_roots: list[str] = []
    for index in range(args.count):
        spec, projection = rng.choice(candidates)
        vector, generated_vector = ensure_vector_case(
            simvectors_root=simvectors_root,
            spec=spec,
            projection=projection,
            python=args.python,
            test_generator=test_generator,
            vector_seed=args.vector_seed,
            dry_run=args.dry_run,
        )
        if generated_vector:
            generated_vector_roots.append(rel_to_workspace(vector.vector_root))
        case_seed = rng.randrange(1, 2**31)
        entries.append(
            build_case_entry(
                vector=vector,
                projection=projection,
                seed=case_seed,
                index=index,
                source_gap_max=args.source_gap_max,
                ready_low_max=args.ready_low_max,
                ready_high_max=args.ready_high_max,
                generated_vector=generated_vector,
            )
        )

    manifest = {
        "name": "random_mha8_regression_cases",
        "generator": Path(__file__).name,
        "seed": args.seed,
        "count": len(entries),
        "constraints": {
            "projections": projections,
            "activations": activations,
            "heads": args.heads,
            "shape_values": shape_values,
            "min_tile": args.min_tile,
            "max_tile": args.max_tile,
            "include_bias": allow_bias,
            "include_no_bias": allow_no_bias,
            "auto_generate": not args.no_auto_generate,
            "test_generator": rel_to_workspace(test_generator),
            "vector_seed": args.vector_seed,
            "source_gap_max": args.source_gap_max,
            "ready_low_max": args.ready_low_max,
            "ready_high_max": args.ready_high_max,
        },
        "generated_vector_roots": sorted(set(generated_vector_roots)),
        "cases": entries,
    }

    if args.dry_run:
        print(json.dumps(manifest, indent=2, sort_keys=True))
    else:
        write_manifest(args.out, manifest)
        print(f"Wrote {len(entries)} case(s) -> {args.out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
