#!/bin/bash

set -e

echo "======================================="
echo " Ubuntu 24 Root SSH Key Installer (SAFE)"
echo "======================================="

SSH_PORT="7796"

if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 运行"
    exit 1
fi

# =========================
# 等待 apt lock（关键）
# =========================
wait_for_apt() {
    echo "等待 apt 锁释放..."
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
        echo "apt 正在被占用，等待中..."
        sleep 3
    done
}

wait_for_apt
apt update

wait_for_apt
apt install -y openssh-server

# =========================
# SSH key
# =========================

mkdir -p /root/.ssh
chmod 700 /root/.ssh

echo ""
echo "请粘贴 SSH 公钥:"
read PUBKEY

echo "$PUBKEY" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# =========================
# SSH config
# =========================

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication no/g" /etc/ssh/sshd_config
sed -i "s/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/g" /etc/ssh/sshd_config
sed -i "s/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/g" /etc/ssh/sshd_config

if grep -q "^#Port" /etc/ssh/sshd_config; then
    sed -i "s/^#Port.*/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
elif grep -q "^Port" /etc/ssh/sshd_config; then
    sed -i "s/^Port.*/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
else
    echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
fi

# =========================
# firewall
# =========================

wait_for_apt
apt install -y ufw

ufw allow ${SSH_PORT}/tcp
ufw --force enable

systemctl restart ssh

echo ""
echo "======================================="
echo "完成"
echo "======================================="
echo "SSH Port: $SSH_PORT"
echo "Root login: key only"
echo "Password login: disabled"
echo ""
echo "ssh -p ${SSH_PORT} root@IP"
