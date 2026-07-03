#!/usr/bin/env python3
# Copyright 2026
# SPDX-License-Identifier: Apache-2.0

"""Lightweight schedule checker for the tbak MHA8 UVM CSV flow.

This tool does not simulate math and does not call Questa.  It compares the
stream CSV's transaction schedule against the tile/inner/beat order implied by
the MHA8 controller for the tile fields recorded in the manifest.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any


HEAD_STEPS = ("Q", "K", "V", "QK", "AV", "OW")
FF_STEPS = ("F1", "F2")
HEAD_KINDS = ("head_weight", "head_input", "head_bias")
FF_KINDS = ("ff_weight", "ff_input", "ff_bias")
NATIVE_TB_PHASE_GROUP = {
    "Q": (0, 0),
    "K": (1, 0),
    "V": (2, 0),
    "QK": (3, 0),
    "AV": (3, 1),
    "OW": (4, 0),
    "F1": (5, 0),
    "F2": (6, 0),
}


@dataclass(frozen=True)
class Segment:
    step: str
    tile_id: int
    inner_tile_id: int
    beats: int


@dataclass
class StreamGroup:
    first_row: int
    beats: list[int]


def core_root() -> Path:
    return Path(__file__).resolve().parents[2]


def resolve_path(path_text: str, manifest_path: Path, root: Path) -> Path:
    path = Path(path_text)
    if path.is_absolute():
        return path

    root_candidate = root / path
    if root_candidate.exists():
        return root_candidate

    return manifest_path.parent / path


def parse_int(value: Any, name: str) -> int:
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"Invalid integer for {name}: {value!r}") from exc


def load_manifest(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        manifest = json.load(f)
    if not isinstance(manifest, dict):
        raise ValueError("Manifest must contain a JSON object")
    return manifest


def expected_segments(step: str, tile_s: int, tile_e: int, tile_p: int, tile_f: int, beats_per_tile: int) -> list[Segment]:
    segments: list[Segment] = []

    if step in ("Q", "K", "V"):
        for tile_id in range(tile_s * tile_p):
            for inner_id in range(tile_e):
                segments.append(Segment(step, tile_id, inner_id, beats_per_tile))
        return segments

    if step in ("QK", "AV"):
        for softmax_tile in range(tile_s):
            if step == "QK":
                for tile in range(tile_s):
                    for inner_id in range(tile_p):
                        segments.append(Segment(step, softmax_tile * tile_s + tile, inner_id, beats_per_tile))
            else:
                for tile in range(tile_p):
                    for inner_id in range(tile_s):
                        segments.append(Segment(step, softmax_tile * tile_p + tile, inner_id, beats_per_tile))
        return segments

    if step == "OW":
        for tile_id in range(tile_s * tile_e):
            for inner_id in range(tile_p):
                segments.append(Segment(step, tile_id, inner_id, beats_per_tile))
        return segments

    if step == "F1":
        for tile_id in range(tile_s * tile_f):
            for inner_id in range(tile_e):
                segments.append(Segment(step, tile_id, inner_id, beats_per_tile))
        return segments

    if step == "F2":
        for tile_id in range(tile_s * tile_e):
            for inner_id in range(tile_f):
                segments.append(Segment(step, tile_id, inner_id, beats_per_tile))
        return segments

    raise ValueError(f"Unsupported schedule step: {step}")


def normalize_single_segment_native_labels(
    segments: list[Segment],
    schedule_name: str,
    total_beats: int,
) -> list[Segment]:
    if schedule_name != "native_tb_stream_order" or len(segments) != 1:
        return segments

    step = segments[0].step
    phase_group = NATIVE_TB_PHASE_GROUP.get(step)
    if phase_group is None:
        return segments

    phase, group = phase_group
    return [Segment(step, phase, group, total_beats)]


def tile_count(step: str, tile_s: int, tile_e: int, tile_p: int, tile_f: int) -> int:
    if step in ("Q", "K", "V"):
        return tile_s * tile_p * tile_e
    if step in ("QK", "AV"):
        return tile_s * tile_s * tile_p
    if step == "OW":
        return tile_s * tile_e * tile_p
    if step == "F1":
        return tile_s * tile_f * tile_e
    if step == "F2":
        return tile_s * tile_e * tile_f
    raise ValueError(f"Unsupported tile count step: {step}")


def infer_beats_per_tile(manifest: dict[str, Any], steps: list[str], tile_s: int, tile_e: int, tile_p: int, tile_f: int) -> int:
    explicit = manifest.get("tile_beats")
    if explicit not in (None, ""):
        return parse_int(explicit, "tile_beats")

    candidates: set[int] = set()
    per_head = manifest.get("per_head", [])
    if isinstance(per_head, list):
        for head_entry in per_head:
            if not isinstance(head_entry, dict):
                continue
            step_map = head_entry.get("steps", {})
            if not isinstance(step_map, dict):
                continue
            for step in steps:
                entry = step_map.get(step)
                if not isinstance(entry, dict):
                    continue
                expected_beats = entry.get("expected_beats")
                if expected_beats in (None, ""):
                    continue
                count = tile_count(step, tile_s, tile_e, tile_p, tile_f)
                beats = parse_int(expected_beats, f"{step}.expected_beats")
                if count <= 0 or beats % count != 0:
                    continue
                candidates.add(beats // count)

    for extra in manifest.get("compare", {}).get("extra_entries", []) if isinstance(manifest.get("compare"), dict) else []:
        if not isinstance(extra, dict):
            continue
        step = str(extra.get("step", ""))
        if step not in FF_STEPS and not (step == "OW" and extra.get("stream") == "sum"):
            continue
        expected_beats = extra.get("expected_beats")
        if expected_beats in (None, ""):
            continue
        count = tile_count(step, tile_s, tile_e, tile_p, tile_f)
        beats = parse_int(expected_beats, f"{step}.expected_beats")
        if count > 0 and beats % count == 0:
            candidates.add(beats // count)

    if not candidates:
        raise ValueError("Could not infer beats_per_tile from manifest; add tile_beats or expected_beats")
    if len(candidates) != 1:
        raise ValueError(f"Inconsistent inferred beats_per_tile candidates: {sorted(candidates)}")
    return candidates.pop()


def load_stream_groups(path: Path) -> dict[tuple[str, str, int, int, int], StreamGroup]:
    groups: dict[tuple[str, str, int, int, int], StreamGroup] = {}
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row_no, row in enumerate(reader, start=2):
            kind = row.get("kind", "").strip()
            step = row.get("step", "").strip()
            if kind not in HEAD_KINDS and kind not in FF_KINDS:
                continue

            head = parse_int(row.get("head_id", ""), f"row {row_no} head_id")
            tile_id = parse_int(row.get("tile_id", ""), f"row {row_no} tile_id")
            inner_id = parse_int(row.get("inner_tile_id", ""), f"row {row_no} inner_tile_id")
            beat_id = parse_int(row.get("beat_id", ""), f"row {row_no} beat_id")
            key = (kind, step, head, tile_id, inner_id)
            group = groups.get(key)
            if group is None:
                groups[key] = StreamGroup(first_row=row_no, beats=[beat_id])
            else:
                group.beats.append(beat_id)
    return groups


def expected_beats_for_entry(entry: dict[str, Any], kind: str) -> int | None:
    field = {
        "head_weight": "weight_beats",
        "head_input": "input_beats",
        "head_bias": "bias_beats",
        "ff_weight": "weight_beats",
        "ff_input": "input_beats",
        "ff_bias": "bias_beats",
    }[kind]
    value = entry.get(field)
    if value in (None, ""):
        return None
    return parse_int(value, field)


def check_beat_list(beats: list[int], expected_start: int, expected_count: int) -> str | None:
    if len(beats) != expected_count:
        return f"count_mismatch expected={expected_count} got={len(beats)}"
    for offset, beat in enumerate(beats):
        expected = expected_start + offset
        if beat != expected:
            return f"beat_mismatch offset={offset} expected={expected} got={beat}"
    return None


def check_stream_step(
    groups: dict[tuple[str, str, int, int, int], StreamGroup],
    kinds: tuple[str, ...],
    step: str,
    head: int,
    segments: list[Segment],
    entry: dict[str, Any],
) -> tuple[bool, str]:
    errors: list[str] = []
    total_values = 0

    for kind in kinds:
        expected_total = expected_beats_for_entry(entry, kind)
        if expected_total is None:
            expected_total = sum(segment.beats for segment in segments)
        if len(segments) == 0:
            errors.append(f"empty_segment_schedule kind={kind} step={step} head={head}")
            break
        if expected_total % len(segments) != 0:
            errors.append(
                f"segment_count_mismatch kind={kind} step={step} head={head} "
                f"total={expected_total} segments={len(segments)}"
            )
            break
        expected_segment_beats = expected_total // len(segments)
        actual_total = 0
        cursor = 0

        for seg_index, segment in enumerate(segments):
            key = (kind, step, head, segment.tile_id, segment.inner_tile_id)
            group = groups.get(key)
            if group is None:
                errors.append(
                    f"missing_segment kind={kind} step={step} head={head} segment={seg_index} "
                    f"tile={segment.tile_id} inner={segment.inner_tile_id} expected_start={cursor}"
                )
                break

            beat_error = check_beat_list(group.beats, cursor, expected_segment_beats)
            if beat_error is not None:
                errors.append(
                    f"{beat_error} kind={kind} step={step} head={head} segment={seg_index} "
                    f"tile={segment.tile_id} inner={segment.inner_tile_id} first_row={group.first_row}"
                )
                break

            cursor += expected_segment_beats
            actual_total += len(group.beats)

        if actual_total != expected_total and not errors:
            errors.append(f"total_mismatch kind={kind} step={step} head={head} expected={expected_total} got={actual_total}")

        total_values = max(total_values, actual_total)

    if errors:
        return False, errors[0]

    return True, f"PASS {step}/{'ff' if kinds == FF_KINDS else 'head' + str(head)} segments={len(segments)} values={total_values}"


def head_step_entries(manifest: dict[str, Any]) -> dict[int, dict[str, dict[str, Any]]]:
    result: dict[int, dict[str, dict[str, Any]]] = {}
    per_head = manifest.get("per_head", [])
    if not isinstance(per_head, list):
        raise ValueError("Manifest per_head must be a list")
    for head_entry in per_head:
        if not isinstance(head_entry, dict):
            continue
        head = parse_int(head_entry.get("head_id"), "per_head.head_id")
        steps = head_entry.get("steps")
        if isinstance(steps, dict):
            result[head] = {str(step): entry for step, entry in steps.items() if isinstance(entry, dict)}
        else:
            step = str(manifest.get("step", ""))
            result[head] = {step: head_entry}
    return result


def ff_entries(manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    compare = manifest.get("compare", {})
    entries: dict[str, dict[str, Any]] = {}
    if not isinstance(compare, dict):
        return entries
    for extra in compare.get("extra_entries", []) or []:
        if not isinstance(extra, dict):
            continue
        if extra.get("stream") == "ff" and str(extra.get("step", "")) in FF_STEPS:
            entries[str(extra["step"])] = extra
    return entries


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check MHA8 UVM stream CSV schedule against controller tile order.")
    parser.add_argument("--manifest", required=True, type=Path, help="Path to uvm_*_mha8_manifest.json")
    parser.add_argument("--stream", type=Path, help="Path to stream CSV. Defaults to manifest.stream_path.")
    parser.add_argument("--max-pass-lines", type=int, default=16, help="Limit printed PASS lines; summary still includes all checks.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = core_root()
    manifest_path = args.manifest
    manifest = load_manifest(manifest_path)
    stream_path = args.stream
    if stream_path is None:
        stream_path = resolve_path(str(manifest.get("stream_path", "")), manifest_path, root)

    tile_s = parse_int(manifest.get("tile_s", 1), "tile_s")
    tile_e = parse_int(manifest.get("tile_e", 1), "tile_e")
    tile_p = parse_int(manifest.get("tile_p", 1), "tile_p")
    tile_f = parse_int(manifest.get("tile_f", 1), "tile_f")
    heads = parse_int(manifest.get("heads", 1), "heads")
    schedule_name = str(manifest.get("schedule", ""))
    compare = manifest.get("compare", {})
    if not isinstance(compare, dict):
        compare = {}
    actual_steps = [str(step) for step in compare.get("actual_steps", []) if str(step) in HEAD_STEPS]
    if not actual_steps:
        step = str(manifest.get("step", ""))
        actual_steps = [step] if step in HEAD_STEPS else []

    beats_per_tile = infer_beats_per_tile(manifest, actual_steps or list(HEAD_STEPS), tile_s, tile_e, tile_p, tile_f)
    groups = load_stream_groups(stream_path)
    head_entries = head_step_entries(manifest)
    ff_step_entries = ff_entries(manifest)

    print(
        "SCHEDULE_SUMMARY "
        f"tile_s={tile_s} tile_e={tile_e} tile_p={tile_p} tile_f={tile_f} "
        f"beats_per_tile={beats_per_tile} stream={stream_path}"
    )

    pass_lines: list[str] = []
    fail_lines: list[str] = []
    checked = 0

    for head in range(heads):
        step_entries = head_entries.get(head, {})
        for step in actual_steps:
            entry = step_entries.get(step)
            if entry is None:
                fail_lines.append(f"FAIL {step}/head{head} missing_manifest_entry")
                continue
            segments = expected_segments(step, tile_s, tile_e, tile_p, tile_f, beats_per_tile)
            expected_total = parse_int(entry.get("expected_beats", sum(segment.beats for segment in segments)), f"{step}.expected_beats")
            segments = normalize_single_segment_native_labels(segments, schedule_name, expected_total)
            ok, message = check_stream_step(groups, HEAD_KINDS, step, head, segments, entry)
            checked += 1
            if ok:
                pass_lines.append(message)
            else:
                fail_lines.append(f"FAIL {step}/head{head} {message}")

    for step in FF_STEPS:
        entry = ff_step_entries.get(step)
        if entry is None:
            continue
        segments = expected_segments(step, tile_s, tile_e, tile_p, tile_f, beats_per_tile)
        expected_total = parse_int(entry.get("expected_beats", sum(segment.beats for segment in segments)), f"{step}.expected_beats")
        segments = normalize_single_segment_native_labels(segments, schedule_name, expected_total)
        ok, message = check_stream_step(groups, FF_KINDS, step, 0, segments, entry)
        checked += 1
        if ok:
            pass_lines.append(message)
        else:
            fail_lines.append(f"FAIL {step}/ff {message}")

    print(f"SCHEDULE_CHECK_SUMMARY checked={checked} passed={len(pass_lines)} failed={len(fail_lines)}")
    if pass_lines:
        print("PASS_ENTRIES:")
        for line in pass_lines[: max(0, args.max_pass_lines)]:
            print(f"  {line}")
        if len(pass_lines) > args.max_pass_lines:
            print(f"  ... +{len(pass_lines) - args.max_pass_lines} more pass entries")

    if fail_lines:
        print("FAIL_ENTRIES:")
        for line in fail_lines:
            print(f"  {line}")
        print("MHA8_SCHEDULE_CHECK_FAIL")
        return 1

    print("MHA8_SCHEDULE_CHECK_PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
