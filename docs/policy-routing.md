# TUN policy routing and firewall marks

The kernel overlay explicitly enables IPv4/IPv6 policy routing and connection
and packet marks for applications such as Tailscale in kernel/TUN mode (#23).
TUN creation alone does not establish that these routing/firewall primitives are
available.

## Build configuration

The builder starts with x86_64 `defconfig`, merges `pve-microvm-6.12.config` and
`pve-microvm-overlay.config`, then runs `olddefconfig`. The retained 6.1 reference
config is not a build input. `kernel/check-network.sh` checks the effective
config after normalisation and rejects missing or modular primitives: those
modules are not included in the shipped initrd.

The required overlay settings include:

```text
CONFIG_IP_ADVANCED_ROUTER=y
CONFIG_IP_MULTIPLE_TABLES=y
CONFIG_IPV6_MULTIPLE_TABLES=y
CONFIG_NF_CONNTRACK_MARK=y
CONFIG_NETFILTER_XT_MARK=y
CONFIG_NETFILTER_XT_CONNMARK=y
CONFIG_IP6_NF_MANGLE=y
```

The guard also verifies built-in TUN, IPv4/IPv6, conntrack, xtables and the
IPv4/IPv6 iptables/mangle tables. Inspect the shipped `kernel/build.config` to
check the effective package configuration.

## Runtime test

The isolated QEMU/TCG boot test attaches no disks or network interfaces. It
creates a TUN interface in the guest, installs IPv4 and IPv6 fwmark rules and
routes through a separate table, then sends marked UDP packets and reads them
from TUN. The fixture verifies their IP family, destination, protocol and
payload so neighbour-discovery traffic cannot satisfy the test.

Legacy iptables and ip6tables each install MARK, mark-match, CONNMARK save/restore
and connmark-match rules. Actual loopback packets must increment the final rule
counter after the mark is cleared and restored. This checks kernel enforcement,
not just userspace help or accepted command syntax. The test uses iproute2
explicitly because a BusyBox shell can substitute its limited `ip` applet.

The previous 6.12.22 build fails the IPv6 policy-rule operation with `Rule family
not supported`. The candidate 6.12.113 build passes all routing and counter checks,
as well as the existing EROFS and unprivileged Landlock boot tests. The local
suite passes 92 tests; a Debian package build using the candidate kernel passes.
These checks do not exercise an authenticated Tailscale connection, DNS, network
ACLs, forwarding/NAT across real interfaces or every nftables backend. Those
require separate application-level tests. No managed guest was changed for this
validation.

## Kernel update decision

The candidate moves from 6.12.22 to **6.12.113**, the latest kernel.org 6.12
long-term release listed on 2026-10-20 (released 2026-10-15). Staying on the 6.12
series retains the existing fragment and driver model while incorporating later
stable fixes; changing to another series would need broader compatibility work.
The version is centralised in `kernel/version`, consumed by the builder and CI
source-cache key. Installed kernel build tooling includes that file too.

The full candidate kernel and modules built successfully. The boot gate passes
policy routing, mark handling, plain/LZ4 EROFS and Landlock ABI 6 confinement.
This is development validation; the updated source has not been released or
fleet-deployed. A release still needs pre-release profiling and the complete
release pipeline, followed by a staged normal-guest boot and application check.
Existing running guests retain their current kernel until an authorised restart.

[Issue #23](https://github.com/rcarmo/pve-microvm/issues/23) ·
[kernel.org releases](https://www.kernel.org/releases.json)
