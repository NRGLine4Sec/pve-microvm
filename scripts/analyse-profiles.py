#!/usr/bin/env python3
"""Summarise temporary Valgrind CPU/allocation captures, not a performance gate."""
from pathlib import Path
import shlex
import subprocess
import sys


def public_command(command):
    """Keep the test/tool name without host paths, compiler flags or inline code."""
    try:
        args = shlex.split(command)
    except ValueError:
        return 'Test subprocess'
    if not args:
        return 'Test subprocess'
    program = Path(args[0]).name
    for arg in args[1:]:
        # Only repository-relative test identifiers are useful in public reports.
        parts = Path(arg).parts
        if 'tests' in parts:
            index = parts.index('tests')
            if index + 1 < len(parts) and parts[index + 1].endswith(('.py', '.sh', '.c', '.pl')):
                return f'{program} tests/{parts[index + 1]}'
    if program.startswith('python') and '-c' in args:
        return f'{program} inline test'
    if program.startswith('python') and '-' in args:
        return f'{program} standard-input test'
    return program

report = Path(sys.argv[1]).resolve()
cpu, heap = [], []
for kind, rows in (('cpu', cpu), ('heap', heap)):
    for path in report.glob(f'{kind}.*'):
        if not path.name.split('.')[-1].isdigit():
            continue
        lines = path.read_text().splitlines()
        cmd = next((line[5:] for line in lines if line.startswith('cmd: ')), '')
        marker = 'summary: ' if kind == 'cpu' else 'totals: '
        counts = next((list(map(int, line.split()[1:])) for line in lines
                       if line.startswith(marker)), [])
        if counts:
            # Xt memory events: curB curBk totB totBk totFdB totFdBk.
            score = counts[0] if kind == 'cpu' else counts[2]
            rows.append((score, counts, cmd, path))

out = [f'CPU profiles: {len(cpu)}; allocation profiles: {len(heap)}.\n\n',
       'Callgrind counts executed instructions. Memcheck counts cumulative '
       'allocated bytes and objects. The two runs use the same test workload. '
       'These counts do not measure elapsed time.\n']
for kind, rows in (('CPU instructions', cpu), ('Allocated bytes/objects', heap)):
    heading = 'Highest instruction counts' if kind == 'CPU instructions' else 'Largest allocations'
    out += [f'\n## {heading}\n\n']
    for score, counts, cmd, path in sorted(rows, key=lambda row: row[0], reverse=True)[:6]:
        value = str(score) if kind.startswith('CPU') else f'{score} / {counts[3]}'
        out.append(f'* {value}: `{public_command(cmd)}`\n')
        target = Path(str(path) + '.top.txt')
        if not target.exists() or not target.stat().st_size:
            with target.open('w') as stream:
                subprocess.run(['callgrind_annotate', '--inclusive=yes', '--threshold=95',
                                str(path)], stdout=stream, stderr=subprocess.DEVNULL,
                               check=False)
(report / 'profile-summary.md').write_text(''.join(out))
print(''.join(out))
if not cpu or not heap:
    raise SystemExit('Missing captures: do not accept the profiling gate')
