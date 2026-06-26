#!/usr/bin/env python3
# Copyright 2026
# SPDX-License-Identifier: Apache-2.0

"""Bit-exact compare PyITA expected txt files against DUT actual txt files.

The script intentionally stays small:

  1. File mode:
       compare.py --expected standalone/Out_soft_0.txt --actual actual/Out_soft_0.txt

  2. Directory mode:
       compare.py --expected-dir standalone --actual-dir actual

By default values are compared as exact Python integers. If --bit-width is
provided, values are compared by their masked two's-complement bit pattern, so
-1 and 255 match when --bit-width 8 is used.

On failure the output always includes a FIRST_MISMATCH line with index, row, and
column information. Row/column are derived from --row-words, which defaults to
1 to match PyITA txt files that use one value per line.

Use --count-all to scan complete files and report full mismatch counts while
still limiting printed mismatch details with --max-mismatches.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


HEAD_FILE_RE = re.compile(r"^(?P<phase>[A-Za-z0-9]+)_per_head_head(?P<head>[0-9]+)\.txt$")

PHASE_TO_EXPECTED_PREFIX = {
    "Q": "Qp",
    "K": "Kp",
    "V": "Vp",
    "QK": "A",
    "AV": "O_soft",
    "OW": "Out_soft",
}

SPECIAL_EXPECTED_FILES = {
    "OW_sum.txt": "Out_soft_sum.txt",
    "FF1_ff.txt": "FFp_0.txt",
    "FF2_ff.txt": "FF2p_0.txt",
}


@dataclass(frozen=True)
class Mismatch:
    index: int
    expected: int
    actual: int
    expected_bits: int | None = None
    actual_bits: int | None = None
    is_length_mismatch: bool = False


@dataclass(frozen=True)
class CompareResult:
    expected_path: Path
    actual_path: Path
    checked: int
    expected_count: int
    actual_count: int
    mismatch_count: int
    mismatches: list[Mismatch]

    @property
    def failed(self) -> bool:
        return self.mismatch_count != 0 or self.expected_count != self.actual_count


def parse_int_token(token: str) -> int:
    text = token.strip().replace("_", "")
    if text.lower().startswith("0x"):
        return int(text, 16)
    if text.lower().startswith("-0x"):
        return -int(text[1:], 16)
    return int(text, 10)


def read_values(path: Path) -> list[int]:
    values: list[int] = []
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for raw_line in f:
            line = raw_line.split("#", 1)[0].strip()
            if not line:
                continue
            for token in line.split():
                values.append(parse_int_token(token))
    return values


def bit_mask(bit_width: int) -> int:
    if bit_width <= 0:
        raise ValueError("--bit-width must be greater than zero")
    return (1 << bit_width) - 1


def bit_pattern(value: int, bit_width: int | None) -> int:
    if bit_width is None:
        return value
    return value & bit_mask(bit_width)


def format_bits(value: int | None, bit_width: int | None) -> str:
    if value is None or bit_width is None:
        return ""
    hex_digits = max(1, (bit_width + 3) // 4)
    return f"0x{value:0{hex_digits}x}"


def compare_values(
    expected_path: Path,
    actual_path: Path,
    max_mismatches: int,
    bit_width: int | None,
    count_all: bool,
) -> CompareResult:
    expected = read_values(expected_path)
    actual = read_values(actual_path)

    mismatches: list[Mismatch] = []
    mismatch_count = 0
    checked = min(len(expected), len(actual))

    for index in range(checked):
        expected_bits = bit_pattern(expected[index], bit_width)
        actual_bits = bit_pattern(actual[index], bit_width)
        if expected_bits != actual_bits:
            mismatch_count += 1
            if len(mismatches) < max_mismatches:
                mismatches.append(
                    Mismatch(
                        index=index,
                        expected=expected[index],
                        actual=actual[index],
                        expected_bits=expected_bits if bit_width is not None else None,
                        actual_bits=actual_bits if bit_width is not None else None,
                    )
                )
            if not count_all and len(mismatches) >= max_mismatches:
                break

    if len(expected) != len(actual) and len(mismatches) < max_mismatches:
        mismatches.append(
            Mismatch(
                index=checked,
                expected=len(expected),
                actual=len(actual),
                is_length_mismatch=True,
            )
        )

    return CompareResult(
        expected_path=expected_path,
        actual_path=actual_path,
        checked=checked,
        expected_count=len(expected),
        actual_count=len(actual),
        mismatch_count=mismatch_count,
        mismatches=mismatches,
    )


def expected_name_for_actual(actual_name: str) -> str | None:
    if actual_name in SPECIAL_EXPECTED_FILES:
        return SPECIAL_EXPECTED_FILES[actual_name]

    match = HEAD_FILE_RE.match(actual_name)
    if match is None:
        return None

    phase = match.group("phase")
    head = match.group("head")
    prefix = PHASE_TO_EXPECTED_PREFIX.get(phase)
    if prefix is None:
        return None
    return f"{prefix}_{head}.txt"


def collect_pairs(expected_dir: Path, actual_dir: Path) -> list[tuple[Path, Path]]:
    pairs: list[tuple[Path, Path]] = []
    for actual_path in sorted(actual_dir.glob("*.txt")):
        expected_path = expected_dir / actual_path.name
        if not expected_path.is_file():
            mapped_name = expected_name_for_actual(actual_path.name)
            if mapped_name is not None:
                expected_path = expected_dir / mapped_name

        if expected_path.is_file():
            pairs.append((expected_path, actual_path))
    return pairs


def row_col(index: int, row_words: int) -> tuple[int, int]:
    if row_words <= 0:
        raise ValueError("--row-words must be greater than zero")
    return index // row_words, index % row_words


def print_mismatch(prefix: str, mismatch: Mismatch, row_words: int, bit_width: int | None) -> None:
    row, col = row_col(mismatch.index, row_words)
    if mismatch.is_length_mismatch:
        print(
            f"  {prefix} index={mismatch.index} row={row} col={col} "
            f"length mismatch expected_count={mismatch.expected} actual_count={mismatch.actual}"
        )
        return

    message = (
        f"  {prefix} index={mismatch.index} row={row} col={col} "
        f"expected={mismatch.expected} actual={mismatch.actual}"
    )
    if bit_width is not None:
        message += (
            f" expected_bits={format_bits(mismatch.expected_bits, bit_width)}"
            f" actual_bits={format_bits(mismatch.actual_bits, bit_width)}"
        )
    print(message)


def print_result(result: CompareResult, max_mismatches: int, row_words: int, bit_width: int | None) -> None:
    if not result.failed:
        mode = f"bit_width={bit_width}" if bit_width is not None else "integer-exact"
        print(f"PASS {result.actual_path.name}: checked {result.checked} values ({mode})")
        return

    print(
        f"FAIL {result.actual_path.name}: compared with {result.expected_path.name}; "
        f"checked={result.checked} mismatches={result.mismatch_count} "
        f"expected_count={result.expected_count} actual_count={result.actual_count}"
    )
    if result.mismatches:
        print_mismatch("FIRST_MISMATCH", result.mismatches[0], row_words, bit_width)
        for mismatch in result.mismatches[1:max_mismatches]:
            print_mismatch("MISMATCH", mismatch, row_words, bit_width)


def main() -> int:
    parser = argparse.ArgumentParser(description="Bit-exact compare PyITA expected txt with DUT actual txt.")
    file_group = parser.add_argument_group("single file mode")
    file_group.add_argument("--expected", "-e", type=Path, help="Expected PyITA txt file.")
    file_group.add_argument("--actual", "-a", type=Path, help="Actual DUT txt file.")

    dir_group = parser.add_argument_group("directory mode")
    dir_group.add_argument("--expected-dir", type=Path, help="Directory with expected PyITA txt files.")
    dir_group.add_argument("--actual-dir", type=Path, help="Directory with parsed actual txt files.")

    parser.add_argument("--bit-width", type=int, help="Compare masked two's-complement bit patterns at this width.")
    parser.add_argument("--row-words", type=int, default=1, help="Values per logical row for mismatch row/col reporting.")
    parser.add_argument("--max-mismatches", type=int, default=10, help="Maximum mismatches to print per file.")
    parser.add_argument("--count-all", action="store_true", help="Scan full files and report complete mismatch counts.")
    parser.add_argument("--allow-empty", action="store_true", help="Allow directory mode to find zero pairs.")
    args = parser.parse_args()

    if args.max_mismatches <= 0:
        raise ValueError("--max-mismatches must be greater than zero")
    if args.row_words <= 0:
        raise ValueError("--row-words must be greater than zero")
    if args.bit_width is not None and args.bit_width <= 0:
        raise ValueError("--bit-width must be greater than zero")

    file_mode = args.expected is not None or args.actual is not None
    dir_mode = args.expected_dir is not None or args.actual_dir is not None
    if file_mode == dir_mode:
        raise ValueError("Use exactly one mode: --expected/--actual or --expected-dir/--actual-dir")

    if file_mode:
        if args.expected is None or args.actual is None:
            raise ValueError("File mode requires both --expected and --actual")
        result = compare_values(args.expected, args.actual, args.max_mismatches, args.bit_width, args.count_all)
        print_result(result, args.max_mismatches, args.row_words, args.bit_width)
        if result.failed:
            print(
                f"SUMMARY files=1 failed_files=1 checked_values={result.checked} "
                f"mismatches={result.mismatch_count} length_mismatches={int(result.expected_count != result.actual_count)}"
            )
        return 1 if result.failed else 0

    if args.expected_dir is None or args.actual_dir is None:
        raise ValueError("Directory mode requires both --expected-dir and --actual-dir")
    if not args.expected_dir.is_dir():
        raise FileNotFoundError(f"Expected directory not found: {args.expected_dir}")
    if not args.actual_dir.is_dir():
        raise FileNotFoundError(f"Actual directory not found: {args.actual_dir}")

    pairs = collect_pairs(args.expected_dir, args.actual_dir)
    if not pairs and not args.allow_empty:
        raise ValueError(f"No comparable txt pairs found under {args.actual_dir}")

    failed = 0
    total_values = 0
    total_mismatches = 0
    length_mismatches = 0
    for expected_path, actual_path in pairs:
        result = compare_values(expected_path, actual_path, args.max_mismatches, args.bit_width, args.count_all)
        print_result(result, args.max_mismatches, args.row_words, args.bit_width)
        total_values += result.checked
        total_mismatches += result.mismatch_count
        if result.expected_count != result.actual_count:
            length_mismatches += 1
        if result.failed:
            failed += 1

    print(
        f"SUMMARY files={len(pairs)} failed_files={failed} checked_values={total_values} "
        f"mismatches={total_mismatches} length_mismatches={length_mismatches}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
