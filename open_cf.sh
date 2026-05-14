#!/bin/bash

set -e

echo "======================================="
echo " Cloudflare Firewall Auto Installer"
echo " Ubuntu Only"
echo "======================================="

# =========================
# 配置
# =========================

SSH_PORT="22"

CF_IPV4_URL="https://www.cloudflare.com/ips-v4"
CF_IPV6_URL="https://www.cloudflare.com/ips-v6"

IPSET_V4="cloudflare4"
IPSET_V6="cloudflare6"

SCRIPT_PATH="/usr/local/bin/cf-firewall-update.sh"

# =========================
# 安装依赖
# =========================

apt-get update -y
apt-get install -y curl ipset iptables iptables-persistent

# =========================
# 创建更新脚本
# =========================

cat > $SCRIPT_PATH << 'EOF'
#!/bin/bash

set -e

IPSET_V4="cloudflare4"
IPSET_V6="cloudflare6"

# 创建 ipset
ipset create ${IPSET_V4} hash:net family inet -exist
ipset create ${IPSET_V6} hash:net family inet6 -exist

# 清空旧数据
ipset flush ${IPSET_V4}
ipset flush ${IPSET_V6}

# 拉取 Cloudflare IP
CF_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)
CF_IPV6=$(curl -s https://www.cloudflare.com/ips-v6)

# IPv4
for ip in $CF_IPV4
do
    ipset add ${IPSET_V4} $ip -exist
done

# IPv6
for ip in $CF_IPV6
do
    ipset add ${IPSET_V6} $ip -exist
done

echo "Cloudflare IP Updated"
EOF

chmod +x $SCRIPT_PATH

# =========================
# 首次执行更新
# =========================

bash $SCRIPT_PATH

# =========================
# 放行 SSH
# =========================

iptables -C INPUT -p tcp --dport ${SSH_PORT} -j ACCEPT 2>/dev/null || \
iptables -A INPUT -p tcp --dport ${SSH_PORT} -j ACCEPT

# =========================
# 放行已建立连接
# =========================

iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# =========================
# 80 端口
# =========================

iptables -C INPUT -p tcp --dport 80 -m set --match-set ${IPSET_V4} src -j ACCEPT 2>/dev/null || \
iptables -A INPUT -p tcp --dport 80 -m set --match-set ${IPSET_V4} src -j ACCEPT

iptables -C INPUT -p tcp --dport 80 -j DROP 2>/dev/null || \
iptables -A INPUT -p tcp --dport 80 -j DROP

# =========================
# 443 端口
# =========================

iptables -C INPUT -p tcp --dport 443 -m set --match-set ${IPSET_V4} src -j ACCEPT 2>/dev/null || \
iptables -A INPUT -p tcp --dport 443 -m set --match-set ${IPSET_V4} src -j ACCEPT

iptables -C INPUT -p tcp --dport 443 -j DROP 2>/dev/null || \
iptables -A INPUT -p tcp --dport 443 -j DROP

# =========================
# IPv6
# =========================

ip6tables -C INPUT -p tcp --dport 80 -m set --match-set ${IPSET_V6} src -j ACCEPT 2>/dev/null || \
ip6tables -A INPUT -p tcp --dport 80 -m set --match-set ${IPSET_V6} src -j ACCEPT

ip6tables -C INPUT -p tcp --dport 80 -j DROP 2>/dev/null || \
ip6tables -A INPUT -p tcp --dport 80 -j DROP

ip6tables -C INPUT -p tcp --dport 443 -m set --match-set ${IPSET_V6} src -j ACCEPT 2>/dev/null || \
ip6tables -A INPUT -p tcp --dport 443 -m set --match-set ${IPSET_V6} src -j ACCEPT

ip6tables -C INPUT -p tcp --dport 443 -j DROP 2>/dev/null || \
ip6tables -A INPUT -p tcp --dport 443 -j DROP

# =========================
# 保存规则
# =========================

netfilter-persistent save

# =========================
# 创建 systemd service
# =========================

cat > /etc/systemd/system/cf-firewall-update.service << EOF
[Unit]
Description=Update Cloudflare Firewall IPs

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOF

# =========================
# 创建 systemd timer
# =========================

cat > /etc/systemd/system/cf-firewall-update.timer << EOF
[Unit]
Description=Run Cloudflare Firewall Update every 6 hours

[Timer]
OnBootSec=1min
OnUnitActiveSec=6h
Unit=cf-firewall-update.service

[Install]
WantedBy=timers.target
EOF

# =========================
# 启动 timer
# =========================

systemctl daemon-reload
systemctl enable cf-firewall-update.timer
systemctl start cf-firewall-update.timer

echo "======================================="
echo " 安装完成"
echo "======================================="
echo ""
echo " 已开启："
echo " - 仅允许 Cloudflare 访问 80/443"
echo " - SSH 保持开放"
echo " - 自动同步 Cloudflare IP"
echo " - 开机自动启动"
echo ""
echo " systemd timer:"
echo " cf-firewall-update.timer"
echo ""
echo " 查看状态："
echo " systemctl status cf-firewall-update.timer"
echo ""
echo "======================================="
