# Latest pre-release profiling

Workload: full suite; Callgrind instructions and Memcheck cumulative bytes/objects in paired passes.
CPU pass: 0; allocation pass: 0.
24cdea4c184577df86f5b291251342f517dd936c
valgrind-3.27.1
CPU captures: 805; allocation captures: 805.
CPU units are instrumented instructions, not latency. Heap units are cumulative bytes and objects. Paired runs execute the same test workload.

## Largest cpu instructions processes
* 1490757349:  /home/linuxbrew/.linuxbrew/bin/python3 tests/test-audit-regressions.py
* 1463927307:  /home/linuxbrew/.linuxbrew/bin/python3 tests/test-postinst.py
* 800525121:  /home/linuxbrew/.linuxbrew/bin/python3 -
* 799332282:  /home/linuxbrew/.linuxbrew/bin/python3 -
* 798293658:  /home/linuxbrew/.linuxbrew/bin/python3 -
* 679802805:  /home/linuxbrew/.linuxbrew/bin/python3 -c \nimport json, sys\ntry:\n    d = json.load(sys.stdin)\n    if not isinstance(d, dict) or type(d.

## Largest allocated bytes/objects processes
* 138354815 / 43272: /home/linuxbrew/.linuxbrew/bin/python3 tests/test-audit-regressions.py
* 130447920 / 37956: /home/linuxbrew/.linuxbrew/bin/python3 tests/test-postinst.py
* 82622229 / 75473: /usr/libexec/gcc/x86_64-linux-gnu/13/cc1 -quiet -imultiarch x86_64-linux-gnu /workspace/projects/pve-microvm/tests/landlock-smoke.c -D_FORTI
* 68233343 / 21681: /home/linuxbrew/.linuxbrew/bin/python3 -
* 67745527 / 21649: /home/linuxbrew/.linuxbrew/bin/python3 -
* 67617387 / 21672: /home/linuxbrew/.linuxbrew/bin/python3 -

Analysis: interpreter/import startup dominates the mock fixture suite.
No PVE runtime or guest performance claim; CPU is instruction events, not wall time.
Equivalent paired workload; isolation preserved. Raw captures disposed after analysis.
