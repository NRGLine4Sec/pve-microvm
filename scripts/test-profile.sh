#!/bin/bash
# Retained CPU/allocation reports are separate from disposable project scratch.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/tools/pve-microvm-env.sh"
pve_microvm_env tests
command -v valgrind >/dev/null || { echo 'Install valgrind before running profiled tests' >&2; exit 1; }
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
REPORT="$ROOT/docs/evidence/path-policy/$RUN_ID"
mkdir -p "$REPORT"
{
    git -C "$ROOT" rev-parse HEAD
    git -C "$ROOT" status --short
    valgrind --version
    bash --version | sed -n '1p'
    python3 --version
    printf 'Commands: Callgrind CPU pass; Memcheck allocation pass; both trace children\n'
    printf 'CPU: instrumented instruction events (not wall-clock samples); allocations: full xtree events\n'
    printf 'Valgrind tools cannot run together: equivalent workload captured twice as a pair\n'
    printf 'Workload: full mock/static suite; TMPDIR=%s\n' "$TMPDIR"
} > "$REPORT/receipt.txt"
set +e
valgrind --tool=callgrind --trace-children=yes \
    --callgrind-out-file="$REPORT/cpu.%p" --log-file="$REPORT/callgrind.%p.log" \
    bash "$ROOT/tests/run-tests.sh" > "$REPORT/cpu-tests.log" 2>&1
cpu_rc=$?
valgrind --tool=memcheck --trace-children=yes --xtree-memory=full \
    --xtree-memory-file="$REPORT/heap.%p" --log-file="$REPORT/memcheck.%p.log" \
    bash "$ROOT/tests/run-tests.sh" > "$REPORT/tests.log" 2>&1
heap_rc=$?
rc=$((cpu_rc || heap_rc))
set -e
printf 'CPU pass: %s; heap pass: %s\n' "$cpu_rc" "$heap_rc" >> "$REPORT/receipt.txt"
printf 'Retained profiling report: %s\n' "$REPORT"
tail -8 "$REPORT/tests.log"
# Retain every raw capture; annotate only the largest processes. Whole-tree
# annotation takes longer than tests and adds no value for tiny helper processes.
python3 "$ROOT/scripts/analyse-profiles.py" "$REPORT" > "$REPORT/profile-summary.log"
exit "$rc"
