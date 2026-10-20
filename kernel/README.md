# pve-microvm guest kernel

`kernel/version` selects the default kernel for `make kernel` and the release
CI source-cache key. Version 0.4.0 uses **Linux 6.12.113** from the 6.12 long-term
support series.

## Build inputs and outputs

The builder starts with x86_64 `defconfig`. It merges
`pve-microvm-6.12.config` and `pve-microvm-overlay.config`, then runs
`olddefconfig` to resolve dependencies. The retained Firecracker
`base-x86_64-6.1.config` is a reference. Editing it does not change the shipped
kernel.

The build checks the final config for required virtio and networking features.
It also runs `check-landlock.sh`, `check-erofs.sh` and `check-network.sh`.
Required network features must be built in because the shipped initrd does not
include arbitrary networking modules. The release includes `kernel-config`;
the package installs it as `/usr/share/pve-microvm/kernel/build.config`.

Downloads, build files and temporary files use the project scratch directory.
The default local output directory is
`/workspace/tmp/pve-microvm/build/kernel/`. CI and explicit overrides use the
same directory layout. See [development instructions][development].

## Boot checks

A normal guest boots with the shipped kernel and initrd. For Linux guests, the
PVE command builder uses PCIe non-transitional virtio devices. The initrd mounts
the guest root filesystem and starts its init process.

Release CI boots the kernel with QEMU software CPU emulation (TCG). The test has
no attached disks or network connections. Inside the guest, it checks:

* IPv4/IPv6 TUN routing selected by packet marks. Real packets must also increase
  legacy iptables/ip6tables `MARK` and `CONNMARK` save/restore/match counters.
* Plain and LZ4-compressed EROFS mounts, data reads and rejected writes.
* Active Landlock, ABI 3 or later, and unprivileged filesystem restrictions that
  survive fork and exec.

The tests do not cover full Tailscale connectivity, all filesystem codecs or all
guest distributions. Deployment needs a normal PVE-guest test before wider
rollout. Running guests keep their kernel until restarted. Package installation
does not restart them.

## Building

On a Debian/Ubuntu build host:

```sh
sudo apt install build-essential flex bison libelf-dev bc libssl-dev wget cpio busybox-static
make kernel
```

To select another version, run the builder through the project environment
helper. Outputs stay under project scratch:

```sh
bash tools/pve-microvm-env.sh --exec kernel bash kernel/build-kernel.sh --version 6.12.113
```

For the isolated boot test, install `qemu-system-x86 erofs-utils iproute2 iptables`
and run:

```sh
bash tests/boot-landlock.sh /path/to/project/build/kernel/vmlinuz-microvm
```

Use `make deb` to package the built kernel and initrd. Use the release workflow
to publish a release. Local testing must not replace files on managed hosts.

[Policy-routing tests and kernel update decision][routing]

[development]: ../docs/development.md
[routing]: ../docs/policy-routing.md
