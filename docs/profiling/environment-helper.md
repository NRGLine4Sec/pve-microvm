# Path helper performance comparison

The path helper now validates five temporary/cache directories, then creates
them with one `mkdir -p` command. Previously, it ran one command for each path.
The validation rules and export order are unchanged.

## Measurements

The test ran 12 identical helper invocations. Each invocation ran `true` with
the same project root and run directory. Callgrind measured instruction counts.
A separate Memcheck run measured cumulative allocated bytes and objects. Both
versions had 12 empty post-fork allocation records with no counters; these
records are excluded from both totals.

| Metric | Before | After | Change |
| --- | ---: | ---: | ---: |
| Instructions | 170,654,490 | 146,102,842 | -24,551,648 (-14.4%) |
| Allocated bytes | 7,585,225 | 6,942,737 | -642,488 (-8.5%) |
| Allocated objects | 181,529 | 171,857 | -9,672 (-5.3%) |
| Processes with instruction profiles | 134 | 86 | -48 |

A separate test timed 120 invocations without profiling. It alternated the two
versions and took three measurements for each. Median time fell from 1.0494 s to
0.7261 s: a reduction of 0.3233 s (30.8%). The ranges were 1.0169–1.0509 s before
and 0.7177–0.7404 s after. Other activity and filesystem caches can affect these
short measurements. This test does not measure PVE or guest performance.

## Correctness and cleanup

Ownership, symbolic-link, path and conflicting-override checks are unchanged.
The full suite passed **93/93** after the change, including path-isolation and
chroot environment tests. Release CI will repeat the committed suite with
profiling. Raw comparison profiles and temporary files were deleted after
analysis.
