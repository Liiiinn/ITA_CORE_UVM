#!/usr/bin/env python3
# Copyright 2026
# SPDX-License-Identifier: Apache-2.0

"""Convert UVM/ITA actual-output logs to simple decimal txt files.

This tbak copy is intentionally dependency-light.  It only uses Python's
standard library and is meant for the UVM exercise flow:

  1. UVM logger CSV:
       time,kind,head_id,tile_id,inner_tile_id,beat_id,step,is_lockstep,payload

  2. JSON lines:
       {"phase":"MatMul","stream":"per_head","head":0,"beat":0,"value":"0x12"}

  3. Text lines containing ACTUAL plus key=value fields:
       ACTUAL phase=MatMul stream=per_head head=0 beat=0 value=0x12

The output is a decimal txt file compatible with tbak/tools/compare.py.
For UVM CSV, payload is interpreted as packed hexadecimal because the SV
logger writes it with %h.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

KEY_VALUE_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)=([^ \t\r\n,]+)")

PER_HEAD_EXPECTED_PREFIX = {
    "Q": "Qp",
    "K": "Kp",
    "V": "Vp",
    "QK": "A",
    "AV": "O_soft",
    "OW": "Out_soft",
    "MATMUL": "MatMul",
}

STREAM_EXPECTED_FILES = {
    ("OW", "sum"): "Out_soft_sum.txt",
    ("F1", "ff"): "FFp_0.txt",
    ("F2", "ff"): "FF2p_0.txt",
}

KIND_TO_STREAM = {
    "head_output": "per_head",
    "sum_output": "sum",
    "ff_output": "ff",
}


@dataclass(frozen=True)
class ActualRecord:
    phase: str
    stream: str
    value: int
    head: int | None = None
    beat: int | None = None
    lane: int | None = None
    step: str | None = None
    group: int | None = None
    row: int | None = None
    word: int | None = None
    raw: str | None = None


def parse_int(value: Any) -> int:
    if isinstance(value, bool):
        raise ValueError(f"Boolean is not a valid integer value: {value}")
    if isinstance(value, int):
        return value

    text = str(value).strip().replace("_", "")
    if text.lower().startswith("0x"):
        return int(text, 16)
    if text.lower().startswith("-0x"):
        return -int(text[1:], 16)
    return int(text, 10)


def parse_uvm_payload(value: Any) -> int:
    text = str(value).strip().replace("_", "")
    if text == "":
        raise ValueError("Empty UVM payload")
    if text.lower().startswith("0x"):
        text = text[2:]
    return int(text, 16)


def optional_int(obj: dict[str, Any], key: str) -> int | None:
    if key not in obj or obj[key] in (None, ""):
        return None
    return parse_int(obj[key])


def record_from_mapping(obj: dict[str, Any], raw: str | None = None) -> ActualRecord:
    missing = [key for key in ("phase", "stream", "value") if key not in obj]
    if missing:
        raise ValueError(f"Missing required actual field(s): {', '.join(missing)}")

    return ActualRecord(
        phase=str(obj["phase"]),
        stream=str(obj["stream"]),
        value=parse_int(obj["value"]),
        head=optional_int(obj, "head"),
        beat=optional_int(obj, "beat"),
        lane=optional_int(obj, "lane"),
        step=str(obj["step"]) if "step" in obj and obj["step"] not in (None, "") else None,
        group=optional_int(obj, "group"),
        row=optional_int(obj, "row"),
        word=optional_int(obj, "word"),
        raw=raw,
    )


def record_from_uvm_csv_row(row: dict[str, str]) -> ActualRecord | None:
    kind = row.get("kind", "").strip()
    stream = KIND_TO_STREAM.get(kind)
    if stream is None:
        return None

    step = row.get("step", "").strip() or "UNKNOWN"
    return ActualRecord(
        phase=step,
        stream=stream,
        value=parse_uvm_payload(row.get("payload", "")),
        head=parse_int(row["head_id"]) if row.get("head_id", "") != "" else None,
        beat=parse_int(row["beat_id"]) if row.get("beat_id", "") != "" else None,
        row=parse_int(row["tile_id"]) if row.get("tile_id", "") != "" else None,
        group=parse_int(row["inner_tile_id"]) if row.get("inner_tile_id", "") != "" else None,
        step=step,
        raw=repr(row),
    )


def parse_jsonl_line(line: str) -> ActualRecord:
    obj = json.loads(line)
    if not isinstance(obj, dict):
        raise ValueError("JSONL actual line must contain an object")
    return record_from_mapping(obj, raw=line)


def parse_key_value_line(line: str) -> ActualRecord | None:
    if "ACTUAL" not in line:
        return None

    fields = {match.group(1).lower(): match.group(2) for match in KEY_VALUE_RE.finditer(line)}
    if not fields:
        return None
    return record_from_mapping(fields, raw=line)


def parse_text_lines(lines: Iterable[str], input_format: str, strict: bool) -> list[ActualRecord]:
    records: list[ActualRecord] = []

    for line_no, raw_line in enumerate(lines, start=1):
        line = raw_line.strip()
        if not line:
            continue

        try:
            record: ActualRecord | None
            if input_format == "jsonl":
                record = parse_jsonl_line(line)
            elif input_format == "kv":
                record = parse_key_value_line(line)
            else:
                if line.startswith("{"):
                    record = parse_jsonl_line(line)
                else:
                    record = parse_key_value_line(line)

            if record is not None:
                records.append(record)
        except Exception as exc:
            if strict:
                raise ValueError(f"Failed to parse line {line_no}: {line}") from exc

    return records


def parse_uvm_csv(path: Path, strict: bool) -> list[ActualRecord]:
    records: list[ActualRecord] = []
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for line_no, row in enumerate(reader, start=2):
            try:
                record = record_from_uvm_csv_row(row)
                if record is not None:
                    records.append(record)
            except Exception as exc:
                if strict:
                    raise ValueError(f"Failed to parse CSV row {line_no}: {row}") from exc
    return records


def filter_records(
    records: list[ActualRecord],
    phase: str | None,
    stream: str | None,
    head: int | None,
) -> list[ActualRecord]:
    selected: list[ActualRecord] = []
    for record in records:
        if phase is not None and record.phase.lower() != phase.lower():
            continue
        if stream is not None and record.stream.lower() != stream.lower():
            continue
        if head is not None and record.head != head:
            continue
        selected.append(record)
    return selected


def position_key(record: ActualRecord) -> tuple[Any, ...]:
    none_last = 1 << 30
    return (
        record.phase,
        record.stream,
        record.head if record.head is not None else none_last,
        record.group if record.group is not None else none_last,
        record.row if record.row is not None else none_last,
        record.beat if record.beat is not None else none_last,
        record.word if record.word is not None else none_last,
        record.lane if record.lane is not None else none_last,
    )


def write_txt_output(path: Path, records: list[ActualRecord], row_words: int) -> None:
    if row_words <= 0:
        raise ValueError("--row-words must be greater than zero")

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for index, record in enumerate(records):
            if index != 0:
                f.write("\n" if (index % row_words) == 0 else " ")
            f.write(str(record.value))
        if records:
            f.write("\n")


def sanitize_name(text: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", text.strip())


def split_key(record: ActualRecord) -> tuple[str, str, int | None]:
    return (record.phase, record.stream, record.head)


def split_output_name(phase: str, stream: str, head: int | None) -> str:
    phase_key = phase.upper()
    stream_key = stream.lower()

    if stream_key == "per_head" and head is not None:
        prefix = PER_HEAD_EXPECTED_PREFIX.get(phase_key)
        if prefix is not None:
            return f"{prefix}_{head}.txt"

    mapped_name = STREAM_EXPECTED_FILES.get((phase_key, stream_key))
    if mapped_name is not None:
        return mapped_name

    name = f"{sanitize_name(phase)}_{sanitize_name(stream)}"
    if head is not None:
        name += f"_head{head}"
    return f"{name}.txt"


def write_split_outputs(out_dir: Path, records: list[ActualRecord], row_words: int) -> list[Path]:
    grouped: dict[tuple[str, str, int | None], list[ActualRecord]] = {}
    for record in records:
        grouped.setdefault(split_key(record), []).append(record)

    written: list[Path] = []
    for (phase, stream, head), group_records in sorted(grouped.items()):
        path = out_dir / split_output_name(phase, stream, head)
        write_txt_output(path, group_records, row_words)
        written.append(path)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse ITA/UVM actual output logs into decimal txt.")
    parser.add_argument("--input", "-i", required=True, type=Path, help="Input actual log, JSONL, or UVM CSV file.")
    parser.add_argument("--out", "-o", type=Path, help="Output decimal txt file for single-file mode.")
    parser.add_argument("--out-dir", type=Path, help="Output directory for split mode.")
    parser.add_argument(
        "--format",
        choices=("auto", "jsonl", "kv", "uvm-csv"),
        default="auto",
        help="Input format. auto uses uvm-csv for .csv files, otherwise JSONL/KV text.",
    )
    parser.add_argument("--phase", help="Only emit records from this phase, e.g. MatMul, Q, K, OW, F1.")
    parser.add_argument("--stream", help="Only emit records from this stream, e.g. per_head, sum, ff.")
    parser.add_argument("--head", type=int, help="Only emit records from this head.")
    parser.add_argument("--row-words", type=int, default=1, help="Number of decimal values per output row.")
    parser.add_argument("--sort", choices=("input", "position"), default="input")
    parser.add_argument("--strict", action="store_true", help="Fail on the first malformed record.")
    parser.add_argument("--allow-empty", action="store_true", help="Allow zero parsed records.")
    args = parser.parse_args()

    if (args.out is None) == (args.out_dir is None):
        raise ValueError("Specify exactly one of --out or --out-dir.")

    if not args.input.is_file():
        raise FileNotFoundError(f"Input actual log not found: {args.input}")

    input_format = args.format
    if input_format == "auto":
        input_format = "uvm-csv" if args.input.suffix.lower() == ".csv" else "auto"

    if input_format == "uvm-csv":
        records = parse_uvm_csv(args.input, args.strict)
    else:
        with args.input.open("r", encoding="utf-8", errors="replace") as f:
            records = parse_text_lines(f, input_format, args.strict)

    records = filter_records(records, args.phase, args.stream, args.head)
    if args.sort == "position":
        records = sorted(records, key=position_key)

    if not records and not args.allow_empty:
        raise ValueError(f"No actual records parsed from {args.input}")

    if args.out_dir is not None:
        written = write_split_outputs(args.out_dir, records, args.row_words)
        print(f"Wrote {len(records)} actual values into {len(written)} file(s) under {args.out_dir}")
    else:
        write_txt_output(args.out, records, args.row_words)
        print(f"Wrote {len(records)} actual values -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
