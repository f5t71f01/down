#!/usr/bin/env bash
# ufw-allow.sh —— 交互式放行端口，可限定来源 IP（支持 1.1.1.* 通配符）
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "❌ 请用 root 运行：sudo bash $0"; exit 1
fi
if ! command -v ufw >/dev/null 2>&1; then
  echo "❌ 未检测到 ufw，请先安装：sudo apt install ufw"; exit 1
fi

# 把 1.1.1.* / 10.0.*.* / 单个IP / CIDR / any 统一转成 ufw 认的来源
to_cidr() {
  local ip="$1" i
  [[ "$ip" == */* ]] && { echo "$ip"; return 0; }                 # 已是 CIDR
  case "${ip,,}" in any|all|anywhere) echo "any"; return 0;; esac # 所有人
  IFS='.' read -ra o <<< "$ip"
  [[ ${#o[@]} -eq 4 ]] || return 1
  local stars=0
  for i in 3 2 1 0; do [[ "${o[$i]}" == "*" ]] && stars=$((stars+1)) || break; done
  local last=$((3-stars))
  for ((i=0;i<=last;i++)); do
    [[ "${o[$i]}" =~ ^[0-9]+$ ]] && (( o[$i]>=0 && o[$i]<=255 )) || return 1
  done
  for i in 0 1 2 3; do [[ "${o[$i]}" == "*" ]] && o[$i]=0; done
  local prefix=$((32-stars*8))
  (( prefix==0 )) && { echo "any"; return 0; }
  echo "${o[0]}.${o[1]}.${o[2]}.${o[3]}/${prefix}"
}

read -rp "请输入要放行的端口: " PORT
[[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT>=1 && PORT<=65535 )) || { echo "❌ 端口无效"; exit 1; }

read -rp "协议 [tcp/udp/both]，回车默认 both(tcp+udp): " PROTO
PROTO="${PROTO:-both}"
[[ "$PROTO" == "tcp" || "$PROTO" == "udp" || "$PROTO" == "both" ]] || { echo "❌ 协议只能 tcp / udp / both"; exit 1; }

echo "请输入允许访问的 IP（多个用空格或逗号分隔）"
echo "  例：1.2.3.4   1.1.1.*   10.0.*.*   any(所有人)"
read -rp "来源 IP: " SRC_RAW
SRC_RAW="${SRC_RAW//,/ }"

declare -a RULES=()
for token in $SRC_RAW; do
  cidr=$(to_cidr "$token") || { echo "❌ 无法识别的 IP：$token"; exit 1; }
  RULES+=("$cidr")
done
[[ ${#RULES[@]} -gt 0 ]] || { echo "❌ 未输入来源"; exit 1; }

proto_label="tcp+udp"; [[ "$PROTO" != "both" ]] && proto_label="$PROTO"
echo
echo "将添加以下规则："
for cidr in "${RULES[@]}"; do
  if [[ "$cidr" == "any" ]]; then
    echo "  端口 ${PORT}/${proto_label}  ← 任何人"
  else
    echo "  端口 ${PORT}/${proto_label}  ← 仅 ${cidr}"
  fi
done
read -rp "确认执行？(y/N): " ok
[[ "${ok,,}" == "y" ]] || { echo "已取消"; exit 0; }

# 执行；both 时不指定协议，ufw 自动同时放行 tcp 和 udp
add_rule() {
  local cidr="$1"
  if [[ "$PROTO" == "both" ]]; then
    if [[ "$cidr" == "any" ]]; then ufw allow "${PORT}"
    else ufw allow from "$cidr" to any port "$PORT"; fi
  else
    if [[ "$cidr" == "any" ]]; then ufw allow "${PORT}/${PROTO}"
    else ufw allow from "$cidr" to any port "$PORT" proto "$PROTO"; fi
  fi
}

for cidr in "${RULES[@]}"; do add_rule "$cidr"; done

echo
echo "✅ 完成。当前规则："
ufw status
