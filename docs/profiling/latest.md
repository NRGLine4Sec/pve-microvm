# Latest pre-release profiling

Workload: full local regression suite, run once for each profile type.

Exit codes: CPU run 0; allocation run 0 (zero means success).

Source revision: `d7933a72884cd49a3ae75a6272c59fa87629ffae`.

Tool version: `valgrind-3.22.0`.

CPU profiles: 1200; allocation profiles: 1200.

Callgrind counts executed instructions. Memcheck counts cumulative allocated bytes and objects. The two runs use the same test workload. These counts do not measure elapsed time.

## Highest instruction counts

* 1087219797: `python3 tests/test-audit-regressions.py`
* 1072775960: `python3 tests/test-blockjob-patch.py`
* 1066746723: `python3 tests/test-postinst.py`
* 818677316: `python3 tests/test-profile-summary.py`
* 683893695: `python3 standard-input test`
* 682974217: `python3 standard-input test`

## Largest allocations

* 118169935 / 40782: `python3 tests/test-blockjob-patch.py`
* 116189388 / 45840: `python3 tests/test-audit-regressions.py`
* 111675825 / 40079: `python3 tests/test-postinst.py`
* 85516474 / 31742: `python3 tests/test-profile-summary.py`
* 82663802 / 75478: `cc1 tests/landlock-smoke.c`
* 80331406 / 73752: `cc1 tests/network-smoke.c`

## Analysis

Python startup and imports use most of the measured work in the mock tests.
The tests do not measure PVE runtime or guest performance. Each test keeps its
process isolation. Raw profiles and temporary files are deleted after analysis.
