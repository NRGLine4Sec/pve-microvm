#!/bin/bash
# Verify the effective post-olddefconfig config, not just the input overlay.
set -euo pipefail
config=${1:?Usage: check-landlock.sh CONFIG}
for setting in CONFIG_SECURITY=y CONFIG_SECURITY_LANDLOCK=y CONFIG_SECURITYFS=y; do
    grep -qxF "$setting" "$config" || { echo "ERROR: required $setting missing" >&2; exit 1; }
done
lsms=$(sed -n 's/^CONFIG_LSM="\([^"]*\)"$/\1/p' "$config")
for lsm in landlock selinux bpf; do
    case ",$lsms," in
        *",$lsm,"*) ;;
        *) echo "ERROR: $lsm missing from effective CONFIG_LSM" >&2; exit 1 ;;
    esac
done
printf 'Landlock built-in; CONFIG_LSM=%s\n' "$lsms"
