# TUN policy routing and firewall marks

The kernel includes IPv4/IPv6 policy routing and packet and connection marks for
applications such as Tailscale in TUN mode. Creating a TUN interface does not
check that these other features work.

Policy routing selects a route by a rule, such as a packet mark (`fwmark`).
A connection mark stores a value for packets that belong to the same tracked
connection. Tailscale can use these features to select routes and avoid loops.

## Build configuration

The builder starts with x86_64 `defconfig`. It merges `pve-microvm-6.12.config`
and `pve-microvm-overlay.config`, then runs `olddefconfig` to resolve kernel
configuration dependencies. The retained 6.1 reference config is not a build
input.

`kernel/check-network.sh` checks the final config. It rejects missing features
and features built as modules because the shipped initrd does not include those
modules. The overlay includes:

```text
CONFIG_IP_ADVANCED_ROUTER=y
CONFIG_IP_MULTIPLE_TABLES=y
CONFIG_IPV6_MULTIPLE_TABLES=y
CONFIG_NF_CONNTRACK_MARK=y
CONFIG_NETFILTER_XT_MARK=y
CONFIG_NETFILTER_XT_CONNMARK=y
CONFIG_IP6_NF_MANGLE=y
```

The check also requires built-in TUN, IPv4/IPv6, connection tracking, xtables and
IPv4/IPv6 iptables mangle tables. The installed package contains the final config
at `/usr/share/pve-microvm/kernel/build.config`.

## Runtime test

The QEMU boot test uses software CPU emulation (TCG). It has no attached disks
or network connections. Inside the guest, it creates a TUN interface and adds
IPv4 and IPv6 rules that select a separate routing table by packet mark. It
then sends marked UDP packets and reads them from TUN. The test checks the IP
family, destination, protocol and payload of each packet.

Legacy iptables and ip6tables each install `MARK`, mark-match, `CONNMARK`
save/restore and connection-mark-match rules. The test clears and restores a
mark, then requires packets to reach the last rule and increase its counter.
The test calls iproute2 by an explicit name to prevent BusyBox from substituting
its limited `ip` applet.

The previous 6.12.22 build fails the IPv6 rule operation with
`Rule family not supported`. The 6.12.113 build passes the routing and counter
checks. It also passes the EROFS mount/read-only tests and Landlock ABI 6
restriction tests. The local suite passes **93 tests**, and a Debian package
build with the updated kernel passes.

These checks do not cover an authenticated Tailscale connection, DNS,
access-control rules, forwarding/NAT through external interfaces or all nftables
backends. Those need application-level tests. No managed guest was changed for
this validation.

## Kernel update decision

Version 0.4.0 updates the kernel from 6.12.22 to **6.12.113**. On 2026-10-20,
kernel.org listed 6.12.113, released on 2026-10-15, as the latest 6.12 long-term
release. This update keeps the existing configuration fragment and driver model.
An update to another kernel series would need more compatibility testing.

`kernel/version` sets the default version for the builder and the CI source-cache
key. The installed kernel build tools include that file.

Release checks include CPU/allocation analysis and the complete release pipeline.
Application connectivity and deployment need separate validation. Running guests
keep their current kernel until an authorised restart.

[Issue #23][issue] · [kernel.org releases][kernels]

[issue]: https://github.com/rcarmo/pve-microvm/issues/23
[kernels]: https://www.kernel.org/releases.json
