# Pre-release profile results

The full local regression suite passed in both runs: CPU exit code **0** and
allocation exit code **0**. Each run captured **1,319 processes**.

Source revision: `2024b710803df1062af1f0d594516817d61304f8`.
Tool: Valgrind 3.27.1. These results precede the path-helper optimisation.

Callgrind counts executed instructions. Memcheck counts cumulative allocated
bytes and objects. The two runs used the same workload. These counts do not
measure elapsed time.

## Highest instruction counts

* 1,493,990,815: `python3 tests/test-audit-regressions.py`
* 1,476,543,646: `python3 tests/test-blockjob-patch.py`
* 1,463,537,371: `python3 tests/test-postinst.py`
* 800,299,630; 799,320,286; 798,252,492: Python standard-input tests

## Largest allocations

| Process | Allocated bytes | Allocated objects |
| --- | ---: | ---: |
| `python3 tests/test-blockjob-patch.py` | 146,990,468 | 38,723 |
| `python3 tests/test-audit-regressions.py` | 140,415,356 | 43,367 |
| `python3 tests/test-postinst.py` | 130,447,864 | 37,956 |
| Compiler: `tests/landlock-smoke.c` | 82,622,229 | 75,473 |
| Compiler: `tests/network-smoke.c` | 80,289,833 | 73,747 |
| Python standard-input test | 68,233,343 | 21,681 |

## Analysis

Python startup and imports use most of the measured work in the mock tests.
The tests do not measure PVE runtime or guest performance. Process isolation
was preserved. Raw profiles were deleted after analysis.

The [path-helper comparison](environment-helper.md) records a separate
before/after measurement and the applied optimisation. Release CI will profile
the final committed source again.
