#!/usr/bin/env python3
"""Generate a LaTeX table from microbenchmark CSV data.

Usage:
    python benchmark/scripts/parse_logs.py benchmark_logs/ -o results.csv
    python benchmark/scripts/logs_to_latex.py results.csv
    python benchmark/scripts/logs_to_latex.py results.csv -o table.tex

    # Or piped:
    python benchmark/scripts/parse_logs.py benchmark_logs/ | python benchmark/scripts/logs_to_latex.py -
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path
from collections import OrderedDict

# Benchmark name -> instruction count for CPI calculation
BENCH_OPS: dict[str, int] = {
    "bench-nop":          100,
    "bench-alu":          100,
    "bench-alu16":        100,
    "bench-mul":          100,
    "bench-div":           20,
    "bench-div_short":     20,
    "bench-pushpop":        6,
    "bench-fpu":           45,
    "bench-dmb":           50,
    "bench-mixed_width":  100,
    "bench-load":          50,
    "bench-load_dep":      50,
    "bench-store":         50,
    "bench-store_burst":   50,
    "bench-ldr_literal":   50,
    "bench-ccm_sram":     100,
    "bench-scs_read":      50,
    "bench-scs_store":     50,
    "bench-art_prefetch": 200,
    "bench-icache_miss": 4096,
    "bench-branch":       100,
    "bench-bp_tight":     200,
    "bench-bp_long_body": 100,
    "bench-bp_forward":   100,
    "bench-bp_alternating": 200,
    "bench-bp_nested":    200,
    "bench-bp_align":     300,
}

CATEGORIES = [
    ("Compute", [
        "bench-nop", "bench-alu", "bench-alu16",
        "bench-mul", "bench-div", "bench-div_short",
        "bench-pushpop", "bench-fpu", "bench-dmb", "bench-mixed_width",
    ]),
    ("Memory", [
        "bench-load", "bench-load_dep", "bench-store", "bench-store_burst",
        "bench-ldr_literal", "bench-ccm_sram", "bench-scs_read", "bench-scs_store",
    ]),
    ("Cache", [
        "bench-art_prefetch", "bench-icache_miss",
    ]),
    ("Branch", [
        "bench-branch", "bench-bp_tight", "bench-bp_long_body",
        "bench-bp_forward", "bench-bp_alternating", "bench-bp_nested",
        "bench-bp_align",
    ]),
]

# Preferred config column ordering and display labels
CONFIG_LABELS: dict[str, str] = {
    "cache_pf":      "C+P",
    "cache_nopf":    "C",
    "nocache_pf":    "P",
    "nocache_nopf":  "None",
}
CONFIG_ORDER = ["cache_pf", "cache_nopf", "nocache_pf", "nocache_nopf"]


def read_csv(path: Path | str) -> list[dict]:
    if str(path) == "-":
        reader = csv.DictReader(sys.stdin)
        return list(reader)
    with open(path) as f:
        return list(csv.DictReader(f))


def display_name(bench: str) -> str:
    name = bench.replace("bench-", "")
    name = name.replace("_", "\\_")
    return name


def generate_latex(rows: list[dict]) -> str:
    # Index: (config, benchmark) -> cycles_per_call
    data: dict[tuple[str, str], float] = {}
    configs_seen: set[str] = set()
    benchmarks_seen: OrderedDict[str, None] = OrderedDict()

    for row in rows:
        config = row["config"]
        bench = row["benchmark"]
        cyc = float(row["cycles_per_call"])
        data[(config, bench)] = cyc
        configs_seen.add(config)
        benchmarks_seen[bench] = None

    # Order configs: use preferred order, then any extras alphabetically
    configs = [c for c in CONFIG_ORDER if c in configs_seen]
    extras = sorted(configs_seen - set(configs))
    configs.extend(extras)

    multi = len(configs) > 1

    # Count active benchmarks per category for multirow
    cat_counts = {}
    for cat_name, benchmarks in CATEGORIES:
        count = sum(1 for b in benchmarks if b in benchmarks_seen
                    and any((cfg, b) in data for cfg in configs))
        cat_counts[cat_name] = count

    lines: list[str] = []

    if multi:
        # Columns: Category | Benchmark | Ops | (Cyc CPI) per config
        col_spec = "l l r" + " r r" * len(configs)
        lines.append(f"\\begin{{tabular}}{{{col_spec}}}")
        lines.append(r"  \toprule")

        # Header row 1: config group labels
        header1 = [r"  ", "", ""]
        for cfg in configs:
            label = CONFIG_LABELS.get(cfg, cfg.replace("_", " ").title())
            header1.append(f"\\multicolumn{{2}}{{c}}{{{label}}}")
        lines.append(" & ".join(header1) + r" \\")

        # Cmidrule for each config pair
        cmidrules = []
        col = 4  # first data column (1-indexed)
        for _ in configs:
            cmidrules.append(f"\\cmidrule(lr){{{col}-{col+1}}}")
            col += 2
        lines.append("  " + " ".join(cmidrules))

        # Header row 2
        header2 = ["  Category", "Benchmark", "Ops"]
        for _ in configs:
            header2.extend(["Cyc", "CPI"])
        lines.append(" & ".join(header2) + r" \\")
    else:
        lines.append(r"\begin{tabular}{l l r r r}")
        lines.append(r"  \toprule")
        lines.append(r"  Category & Benchmark & Ops & Cyc & CPI \\")

    lines.append(r"  \midrule")

    for cat_idx, (cat_name, benchmarks) in enumerate(CATEGORIES):
        count = cat_counts.get(cat_name, 0)
        if count == 0:
            continue

        if cat_idx > 0:
            lines.append(r"  \midrule")

        row_idx = 0
        for bench in benchmarks:
            if bench not in benchmarks_seen:
                continue
            if not any((cfg, bench) in data for cfg in configs):
                continue

            ops = BENCH_OPS.get(bench, 0)
            name = display_name(bench)

            if row_idx == 0:
                cat_cell = f"\\multirow{{{count}}}{{*}}{{{cat_name}}}"
            else:
                cat_cell = ""

            if multi:
                parts = [f"  {cat_cell}", name, str(ops)]
                for cfg in configs:
                    cyc = data.get((cfg, bench))
                    if cyc is not None:
                        cpi = cyc / ops if ops else 0
                        parts.append(f"{cyc:,.0f}")
                        parts.append(f"{cpi:.2f}")
                    else:
                        parts.extend(["--", "--"])
                lines.append(" & ".join(parts) + r" \\")
            else:
                cyc = data.get((configs[0], bench))
                if cyc is not None:
                    cpi = cyc / ops if ops else 0
                    lines.append(
                        f"  {cat_cell} & {name} & {ops} "
                        f"& {cyc:,.0f} & {cpi:.2f} \\\\"
                    )
                else:
                    lines.append(
                        f"  {cat_cell} & {name} & {ops} & -- & -- \\\\"
                    )

            row_idx += 1

    lines.append(r"  \bottomrule")
    lines.append(r"\end{tabular}")

    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate LaTeX table from microbenchmark CSV"
    )
    parser.add_argument("csv_file", type=str,
                        help="Input CSV file (or - for stdin)")
    parser.add_argument("--output", "-o", type=Path, default=None,
                        help="Output .tex file (default: stdout)")
    args = parser.parse_args()

    rows = read_csv(args.csv_file)

    tex = generate_latex(rows)

    if args.output:
        args.output.write_text(tex)
        print(f"LaTeX table written to {args.output}", file=sys.stderr)
    else:
        print(tex)


if __name__ == "__main__":
    main()
