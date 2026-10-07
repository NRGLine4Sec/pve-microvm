# v0.3.27 validation and rollout

On 2026-10-07, v0.3.27 was published and deployed to borg, u59, tnas, radxax4
and z83ii. All report `pve-microvm 0.3.27-1`; existing running VM PIDs remained
unchanged. No existing guest or host was rebooted. Guest-agent checks passed
for VMs 114, 9022, 119, 122 and 900. Daemons refreshed gracefully and no new host
failed units or package-state errors appeared. Host recovery copies are retained
under `/root/pve-microvm-recovery/release-0327-*`.

## Landlock checks

* The normalised kernel config has `CONFIG_SECURITY=y`, `CONFIG_SECURITYFS=y`,
  `CONFIG_SECURITY_LANDLOCK=y` and an LSM list preserving the existing defaults.
* Local and release-CI isolated QEMU/TCG boots passed the active-LSM and
  unprivileged ABI/enforcement gate. No disks or networking are attached to that
  test.
* A disposable normal Debian guest on z83ii booted both the local kernel and the
  exact published kernel/initrd. Active LSMs were
  `capability,landlock,selinux,bpf`; Landlock reported **ABI 6**, UID **65534**.
* Allowed-directory write/truncate/rename passed. Outside write/create/truncate
  and rename were denied. Restrictions survived fork and exec. The guest agent
  reported zero restarts. Disposable template/clone VMIDs 9880/9881 were purged.
* That Debian image had a `systemd-modules-load` failed unit in both initial and
  final boots. No Landlock test or guest-agent operation failed; the template
  module-load warning was not resolved in this kernel-feature release.

## Build and profiling

The full suite passed **90/90** in development and paired pre-release
CPU/allocation runs. CPU instruction and cumulative byte/object profiles traced
child processes. Python import/interpreter fixture setup dominates (~1.491
billion instructions, 138.35 MB / 43,272 objects for the audit fixture); no PVE
runtime throughput or latency improvement is claimed. Independent fixtures and
security/error checks were retained. Summaries are in `docs/profiling/`; raw
profiles and disposable failed probes/build scratch were removed after use.

The chroot setup failed once because host TMPDIR leaked into the guest image;
the new environment-boundary wrapper and regression test fixed it. Kernel
compilation initially failed on this development host's missing libelf headers;
the build dependency was installed and the final full build passed. A guest
probe had to be reinstalled after reboot because systemd cleared guest `/tmp`.

Both [CI](https://github.com/rcarmo/pve-microvm/actions/runs/37675455685) and the
[release pipeline](https://github.com/rcarmo/pve-microvm/actions/runs/37675463508)
succeeded. Release CI rebuilt the kernel, boot-tested enforcement, packaged the
effective config and published the Debian package and OCI artifact.

## Activation boundary

Running guests still use their pre-upgrade kernels until an authorised restart.
Future starts using `/usr/share/pve-microvm/vmlinuz` get the updated kernel;
custom kernel paths or an explicit `lsm=` override need separate attention.
Package deployment does not prove Landlock is active in already-running guests.

[Issue #21](https://github.com/rcarmo/pve-microvm/issues/21) and
[v0.3.27](https://github.com/rcarmo/pve-microvm/releases/tag/v0.3.27).
