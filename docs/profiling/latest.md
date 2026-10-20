# Latest pre-release profiling

Workload: full local regression suite, run once for each profile type.

Exit codes: CPU run 0; allocation run 0 (zero means success).

Source revision: `a734586f06795ee6f6fa7837a4dc39dd64e43410`.

Tool version: `valgrind-3.27.1`.

CPU profiles: 1281; allocation profiles: 1299.

Callgrind counts executed instructions. Memcheck counts cumulative allocated bytes and objects. The two runs use the same test workload. These counts do not measure elapsed time.

## Highest instruction counts

* 1494157426: `python3 tests/test-audit-regressions.py`
* 1476613988: `python3 tests/test-blockjob-patch.py`
* 1463759274: `python3 tests/test-postinst.py`
* 869820426: `python3 tests/test-profile-summary.py`
* 800263661: `python3 standard-input test`
* 799515976: `python3 standard-input test`

## Largest allocations

* 146990468 / 38723: `python3 tests/test-blockjob-patch.py`
* 140415311 / 43367: `python3 tests/test-audit-regressions.py`
* 130447864 / 37956: `python3 tests/test-postinst.py`
* 82622229 / 75473: `cc1 tests/landlock-smoke.c`
* 80289833 / 73747: `cc1 tests/network-smoke.c`
* 73056473 / 23334: `python3 tests/test-profile-summary.py`

## Analysis

Python startup and imports use most of the measured work in the mock tests.
The tests do not measure PVE runtime or guest performance. Each test keeps its
process isolation. Raw profiles and temporary files are deleted after analysis.

Local tests were extended while these captures were running. They are not an
identical-workload comparison or a performance improvement measurement. The
release workflow repeats both passes on the immutable tagged source. Python
startup/import work dominates the test fixtures; security and process-isolation
checks were retained. No PVE runtime performance claim is made.
