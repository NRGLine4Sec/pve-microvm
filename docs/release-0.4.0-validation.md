# v0.4.0 validation

Version 0.4.0 updates the guest kernel to **Linux 6.12.113** and fixes the missing
TUN policy-routing and mark features in [#23][issue]. The release was published
on 2026-10-20. No fleet packages or running guests were changed for this release.

## Tests and package checks

* The local suite passed **93/93** tests. [CI][ci] also passed.
* The [release workflow][release-ci] passed both profiled test runs, the kernel
  build, boot tests, Debian packaging and publication to GitHub Releases and OCI.
* The profiled runs used the same committed source. Each produced **1,200 process
  profiles**. Python startup and imports account for most measured work in the
  mock tests. These results do not measure PVE runtime or guest performance.
* The measured path-helper change reduced instruction counts by **14.4%**,
  allocated bytes by **8.5%** and allocated objects by **5.3%** in the same test
  workload. All path checks remain in place. See the [comparison][helper].
* The published Debian package and config matched their release asset digests.
  The config in the package matched the separate `kernel-config` asset. The
  packaged version file reports `6.12.113`, and all configuration checks pass.

The kernel extracted from the exact published package passed an isolated
QEMU/TCG boot test. Marked IPv4 and IPv6 UDP packets reached the selected TUN
routes. Legacy iptables/ip6tables packet counters confirmed `MARK`, mark match,
`CONNMARK` save/restore and connection-mark match operations.

The same boot passed plain/LZ4 EROFS mount and read-only checks. It also passed
Landlock ABI **6** tests as an unprivileged user, including restrictions inherited
through fork and exec. The previous 6.12.22 kernel failed the IPv6 policy-rule
operation with `Rule family not supported`.

## Test limits and cleanup

These tests do not cover an authenticated Tailscale session, DNS, access-control
rules, external-interface forwarding/NAT or every nftables backend. A normal
PVE-guest boot and application test are still required before fleet rollout.
Running guests keep their current kernel until an authorised restart.

Raw profiles, extracted test files, temporary build files and disposable logs
were deleted after analysis. Only concise results and intentional release assets
were kept. The new notes were reviewed for plain technical English and checked
for managed-infrastructure details. Public profiling labels omit host paths and
inline commands; a regression test checks that behaviour.

[Release v0.4.0][release] · [Configuration and test details][routing]

[issue]: https://github.com/rcarmo/pve-microvm/issues/23
[ci]: https://github.com/rcarmo/pve-microvm/actions/runs/39473852426
[release-ci]: https://github.com/rcarmo/pve-microvm/actions/runs/39473876769
[release]: https://github.com/rcarmo/pve-microvm/releases/tag/v0.4.0
[helper]: profiling/environment-helper.md
[routing]: policy-routing.md
