# Docker in microVM guests

Docker can run without AppArmor or SELinux. It needs kernel features such as
namespaces, cgroups, OverlayFS, virtual Ethernet devices and firewall support.
AppArmor and SELinux add security controls. Removing an active control can let
containers run with less protection.

## AppArmor from v0.4.1

The shipped Linux 6.12.113 kernel includes AppArmor and selects it by default.
Docker on Debian/Ubuntu can then apply its `docker-default` profile. The guest
also needs AppArmor userspace tools, including `apparmor_parser`. Install them
before starting containers:

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

A container using the default AppArmor profile should report `docker-default`.
A container with `apparmor=unconfined` does not use that protection. A privileged
container can also bypass normal Docker isolation; it needs a separate security
assessment.

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
