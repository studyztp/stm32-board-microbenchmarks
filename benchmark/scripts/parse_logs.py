#!/usr/bin/env python3
"""Parse microbenchmark semihosting logs into a CSV.

Usage:
    python benchmark/scripts/parse_logs.py benchmark_logs/
    python benchmark/scripts/parse_logs.py benchmark_logs/ -o results.csv
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path


def parse_log(log_path: Path) -> dict | None:
    """Extract benchmark config and results from a semihosting log."""
    text = log_path.read_text(errors="replace")
    lines = text.splitlines()

    result = {"name": log_path.stem}

    # Parse config
    for line in lines:
        m = re.match(r"REPS:\s+(\d+)", line)
        if m:
            result["reps"] = int(m.group(1))
        m = re.match(r"INNER_REPS:\s+(\d+)", line)
        if m:
            result["inner_reps"] = int(m.group(1))
        m = re.match(r"ENABLE_CACHES:\s+(\w+)", line)
        if m:
            result["enable_caches"] = m.group(1).lower() == "true"
        m = re.match(r"ENABLE_PREFETCH:\s+(\w+)", line)
        if m:
            result["enable_prefetch"] = m.group(1).lower() == "true"
        m = re.match(r"DO_WARMUP:\s+(\w+)", line)
        if m:
            result["do_warmup"] = m.group(1).lower() == "true"

    # Parse per-rep cycles
    rep_cycles = []
    for line in lines:
        m = re.match(r"Rep \d+: Cycles = (\d+)", line)
        if m:
            rep_cycles.append(int(m.group(1)))

    if not rep_cycles:
        return None

    # Parse summary lines
    for line in lines:
        m = re.match(r"Average cycles:\s+([\d.]+)", line)
        if m:
            result.setdefault("avg_cycles", float(m.group(1)))
        m = re.match(r"Max cycles:\s+(\d+)", line)
        if m:
            result.setdefault("max_cycles", int(m.group(1)))
        m = re.match(r"Min cycles:\s+(\d+)", line)
        if m:
            result.setdefault("min_cycles", int(m.group(1)))
        m = re.match(r"Final ROI cycles:\s+(\d+)", line)
        if m:
            result["final_roi_cycles"] = int(m.group(1))

    result["rep_cycles"] = rep_cycles
    result["median_cycles"] = sorted(rep_cycles)[len(rep_cycles) // 2]

    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Parse microbenchmark logs into CSV"
    )
    parser.add_argument("log_dir", type=Path,
                        help="Top-level log directory (contains cache/ and nocache/)")
    parser.add_argument("--output", "-o", type=Path, default=None,
                        help="Output CSV file (default: stdout)")
    args = parser.parse_args()

    log_dir: Path = args.log_dir
    rows = []

    for subdir in sorted(log_dir.iterdir()):
        if not subdir.is_dir():
            continue
        config_name = subdir.name  # "cache" or "nocache"

        for log_path in sorted(subdir.glob("*.log")):
            result = parse_log(log_path)
            if result is None:
                print(f"Warning: no data in {log_path}", file=sys.stderr)
                continue

            inner_reps = result.get("inner_reps", 1)
            avg = result.get("avg_cycles", 0)
            cycles_per_call = avg / inner_reps if inner_reps else avg

            rows.append({
                "config": config_name,
                "benchmark": result["name"],
                "reps": result.get("reps", ""),
                "inner_reps": inner_reps,
                "enable_caches": result.get("enable_caches", ""),
                "enable_prefetch": result.get("enable_prefetch", ""),
                "avg_cycles": f"{avg:.1f}",
                "median_cycles": result.get("median_cycles", ""),
                "min_cycles": result.get("min_cycles", ""),
                "max_cycles": result.get("max_cycles", ""),
                "cycles_per_call": f"{cycles_per_call:.1f}",
            })

    fieldnames = [
        "config", "benchmark", "reps", "inner_reps",
        "enable_caches", "enable_prefetch",
        "avg_cycles", "median_cycles", "min_cycles", "max_cycles",
        "cycles_per_call",
    ]

    out = open(args.output, "w", newline="") if args.output else sys.stdout
    writer = csv.DictWriter(out, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

    if args.output:
        out.close()
        print(f"CSV written to {args.output} ({len(rows)} rows)", file=sys.stderr)


if __name__ == "__main__":
    main()
