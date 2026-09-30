# v0.3.26

WebUI package updates can be interrupted when pve-microvm restarts the daemon
hosting their terminal. This patch release replaces that full restart with
Proxmox's graceful `deb-systemd-invoke reload-or-try-restart` action in both
package configuration and qemu-server trigger hooks. Cached Perl code is still
refreshed; existing terminal children are preserved on PVE's reload path.

The restart was introduced in v0.3.20. Versions through v0.3.25 can disconnect
the terminal and terminate the package manager beneath it. The yellow
`Disconnecting... (Detecting migration...)` message does not establish that a
VM migrated or that the update completed.

If an update was interrupted, use SSH to check for an active apt/dpkg process
before starting another transaction. Once it has stopped, inspect `dpkg --audit`
and `/var/log/apt/term.log`; finish pending configuration with `dpkg --configure -a`
if needed, then retry the upgrade over SSH. Do not delete active lock files.

Validation: 88 tests pass. On idle z83ii (PVE manager 9.2.20), the old restart
terminated a disposable terminal/child in the daemon cgroup. A graceful reload
preserved both. The fixed Debian candidate installed through that terminal and
completed both configure and trigger paths without disconnecting it. No real
system-wide apt upgrade or browser automation was used for these checks.

See [issue #20](https://github.com/rcarmo/pve-microvm/issues/20) and the
[RCA](docs/rca-issue-20.md) for the process lifecycle, test results and recovery.
