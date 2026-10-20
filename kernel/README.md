# pve-microvm guest kernel

`kernel/version` selects the default Linux release for `make kernel` and the
release CI source-cache key. The current development candidate is **6.12.113**,
an update within the existing 6.12 long-term series.

## Build inputs and outputs

The builder runs x86_64 `defconfig`, merges `pve-microvm-6.12.config`, merges
`pve-microvm-overlay.config`, then runs `olddefconfig`. The retained Firecracker
`base-x86_64-6.1.config` is a reference only. Editing it does not change the shipped
kernel. The effective generated config, rather than an input fragment alone,
determines available features.

After normalisation, the build verifies required virtio/networking settings and
runs `check-landlock.sh`, `check-erofs.sh` and `check-network.sh`. Required network
primitives must be built in: the shipped initrd does not include arbitrary
networking modules. The generated `kernel-config` accompanies release artifacts
and is packaged as `/usr/share/pve-microvm/kernel/build.config`.

Host downloads, compilation and temporary files use the project-owned scratch
resolver. By default on a local workspace, outputs are under
`/workspace/tmp/pve-microvm/build/kernel/`; CI and explicit overrides use the same
project hierarchy. See [development instructions](../docs/development.md).

## Supported boot path and checks

The normal guest boots with the shipped kernel **and initrd**. PVE's microVM
builder uses PCIe non-transitional virtio devices for Linux guests. The initrd
mounts the guest root filesystem and hands control to its init process.

Release CI boots the built kernel under isolated QEMU/TCG without disks or
network connections and checks:

* IPv4/IPv6 TUN policy rules and packet delivery selected by fwmark; real legacy
  iptables/ip6tables MARK and CONNMARK save/restore/match counters.
* Plain and LZ4-compressed EROFS mounting, data reads and read-only enforcement.
* Active Landlock selection, ABI 3+ and unprivileged write/truncate/rename
  confinement with fork/exec inheritance.

The tests do not establish full Tailscale connectivity, every filesystem codec,
or every supported guest distribution. Kernel upgrades also need a normal
PVE-guest canary before wider rollout. Running guests keep their existing kernel
until restarted; installation does not reboot them.

## Building

On a Debian/Ubuntu build host:

```sh
sudo apt install build-essential flex bison libelf-dev bc libssl-dev wget cpio busybox-static
make kernel
```

To test a different release while keeping outputs under project scratch:

```sh
bash tools/pve-microvm-env.sh --exec kernel bash kernel/build-kernel.sh --version 6.12.113
```

For the isolated boot gate, install `qemu-system-x86 erofs-utils iproute2 iptables`
and run:

```sh
bash tests/boot-landlock.sh /path/to/project/build/kernel/vmlinuz-microvm
```

Use `make deb` to package the staged kernel and initrd. Publish and validate an
intentional release through the project release workflow; do not replace kernel
files on managed hosts as part of ordinary local testing.

[Policy-routing implementation and upgrade assessment](../docs/policy-routing.md).
