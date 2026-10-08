# v0.3.28

The shipped Linux 6.12.22 kernel now enables built-in **EROFS**, including LZ4,
DEFLATE and ZSTD decompression. AgentsInTheCloud's current Docker installer
requires EROFS alongside OverlayFS; the previous kernel had OverlayFS but no
EROFS support. This release supplies that kernel prerequisite. Installation
still depends on the application's CPU, memory and other runtime requirements.

The build validates these options after `olddefconfig`. Release CI boots the
built kernel under isolated QEMU/TCG and mounts plain and LZ4-compressed EROFS
images, checks their contents and rejects attempted writes. The existing
unprivileged Landlock ABI/confinement test runs in the same boot gate. DEFLATE
and ZSTD are configuration-verified; their image codecs are not runtime-tested
by this gate.

The kernel and initrd version remains **6.12.22**; use the published effective
`kernel-config` or package version **0.3.28-1** to identify this build.

**Running guests keep their old kernel until restarted.** Host installation
updates the shipped kernel/initrd for future starts; no workloads are rebooted
by the package. Custom kernel paths need separate updates.
