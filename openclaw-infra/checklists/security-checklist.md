# OpenClaw 安全配置检查清单

> 课程：AI 业务流架构师 · 第二节课
> 完成实战后，逐项检查，确保每一项都打勾

---

## 🔴 网络层（最高优先级）

- [ ] 云服务器安全组：**关闭所有入站端口**（包括 22/SSH，改用 Tailscale SSH）
- [ ] OpenClaw 绑定 `127.0.0.1`（不是 `0.0.0.0`）
- [ ] Docker ports 写 `"127.0.0.1:18789:18789"`（不是 `"18789:18789"`）
- [ ] Tailscale 已安装并 `tailscale up` 认证成功
- [ ] Tailscale Serve 已配置 `tailscale serve --bg 18789`

**验证命令：**
```bash
ss -tlnp | grep 18789
# 应显示 127.0.0.1:18789，不应显示 0.0.0.0:18789
```

---

## 🟡 认证层

- [ ] `gateway.auth.mode` 设为 `token`
- [ ] 使用 `openclaw doctor --generate-gateway-token` 生成强令牌
- [ ] `gateway.controlUi.allowInsecureAuth` 设为 `false`
- [ ] `gateway.bind` 设为 `loopback`

**验证命令：**
```bash
docker compose exec openclaw openclaw config get gateway.auth.mode
# 应返回 token
```

---

## 🔵 运维层

- [ ] systemd 服务已创建并 `systemctl enable openclaw`
- [ ] Docker `restart: unless-stopped` 已配置
- [ ] 日志 rotation 已配置（`max-size: 10m, max-file: 3`）
- [ ] Tailscale SSH 已启用 `sudo tailscale set --ssh`
- [ ] 公网 SSH（22 端口）已在安全组中删除

**验证命令：**
```bash
sudo systemctl status openclaw     # 应显示 active (running)
tailscale status                    # 应显示设备在线
curl http://localhost:18789/health  # 应返回正常响应
```

---

## ✅ 完成确认

全部检查通过后，你的 Agent 具备：

| 能力 | 状态 |
|------|------|
| 7×24 不掉线 | ✅ Docker restart + systemd 双保险 |
| 公网不可见 | ✅ 零公网 IP，Shodan/Censys 扫不到 |
| 强认证 | ✅ Gateway Token，拒绝未授权访问 |
| 端到端加密 | ✅ WireGuard 隧道 |
| 数据主权 | ✅ 数据全在你自己的服务器上 |
