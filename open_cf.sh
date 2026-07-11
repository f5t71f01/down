#!/bin/bash
set -euo pipefail

IPSET_V4="cloudflare4"
IPSET_V6="cloudflare6"
CHAIN="CF_CLOUDFLARE"
UPDATER="/usr/local/sbin/update-cloudflare-ipset"
CRON_FILE="/etc/cron.d/cloudflare-ipset"

echo "======================================="
echo " Cloudflare Firewall ENABLE (Stable)"
echo "======================================="

apt-get update -y
apt-get install -y curl ipset iptables iptables-persistent ipset-persistent

# 创建正式 ipset；规则始终只引用这两个名称
ipset create "${IPSET_V4}" hash:net family inet -exist
ipset create "${IPSET_V6}" hash:net family inet6 -exist

# 创建独立的 Cloudflare IP 更新脚本
cat > "${UPDATER}" <<'EOF'
#!/bin/bash
set -euo pipefail

IPSET_V4="cloudflare4"
IPSET_V6="cloudflare6"
TMP_V4="cloudflare4_new"
TMP_V6="cloudflare6_new"
LOCK_FILE="/run/lock/cloudflare-ipset-update.lock"

exec 9>"${LOCK_FILE}"
flock -n 9 || exit 0

FILE_V4="$(mktemp)"
FILE_V6="$(mktemp)"

cleanup() {
    rm -f "${FILE_V4}" "${FILE_V6}"
    ipset destroy "${TMP_V4}" 2>/dev/null || true
    ipset destroy "${TMP_V6}" 2>/dev/null || true
}
trap cleanup EXIT

# 先完整下载 IPv4 与 IPv6；任何一个失败都不改现有规则
curl --fail --silent --show-error --location \
    --connect-timeout 10 --max-time 60 --retry 3 \
    -o "${FILE_V4}" "https://www.cloudflare.com/ips-v4"

curl --fail --silent --show-error --location \
    --connect-timeout 10 --max-time 60 --retry 3 \
    -o "${FILE_V6}" "https://www.cloudflare.com/ips-v6"

# 下载内容不能为空
test -s "${FILE_V4}"
test -s "${FILE_V6}"

# 先构建临时集合。若某条 CIDR 无效，脚本退出，旧集合仍保持原样。
ipset destroy "${TMP_V4}" 2>/dev/null || true
ipset destroy "${TMP_V6}" 2>/dev/null || true

ipset create "${TMP_V4}" hash:net family inet maxelem 65536
ipset create "${TMP_V6}" hash:net family inet6 maxelem 65536

count_v4=0
while IFS= read -r cidr; do
    cidr="${cidr%$'\r'}"
    [ -z "${cidr}" ] && continue
    ipset add "${TMP_V4}" "${cidr}" -exist
    count_v4=$((count_v4 + 1))
done < "${FILE_V4}"

count_v6=0
while IFS= read -r cidr; do
    cidr="${cidr%$'\r'}"
    [ -z "${cidr}" ] && continue
    ipset add "${TMP_V6}" "${cidr}" -exist
    count_v6=$((count_v6 + 1))
done < "${FILE_V6}"

# 防止拿到异常的空列表后替换正式集合
[ "${count_v4}" -gt 0 ]
[ "${count_v6}" -gt 0 ]

ipset create "${IPSET_V4}" hash:net family inet -exist
ipset create "${IPSET_V6}" hash:net family inet6 -exist

# 原子交换：iptables 规则始终引用 cloudflare4/cloudflare6，
# 因此交换过程不会产生“空白窗口”。
ipset swap "${TMP_V4}" "${IPSET_V4}"
ipset swap "${TMP_V6}" "${IPSET_V6}"

# 保存 iptables 与 ipset，确保重启后仍有效
netfilter-persistent save

logger -t cloudflare-ipset \
    "Cloudflare IP updated: IPv4=${count_v4}, IPv6=${count_v6}"

echo "Cloudflare IP updated: IPv4=${count_v4}, IPv6=${count_v6}"
EOF

chmod 700 "${UPDATER}"

# 先立刻拉取并填充 IP 集合
"${UPDATER}"

# 每 6 小时的第 17 分钟更新一次
cat > "${CRON_FILE}" <<EOF
SHELL=/bin/bash
PATH=/usr/sbin:/usr/bin:/sbin:/bin
17 */6 * * * root ${UPDATER} >> /var/log/cloudflare-ipset-update.log 2>&1
EOF

chmod 644 "${CRON_FILE}"

# 创建 Cloudflare 专用链
iptables -N "${CHAIN}" 2>/dev/null || true
iptables -F "${CHAIN}"

ip6tables -N "${CHAIN}" 2>/dev/null || true
ip6tables -F "${CHAIN}"

# INPUT 只挂载一次
iptables -C INPUT -j "${CHAIN}" 2>/dev/null || \
    iptables -I INPUT 1 -j "${CHAIN}"

ip6tables -C INPUT -j "${CHAIN}" 2>/dev/null || \
    ip6tables -I INPUT 1 -j "${CHAIN}"

# IPv4：Cloudflare 明确 ACCEPT；其他来源访问 80/443 直接 DROP
iptables -A "${CHAIN}" -p tcp --dport 80 \
    -m set --match-set "${IPSET_V4}" src -j ACCEPT
iptables -A "${CHAIN}" -p tcp --dport 443 \
    -m set --match-set "${IPSET_V4}" src -j ACCEPT
iptables -A "${CHAIN}" -p tcp --dport 80 -j DROP
iptables -A "${CHAIN}" -p tcp --dport 443 -j DROP

# IPv6：同样限制
ip6tables -A "${CHAIN}" -p tcp --dport 80 \
    -m set --match-set "${IPSET_V6}" src -j ACCEPT
ip6tables -A "${CHAIN}" -p tcp --dport 443 \
    -m set --match-set "${IPSET_V6}" src -j ACCEPT
ip6tables -A "${CHAIN}" -p tcp --dport 80 -j DROP
ip6tables -A "${CHAIN}" -p tcp --dport 443 -j DROP

# SSH 与已建立连接放行（IPv4 / IPv6）
iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || \
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

ip6tables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || \
    ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT
ip6tables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

netfilter-persistent save

echo "Cloudflare firewall enabled."
echo "Auto-updater: ${UPDATER}"
echo "Cron schedule: every 6 hours"
