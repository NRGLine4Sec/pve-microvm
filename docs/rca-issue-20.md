# WebUI package update interruption (#20)

## Cause

Versions 0.3.20 through 0.3.25 called `systemctl try-restart pvedaemon.service`
after patch application in both `configure` and `triggered` package hooks. The
restart refreshed cached Perl code but could also terminate the WebUI terminal
and the package manager running beneath it.

The WebUI upgrade console launches `termproxy` through a `vncshell` API worker.
Its command is `/usr/bin/pveupgrade --shell`, which runs `apt-get dist-upgrade`.
These child processes belong to `pvedaemon.service`'s cgroup. With
`KillMode=control-group`, a full service stop terminates that group. Calling the
restart from a package hook inside the upgrade can therefore interrupt its own
parent operation.

The xterm.js `Disconnecting... (Detecting migration...)` banner is a connection
recovery message. It does not establish that a VM migrated. The reporter's PVE
version and package-manager logs were unavailable when the fix was published;
the exact state of their interrupted transaction is unknown.

## Resolution

Version 0.3.26 uses the action in Proxmox's own `pve-manager` package hook:

```sh
deb-systemd-invoke reload-or-try-restart pvedaemon.service || true
```

On the tested PVE service, `ExecReload=/usr/bin/pvedaemon restart` selects PVE's
HUP/re-exec path. `leave_children_open_on_reload => 1` preserves terminal children
while the daemon reloads Perl modules and replaces API workers. This retains the
code refresh needed after patching without stopping the service cgroup.

Both package-hook paths use the same action. Debian's helper respects local
service policy; service-refresh failures remain best-effort. A patch-application
failure aborts before any refresh. The fix does not change guest configurations
or disk contents. The fallback in `reload-or-try-restart` would restart an active
service that has no reload support; the tested PVE service has `CanReload=yes`.

## Regression tests

The former test counted two full-restart calls and inadvertently required the
bug. `tests/test-postinst.py` now executes each hook with isolated command mocks
and verifies:

* Patch application precedes a graceful refresh on both configure and trigger.
* Configure also reloads systemd metadata and enables the early service.
* Patch failures prevent refresh.
* Refresh failures do not invoke a second, full-restart fallback.
* Unrelated hook actions do nothing.

The complete suite passes 88 tests. The Debian candidate builds successfully.

## Canary results

Tests ran on an idle z83ii node on 2026-09-30 with no VMs, containers or active
PVE tasks. Installed versions were `pve-manager 9.2.20`, `qemu-server 9.2.8`,
`libpve-common-perl 9.2.2` and `pve-xtermjs 6.0.0-2`.

A disposable, authenticated `termproxy` and a harmless child command were placed
in the actual `pvedaemon.service` cgroup. No real apt transaction ran during the
failure reproduction.

| Service action | Terminal connection | Child command |
| --- | --- | --- |
| `systemctl reload` | Survived | Continued heartbeats |
| Old `systemctl try-restart` | Disconnected | Terminated |

For the fixed `0.3.26~rc1-1` package, the same terminal/cgroup setup executed
`dpkg -i` and then the installed postinst's trigger path. Both hooks completed
with exit code zero; the terminal answered input after each operation and the
child continued heartbeats. The daemon PID stayed unchanged through graceful
re-exec. A repeated run passed with the same results.

Temporary processes/files were removed. The node had an active daemon, no failed
services, no active tasks and no `dpkg --audit` findings afterwards. Other hosts
were not modified. This test exercises the installed terminal proxy and real
package hooks; it does not run a browser or a full system-wide apt upgrade.

## Recovery from an interrupted update

Connect over SSH. Check whether `apt` or `dpkg` is still running before starting
another transaction; do not delete lock files held by an active process. After
it has stopped, inspect `dpkg --audit` and `/var/log/apt/term.log`. Finish pending
configuration with `dpkg --configure -a` if needed, then retry the upgrade over
SSH and install version 0.3.26 or later.

[Issue #20](https://github.com/rcarmo/pve-microvm/issues/20) contains the release
and closure details.
