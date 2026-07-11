#!/usr/bin/env bash
# install-cloudflared-tunnel.sh
# 一键安装 cloudflared，以令牌方式把隧道注册为常驻服务，并自动验证。
set -euo pipefail

# ---------- 前置检查 ----------
if [[ $EUID -ne 0 ]]; then
  echo "❌ 请用 root 运行：sudo bash $0"; exit 1
fi

log()  { echo -e "\n\033[1;36m==> $*\033[0m"; }
ok()   { echo -e "\033[1;32m✅ $*\033[0m"; }
warn() { echo -e "\033[1;33m⚠️  $*\033[0m"; }
err()  { echo -e "\033[1;31m❌ $*\033[0m"; }

# ---------- 安装 cloudflared（apt 优先，失败降级为二进制） ----------
install_via_apt() {
  apt-get install -y ca-certificates curl gnupg >/dev/null 2>&1 || return 1
  mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    -o /usr/share/keyrings/cloudflare-main.gpg || return 1
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
    > /etc/apt/sources.list.d/cloudflared.list
  apt-get update -y >/dev/null 2>&1 || return 1
  apt-get install -y cloudflared >/dev/null 2>&1 || return 1
  command -v cloudflared >/dev/null 2>&1
}

install_via_binary() {
  local arch a
  arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
  case "$arch" in
    amd64|x86_64)  a=amd64 ;;
    arm64|aarch64) a=arm64 ;;
    armhf|armv7l)  a=arm ;;
    *) err "不支持的架构：$arch"; exit 1 ;;
  esac
  command -v curl >/dev/null 2>&1 || { apt-get install -y curl >/dev/null 2>&1 || true; }
  curl -fL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${a}" \
    -o /usr/local/bin/cloudflared || { err "下载 cloudflared 失败"; exit 1; }
  chmod +x /usr/local/bin/cloudflared
  command -v cloudflared >/dev/null 2>&1 || { err "cloudflared 安装失败"; exit 1; }
}

log "安装 cloudflared"
if command -v cloudflared >/dev/null 2>&1; then
  ok "已安装：$(cloudflared --version 2>&1 | head -1)"
else
  if command -v apt-get >/dev/null 2>&1 && install_via_apt; then
    ok "通过 apt 安装成功"
  else
    warn "apt 安装不可用/失败，改用直接下载二进制"
    install_via_binary
    ok "二进制安装成功"
  fi
fi
cloudflared --version 2>&1 | head -1

# ---------- 输入并校验隧道 token ----------
log "配置隧道令牌"
echo "从 Cloudflare 后台 (Zero Trust → Networks → Tunnels → 你的隧道 → Install) 复制 token"
read -rp "请粘贴 Tunnel Token: " TOKEN
TOKEN="$(echo -n "$TOKEN" | tr -d '[:space:]')"
[[ -n "$TOKEN" ]] || { err "token 不能为空"; exit 1; }
[[ "$TOKEN" == eyJ* ]] || warn "token 通常以 eyJ 开头，请确认没复制错"

# ---------- 注册为服务（先清旧，避免冲突） ----------
log "注册为系统服务"
cloudflared service uninstall >/dev/null 2>&1 || true
systemctl stop cloudflared >/dev/null 2>&1 || true
cloudflared service install "$TOKEN"
systemctl enable cloudflared >/dev/null 2>&1 || true
systemctl restart cloudflared

# ---------- 验证 ----------
log "验证运行状态"
sleep 3
if systemctl is-active --quiet cloudflared; then
  ok "cloudflared 服务运行中，且已设开机自启"
else
  err "cloudflared 服务未运行，请看日志：journalctl -u cloudflared -n 50 --no-pager"
  exit 1
fi

# 是否连上 Cloudflare 边缘
if journalctl -u cloudflared -n 80 --no-pager 2>/dev/null \
     | grep -qiE "Registered tunnel connection|Connection [a-z0-9-]+ registered|Updated to new configuration"; then
  ok "隧道已连上 Cloudflare 边缘"
else
  warn "暂未捕获到连接成功日志，稍等几秒或执行：journalctl -u cloudflared -f"
fi

# 转发目标 gogate-api 在不在
if ss -tlnp 2>/dev/null | grep -q ':3000'; then
  ok "本机 3000 有服务监听（gogate-api 正常）"
else
  warn "本机 3000 未检测到监听！隧道即使通了，也没有后端可转发——请确认 gogate-api 已启动。"
fi

# ---------- 收尾提示 ----------
cat <<EOF

\033[1;32m========== 完成 ==========\033[0m
隧道已常驻并开机自启。管理命令：
  systemctl status cloudflared      # 状态
  systemctl restart cloudflared     # 重启
  journalctl -u cloudflared -f      # 实时日志

后续还需在【Cloudflare 后台】确认这条隧道的 Public Hostname：
  api.你的域名.com  →  Service: HTTP  →  URL: localhost:3000

验证（配好 Public Hostname 后）：
  curl -i https://api.你的域名.com/api/login -X POST
  返回 {"code":1,...} 即通。

别忘了前端 .env.production：
  VITE_GLOB_API_URL=https://api.你的域名.com   然后重新 pnpm build
EOF
