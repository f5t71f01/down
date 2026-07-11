#!/bin/bash
set -euo pipefail

echo "======================================="
echo " Cloudflare Firewall DISABLE (Stable)"
echo "======================================="

IPSET_V4="cloudflare4"
IPSET_V6="cloudflare6"
TMP_V4="cloudflare4_new"
TMP_V6="cloudflare6_new"
CHAIN="CF_CLOUDFLARE"

UPDATER="/usr/local/sbin/update-cloudflare-ipset"
CRON_FILE="/etc/cron.d/cloudflare-ipset"
LOCK_FILE="/run/lock/cloudflare-ipset-update.lock"

# 先删除定时任务，阻止新的更新进程启动
rm -f "${CRON_FILE}"

# 等待已经运行的更新任务完成，避免并发删除 ipset
exec 9>"${LOCK_FILE}"
flock 9

# 从 INPUT 移除所有指向该 chain 的跳转
while iptables -C INPUT -j "${CHAIN}" 2>/dev/null; do
    iptables -D INPUT -j "${CHAIN}"
done

while ip6tables -C INPUT -j "${CHAIN}" 2>/dev/null; do
    ip6tables -D INPUT -j "${CHAIN}"
done

# 删除专用 chain
iptables -F "${CHAIN}" 2>/dev/null || true
iptables -X "${CHAIN}" 2>/dev/null || true

ip6tables -F "${CHAIN}" 2>/dev/null || true
ip6tables -X "${CHAIN}" 2>/dev/null || true

# 删除正式及可能残留的临时 ipset
ipset destroy "${IPSET_V4}" 2>/dev/null || true
ipset destroy "${IPSET_V6}" 2>/dev/null || true
ipset destroy "${TMP_V4}" 2>/dev/null || true
ipset destroy "${TMP_V6}" 2>/dev/null || true

# 删除自动更新脚本
rm -f "${UPDATER}"

# 保存当前状态，确保重启后不会恢复 Cloudflare 限制
netfilter-persistent save

echo "Cloudflare firewall disabled."
echo "Cron task and updater removed."
