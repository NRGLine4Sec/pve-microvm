# v0.4.0

This release updates the guest kernel from **Linux 6.12.22 to 6.12.113** within
the same long-term support series. It also fixes missing policy-routing and
firewall-mark support reported in [#23][issue].

A guest could create a TUN interface but fail to add IPv6 routing rules or use
packet and connection marks. The kernel now includes these features as built-in
code. The build checks the final configuration and fails if a required feature
is missing or available only as a module.

The boot test sends marked IPv4 and IPv6 UDP packets through selected TUN routes.
It also checks packet counters for legacy iptables/ip6tables `MARK` and
`CONNMARK` operations. The same test checks EROFS mounts and unprivileged
Landlock restrictions. The previous kernel fails the IPv6 routing-rule test;
the updated kernel passes. These tests do not cover an authenticated Tailscale
connection, DNS, access-control rules or all nftables backends.

`kernel/version` now sets the default kernel version and the CI source-cache
key. The release includes the final `kernel-config` file. Build documentation
now describes the active configuration inputs. The path helper also creates
its temporary and cache directories with one command after validating each path.

**Running guests keep their current kernel until restarted.** Package installation
updates files for future starts and does not reboot guests. Guests that use a
custom kernel path need a separate path update.

See [configuration, tests and the kernel update decision][routing].

[issue]: https://github.com/rcarmo/pve-microvm/issues/23
[routing]: docs/policy-routing.md
