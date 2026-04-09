#!/bin/bash
# ============================================================
# OpenClaw 一键部署脚本
# 课程：AI 业务流架构师 · 第二节课实战
#
# 使用方法：
#   chmod +x setup-openclaw.sh
#   sudo ./setup-openclaw.sh
#
# 前置条件：
#   - Ubuntu 24.04 LTS（推荐火山引擎 2C4G ¥99/年）
#   - 已通过 SSH 连接到服务器
#   - 准备好大模型 API Key（OpenAI / DeepSeek / 豆包等均可）
# ============================================================

set -e

echo "=========================================="
echo "  OpenClaw 一键部署脚本"
echo "  课程：AI 业务流架构师 · 第二节课"
echo "=========================================="
echo ""

# ----------------------------------------------------------
# Step 1: 更新系统
# ----------------------------------------------------------
echo "[Step 1/6] 更新系统..."
apt update && apt upgrade -y
echo "✅ 系统更新完成"
echo ""

# ----------------------------------------------------------
# Step 2: 安装 Docker
# ----------------------------------------------------------
echo "[Step 2/6] 安装 Docker..."
if command -v docker &> /dev/null; then
    echo "Docker 已安装，跳过"
else
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
fi
docker --version
docker compose version
echo "✅ Docker 安装完成"
echo ""

# ----------------------------------------------------------
# Step 3: 部署 OpenClaw
# ----------------------------------------------------------
echo "[Step 3/6] 部署 OpenClaw..."
mkdir -p /opt/openclaw
cd /opt/openclaw

# 配置 .env
ENV_VALID=false
if [ -f .env ]; then
    # 文件存在，检查内容是否有效
    if grep -q 'OPENAI_API_KEY=.' .env && ! grep -q 'OPENAI_API_KEY=sk-xxx' .env; then
        echo ".env 已存在，内容如下："
        echo "---"
        cat .env
        echo "---"
        read -rp "是否使用现有配置？[Y/n]：" USE_EXISTING
        if [[ ! "$USE_EXISTING" =~ ^[Nn]$ ]]; then
            ENV_VALID=true
        fi
    else
        echo "⚠️  .env 文件存在但 API Key 未配置（仍是占位符），需要重新配置。"
    fi
fi

if [ "$ENV_VALID" = false ]; then
    echo ""
    echo "请选择你的大模型 API 提供商："
    echo "  1) DeepSeek（推荐，国内性价比最高）"
    echo "  2) 豆包（火山引擎）"
    echo "  3) 通义千问（阿里云百炼）"
    echo "  4) Kimi（Moonshot AI）"
    echo "  5) OpenAI 官方"
    echo "  6) 其他（手动输入 Base URL）"
    echo ""
    read -rp "请输入编号 [1-6]（默认 1）：" PROVIDER_CHOICE
    PROVIDER_CHOICE=${PROVIDER_CHOICE:-1}

    case $PROVIDER_CHOICE in
        1) BASE_URL="https://api.deepseek.com/v1" ; PROVIDER_NAME="DeepSeek" ;;
        2) BASE_URL="https://ark.cn-beijing.volces.com/api/v3" ; PROVIDER_NAME="豆包" ;;
        3) BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1" ; PROVIDER_NAME="通义千问" ;;
        4) BASE_URL="https://api.moonshot.cn/v1" ; PROVIDER_NAME="Kimi" ;;
        5) BASE_URL="https://api.openai.com/v1" ; PROVIDER_NAME="OpenAI" ;;
        6) read -rp "请输入 Base URL：" BASE_URL ; PROVIDER_NAME="自定义" ;;
        *) BASE_URL="https://api.deepseek.com/v1" ; PROVIDER_NAME="DeepSeek" ;;
    esac

    echo ""
    read -rp "请输入你的 ${PROVIDER_NAME} API Key：" API_KEY

    if [ -z "$API_KEY" ]; then
        echo "❌ API Key 不能为空，请重新运行脚本。"
        exit 1
    fi

    cat > .env << ENV_EOF
OPENAI_API_KEY=${API_KEY}
OPENAI_BASE_URL=${BASE_URL}
ENV_EOF

    echo "✅ .env 已创建（${PROVIDER_NAME}）"
fi

# 创建 docker-compose.yml
cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  openclaw:
    image: ghcr.io/openclaw/openclaw:latest
    ports:
      - "127.0.0.1:18789:18789"
    volumes:
      - openclaw-data:/root/.openclaw
    env_file:
      - .env
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  openclaw-data:
    driver: local
COMPOSE_EOF

docker compose pull

