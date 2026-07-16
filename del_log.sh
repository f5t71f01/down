#!/bin/bash

# =========================================================================
# 脚本名称: safe-sys-clean.sh
# 描述: 终极安全无痕脚本 - 自动关闭全局日志并物理粉碎现有痕迹 (中文注释版)
# =========================================================================

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "[错误] 请以 root 权限运行此脚本。"
    exit 1
fi

echo "[*] 开始配置：关闭全局系统日志并清理历史痕迹..."

# -------------------------------------------------------------------------
# 1. 配置 Systemd Journal 为黑洞模式 (只运行、不记录任何日志)
# -------------------------------------------------------------------------
echo "[1/5] 正在配置 Systemd Journal 至黑洞模式..."
CONF_FILE="/etc/systemd/journald.conf"
if [ -f "$CONF_FILE" ]; then
    # 备份原始配置 (以防万一)
    if [ ! -f "${CONF_FILE}.bak" ]; then
        cp "$CONF_FILE" "${CONF_FILE}.bak" 2>/dev/null
    fi

    # 清除已有的冲突配置项，防止重复写入
    sed -i '/^Storage=/d' "$CONF_FILE"
    sed -i '/^ForwardToSyslog=/d' "$CONF_FILE"
    sed -i '/^ForwardToKMsg=/d' "$CONF_FILE"
    sed -i '/^ForwardToConsole=/d' "$CONF_FILE"
    sed -i '/^ForwardToWall=/d' "$CONF_FILE"

    # 在 [Journal] 配置组下方注入关闭日志的核心参数
    sed -i '/\[Journal\]/a Storage=none\nForwardToSyslog=no\nForwardToKMsg=no\nForwardToConsole=no\nForwardToWall=no' "$CONF_FILE"

    # 热重载并重启服务，使配置立即生效（此操作对运行中的网页程序和当前 SSH 无感）
    systemctl daemon-reload 2>/dev/null
    systemctl restart systemd-journald 2>/dev/null
fi

# -------------------------------------------------------------------------
# 2. 彻底禁用传统的 rsyslog 和 auditd 审计服务
# -------------------------------------------------------------------------
echo "[2/5] 正在停止并禁用系统传统日志与审计服务..."
# 停止并禁用传统的 syslog 服务
systemctl stop rsyslog 2>/dev/null
systemctl disable rsyslog 2>/dev/null

# 停止并禁用安全审计服务（如果存在）
systemctl stop auditd 2>/dev/null
systemctl disable auditd 2>/dev/null

# -------------------------------------------------------------------------
# 3. 物理粉碎现有的历史日志文件 (安全处理，不伤 SSH 结构)
# -------------------------------------------------------------------------
echo "[3/5] 正在安全粉碎磁盘上的历史日志残余..."

# 物理粉碎所有的二进制旧日志文件并清空目录
if [ -d "/var/log/journal" ]; then
    find /var/log/journal/ -type f -exec shred -u -z -n 1 {} + 2>/dev/null
    rm -rf /var/log/journal/* 2>/dev/null
fi

# 物理粉碎常规的文本旧日志文件 (例如 syslog, auth.log 等)
find /var/log/ -type f \( -name "*.log" -o -name "*.gz" -o -name "*.1" \) -exec shred -u -z -n 1 {} + 2>/dev/null

# 【核心安全防线】针对系统登录状态数据库，决不能用 shred 删除文件实体
# 采用安全截断（truncate）至 0 字节，既抹去了登录和会话痕迹，又不会破坏 SSH 连接
for safe_file in /var/log/wtmp /var/log/btmp /var/log/lastlog /var/run/utmp /var/log/secure; do
    if [ -f "$safe_file" ]; then
        truncate -s 0 "$safe_file" 2>/dev/null
    fi
done

# -------------------------------------------------------------------------
# 4. 安全粉碎所有有效用户的 Shell 历史指令与连接缓存
# -------------------------------------------------------------------------
echo "[4/5] 正在粉碎各用户的 Shell 历史指令与 SSH 记录..."
for user_home in /home/* /root; do
    if [ -d "$user_home" ]; then
        for hist_file in .bash_history .zsh_history .sh_history .lesshst .viminfo .nano_history .python_history; do
            if [ -f "$user_home/$hist_file" ]; then
                shred -u -z -n 1 "$user_home/$hist_file" 2>/dev/null
            fi
        done
        # 粉碎已保存的 SSH 信任主机记录
        if [ -f "$user_home/.ssh/known_hosts" ]; then
            shred -u -z -n 1 "$user_home/.ssh/known_hosts" 2>/dev/null
        fi
    fi
done

# 彻底切断当前正在运行的这个 Bash 会话的内存历史回写
export HISTSIZE=0
export HISTFILESIZE=0
history -c 2>/dev/null

# -------------------------------------------------------------------------
# 5. 清理临时缓存文件与包管理器缓存 (只粉碎文件，保留目录骨架)
# -------------------------------------------------------------------------
echo "[5/5] 正在清理临时系统缓存..."
find /tmp -type f -exec shred -u -z -n 1 {} + 2>/dev/null
find /var/tmp -type f -exec shred -u -z -n 1 {} + 2>/dev/null
apt-get clean -y 2>/dev/null

echo "[*] 配置完毕！全局日志已永久关闭，历史痕迹已完全安全抹去。"