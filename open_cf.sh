#!/bin/bash
set -e

echo "======================================="
echo " Cloudflare Firewall ENABLE (Stable)"
echo "======================================="

IPSET_V4="cloudflare4"
IPSET_V6="cloudflare6"
CHAIN="CF_CLOUDFLARE"

# =========================
# 安装依赖
# =========================
apt-get update -y
apt-get install -y curl ipset iptables iptables-persistent

# =========================
# 创建 ipset
# =========================
ipset create ${IPSET_V4} hash:net family inet -exist
ipset create ${IPSET_V6} hash:net family inet6 -exist

ipset flush ${IPSET_V4}
ipset flush ${IPSET_V6}

# =========================
# 创建 / 更新 Cloudflare IP
# =========================
for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
    ipset add ${IPSET_V4} $ip -exist
done

for ip in $(curl -s https://www.cloudflare.com/ips-v6); do
    ipset add ${IPSET_V6} $ip -exist
done

# =========================
# 创建专用 chain（核心）
# =========================
iptables -N ${CHAIN} 2>/dev/null || true
iptables -F ${CHAIN}

ip6tables -N ${CHAIN} 2>/dev/null || true
ip6tables -F ${CHAIN}

# =========================
# 绑定 INPUT -> CF_CHAIN（只做一次）
# =========================
iptables -C INPUT -j ${CHAIN} 2>/dev/null || \
iptables -I INPUT 1 -j ${CHAIN}

ip6tables -C INPUT -j ${CHAIN} 2>/dev/null || \
ip6tables -I INPUT 1 -j ${CHAIN}

# =========================
# CF_CHAIN 规则（IPv4）
# =========================
iptables -A ${CHAIN} -p tcp --dport 80 -m set --match-set ${IPSET_V4} src -j RETURN
iptables -A ${CHAIN} -p tcp --dport 443 -m set --match-set ${IPSET_V4} src -j RETURN

iptables -A ${CHAIN} -p tcp --dport 80 -j DROP
iptables -A ${CHAIN} -p tcp --dport 443 -j DROP

# =========================
# CF_CHAIN 规则（IPv6）
# =========================
ip6tables -A ${CHAIN} -p tcp --dport 80 -m set --match-set ${IPSET_V6} src -j RETURN
ip6tables -A ${CHAIN} -p tcp --dport 443 -m set --match-set ${IPSET_V6} src -j RETURN

ip6tables -A ${CHAIN} -p tcp --dport 80 -j DROP
ip6tables -A ${CHAIN} -p tcp --dport 443 -j DROP

# =========================
# SSH 放行（直接 INPUT）
# =========================
iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || \
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# =========================
# 保存
# =========================
netfilter-persistent save

echo "Cloudflare ENABLE DONE"
