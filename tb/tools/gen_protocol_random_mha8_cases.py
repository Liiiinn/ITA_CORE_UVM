#!/usr/bin/env python3
"""Generate no-golden MHA8 protocol-random regression manifests."""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path
from typing import Any


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def default_out() -> Path:
    return repo_root() / "sim" / "cases" / "protocol_random_mha8_cases.json"


def protocol_case(
    index: int,
    seed: int,
    jobs: int,
    tile_max: int,
    input_gap: int,
    weight_gap: int,
    bias_gap: int,
    lockstep_idle_gap: int,
    ready_low: int,
    ready_high: int,
    start_gap: int,
    reset_cycles: int,
) -> dict[str, Any]:
    name = f"pr_{index:03d}_jobs{jobs}_tile1to{tile_max}_seed{seed}"
    return {
        "name": name,
        "category": "protocol_random",
        "spec_basis": "core_spec_observable",
        "seed": seed,
        "target": "ita_mha8_tb_top",
        "dut": "ita_mha8",
        "projection": "RANDOM",
        "activation": "random",
        "tile_s": 0,
        "tile_e": 0,
        "tile_p": 0,
        "tile_f": 0,
        "flow": {
            "vector_source": "sv_deterministic_protocol",
            "test_name": "ita_mha8_protocol_random_test",
            "generate_vectors": False,
            "compare": False,
            "num_jobs": jobs,
            "tile_min": 1,
            "tile_max": tile_max,
            "source_arrival_skew": False,
            "lockstep_idle_gap_max": lockstep_idle_gap,
            "sink_backpressure": ready_low > 0,
        },
        "smoke_ps1": {
            "args": [
                "-TestName",
                "ita_mha8_protocol_random_test",
                "-NoGenerateVectors",
                "-NoCompare",
                "-ProtocolNumJobs",
                str(jobs),
                "-ProtocolTileMin",
                "1",
                "-ProtocolTileMax",
                str(tile_max),
                "-ProtocolProjection",
                "RANDOM",
                "-ProtocolStartGapMax",
                str(start_gap),
                "-ResetCycles",
                str(reset_cycles),
            ],
            "future_plusargs": {
                "ntb_random_seed": seed,
                "ITA_INPUT_SOURCE_GAP_MAX": input_gap,
                "ITA_WEIGHT_SOURCE_GAP_MAX": weight_gap,
                "ITA_BIAS_SOURCE_GAP_MAX": bias_gap,
                "ITA_LOCKSTEP_IDLE_GAP_MAX": lockstep_idle_gap,
                "ITA_READY_LOW_MAX": ready_low,
                "ITA_READY_HIGH_MAX": ready_high,
            },
        },
    }


def negative_skew_case(seed: int, jobs: int, tile_max: int) -> dict[str, Any]:
    name = f"pr_neg_lockstep_skew_jobs{jobs}_tile1to{tile_max}_seed{seed}"
    return {
        "name": name,
        "category": "protocol_negative_skew",
        "spec_basis": "core_spec_observable",
        "seed": seed,
        "target": "ita_mha8_tb_top",
        "dut": "ita_mha8",
        "projection": "ATTN",
        "activation": "identity",
        "tile_s": 0,
        "tile_e": 0,
        "tile_p": 0,
        "tile_f": 0,
        "expect_fail": True,
        "expected_error_regex": r"(ITA_SOURCE_SKEW|UVM_ERROR|UVM_FATAL|timeout)",
        "flow": {
            "vector_source": "sv_deterministic_protocol",
            "test_name": "ita_mha8_protocol_random_test",
            "generate_vectors": False,
            "compare": False,
            "num_jobs": jobs,
            "tile_min": 1,
            "tile_max": tile_max,
            "negative_lockstep_skew": True,
        },
        "smoke_ps1": {
            "args": [
                "-TestName",
                "ita_mha8_protocol_random_test",
                "-NoGenerateVectors",
                "-NoCompare",
                "-ProtocolNumJobs",
                str(jobs),
                "-ProtocolTileMin",
                "1",
                "-ProtocolTileMax",
                str(tile_max),
                "-ProtocolProjection",
                "ATTN",
                "-ProtocolNegativeSkew",
            ],
            "future_plusargs": {
                "ntb_random_seed": seed,
                "ITA_INPUT_SOURCE_GAP_MAX": 3,
                "ITA_WEIGHT_SOURCE_GAP_MAX": 0,
                "ITA_BIAS_SOURCE_GAP_MAX": 1,
                "ITA_READY_LOW_MAX": 0,
                "ITA_READY_HIGH_MAX": 1,
            },
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate MHA8 protocol-random regression cases without numerical golden files.")
    parser.add_argument("--count", type=int, default=4, help="Number of legal protocol-random simulations.")
    parser.add_argument("--seed", type=int, default=1, help="Master seed for case sampling.")
    parser.add_argument("--jobs-min", type=int, default=8)
    parser.add_argument("--jobs-max", type=int, default=16)
    parser.add_argument("--tile-max", type=int, default=2, help="Maximum randomly selected tile dimension for legal protocol jobs.")
    parser.add_argument("--out", type=Path, default=default_out())
    parser.add_argument("--include-negative-skew", action="store_true", help="Append one expected-fail lockstep source-skew case.")
    parser.add_argument("--dry-run", action="store_true", help="Print JSON instead of writing --out.")
    args = parser.parse_args()

    if args.count < 1:
        raise ValueError("--count must be positive")
    if args.jobs_min < 1 or args.jobs_max < args.jobs_min:
        raise ValueError("--jobs-min/--jobs-max must describe a positive range")
    if args.tile_max < 1 or args.tile_max > 4:
        raise ValueError("--tile-max must be within 1..4")

    rng = random.Random(args.seed)
    cases: list[dict[str, Any]] = []
    for index in range(args.count):
        case_seed = rng.randrange(1, 2**31)
        cases.append(
            protocol_case(
                index=index,
                seed=case_seed,
                jobs=rng.randint(args.jobs_min, args.jobs_max),
                tile_max=args.tile_max,
                input_gap=0,
                weight_gap=0,
                bias_gap=0,
                lockstep_idle_gap=rng.randrange(1, 9),
                ready_low=rng.randrange(0, 9),
                ready_high=rng.randrange(1, 5),
                start_gap=rng.randrange(0, 9),
                reset_cycles=rng.randrange(8, 17),
            )
        )

    if args.include_negative_skew:
        cases.append(negative_skew_case(rng.randrange(1, 2**31), args.jobs_min, args.tile_max))

    manifest: dict[str, Any] = {
        "suite": "protocol_random",
        "description": "Deterministic-payload UVM protocol random jobs; no PyITA numerical compare.",
        "seed": args.seed,
        "cases": cases,
    }

    if args.dry_run:
        print(json.dumps(manifest, indent=2, sort_keys=True))
        return 0

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {len(cases)} protocol-random cases -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