# 启动前检查端口占用
PORT_PID=$(ss -tlnp | grep ':18789' | grep -oP 'pid=\K[0-9]+' | head -1)
if [ -n "$PORT_PID" ]; then
    PORT_CMD=$(ps -p "$PORT_PID" -o comm= 2>/dev/null || echo "未知")
    echo ""
    echo "⚠️  端口 18789 已被占用："
    echo "   PID: ${PORT_PID}"
    echo "   进程: ${PORT_CMD}"
    echo ""

    # 判断是否为 Docker 相关进程
    if echo "$PORT_CMD" | grep -qiE "docker|containerd"; then
        echo "   看起来是一个旧的 Docker 容器在占用。"
        echo "   正在尝试清理旧容器..."
        docker compose down 2>/dev/null || true
        # 如果不是当前目录的 compose，尝试全局清理
        PORT_PID_AFTER=$(ss -tlnp | grep ':18789' | grep -oP 'pid=\K[0-9]+' | head -1)
        if [ -n "$PORT_PID_AFTER" ]; then
            echo "   旧容器清理后端口仍被占用，尝试停止占用容器..."
            CONTAINER_ID=$(docker ps --format '{{.ID}} {{.Ports}}' | grep '18789' | awk '{print $1}')
            if [ -n "$CONTAINER_ID" ]; then
                docker stop "$CONTAINER_ID" && docker rm "$CONTAINER_ID"
                echo "   ✅ 旧容器已清理"
            fi
        else
            echo "   ✅ 旧容器已清理"
        fi
    else
        echo "   该进程不是 Docker 容器（可能是 npm 直装的 OpenClaw）。"
        echo ""
        read -rp "   是否杀掉该进程以释放端口？[y/N]：" KILL_CHOICE
        if [[ "$KILL_CHOICE" =~ ^[Yy]$ ]]; then
            kill "$PORT_PID"
            sleep 2
            # 检查是否成功释放
            if ss -tlnp | grep -q ':18789'; then
                echo "   进程未退出，尝试强制杀掉..."
                kill -9 "$PORT_PID" 2>/dev/null || true
                sleep 1
            fi
            echo "   ✅ 端口已释放"
        else
            echo ""
            echo "   ❌ 端口仍被占用，无法启动 OpenClaw。"
            echo "   请手动处理后重新运行脚本："
            echo "     ss -tlnp | grep 18789    # 查看占用进程"
            echo "     kill <PID>                # 杀掉进程"
            echo "     sudo ./setup-openclaw.sh  # 重新运行"
            exit 1
        fi
    fi
    echo ""
fi

docker compose up -d
echo "✅ OpenClaw 容器已启动"
echo ""

# ----------------------------------------------------------
# Step 4: 配置 systemd 双保险
# ----------------------------------------------------------
echo "[Step 4/6] 配置 systemd 双保险..."
cat > /etc/systemd/system/openclaw.service << 'SERVICE_EOF'
[Unit]
Description=OpenClaw Docker Compose
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/openclaw
ExecStartPre=/usr/bin/docker compose down
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable openclaw
echo "✅ systemd 双保险已配置"
echo ""

# ----------------------------------------------------------
# Step 5: 安装 Tailscale
# ----------------------------------------------------------
echo "[Step 5/6] 安装 Tailscale..."
if command -v tailscale &> /dev/null; then
    echo "Tailscale 已安装，跳过"
else
    curl -fsSL https://tailscale.com/install.sh | sh
    systemctl enable --now tailscaled
fi

# 添加公网 DNS（防止 MagicDNS 导致 Let's Encrypt 证书获取超时）
if ! grep -q '8.8.8.8' /etc/resolv.conf 2>/dev/null; then
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    echo "   已添加公网 DNS 8.8.8.8（用于 HTTPS 证书获取）"
fi

echo "✅ Tailscale 安装完成"
echo ""

# ----------------------------------------------------------
# Step 6: 输出后续操作提示
# ----------------------------------------------------------
echo "=========================================="
echo "  ✅ 自动化部署完成！"
echo "=========================================="
echo ""
echo "接下来需要手动完成以下操作："
echo ""
echo "1️⃣  Tailscale 认证："
echo "   sudo tailscale up"
echo ""
echo "2️⃣  开启 Serve（私有访问）："
echo "   tailscale serve --bg 18789"
echo ""
echo "3️⃣  预获取 HTTPS 证书（重要！避免首次访问超时）："
echo "   tailscale cert \$(tailscale status --self --json | grep -oP '\"DNSName\":\"\\K[^\"]*' | sed 's/\\.$//')"
echo "   # 如果上面命令报错，手动执行："
echo "   # tailscale cert <你的设备名>.tailnet.ts.net"
echo ""
echo "4️⃣  配置 Gateway 认证："
echo "   docker compose exec openclaw bash"
echo "   openclaw doctor --generate-gateway-token"
echo "   openclaw config set gateway.auth.mode token"
echo "   openclaw config set gateway.auth.token \"你的令牌\""
echo "   openclaw config set gateway.bind loopback"
echo "   openclaw config set gateway.controlUi.allowInsecureAuth false"
echo "   exit && docker compose restart"
echo ""
echo "5️⃣  开启 Tailscale SSH 并关闭公网 SSH："
echo "   sudo tailscale set --ssh"
echo "   # 去云厂商控制台安全组中删除 22 端口"
echo ""
echo "6️⃣  在个人设备安装 Tailscale 后访问："
echo "   https://$(hostname).tailnet.ts.net"
echo ""
echo "⚠️  如果你的笔记本使用了 Clash / V2Ray 等代理工具，"
echo "   需要配置 *.ts.net 和 100.0.0.0/8 走直连（DIRECT），"
echo "   否则浏览器可能无法访问 Dashboard。"
echo "   详见教辅资料 checklists/troubleshooting.md"
echo ""
echo "=========================================="
