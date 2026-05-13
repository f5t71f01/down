#!/bin/bash

set -e

echo "======================================="
echo " Ubuntu 22.04 Root SSH Key Installer"
echo "======================================="

# =========================
# 配置（只修改这里）
# =========================

SSH_PORT="7796"

# 是否关闭22端口
DISABLE_22="yes"

# =========================

if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 运行"
    exit 1
fi

# =========================
# 检查系统
# =========================

if ! grep -q "22.04" /etc/os-release; then
    echo "警告：当前系统可能不是 Ubuntu 22.04"
fi

echo ""
echo "当前SSH端口: $SSH_PORT"
echo ""

# =========================
# 停止自动更新（防 apt lock）
# =========================

systemctl stop unattended-upgrades 2>/dev/null || true
systemctl stop apt-daily.service 2>/dev/null || true
systemctl stop apt-daily-upgrade.service 2>/dev/null || true

killall apt apt-get dpkg 2>/dev/null || true

rm -f /var/lib/dpkg/lock-frontend
rm -f /var/lib/dpkg/lock
rm -f /var/cache/apt/archives/lock

dpkg --configure -a || true

sleep 2

# =========================
# 更新软件源
# =========================

apt update

# =========================
# 安装 openssh-server
# 自动保留本地 sshd_config
# =========================

if ! dpkg -s openssh-server >/dev/null 2>&1; then

    DEBIAN_FRONTEND=noninteractive apt install -y \
    -o Dpkg::Options::="--force-confold" \
    openssh-server

fi

# =========================
# 安装 ufw
# =========================

if ! dpkg -s ufw >/dev/null 2>&1; then

    DEBIAN_FRONTEND=noninteractive apt install -y ufw

fi

# =========================
# 创建 SSH 目录
# =========================

mkdir -p /root/.ssh
chmod 700 /root/.ssh

# =========================
# 输入公钥
# =========================

echo ""
echo "请粘贴 SSH 公钥："
echo "（ssh-ed25519 开头）"
echo ""

read PUBKEY

# 防止重复添加
grep -qxF "$PUBKEY" /root/.ssh/authorized_keys 2>/dev/null || \
echo "$PUBKEY" >> /root/.ssh/authorized_keys

chmod 600 /root/.ssh/authorized_keys

# =========================
# 备份 SSH 配置
# =========================

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%s)

# =========================
# 删除旧配置
# =========================

sed -i '/^Port /d' /etc/ssh/sshd_config
sed -i '/^PasswordAuthentication /d' /etc/ssh/sshd_config
sed -i '/^PubkeyAuthentication /d' /etc/ssh/sshd_config
sed -i '/^PermitRootLogin /d' /etc/ssh/sshd_config

# =========================
# 写入新配置
# =========================

cat >> /etc/ssh/sshd_config <<EOF

# Custom SSH Config
Port ${SSH_PORT}
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
EOF

# =========================
# 检查 SSH 配置
# =========================

sshd -t

if [ $? -ne 0 ]; then

    echo ""
    echo "SSH配置错误"
    echo "已终止"
    exit 1

fi

# =========================
# 防火墙
# =========================

ufw allow ${SSH_PORT}/tcp

if [ "$DISABLE_22" = "yes" ]; then

    ufw delete allow 22/tcp 2>/dev/null || true

fi

ufw --force enable

# =========================
# 重启 SSH
# =========================

systemctl restart ssh

# =========================
# 完成
# =========================

echo ""
echo "======================================="
echo " 配置完成"
echo "======================================="
echo ""

echo "SSH端口: ${SSH_PORT}"
echo "Root登录: 已开启（仅允许密钥）"
echo "密码登录: 已关闭"

if [ "$DISABLE_22" = "yes" ]; then
    echo "22端口: 已关闭"
fi

echo ""
echo "连接命令："
echo ""
echo "ssh -p ${SSH_PORT} root@你的服务器IP"
echo ""

echo "请务必先测试新SSH连接成功，再关闭当前窗口！"
