#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/tools/pve-microvm-env.sh"
pve_microvm_env tests
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Model a normalised config: duplicate overlay entries would not survive olddefconfig.
cat > "$work/config" <<'CONFIG'
CONFIG_TUN=y
CONFIG_INET=y
CONFIG_IPV6=y
CONFIG_IP_ADVANCED_ROUTER=y
CONFIG_IP_MULTIPLE_TABLES=y
CONFIG_IPV6_MULTIPLE_TABLES=y
CONFIG_NF_CONNTRACK=y
CONFIG_NF_CONNTRACK_MARK=y
CONFIG_NETFILTER_XTABLES=y
CONFIG_NETFILTER_XT_MARK=y
CONFIG_NETFILTER_XT_CONNMARK=y
CONFIG_IP_NF_IPTABLES=y
CONFIG_IP_NF_MANGLE=y
CONFIG_IP6_NF_IPTABLES=y
CONFIG_IP6_NF_MANGLE=y
CONFIG
bash "$ROOT/kernel/check-network.sh" "$work/config"
while read -r option; do
    grep -vFx "$option" "$work/config" > "$work/bad"
    if bash "$ROOT/kernel/check-network.sh" "$work/bad"; then exit 1; fi
    # Modules are insufficient: the initrd does not ship these modules.
    sed "s/^${option%=y}=y$/${option%=y}=m/" "$work/config" > "$work/bad"
    if bash "$ROOT/kernel/check-network.sh" "$work/bad"; then exit 1; fi
done < "$work/config"
for option in CONFIG_IP_MULTIPLE_TABLES CONFIG_IPV6_MULTIPLE_TABLES CONFIG_NF_CONNTRACK_MARK CONFIG_NETFILTER_XT_MARK CONFIG_NETFILTER_XT_CONNMARK; do
    grep -qxF "$option=y" "$ROOT/kernel/pve-microvm-overlay.config"
done
cc -O2 -Wall -Wextra -Werror "$ROOT/tests/network-smoke.c" -o "$work/network-smoke"
[[ "$(cat "$ROOT/kernel/version")" =~ ^6\.12\.[0-9]+$ ]]
grep -q 'check-network.sh.*\.config' "$ROOT/kernel/build-kernel.sh"
echo 'Routing/mark normalised-config guards and packet test compile passed'
