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

# 必须以 root 执行
if [ "${EUID}" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# =======================================
# 删除定时更新任务
# =======================================

# 删除 /etc/cron.d 中由启用脚本创建的任务
rm -f "${CRON_FILE}"

# 兼容：删除 root crontab 中手动添加的更新任务
CURRENT_CRON="$(crontab -l 2>/dev/null || true)"

if printf '%s\n' "${CURRENT_CRON}" | grep -Fq "${UPDATER}"; then
    printf '%s\n' "${CURRENT_CRON}" \
        | grep -Fv "${UPDATER}" \
        | crontab -
fi

# =======================================
# 等待正在运行的更新任务结束
# =======================================

exec 9>"${LOCK_FILE}"
flock 9

# =======================================
# 从 INPUT 移除跳转规则
# =======================================

# 循环删除，避免历史上有重复规则残留
while iptables -C INPUT -j "${CHAIN}" 2>/dev/null; do
    iptables -D INPUT -j "${CHAIN}"
done

while ip6tables -C INPUT -j "${CHAIN}" 2>/dev/null; do
    ip6tables -D INPUT -j "${CHAIN}"
done

# =======================================
# 删除 Cloudflare 专用 chain
# =======================================

iptables -F "${CHAIN}" 2>/dev/null || true
iptables -X "${CHAIN}" 2>/dev/null || true

ip6tables -F "${CHAIN}" 2>/dev/null || true
ip6tables -X "${CHAIN}" 2>/dev/null || true

# =======================================
# 删除正式 / 临时 ipset
# =======================================

ipset destroy "${IPSET_V4}" 2>/dev/null || true
ipset destroy "${IPSET_V6}" 2>/dev/null || true
ipset destroy "${TMP_V4}" 2>/dev/null || true
ipset destroy "${TMP_V6}" 2>/dev/null || true

# =======================================
# 删除更新脚本与锁文件
# =======================================

rm -f "${UPDATER}"
rm -f "${LOCK_FILE}"

# =======================================
# 持久化当前状态
# =======================================

netfilter-persistent save

echo "Cloudflare firewall disabled."
echo "Cron task, updater, chain, and ipsets removed."
