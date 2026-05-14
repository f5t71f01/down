#!/bin/bash
set -e

echo "======================================="
echo " Cloudflare Firewall DISABLE (Stable)"
echo "======================================="

IPSET_V4="cloudflare4"
IPSET_V6="cloudflare6"
CHAIN="CF_CLOUDFLARE"

# =========================
# 从 INPUT 移除 chain（关键）
# =========================
iptables -D INPUT -j ${CHAIN} 2>/dev/null || true
ip6tables -D INPUT -j ${CHAIN} 2>/dev/null || true

# =========================
# 删除 chain
# =========================
iptables -F ${CHAIN} 2>/dev/null || true
iptables -X ${CHAIN} 2>/dev/null || true

ip6tables -F ${CHAIN} 2>/dev/null || true
ip6tables -X ${CHAIN} 2>/dev/null || true

# =========================
# 删除 ipset
# =========================
ipset destroy ${IPSET_V4} 2>/dev/null || true
ipset destroy ${IPSET_V6} 2>/dev/null || true

# =========================
# 保存
# =========================
netfilter-persistent save

echo "Cloudflare DISABLE DONE"
