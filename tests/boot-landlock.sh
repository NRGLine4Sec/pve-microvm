#!/bin/bash
# Boot the built kernel under TCG with an isolated initramfs, no disks/network.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/tools/pve-microvm-env.sh"
pve_microvm_env landlock-boot
export PATH="$PATH:/usr/sbin:/sbin"
kernel=${1:-$PVE_MICROVM_KERNEL_DIR/vmlinuz-microvm}
work=$(mktemp -d "$PVE_MICROVM_RUN_DIR/smoke.XXXXXX")
trap 'rm -rf "$work"' EXIT
for tool in cc cpio qemu-system-x86_64 busybox mkfs.erofs ip iptables-legacy ip6tables-legacy apparmor_parser aa-exec ldd; do command -v "$tool" >/dev/null; done
file "$(command -v busybox)" | grep -q 'statically linked' || { echo 'busybox-static required'; exit 1; }
mkdir -p "$work/root"/{bin,etc,proc,sys,dev,tmp,run} "$work/erofs-source"
printf 'EROFS boot smoke\n' > "$work/erofs-source/marker"
# Force compressed data blocks, rather than testing only inline/uncompressed data.
awk 'BEGIN { for (i = 0; i < 4096; i++) print "EROFS compressed data block" }' > "$work/erofs-source/payload"
mkfs.erofs "$work/root/erofs-plain.img" "$work/erofs-source" > "$work/mkfs.log" 2>&1
mkfs.erofs -zlz4hc "$work/root/erofs-lz4.img" "$work/erofs-source" >> "$work/mkfs.log" 2>&1
cp "$work/erofs-source/payload" "$work/root/expected-payload"
cc -O2 -static -Wall -Wextra -Werror "$ROOT/tests/landlock-smoke.c" -o "$work/root/bin/landlock-smoke"
cp "$(command -v busybox)" "$work/root/bin/busybox"
cc -O2 -static -Wall -Wextra -Werror "$ROOT/tests/network-smoke.c" -o "$work/root/bin/network-smoke"
cp "$ROOT/tests/network-smoke.sh" "$work/root/bin/network-smoke.sh"
# iproute2 and legacy xtables are dynamic binaries. Copy their resolved shared
# libraries plus extension plugins into this disposable initramfs.
copy_binary() {
    local binary=$1 library
    mkdir -p "$work/root$(dirname "$binary")"
    cp -L "$binary" "$work/root$binary"
    while read -r library; do
        mkdir -p "$work/root$(dirname "$library")"
        cp -L "$library" "$work/root$library"
    done < <(ldd "$binary" | awk '{for(i=1;i<=NF;i++) if ($i ~ /^\//) print $i}')
}
copy_binary "$(readlink -f "$(command -v ip)")"
copy_binary "$(readlink -f "$(command -v iptables-legacy)")"
copy_binary "$(readlink -f "$(command -v apparmor_parser)")"
copy_binary "$(readlink -f "$(command -v aa-exec)")"
cc -O2 -static -Wall -Wextra -Werror "$ROOT/tests/apparmor-smoke.c" -o "$work/root/bin/apparmor-smoke"
mkdir -p "$work/root/etc/apparmor.d/abi"
cp /etc/apparmor.d/abi/4.0 "$work/root/etc/apparmor.d/abi/"
cp "$ROOT/tests/apparmor-smoke.profile" "$work/root/etc/apparmor.d/microvm-smoke"
ln -sf "$(readlink -f "$(command -v apparmor_parser)")" "$work/root/bin/apparmor_parser"
ln -sf "$(readlink -f "$(command -v aa-exec)")" "$work/root/bin/aa-exec"
# Use a non-applet name so BusyBox standalone-shell optimisation cannot
# substitute its limited ip applet for the copied iproute2 binary.
ln -s "$(readlink -f "$(command -v ip)")" "$work/root/bin/iproute2"
for name in iptables-legacy ip6tables-legacy; do
    ln -sf "$(readlink -f "$(command -v "$name")")" "$work/root/bin/$name"
done
# Plugins may have dependencies beyond the main xtables binary.
xtables_dir=$(dirname "$(find /usr/lib -name libxt_MARK.so -print -quit)")
[ -n "$xtables_dir" ] && [ -f "$xtables_dir/libxt_MARK.so" ]
for plugin in "$xtables_dir"/libxt_{mark,connmark,MARK,CONNMARK,udp,standard}.so; do
    copy_binary "$plugin"
done
# Debian /usr-merge: the loader and copied ELF dependencies must resolve at
# both /lib and /usr/lib paths, independently of the host's symlink layout.
if [ -d "$work/root/lib" ]; then mkdir -p "$work/root/usr/lib"; cp -a "$work/root/lib/." "$work/root/usr/lib/"; fi
for cmd in sh mount umount mkdir chown chmod cat grep cmp su env poweroff mknod awk tee touch; do ln -s busybox "$work/root/bin/$cmd"; done
printf 'root:x:0:0:root:/:/bin/sh\nnobody:x:65534:65534:nobody:/:/bin/sh\n' > "$work/root/etc/passwd"
printf 'root:x:0:\nnogroup:x:65534:\n' > "$work/root/etc/group"
cat > "$work/root/init" <<'INIT'
#!/bin/sh
export PATH=/bin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /tmp
export PATH=/bin:/usr/bin:/sbin:/usr/sbin
/bin/sh /bin/network-smoke.sh || { echo POLICY_ROUTING_SMOKE_FAIL; poweroff -f; }
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
grep -qw apparmor /sys/kernel/security/lsm || { echo APPARMOR_SMOKE_FAIL; poweroff -f; }
# Load an enforcing profile and test actual writes, not only feature presence.
touch /tmp/aa-allowed /tmp/aa-denied
printf 'original\n' > /tmp/aa-denied
apparmor_parser -K -r /etc/apparmor.d/microvm-smoke || { echo APPARMOR_SMOKE_FAIL; poweroff -f; }
aa-exec -p microvm-smoke -- /bin/apparmor-smoke || { echo APPARMOR_SMOKE_FAIL; poweroff -f; }
grep -qx original /tmp/aa-denied || { echo APPARMOR_SMOKE_FAIL; poweroff -f; }
echo APPARMOR_SMOKE_PASS
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
grep -q '^APPARMOR_SMOKE_PASS' "$work/serial.log"
! grep -q 'APPARMOR_SMOKE_FAIL' "$work/serial.log"
grep -q '^POLICY_ROUTING_SMOKE_PASS' "$work/serial.log"
! grep -q 'POLICY_ROUTING_SMOKE_FAIL' "$work/serial.log"
grep -q '^EROFS_SMOKE_PASS' "$work/serial.log"
! grep -q 'EROFS_SMOKE_FAIL' "$work/serial.log"
! grep -q 'LANDLOCK_SMOKE_FAIL' "$work/serial.log"
