#!/bin/bash

set -e

echo "======================================="
echo " Cloudflare Firewall Uninstall"
echo " Ubuntu Only"
echo "======================================="

IPSET_V4="cloudflare4"
IPSET_V6="cloudflare6"

SCRIPT_PATH="/usr/local/bin/cf-firewall-update.sh"

# =========================
# 停止 systemd timer
# =========================

systemctl stop cf-firewall-update.timer 2>/dev/null || true
systemctl disable cf-firewall-update.timer 2>/dev/null || true

# =========================
# 删除 systemd 文件
# =========================

rm -f /etc/systemd/system/cf-firewall-update.service
rm -f /etc/systemd/system/cf-firewall-update.timer

systemctl daemon-reload

# =========================
# 删除 IPv4 规则
# =========================

while iptables -C INPUT -p tcp --dport 80 -m set --match-set ${IPSET_V4} src -j ACCEPT 2>/dev/null
do
    iptables -D INPUT -p tcp --dport 80 -m set --match-set ${IPSET_V4} src -j ACCEPT
done

while iptables -C INPUT -p tcp --dport 80 -j DROP 2>/dev/null
do
    iptables -D INPUT -p tcp --dport 80 -j DROP
done

while iptables -C INPUT -p tcp --dport 443 -m set --match-set ${IPSET_V4} src -j ACCEPT 2>/dev/null
do
    iptables -D INPUT -p tcp --dport 443 -m set --match-set ${IPSET_V4} src -j ACCEPT
done

while iptables -C INPUT -p tcp --dport 443 -j DROP 2>/dev/null
do
    iptables -D INPUT -p tcp --dport 443 -j DROP
done

# =========================
# 删除 IPv6 规则
# =========================

while ip6tables -C INPUT -p tcp --dport 80 -m set --match-set ${IPSET_V6} src -j ACCEPT 2>/dev/null
do
    ip6tables -D INPUT -p tcp --dport 80 -m set --match-set ${IPSET_V6} src -j ACCEPT
done

while ip6tables -C INPUT -p tcp --dport 80 -j DROP 2>/dev/null
do
    ip6tables -D INPUT -p tcp --dport 80 -j DROP
done

while ip6tables -C INPUT -p tcp --dport 443 -m set --match-set ${IPSET_V6} src -j ACCEPT 2>/dev/null
do
    ip6tables -D INPUT -p tcp --dport 443 -m set --match-set ${IPSET_V6} src -j ACCEPT
done

while ip6tables -C INPUT -p tcp --dport 443 -j DROP 2>/dev/null
do
    ip6tables -D INPUT -p tcp --dport 443 -j DROP
done

# =========================
# 删除 ipset
# =========================

ipset destroy ${IPSET_V4} 2>/dev/null || true
ipset destroy ${IPSET_V6} 2>/dev/null || true

# =========================
# 删除更新脚本
# =========================

rm -f $SCRIPT_PATH

# =========================
# 保存规则
# =========================

netfilter-persistent save

echo "======================================="
echo " Cloudflare Firewall 已取消"
echo "======================================="
echo ""
echo " 当前状态："
echo " - 所有 IP 可正常访问 80/443"
echo " - Cloudflare 限制已移除"
echo " - 自动更新已关闭"
echo ""
echo "======================================="
