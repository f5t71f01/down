#!/bin/bash

set -e

echo "======================================="
echo " Ubuntu 24 Root SSH Key Installer"
echo "======================================="

# =========================
# 配置（只改这里）
# =========================

SSH_PORT="7796"

# =========================

if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 运行"
    exit 1
fi

echo ""
echo "当前 SSH 端口: $SSH_PORT"
echo ""

# =========================
# 安装 openssh
# =========================

apt update
apt install -y openssh-server

# =========================
# 创建 SSH 目录
# =========================

mkdir -p /root/.ssh
chmod 700 /root/.ssh

echo ""
echo "请粘贴你的 SSH 公钥:"
echo "（ssh-ed25519 开头）"
echo ""

read PUBKEY

echo "$PUBKEY" >> /root/.ssh/authorized_keys

chmod 600 /root/.ssh/authorized_keys

# =========================
# 备份配置
# =========================

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# =========================
# SSH 配置
# =========================

sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication no/g" /etc/ssh/sshd_config

sed -i "s/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/g" /etc/ssh/sshd_config

sed -i "s/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/g" /etc/ssh/sshd_config

# =========================
# 修改端口
# =========================

if grep -q "^#Port" /etc/ssh/sshd_config; then
    sed -i "s/^#Port.*/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
elif grep -q "^Port" /etc/ssh/sshd_config; then
    sed -i "s/^Port.*/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
else
    echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
fi

# =========================
# 防火墙
# =========================

apt install -y ufw

ufw allow ${SSH_PORT}/tcp

ufw --force enable

# =========================
# 重启 SSH
# =========================

systemctl restart ssh

echo ""
echo "======================================="
echo " 配置完成"
echo "======================================="
echo ""

echo "SSH端口: ${SSH_PORT}"
echo "Root登录: 已开启（仅允许密钥）"
echo "密码登录: 已关闭"
echo ""

echo "连接方式："
echo ""
echo "ssh -p ${SSH_PORT} root@你的服务器IP"
echo ""

echo "请务必先测试新连接成功，再关闭当前窗口！"
