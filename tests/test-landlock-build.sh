#!/bin/bash
# Local config and compiler checks; enforcement requires a booted guest.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/tools/pve-microvm-env.sh"
pve_microvm_env tests
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$ROOT/kernel/pve-microvm-overlay.config" "$work/config"
bash "$ROOT/kernel/check-landlock.sh" "$work/config"
for bad in 'CONFIG_SECURITY=y' 'CONFIG_SECURITY_LANDLOCK=y' 'CONFIG_SECURITYFS=y'; do
    grep -vFx "$bad" "$work/config" > "$work/bad"
    if bash "$ROOT/kernel/check-landlock.sh" "$work/bad"; then exit 1; fi
done
sed 's/landlock,/landlockish,/' "$work/config" > "$work/bad"
if bash "$ROOT/kernel/check-landlock.sh" "$work/bad"; then exit 1; fi
# Preserve required existing LSMs, fail on an override dropping either one.
for lsm in selinux bpf; do
    sed "s/$lsm/$lsm-disabled/" "$work/config" > "$work/bad"
    if bash "$ROOT/kernel/check-landlock.sh" "$work/bad"; then exit 1; fi
done
cc -O2 -Wall -Wextra -Werror "$ROOT/tests/landlock-smoke.c" -o "$work/landlock-smoke"
echo 'Landlock build guards and smoke-test compilation passed (guest runtime tested separately)'
