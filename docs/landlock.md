# Landlock in the guest kernel

Version 0.3.27 enables built-in Landlock in the shipped Linux 6.12.22 kernel.
Applications can query its ABI and apply unprivileged filesystem restrictions.
Landlock must also be selected at boot; the default LSM list includes it and
preserves SELinux, BPF and other default entries. Only compiled-in LSMs activate.
An explicit guest `lsm=` command-line override can still disable it.

The build runs `kernel/check-landlock.sh` after config merging and `olddefconfig`.
It requires `CONFIG_SECURITY=y`, `CONFIG_SECURITYFS=y`, `CONFIG_SECURITY_LANDLOCK=y`, and Landlock,
SELinux and BPF in `CONFIG_LSM`. The effective config ships as
`/usr/share/pve-microvm/kernel/build.config` and the release's `kernel-config`
asset. This distinguishes overlay intent from what the kernel build used.

Release CI boots the built kernel in an isolated QEMU/TCG initramfs with no
disks or networking (`tests/boot-landlock.sh`). It verifies the active LSM list,
drops privileges and runs the same enforcement checks. Canary validation also
boots the normal Debian guest and packaged initrd on PVE.

## Activation after an upgrade

Installing the host package updates the kernel/initrd used for future VM starts.
A running guest keeps its existing kernel until it restarts. No host reboot is
required. Guests pointing to a custom kernel path must update that path first.
Schedule guest restarts with their workload owners; package deployment does not
restart guests automatically.

Inside a newly booted guest, mount securityfs if needed and inspect the active
LSMs:

```sh
mountpoint -q /sys/kernel/security || mount -t securityfs securityfs /sys/kernel/security
cat /sys/kernel/security/lsm
```

## ABI and filesystem smoke test

Compile `tests/landlock-smoke.c` (also installed as
`/usr/share/pve-microvm/kernel/landlock-smoke.c`) and run it as an ordinary user with `TMPDIR`
pointing to a writable owned test directory:

```sh
cc -O2 -Wall -Wextra -Werror tests/landlock-smoke.c -o landlock-smoke
TMPDIR=/path/to/owned/test-directory ./landlock-smoke
```

The test rejects ABI values below 3 and fails closed on unsupported syscalls,
rule-installation errors or unexpected permission errors. ABI 2 introduced
refer/rename controls; ABI 3 added truncate protection. Before restricting the
child, the parent verifies ordinary permissions allow writing both fixtures.
The child permits writes/truncation/rename inside one directory and checks that
outside writes, file creation, truncation and rename fail. A forked, exec'd child
checks inherited restrictions. The unsandboxed parent removes its owned fixtures
afterward. The program refuses to run as root.

The test handles only the required write-related rights. It intentionally allows
reads and execution, so it is a smoke test rather than a complete application
sandbox. Applications must choose their own rights and handle unsupported ABI
levels according to their security requirements.
