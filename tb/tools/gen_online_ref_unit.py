#!/usr/bin/env python3
"""Build independent PyITA replay data for ita_mha8_ref_unit_test.

The numeric model is never called here. Expected matrices are standalone
PyITA-generated results. Scalar checks call the current PyITA utility and GELU
functions.
"""

import argparse
import csv
import importlib
import json
import sys
import types
from pathlib import Path
from typing import Any, TextIO

import numpy as np


CORE = Path(__file__).resolve().parents[2]
STEPS = {"Q": 1, "K": 2, "V": 3, "OW": 6, "F1": 7, "F2": 8, "MatMul": 9}
KINDS = {
    "head_input": 0,
    "head_weight": 1,
    "head_bias": 2,
    "ff_input": 5,
    "ff_weight": 6,
    "ff_bias": 7,
}


def resolve(value: str) -> Path:
    path = Path(value.replace("\\", "/"))
    return path if path.is_absolute() else CORE / path


def load_pyita_modules() -> tuple[Any, Any]:
    """Load numerical modules without importing unrelated ONNX exporters."""
    package = types.ModuleType("pyita")
    package.__path__ = [str(CORE.parent / "ITA" / "pyita")]
    sys.modules["pyita"] = package
    util = importlib.import_module("pyita.util")
    gelu = importlib.import_module("pyita.gelu")
    return util, gelu


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    requant_path = resolve(manifest["requant_path"])
    stream_path = resolve(manifest["stream_path"])
    with requant_path.open(encoding="utf-8", newline="") as requant_file:
        requant_rows = list(csv.DictReader(requant_file))
    with stream_path.open(encoding="utf-8", newline="") as stream_file:
        source_rows = list(csv.DictReader(stream_file))

    _util, gelu = load_pyita_modules()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as output:
        generate_vectors(output, manifest, requant_rows, source_rows, gelu)

    print(args.out)


def generate_vectors(
    output: TextIO,
    manifest: dict[str, Any],
    requant_rows: list[dict[str, str]],
    source_rows: list[dict[str, str]],
    gelu: Any,
) -> None:
    def emit(*values: object) -> None:
        print(*values, file=output)

    for value in [-(2**25) - 1, -(2**25), -1, 0, 2**25 - 1, 2**25, 2**26]:
        emit("L", value, int(np.clip(value, -(2**25), 2**25 - 1)))

    requant_inputs = [
        -33554432,
        -129,
        -128,
        -7,
        -3,
        -1,
        0,
        1,
        3,
        7,
        127,
        128,
        33554431,
    ]
    for value in requant_inputs:
        for multiplier in [0, 1, 127, 255]:
            for shift in [0, 1, 2, 7, 25, 33, 63, 255]:
                for addend in [-128, -1, 0, 127]:
                    # gelu_requantize implements the scalar floor(x + 0.5)
                    # contract used by PyITA.
                    golden = int(
                        gelu.gelu_requantize(value, multiplier, shift, addend)
                    )
                    emit("A", value, multiplier, shift, addend, golden)

    for shift in range(23, 34):
        for value in [2 ** (shift - 1) - 1, -(2 ** (shift - 1)) - 1]:
            golden = int(gelu.gelu_requantize(value, 1, shift, 0))
            emit("A", value, 1, shift, 0, golden)

    activation_params = [(74, 20, 0), (255, 16, -3), (1, 0, 1)]
    for value in range(-128, 128):
        for activation in range(3):
            for multiplier, shift, addend in activation_params:
                if activation == 0:
                    golden = value
                elif activation == 1:
                    golden = int(
                        gelu.i_gelu_requantized(
                            value,
                            -7091,
                            -80,
                            -7091,
                            multiplier,
                            shift,
                            addend,
                        )
                    )
                else:
                    golden = int(
                        gelu.gelu_requantize(
                            max(value, 0),
                            multiplier,
                            shift,
                            addend,
                        )
                    )
                emit(
                    "T",
                    value,
                    activation,
                    -80,
                    -7091,
                    multiplier,
                    shift,
                    addend,
                    golden,
                )

    def emit_config(job_id: int, feedforward: bool = False) -> None:
        special = {
            row["step"]: row
            for row in requant_rows
            if row["step"] in ["ACTIVATION", "GELU_B", "GELU_C", "SUM"]
        }
        activation_requant = special.get(
            "ACTIVATION",
            {"mult": 1, "shift": 0, "add": 0},
        )
        sum_requant = special.get("SUM", {"mult": 1, "shift": 0, "add": 0})
        activation = (
            {"Identity": 0, "Gelu": 1, "Relu": 2}[manifest["activation"]]
            if feedforward
            else 0
        )
        emit(
            "C",
            job_id,
            activation,
            manifest["tile_s"],
            manifest["tile_e"],
            manifest["tile_p"],
            manifest["tile_f"],
            special.get("GELU_B", {"mult": 0})["mult"],
            special.get("GELU_C", {"mult": 0})["mult"],
            activation_requant["mult"],
            activation_requant["shift"],
            activation_requant["add"],
            sum_requant["mult"],
            sum_requant["shift"],
            sum_requant["add"],
            1 if feedforward else 0,
        )
        for row in requant_rows:
            if row["step"] in STEPS:
                head_id = 8 if row["step"] in ["F1", "F2"] else row["head_id"]
                emit(
                    "R",
                    head_id,
                    STEPS[row["step"]] - 1,
                    row["mult"],
                    row["shift"],
                    row["add"],
                )
        emit("G")

    def emit_expected(
        entry: dict[str, Any],
        step: str,
        head_id: int,
        kind: int,
    ) -> None:
        if step == "OW":
            inner_tile_id = manifest["tile_p"]
        elif step == "F2":
            inner_tile_id = manifest["tile_f"]
        else:
            inner_tile_id = manifest["tile_e"]

        expected_path = resolve(entry["expected_path"])
        values = expected_path.read_text(encoding="utf-8").split()
        job_id = 2 if step in ["F1", "F2"] else 1
        for index, value in enumerate(values):
            emit(
                "E",
                job_id,
                kind,
                STEPS[step],
                head_id,
                index // 256,
                inner_tile_id - 1,
                index % 256,
                value.removeprefix("0x"),
            )

    # A partial canceled job followed by recovery; its late output is ignored.
    emit_config(99)
    emit("S", 99, 0, 1, 0, 0, 0, 0, "0")
    emit("X", 99)
    emit_config(1)
    emit_config(2, feedforward=True)

    for head in manifest["per_head"]:
        for step, entry in head["steps"].items():
            if step in STEPS:
                emit_expected(entry, step, head["head_id"], 3)

    for entry in manifest["compare"].get("extra_entries", []):
        if entry["step"] in STEPS:
            kind = 4 if entry["stream"] == "sum" else 8
            emit_expected(entry, entry["step"], 0, kind)

    emit("E", 99, 3, 1, 0, 0, 0, 0, "0")

    # Reverse source records. Actuals precede expectations, and source order
    # intentionally differs from both the DUT schedule and FIFO order.
    for row in reversed(source_rows):
        if row["step"] not in STEPS:
            continue
        job_id = 2 if row["step"] in ["F1", "F2"] else 1
        emit(
            "S",
            job_id,
            KINDS[row["kind"]],
            STEPS[row["step"]],
            row["head_id"],
            row["tile_id"],
            row["inner_tile_id"],
            int(row["beat_id"]) % 256,
            row["payload"].removeprefix("0x"),
        )


if __name__ == "__main__":
    main()
