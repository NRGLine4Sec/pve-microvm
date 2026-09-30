#!/usr/bin/env python3
"""Exercise the package hook without root, PVE or a real service manager."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'debian/pve-microvm.postinst').read_text()
patcher = '/usr/share/pve-microvm/pve-microvm-patch'
assert source.count(patcher) == 2

with tempfile.TemporaryDirectory(prefix='microvm-postinst-') as tmp:
    root = Path(tmp)
    stub = '''#!/bin/sh
name=${0##*/}
printf '%s %s\\n' "$name" "$*" >> "$CALLS"
case "$name" in
    patcher) exit "${PATCH_RC:-0}" ;;
    deb-systemd-invoke) exit "${RELOAD_RC:-0}" ;;
esac
'''
    for name in ('patcher', 'systemctl', 'deb-systemd-invoke'):
        path = root / name
        path.write_text(stub)
        path.chmod(0o755)
    hook = root / 'postinst'
    hook.write_text(source.replace(patcher, str(root / 'patcher')))
    log = root / 'calls'

    def invoke(action, patch_rc=0, reload_rc=0):
        log.write_text('')
        result = subprocess.run(
            ['bash', str(hook), action], capture_output=True, text=True,
            env={**os.environ, 'PATH': f'{root}:/usr/bin:/bin', 'CALLS': str(log),
                 'PATCH_RC': str(patch_rc), 'RELOAD_RC': str(reload_rc)},
        )
        return result.returncode, log.read_text().splitlines()

    refresh = 'deb-systemd-invoke reload-or-try-restart pvedaemon.service'
    for action in ('configure', 'triggered'):
        expected = ['patcher apply']
        if action == 'configure':
            expected += ['systemctl daemon-reload', 'systemctl enable pve-microvm-early.service']
        expected += [refresh]
        code, calls = invoke(action)
        assert code == 0 and calls == expected, (action, code, calls)
        # Retain best-effort service refresh, but never fall back to a full restart.
        code, calls = invoke(action, reload_rc=1)
        assert code == 0 and calls == expected, (action, code, calls)
        # Do not reload partially patched code after a patch failure.
        code, calls = invoke(action, patch_rc=42)
        assert code == 42 and calls == ['patcher apply'], (action, code, calls)
    code, calls = invoke('abort-upgrade')
    assert code == 0 and calls == [], (code, calls)

print('postinst: configure/triggered refresh ordering, patch failure, refresh failure and no-op passed')
