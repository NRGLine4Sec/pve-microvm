#!/usr/bin/env python3
"""Check that public profiling summaries omit host paths and inline commands."""
import ast
from pathlib import Path
import shlex

source = Path(__file__).resolve().parents[1] / 'scripts/analyse-profiles.py'
tree = ast.parse(source.read_text())
function = next(node for node in tree.body
                if isinstance(node, ast.FunctionDef) and node.name == 'public_command')
namespace = {'Path': Path, 'shlex': shlex}
exec(compile(ast.Module(body=[function], type_ignores=[]), str(source), 'exec'), namespace)
format_command = namespace['public_command']
for command, expected in (
    ('/opt/private/bin/python3 tests/test-postinst.py', 'python3 tests/test-postinst.py'),
    ('/usr/lib/gcc/cc1 /private/checkout/tests/network-smoke.c -DSECRET=private',
     'cc1 tests/network-smoke.c'),
    ('python3 -c "print(\'private details\')"', 'python3 inline test'),
    ('python3 -', 'python3 standard-input test'),
    ('/private/bin/mkdir -p /private/customer/path', 'mkdir'),
    ('', 'Test subprocess'),
    ('"incomplete', 'Test subprocess'),
):
    actual = format_command(command)
    assert actual == expected, (command, actual, expected)
print('Public profile command labels omit host paths, inline code and tool arguments')
