# v0.3.27

The shipped Linux 6.12.22 guest kernel now enables Landlock for unprivileged
filesystem sandboxing ([#21](https://github.com/rcarmo/pve-microvm/issues/21)).
Landlock is built in and included in the default LSM selection without dropping
existing LSM entries. The build rejects configurations that lose those settings
and publishes the effective `kernel-config` alongside the kernel/initrd.

An unprivileged guest smoke test checks ABI 3+, allowed-directory writes,
denied outside writes/truncation/rename and inheritance across fork/exec.
See [Landlock testing and activation](docs/landlock.md).

This release also fixes host temp/cache paths leaking into guest chroot package
scripts, which could make `mktemp` fail during template creation. Pre-release
CPU/allocation profiles are now analysed and deleted immediately, leaving only
concise conclusions; ordinary development tests need not profile every run.

Validation: **90 tests pass**. The locally rebuilt kernel passes isolated QEMU/TCG
boot testing and a normal Debian/PVE guest boot on z83ii: active LSMs are
`capability,landlock,selinux,bpf`, ABI is **6**, and write/truncate/rename plus
fork/exec tests pass as UID 65534. Pre-release CPU/allocation analysis retains
process isolation; raw captures were disposed after use. Release CI repeats the
profiled suite and booted-kernel enforcement gate before publication.

**Existing running guests keep their current kernel until restarted.** Deployment
updates the host files for future starts and does not reboot workloads. Custom
kernel paths and explicit `lsm=` overrides need separate attention.
