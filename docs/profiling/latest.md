# Latest pre-release profiling

Workload: full suite; Callgrind instructions and Memcheck cumulative bytes/objects in paired passes.
CPU pass: 0; allocation pass: 0.
2f621612c940af0254010a5b9cfd1a7a5b7ef3d7
valgrind-3.27.1
CPU captures: 763; allocation captures: 774.
CPU units are instrumented instructions, not latency. Heap units are cumulative bytes and objects. Paired runs execute the same test workload.

## Largest cpu instructions processes
* 1490903840:  /home/linuxbrew/.linuxbrew/bin/python3 tests/test-audit-regressions.py
* 1463686246:  /home/linuxbrew/.linuxbrew/bin/python3 tests/test-postinst.py
* 800522151:  /home/linuxbrew/.linuxbrew/bin/python3 -
* 799510104:  /home/linuxbrew/.linuxbrew/bin/python3 -
* 798707357:  /home/linuxbrew/.linuxbrew/bin/python3 -
* 679948281:  /home/linuxbrew/.linuxbrew/bin/python3 -c \nimport json, sys\ntry:\n    d = json.load(sys.stdin)\n    if not isinstance(d, dict) or type(d.

## Largest allocated bytes/objects processes
* 138354521 / 43272: /home/linuxbrew/.linuxbrew/bin/python3 tests/test-audit-regressions.py
* 130447864 / 37956: /home/linuxbrew/.linuxbrew/bin/python3 tests/test-postinst.py
* 82622229 / 75473: /usr/libexec/gcc/x86_64-linux-gnu/13/cc1 -quiet -imultiarch x86_64-linux-gnu /workspace/projects/pve-microvm/tests/landlock-smoke.c -D_FORTI
* 68233343 / 21681: /home/linuxbrew/.linuxbrew/bin/python3 -
* 67745527 / 21649: /home/linuxbrew/.linuxbrew/bin/python3 -
* 67617387 / 21672: /home/linuxbrew/.linuxbrew/bin/python3 -

Analysis: interpreter/import startup dominates the mock fixture suite.
No PVE runtime or guest performance claim; CPU is instruction events, not wall time.
Equivalent paired workload; isolation preserved. Raw captures disposed after analysis.
