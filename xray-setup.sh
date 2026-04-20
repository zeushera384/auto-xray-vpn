#!/bin/bash
# ============================================================
#  Xray VLESS + Reality 一键安装脚本（修复版）
#  适用系统：Ubuntu / Debian
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && die "请用 root 用户运行，或加 sudo"

echo ""
echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}   Xray VLESS+Reality 一键安装脚本   ${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

read -rp "监听端口 [默认 443]: " PORT
PORT=${PORT:-443}
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
    die "端口号无效: $PORT"
fi

read -rp "Reality 伪装域名 [默认 www.microsoft.com]: " SNI
SNI=${SNI:-www.microsoft.com}

SERVER_IP=$(curl -s4 --max-time 5 https://ifconfig.me 2>/dev/null \
         || curl -s4 --max-time 5 https://api.ipify.org 2>/dev/null \
         || curl -s4 --max-time 5 https://ipecho.net/plain 2>/dev/null)
if [[ -z "$SERVER_IP" ]]; then
    read -rp "无法自动获取公网 IP，请手动输入: " SERVER_IP
fi
info "检测到服务器公网 IP: $SERVER_IP"

# ── 安装依赖 ────────────────────────────────────────────────
info "更新包索引..."
apt-get update -qq

info "安装依赖..."
apt-get install -y -qq curl unzip openssl

# ── 安装 Xray（已装则跳过）──────────────────────────────────
if ! command -v xray &>/dev/null; then
    info "下载并安装 Xray..."
    bash -c "$(curl -sSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    success "Xray 安装完成"
else
    XRAY_VER=$(xray version 2>/dev/null | head -1 || echo "unknown")
    success "Xray 已安装: $XRAY_VER"
fi

# ── 生成密钥（兼容各版本输出格式）──────────────────────────
info "生成 UUID..."
UUID=$(xray uuid)

info "生成 Reality 密钥对..."
KEY_OUTPUT=$(xray x25519 2>&1)
info "x25519 原始输出: $KEY_OUTPUT"

# 兼容多种格式：
#   "Private key: xxx"  /  "private key: xxx"  /  "Private Key: xxx"
PRIVATE_KEY=$(echo "$KEY_OUTPUT" | grep -i "private" | grep -oP '(?<=[=:\s])\S+$' | tail -1)
PUBLIC_KEY=$(echo  "$KEY_OUTPUT" | grep -i "public"  | grep -oP '(?<=[=:\s])\S+$' | tail -1)

# 兜底：按行顺序取（第1行私钥，第2行公钥）
if [[ -z "$PRIVATE_KEY" ]]; then
    PRIVATE_KEY=$(echo "$KEY_OUTPUT" | sed -n '1p' | awk '{print $NF}')
fi
if [[ -z "$PUBLIC_KEY" ]]; then
    PUBLIC_KEY=$(echo "$KEY_OUTPUT"  | sed -n '2p' | awk '{print $NF}')
fi

[[ -z "$PRIVATE_KEY" ]] && die "无法解析 Private Key，请手动检查 'xray x25519' 的输出"
[[ -z "$PUBLIC_KEY"  ]] && die "无法解析 Public Key，请手动检查 'xray x25519' 的输出"

SHORT_ID=$(openssl rand -hex 8)

success "UUID:         $UUID"
success "Private Key:  $PRIVATE_KEY"
success "Public Key:   $PUBLIC_KEY"
success "Short ID:     $SHORT_ID"

# ── 写入 Xray 配置 ──────────────────────────────────────────
info "写入 Xray 配置..."
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SNI}:443",
          "serverNames": ["${SNI}"],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": ["${SHORT_ID}"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "block"}
  ]
}
EOF

# 验证 JSON 格式
if command -v python3 &>/dev/null; then
    python3 -m json.tool /usr/local/etc/xray/config.json > /dev/null \
        && success "配置文件 JSON 格式正确" \
        || die "配置文件 JSON 格式有误，请检查"
fi

# ── 启动服务 ────────────────────────────────────────────────
info "启用并启动 Xray 服务..."
systemctl enable xray > /dev/null 2>&1
systemctl restart xray
sleep 2

if systemctl is-active --quiet xray; then
    success "Xray 运行正常"
else
    echo ""
    warn "Xray 启动失败，以下是日志："
    journalctl -u xray -n 30 --no-pager
    die "请根据上方日志排查问题"
fi

# ── 防火墙 ──────────────────────────────────────────────────
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    info "ufw 放行端口 $PORT ..."
    ufw allow "${PORT}/tcp" > /dev/null 2>&1
    success "ufw 规则已添加"
else
    warn "请在云控制台安全组手动放行 TCP 端口 $PORT"
fi

# ── 输出 Clash 配置 ─────────────────────────────────────────
CLASH_CFG="/root/clash-proxy.yaml"
cat > "$CLASH_CFG" <<EOF
# ============================================================
#  将 proxies 块复制到你的 Clash config.yaml
#  或直接将本文件作为 Clash 配置使用
# ============================================================
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info

proxies:
  - name: "MyVPS-Reality"
    type: vless
    server: ${SERVER_IP}
    port: ${PORT}
    uuid: ${UUID}
    flow: xtls-rprx-vision
    tls: true
    network: tcp
    reality-opts:
      public-key: ${PUBLIC_KEY}
      short-id: ${SHORT_ID}
    servername: ${SNI}
    client-fingerprint: chrome

proxy-groups:
  - name: "Proxy"
    type: select
    proxies:
      - "MyVPS-Reality"
      - DIRECT

rules:
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
EOF

success "Clash 配置已保存到: $CLASH_CFG"

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  安装成功！节点信息如下                                   ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "  服务器 IP  : ${CYAN}${SERVER_IP}${NC}"
echo -e "  端口       : ${CYAN}${PORT}${NC}"
echo -e "  UUID       : ${CYAN}${UUID}${NC}"
echo -e "  Public Key : ${CYAN}${PUBLIC_KEY}${NC}"
echo -e "  Short ID   : ${CYAN}${SHORT_ID}${NC}"
echo -e "  SNI        : ${CYAN}${SNI}${NC}"
echo ""
echo -e "  Clash 配置 : ${YELLOW}cat ${CLASH_CFG}${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
warn "如果是阿里云/腾讯云/AWS，记得在控制台安全组放行 TCP 端口 ${PORT}"
echo ""