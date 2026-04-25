#!/bin/bash
# Flash the 4 real-algorithm benchmarks (Madgwick / 5-point / RoboFly LQR /
# FAST+BRIEF small) on the STM32G474 board and scrape cycles from the
# semihosting output. Populates both columns of the gem5-vs-hardware table.
#
# Usage:
#   ./verification/sweep_real_board.sh --config cp     # cache + prefetch on
#   ./verification/sweep_real_board.sh --config none   # both off
#   ./verification/sweep_real_board.sh --config both   # runs cp then none
#
# What this does:
#   1. Patches benchmark/configs/{estimation,control,perception}_benchmarks.json
#      via configure_real_bench.py so the 4 target entries have the right
#      enable_caches/enable_prefetch values.
#   2. Reconfigures + rebuilds build-entobench so the compile-time flags bake
#      into the ELF.
#   3. Flashes each target via stm32-flash-<target>-semihosted (runs on-board,
#      captures cycles via semihosting).
#   4. Parses build-entobench/ento-bench-control/flash-<target>_<config>.log
#      for Average/Min/Max cycles.
#
# On exit, the JSON configs are left in whatever state the last requested
# config set them to. Re-run with --config cp to restore the default.

set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR="build-entobench"
OUT_ROOT="verification/logs/real_board"
# Flash logs land under build-entobench/<category>/flash-<target>_<config>.log
# (category depends on where each bench lives in the source tree), so we
# find them rather than hardcoding a single dir.

BENCHES=(
    bench-madgwick-float-imu
    bench-5pt-float
    bench-robofly-lqr
    bench-fastbrief-small
)

CONFIG=""
for arg in "$@"; do
    case "$arg" in
        --config) shift; CONFIG="${1:-}"; shift ;;
        --config=*) CONFIG="${arg#--config=}" ;;
        -h|--help)
            sed -n '2,/^set -euo/p' "$0" | sed 's/^# \?//' | head -n -1
            exit 0
            ;;
    esac
done

case "$CONFIG" in
    cp|none) CONFIGS=("$CONFIG") ;;
    both)    CONFIGS=(cp none) ;;
    "")      echo "Error: --config required (cp | none | both)" >&2; exit 1 ;;
    *)       echo "Error: unknown --config '$CONFIG'" >&2; exit 1 ;;
esac

HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
RUN_TAG="${HEAD_SHA}-$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUT_ROOT/runs/$RUN_TAG"
mkdir -p "$RUN_DIR"
SUMMARY="$RUN_DIR/summary.txt"
: > "$SUMMARY"

for cfg in "${CONFIGS[@]}"; do
    echo "============================================================"
    echo "=== Config: $cfg"
    echo "============================================================"
    python3 verification/configure_real_bench.py "$cfg"

    echo "Reconfiguring + rebuilding (this regenerates the json-driven flags)..."
    # JSONs are read via file(READ) at CMake configure time. The configure step
    # doesn't watch them as dependencies, so we force a fresh configure by
    # invoking cmake on the build dir. Then build each target.
    cmake "$BUILD_DIR" > "$RUN_DIR/reconfigure-${cfg}.log" 2>&1 \
        || { echo "  RECONFIGURE_FAILED (see $RUN_DIR/reconfigure-${cfg}.log)"; exit 1; }
    for b in "${BENCHES[@]}"; do
        echo "  building $b"
        cmake --build "$BUILD_DIR" --target "$b" -j > "$RUN_DIR/build-${cfg}-${b}.log" 2>&1 \
            || { echo "    BUILD_FAILED (see $RUN_DIR/build-${cfg}-${b}.log)"; continue; }
    done

    echo
    echo "Flashing and scraping cycles..."
    printf '%-28s %-10s %-12s %-12s %-12s %s\n' "bench" "config" "avg" "min" "max" "logfile" | tee -a "$SUMMARY"
    printf '%s\n' "----------------------------------------------------------------------------------------------" | tee -a "$SUMMARY"

    for b in "${BENCHES[@]}"; do
        # Remove any stale log so we reliably find the one from this run.
        find "$BUILD_DIR" -name "flash-${b}_*.log" -delete 2>/dev/null

        if ! make -C "$BUILD_DIR" "stm32-flash-${b}-semihosted" > "$RUN_DIR/flash-${cfg}-${b}.stdout" 2>&1; then
            printf '%-28s %-10s FLASH_FAILED (see %s)\n' "$b" "$cfg" "$RUN_DIR/flash-${cfg}-${b}.stdout" | tee -a "$SUMMARY"
            continue
        fi

        log=$(find "$BUILD_DIR" -name "flash-${b}_*.log" 2>/dev/null | head -1)
        if [[ -z "$log" ]]; then
            printf '%-28s %-10s NO_LOG\n' "$b" "$cfg" | tee -a "$SUMMARY"
            continue
        fi

        cp "$log" "$RUN_DIR/"   # preserve a copy with this run

        avg=$(awk '/^Average cycles:/ {print $3}' "$log" | tail -1)
        min=$(awk '/^Min cycles:/     {print $3}' "$log" | tail -1)
        max=$(awk '/^Max cycles:/     {print $3}' "$log" | tail -1)
        printf '%-28s %-10s %-12s %-12s %-12s %s\n' "$b" "$cfg" "${avg:-?}" "${min:-?}" "${max:-?}" "$(basename "$log")" | tee -a "$SUMMARY"
    done
    echo | tee -a "$SUMMARY"
done

echo "Summary written to $SUMMARY"
echo "Per-run artifacts in $RUN_DIR"
echo
echo "Note: json configs left in state '${CONFIGS[${#CONFIGS[@]}-1]}'. Re-run with --config cp to restore default."
