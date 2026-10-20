#!/bin/sh
# Run only in the disposable QEMU initramfs: changes routing and firewall state.
set -eu
iproute2 link set lo up
mkdir -p /dev/net
[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200
/bin/network-smoke --create-tun
iproute2 link set ts-smoke up
iproute2 addr add 100.64.0.1/32 dev ts-smoke
iproute2 -6 addr add fd7a:115c:a1e0::1/128 dev ts-smoke nodad
iproute2 -4 route add table 52 198.18.0.0/24 dev ts-smoke
iproute2 -6 route add table 52 fd00::/64 dev ts-smoke
iproute2 -4 rule add priority 1000 fwmark 0x80000/0xff0000 lookup 52
iproute2 -6 rule add priority 1000 fwmark 0x80000/0xff0000 lookup 52
iproute2 -4 route get 198.18.0.1 mark 0x80000 | grep -q 'dev ts-smoke'
iproute2 -6 route get fd00::1 mark 0x80000 | grep -q 'dev ts-smoke'
/bin/network-smoke --marked-routes

# Legacy xtables specifically exercises XT_MARK/XT_CONNMARK, rather than letting
# the host's alternatives silently select the separate nft translation backend.
for xt in iptables-legacy ip6tables-legacy; do
    "$xt" -t mangle -N ts-smoke
    "$xt" -t mangle -A OUTPUT -p udp -j ts-smoke
    "$xt" -t mangle -A ts-smoke -j MARK --set-xmark 0x80000/0xff0000
    "$xt" -t mangle -A ts-smoke -m mark --mark 0x80000/0xff0000 -j CONNMARK --save-mark
    "$xt" -t mangle -A ts-smoke -j MARK --set-xmark 0x0/0xff0000
    "$xt" -t mangle -A ts-smoke -j CONNMARK --restore-mark
    "$xt" -t mangle -A ts-smoke -m connmark --mark 0x80000/0xff0000 -m mark --mark 0x80000/0xff0000 -j ACCEPT
done
/bin/network-smoke --loopback
for xt in iptables-legacy ip6tables-legacy; do
    # The terminal rule can count packets only if marking and connmark
    # save/restore actually succeeded. Syntax acceptance alone is insufficient.
    "$xt" -t mangle -L ts-smoke -n -v -x | tee /tmp/mark-counters
    awk '$3 == "ACCEPT" && $1 > 0 { ok=1 } END { exit !ok }' /tmp/mark-counters
    "$xt" -t mangle -D OUTPUT -p udp -j ts-smoke
    "$xt" -t mangle -F ts-smoke
    "$xt" -t mangle -X ts-smoke
done
iproute2 -4 rule del priority 1000
iproute2 -6 rule del priority 1000
iproute2 link delete ts-smoke
printf 'POLICY_ROUTING_SMOKE_PASS\n'
