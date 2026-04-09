# ============================================================
# OpenClaw 运维命令速查卡
# 课程：AI 业务流架构师 · 第二节课
# 建议打印或截图保存
# ============================================================

# ==================== Docker Compose ====================

docker compose up -d              # 后台启动
docker compose down                # 停止并移除容器
docker compose restart             # 重启
docker compose ps                  # 查看运行状态
docker compose logs -f             # 实时查看日志
docker compose logs -f --tail 100  # 最近 100 行日志
docker compose pull                # 拉取最新镜像
docker compose exec openclaw bash  # 进入容器

# ==================== systemd ====================

sudo systemctl enable openclaw     # 设置开机自启
sudo systemctl start openclaw      # 启动服务
sudo systemctl stop openclaw       # 停止服务
sudo systemctl restart openclaw    # 重启服务
sudo systemctl status openclaw     # 查看状态
journalctl -u openclaw -f          # 实时查看 systemd 日志
journalctl -u openclaw --since '1 hour ago'  # 最近 1 小时

# ==================== Tailscale ====================

sudo tailscale up                  # 启动并认证
sudo tailscale down                # 断开连接
tailscale status                   # 查看设备列表
tailscale serve --bg 18789         # 开启 Serve（私有访问）
tailscale serve status             # 查看 Serve 状态
tailscale serve 18789 off          # 关闭 Serve
tailscale funnel --bg 18789        # 开启 Funnel（公网访问）
tailscale funnel 18789 off         # 关闭 Funnel
tailscale ping <device>            # 测试连通性
sudo tailscale set --ssh           # 启用 Tailscale SSH
tailscale ssh user@device          # 通过 Tailscale SSH 连接

# ==================== OpenClaw 配置 ====================

# 以下命令在容器内执行（先 docker compose exec openclaw bash）
openclaw doctor                                          # 健康检查
openclaw doctor --generate-gateway-token                 # 生成认证令牌
openclaw config set gateway.auth.mode token              # 设置认证模式
openclaw config set gateway.auth.token "TOKEN"           # 设置令牌
openclaw config set gateway.bind loopback                # 绑定本地
openclaw config set gateway.controlUi.allowInsecureAuth false  # 禁用不安全认证
openclaw config get gateway.auth.token                   # 查看当前令牌
openclaw gateway restart                                 # 重启网关

# ==================== 故障排查 ====================

ss -tlnp | grep 18789             # 检查端口占用
curl http://localhost:18789/health # 检查服务健康状态
docker compose logs --tail 50      # 查看最近日志
systemctl status docker            # 检查 Docker 状态
tailscale status                   # 检查 Tailscale 连接
