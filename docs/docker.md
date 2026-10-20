# Docker in microVM guests

Docker does not require AppArmor or SELinux to run. It needs kernel features
such as namespaces, cgroups, OverlayFS, virtual Ethernet devices and firewall
support. AppArmor and SELinux restrict what container processes can access.
A running container does not prove that either control is active.

## Which security control to use

Use **AppArmor for the standard Debian/Ubuntu guest setup**. Docker normally
applies its `docker-default` profile when the guest kernel supports AppArmor
and the guest has the required userspace tools.

SELinux is an alternative, commonly used on Fedora/RHEL. It needs SELinux
enabled in the guest, container policy packages, correct file labels and Docker
configuration. Compiling SELinux into the kernel alone does not provide that
setup.

Preserve the control that a workload already uses. A kernel change must not
silently remove AppArmor or SELinux protection. Docker's seccomp filter is a
separate control that restricts system calls; it does not replace either one.

## AppArmor from v0.4.1

The v0.4.1 configuration for Linux 6.12.113 builds in AppArmor and selects it by
default. The guest also needs AppArmor userspace tools, including
`apparmor_parser`. Install them before starting containers:

```sh
sudo apt install apparmor apparmor-utils
```

Linux 6.12 treats AppArmor and SELinux as exclusive major Linux Security Modules
(LSMs). Only one is active. The default LSM list places AppArmor before SELinux.
Landlock and BPF remain active with AppArmor. SELinux stays compiled in, but a
workload that needs it must select and validate an explicit `lsm=` boot option.
Keep every other required LSM in that option.

Check the active controls inside a guest:

```sh
mountpoint -q /sys/kernel/security || sudo mount -t securityfs securityfs /sys/kernel/security
cat /sys/kernel/security/lsm
docker info --format '{{json .SecurityOptions}}'
docker inspect --format '{{.AppArmorProfile}}' <container>
```

The active LSM list should include `apparmor`, and Docker's security options
should include `name=apparmor`. A container using the default profile should
report `docker-default` in `docker inspect`. Check the active label as well:

```sh
docker exec <container> cat /proc/self/attr/current
```

For an image with `cat` installed, the expected label is
`docker-default (enforce)`. A container with `apparmor=unconfined` does not use
that protection. A privileged container can also bypass normal Docker isolation;
it needs a separate security assessment.

## Guest networking

Standard templates match uplink names `eth*` and `en*`. They include udev so
systemd can initialise network devices. Network rules must not match every
Ethernet device: systemd-networkd can then manage Docker veth interfaces and
remove them from their bridge. That breaks container traffic even when the
kernel has the required drivers and firewall features.

The host package does not rewrite existing guest network files. Before changing
those files, preserve their static addresses, MAC matches, routes and DNS
settings. Apply only the interface-match correction needed for that guest.

## Validation

The boot gate requires AppArmor in the active LSM list. It loads an enforcing
profile, permits one file write and requires a second write to fail with
`EACCES`. The denied file must retain its original contents. Build tests reject
missing/modular AppArmor settings or an LSM list that selects SELinux first.

A disposable Debian guest also ran Docker with OverlayFS, memory/PID limits,
bridge networking, DNS, HTTPS access and a published TCP port. A persistent
volume and container restart policy worked after a cold boot. The container
reported `docker-default (enforce)`.

A mount test isolated AppArmor enforcement: the mount succeeded with
`CAP_SYS_ADMIN`, seccomp disabled and AppArmor explicitly disabled. With the
same capability/seccomp settings and `docker-default`, the mount was denied.
This verifies profile enforcement. It does not test every Docker feature or
establish that privileged workloads are safe.

## Upgrade behaviour

Installing the host package updates the shipped kernel/initrd for future starts.
Running guests keep their current kernel until restarted. Custom kernel paths
are not changed automatically. Preserve any required security settings and test
workloads before switching a guest from a custom kernel.

[Docker AppArmor documentation](https://docs.docker.com/engine/security/apparmor/)
