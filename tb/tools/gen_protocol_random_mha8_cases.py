#!/usr/bin/env python3
"""Generate no-golden MHA8 protocol-random regression manifests."""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path
from typing import Any


# The controller advances one beat only when all three source valids coincide.
# Legal protocol randomization therefore inserts bubbles between complete source
# groups, never between the input/weight/bias members of one compute beat.
SOURCE_GAP_MAX = 0


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def default_out() -> Path:
    return repo_root() / "sim" / "cases" / "protocol_random_mha8_cases.json"


def protocol_case(
    index: int,
    seed: int,
    jobs: int,
    tile_max: int,
    group_idle_gap: int,
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
            "source_bundle_mode": "atomic_compute_beat",
            "group_source_bubbles": group_idle_gap > 0,
            "group_idle_gap_max": group_idle_gap,
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
                "ITA_INPUT_SOURCE_GAP_MAX": SOURCE_GAP_MAX,
                "ITA_WEIGHT_SOURCE_GAP_MAX": SOURCE_GAP_MAX,
                "ITA_BIAS_SOURCE_GAP_MAX": SOURCE_GAP_MAX,
                "ITA_GROUP_IDLE_GAP_MAX": group_idle_gap,
                "ITA_READY_LOW_MAX": ready_low,
                "ITA_READY_HIGH_MAX": ready_high,
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
        is_baseline = index == 0
        case_seed = rng.randrange(1, 2**31)
        cases.append(
            protocol_case(
                index=index,
                seed=case_seed,
                jobs=rng.randint(args.jobs_min, args.jobs_max),
                tile_max=args.tile_max,
                group_idle_gap=0 if is_baseline else rng.randrange(1, 9),
                ready_low=0 if is_baseline else rng.randrange(1, 9),
                ready_high=1 if is_baseline else rng.randrange(1, 5),
                start_gap=0 if is_baseline else rng.randrange(0, 9),
                reset_cycles=8 if is_baseline else rng.randrange(8, 17),
            )
        )

    manifest: dict[str, Any] = {
        "suite": "protocol_random",
        "description": "Deterministic-payload UVM protocol jobs with atomic source bundles; no PyITA numerical compare.",
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
