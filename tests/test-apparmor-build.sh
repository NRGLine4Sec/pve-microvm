#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/tools/pve-microvm-env.sh"
pve_microvm_env tests
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$ROOT/kernel/pve-microvm-overlay.config" "$work/config"
bash "$ROOT/kernel/check-apparmor.sh" "$work/config"
for setting in CONFIG_SECURITY=y CONFIG_SECURITYFS=y CONFIG_AUDIT=y CONFIG_SECURITY_APPARMOR=y; do
    grep -vFx "$setting" "$work/config" > "$work/bad"
    if bash "$ROOT/kernel/check-apparmor.sh" "$work/bad"; then exit 1; fi
    sed "s/^${setting%=y}=y$/${setting%=y}=m/" "$work/config" > "$work/bad"
    if bash "$ROOT/kernel/check-apparmor.sh" "$work/bad"; then exit 1; fi
done
for lsm in apparmor landlock selinux bpf; do
    sed "s/$lsm/$lsm-disabled/g" "$work/config" > "$work/bad"
    if bash "$ROOT/kernel/check-apparmor.sh" "$work/bad"; then exit 1; fi
done
sed 's/apparmor,selinux/selinux,apparmor/' "$work/config" > "$work/bad"
if bash "$ROOT/kernel/check-apparmor.sh" "$work/bad"; then exit 1; fi
cc -O2 -Wall -Wextra -Werror "$ROOT/tests/apparmor-smoke.c" -o "$work/apparmor-smoke"
echo 'AppArmor build guards and enforcement test compile passed'
