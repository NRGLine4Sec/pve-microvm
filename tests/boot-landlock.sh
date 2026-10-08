#!/bin/bash
# Boot the built kernel under TCG with an isolated initramfs, no disks/network.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/tools/pve-microvm-env.sh"
pve_microvm_env landlock-boot
kernel=${1:-$PVE_MICROVM_KERNEL_DIR/vmlinuz-microvm}
work=$(mktemp -d "$PVE_MICROVM_RUN_DIR/smoke.XXXXXX")
trap 'rm -rf "$work"' EXIT
for tool in cc cpio qemu-system-x86_64 busybox mkfs.erofs; do command -v "$tool" >/dev/null; done
file "$(command -v busybox)" | grep -q 'statically linked' || { echo 'busybox-static required'; exit 1; }
mkdir -p "$work/root"/{bin,etc,proc,sys,dev,tmp} "$work/erofs-source"
printf 'EROFS boot smoke\n' > "$work/erofs-source/marker"
# Force compressed data blocks, rather than testing only inline/uncompressed data.
awk 'BEGIN { for (i = 0; i < 4096; i++) print "EROFS compressed data block" }' > "$work/erofs-source/payload"
mkfs.erofs "$work/root/erofs-plain.img" "$work/erofs-source" > "$work/mkfs.log" 2>&1
mkfs.erofs -zlz4hc "$work/root/erofs-lz4.img" "$work/erofs-source" >> "$work/mkfs.log" 2>&1
cp "$work/erofs-source/payload" "$work/root/expected-payload"
cc -O2 -static -Wall -Wextra -Werror "$ROOT/tests/landlock-smoke.c" -o "$work/root/bin/landlock-smoke"
cp "$(command -v busybox)" "$work/root/bin/busybox"
for cmd in sh mount umount mkdir chown chmod cat grep cmp su env poweroff; do ln -s busybox "$work/root/bin/$cmd"; done
printf 'root:x:0:0:root:/:/bin/sh\nnobody:x:65534:65534:nobody:/:/bin/sh\n' > "$work/root/etc/passwd"
printf 'root:x:0:\nnogroup:x:65534:\n' > "$work/root/etc/group"
cat > "$work/root/init" <<'INIT'
#!/bin/sh
export PATH=/bin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /tmp
mkdir -p /mnt/erofs
for image in /erofs-plain.img /erofs-lz4.img; do
    mount -t erofs -o loop,ro "$image" /mnt/erofs || { echo EROFS_SMOKE_FAIL; poweroff -f; }
    grep -q 'EROFS boot smoke' /mnt/erofs/marker || { echo EROFS_SMOKE_FAIL; poweroff -f; }
    cmp /expected-payload /mnt/erofs/payload || { echo EROFS_SMOKE_FAIL; poweroff -f; }
    # Read-only filesystem must reject modification, even as root.
    if echo forbidden > /mnt/erofs/write 2>/dev/null; then echo EROFS_SMOKE_FAIL; poweroff -f; fi
    umount /mnt/erofs || { echo EROFS_SMOKE_FAIL; poweroff -f; }
done
echo EROFS_SMOKE_PASS
mkdir -p /sys/kernel/security
mount -t securityfs securityfs /sys/kernel/security || { echo LANDLOCK_SMOKE_FAIL; poweroff -f; }
cat /sys/kernel/security/lsm
grep -qw landlock /sys/kernel/security/lsm || { echo LANDLOCK_SMOKE_FAIL; poweroff -f; }
mkdir -p /tmp/pve-microvm/runs/guest-smoke
chown -R 65534:65534 /tmp/pve-microvm
su nobody -s /bin/sh -c 'TMPDIR=/tmp/pve-microvm/runs/guest-smoke /bin/landlock-smoke'
rc=$?
if [ "$rc" = 0 ]; then echo LANDLOCK_SMOKE_PASS; else echo LANDLOCK_SMOKE_FAIL; fi
poweroff -f
INIT
chmod 755 "$work/root/init"
(cd "$work/root" && find . -print0 | cpio --null -o -H newc 2>/dev/null | gzip -1) > "$work/smoke-initrd"
# Run without KVM privileges so hosted CI can exercise the actual syscalls.
if ! timeout 120 qemu-system-x86_64 -machine microvm,accel=tcg -m 256 \
    -nodefaults -no-user-config -nographic -serial stdio -no-reboot \
    -kernel "$kernel" -initrd "$work/smoke-initrd" \
    -append 'rdinit=/init console=ttyS0 panic=-1' > "$work/serial.log" 2>&1; then
    cat "$work/serial.log"; exit 1
fi
cat "$work/serial.log"
grep -q '^LANDLOCK_SMOKE_PASS' "$work/serial.log"
grep -q '^EROFS_SMOKE_PASS' "$work/serial.log"
! grep -q 'EROFS_SMOKE_FAIL' "$work/serial.log"
! grep -q 'LANDLOCK_SMOKE_FAIL' "$work/serial.log"
