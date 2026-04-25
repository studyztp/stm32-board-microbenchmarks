#!/usr/bin/env python3
"""Patch the 4 real-algorithm benchmark target entries across the 3 config
JSONs to toggle enable_caches / enable_prefetch between the 'cp' and 'none'
configurations we care about for the gem5-vs-hardware comparison table.

Why this exists:
  benchmark/configs/{estimation,control,perception}_benchmarks.json feed
  into ento-bench's CMake via per-target overrides. Prefetch defaults to
  ON when absent, caches defaults to ON when absent. For the None column
  we need both explicitly false; the helper ensures that, and for the CP
  column it removes enable_prefetch (so default ON applies) and sets
  enable_caches: true.

Targets patched:
  bench-madgwick-float-imu   -> estimation_benchmarks.json
  bench-5pt-float            -> estimation_benchmarks.json
  bench-robofly-lqr          -> control_benchmarks.json
  bench-fastbrief-small      -> perception_benchmarks.json

JSONs here use trailing commas (jsonc), so we patch lines textually within
each target block rather than round-tripping through json.load — this also
preserves byte-level layout for everything we don't touch.
"""

from __future__ import annotations
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CFG_DIR = ROOT / "benchmark" / "configs"

TARGETS = {
    "estimation_benchmarks.json": ["bench-madgwick-float-imu", "bench-5pt-float"],
    "control_benchmarks.json":    ["bench-robofly-lqr"],
    "perception_benchmarks.json": ["bench-fastbrief-small"],
}


def find_block(lines: list[str], target: str) -> tuple[int, int]:
    """Return (start, end) line indices of the target's `{ ... }` block."""
    opener = re.compile(rf'"\s*{re.escape(target)}\s*"\s*:\s*\{{\s*$')
    for i, line in enumerate(lines):
        if opener.search(line):
            depth = 1
            for j in range(i + 1, len(lines)):
                depth += lines[j].count("{") - lines[j].count("}")
                if depth == 0:
                    return i, j
            raise ValueError(f"Unclosed block for {target}")
    raise ValueError(f"Target {target} not found")


def patch_block(lines: list[str], start: int, end: int, caches: bool, prefetch: bool | None) -> list[str]:
    """Update or insert enable_caches and enable_prefetch in the block.
    prefetch=None means remove the line (let default=true apply)."""
    body = lines[start + 1 : end]

    def upsert(body: list[str], key: str, value: bool | None) -> list[str]:
        pat = re.compile(rf'^(\s*)"{re.escape(key)}"\s*:\s*(true|false)\s*(,?)\s*$')
        for i, ln in enumerate(body):
            m = pat.match(ln)
            if m:
                if value is None:
                    body.pop(i)
                    return body
                indent, _old, comma = m.group(1), m.group(2), m.group(3) or ","
                body[i] = f'{indent}"{key}": {"true" if value else "false"}{comma}\n'
                return body
        if value is None:
            return body
        # insert before first non-whitespace/non-closing-brace line, matching indent
        indent = re.match(r"(\s*)", body[0]).group(1) if body else "      "
        body.insert(0, f'{indent}"{key}": {"true" if value else "false"},\n')
        return body

    body = upsert(body, "enable_caches", caches)
    body = upsert(body, "enable_prefetch", prefetch)
    return lines[: start + 1] + body + lines[end:]


def apply_config(mode: str) -> None:
    # Set both flags explicitly rather than relying on JSON omission — the
    # CMake-side treats an absent enable_prefetch as false when building the
    # CONFIG_STR filename suffix, and may not emit the ENABLE_PREFETCH compile
    # define either. Being explicit makes the two halves agree.
    if mode == "cp":
        caches, prefetch = True, True
    elif mode == "none":
        caches, prefetch = False, False
    else:
        sys.exit(f"Unknown mode: {mode!r}. Use 'cp' or 'none'.")

    for fname, targets in TARGETS.items():
        path = CFG_DIR / fname
        lines = path.read_text().splitlines(keepends=True)
        for t in targets:
            start, end = find_block(lines, t)
            lines = patch_block(lines, start, end, caches, prefetch)
        path.write_text("".join(lines))
        print(f"  patched {path.relative_to(ROOT)}: {', '.join(targets)} -> caches={caches}, prefetch={prefetch!r}")


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in ("cp", "none"):
        print(f"Usage: {sys.argv[0]} <cp|none>", file=sys.stderr)
        return 2
    print(f"Setting real-bench config to '{sys.argv[1]}'...")
    apply_config(sys.argv[1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
