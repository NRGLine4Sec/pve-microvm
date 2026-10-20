#!/bin/bash
# Reject kernels missing the built-in routing/firewall primitives of TUN mode.
set -euo pipefail
config=${1:?Usage: check-network.sh CONFIG}
for option in CONFIG_TUN CONFIG_INET CONFIG_IPV6 CONFIG_IP_ADVANCED_ROUTER \
    CONFIG_IP_MULTIPLE_TABLES CONFIG_IPV6_MULTIPLE_TABLES CONFIG_NF_CONNTRACK \
    CONFIG_NF_CONNTRACK_MARK CONFIG_NETFILTER_XTABLES CONFIG_NETFILTER_XT_MARK \
    CONFIG_NETFILTER_XT_CONNMARK CONFIG_IP_NF_IPTABLES CONFIG_IP_NF_MANGLE \
    CONFIG_IP6_NF_IPTABLES CONFIG_IP6_NF_MANGLE; do
    grep -qxF "$option=y" "$config" || { echo "ERROR: required $option=y missing" >&2; exit 1; }
done
echo 'TUN, dual-stack policy routing and packet/connection marks built-in'
