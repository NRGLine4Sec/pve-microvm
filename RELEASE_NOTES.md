# v0.4.1

The Linux 6.12.113 guest kernel now includes **AppArmor** for Docker's
`docker-default` profile. A build check requires AppArmor, securityfs and audit
support and verifies the default LSM selection. The boot test loads an enforcing
profile, allows a write to one file and requires a denied write to fail.

**AppArmor is now the default major LSM.** Linux 6.12 treats AppArmor and SELinux
as exclusive major LSMs. AppArmor is listed first; Landlock and BPF stay active.
SELinux remains compiled in for an explicit `lsm=` boot choice. Workloads that
require SELinux must select and validate that choice before restarting.

Standard templates now include udev and match only guest uplinks (`eth*` and
`en*`) in their network rules. The old all-Ethernet match could configure Docker
veth devices and detach them from the Docker bridge, breaking container access.
Existing guest network files are not rewritten by host package installation.

The local suite passes **95/95**. The isolated boot test loads an enforcing
AppArmor profile and checks allowed and denied writes. Existing routing/mark,
EROFS and Landlock tests still pass. A disposable Debian guest also passes Docker
container, bridge/DNS/HTTPS, published-port and persistent-volume restart tests.
The container uses `docker-default (enforce)`; a mount permitted by an
unconfined control is denied under that profile. See [Docker setup and test
limits](docs/docker.md).

**Running guests keep their kernel until restarted.** Package installation does
not restart guests or change custom kernel paths. Preserve any required security
settings when moving a guest from a custom kernel.
