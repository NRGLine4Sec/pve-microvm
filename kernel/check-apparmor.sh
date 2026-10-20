#!/bin/bash
# Verify built-in AppArmor and its boot-time selection after olddefconfig.
set -euo pipefail
config=${1:?Usage: check-apparmor.sh CONFIG}
for setting in CONFIG_SECURITY=y CONFIG_SECURITYFS=y CONFIG_AUDIT=y CONFIG_SECURITY_APPARMOR=y; do
    grep -qxF "$setting" "$config" || { echo "ERROR: required $setting missing" >&2; exit 1; }
done
lsms=$(sed -n 's/^CONFIG_LSM="\([^"]*\)"$/\1/p' "$config")
for lsm in landlock selinux apparmor bpf; do
    case ",$lsms," in
        *",$lsm,"*) ;;
        *) echo "ERROR: $lsm missing from effective CONFIG_LSM" >&2; exit 1 ;;
    esac
done
grep -qxF '# CONFIG_SECURITY_APPARMOR_BOOTPARAM_VALUE is not set' "$config" \
    && { echo 'ERROR: AppArmor disabled by default' >&2; exit 1; }
# Both are exclusive major LSMs in 6.12. AppArmor must precede SELinux
# for Docker confinement to be active without a boot command-line override.
case ",$lsms," in
    *,apparmor,*,selinux,*|*,apparmor,selinux,*) ;;
    *) echo 'ERROR: AppArmor must precede SELinux in CONFIG_LSM' >&2; exit 1 ;;
esac
echo 'AppArmor built-in and selected before SELinux; Landlock/BPF preserved'
