# Previous path-policy experiments

The 2026-10-05 final paired mock-suite profiling passed 89/89 tests in
each pass. Python interpreter/import fixture setup dominated (~1.491 billion
instructions, 138.35 MB / 43,272 cumulative allocations for the audit fixture).
No PVE runtime performance was measured. The failed external-root probe
identified exporting TMPDIR before directory creation; create-before-export
fixed it. Annotation was reduced to top processes. Raw completed/probe
captures were analysed and removed under the current disposal policy.

