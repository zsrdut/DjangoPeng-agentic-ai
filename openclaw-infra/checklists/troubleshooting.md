# OpenClaw 常见问题排错指南

> 课程：AI 业务流架构师 · 第二节课
> 实战过程中遇到问题，按以下步骤排查

---

## Q1：docker compose up 报端口占用

**现象：** `Error: port is already allocated` 或 `bind: address already in use`

**排查步骤：**
```bash
# 1. 查看谁占用了 18789 端口
ss -tlnp | grep 18789

# 2. 如果是残留的旧进程，杀掉它
kill <PID>

# 3. 如果是旧的 Docker 容器，清理
docker compose down
docker compose up -d
```

---

## Q2：tailscale up 卡住不动

**现象：** 执行 `tailscale up` 后长时间无响应，不弹出授权链接

**排查步骤：**
```bash
# 1. 重启 tailscaled 服务
sudo systemctl restart tailscaled

# 2. 重新认证
sudo tailscale up --reset

# 3. 如果仍然卡住，检查网络（Tailscale 需要访问 controlplane.tailscale.com）
curl -I https://controlplane.tailscale.com
```

---

## Q3：Serve 成功但浏览器无法访问

**现象：** `tailscale serve status` 显示正常，但浏览器打不开

**排查步骤：**
```bash
# 1. 确认本地服务正常
curl http://localhost:18789/health

# 2. 确认 Tailscale 连通性（从你的笔记本执行）
tailscale ping <server-name>

# 3. 确认 Serve 状态
tailscale serve status

# 4. 确认个人设备也登录了同一个 Tailscale 账号
tailscale status
```

**常见原因：**
- 个人设备没有安装 Tailscale 或没有登录
- 个人设备登录的是不同的 Tailscale 账号
- 服务器上的 OpenClaw 进程未启动

---

## Q4：Dashboard 加载但认证失败

**现象：** 页面能打开，但输入 Token 后提示认证失败

**排查步骤：**
```bash
# 1. 查看当前配置的 Token
docker compose exec openclaw openclaw config get gateway.auth.token

# 2. 确认认证模式
docker compose exec openclaw openclaw config get gateway.auth.mode
# 应返回 token

# 3. 如果 Token 丢失，重新生成
docker compose exec openclaw bash
openclaw doctor --generate-gateway-token
openclaw config set gateway.auth.token "新令牌"
exit && docker compose restart
```

---

## Q5：容器启动后立即退出

**现象：** `docker compose ps` 显示容器状态为 `Exited`

**排查步骤：**
```bash
# 1. 查看容器退出日志
docker compose logs --tail 50

# 2. 常见原因及解决方案：
# - .env 文件不存在 → 创建 .env 并填入 API Key
# - API Key 格式错误 → 检查是否包含多余空格或换行
# - 端口被占用 → 参考 Q1
# - 磁盘空间不足 → df -h 检查

# 3. 清理后重试
docker compose down -v  # ⚠️ -v 会删除数据卷，慎用
docker compose up -d
```

---

## Q6：systemd 服务启动失败

**现象：** `systemctl status openclaw` 显示 `failed`

**排查步骤：**
```bash
# 1. 查看详细错误
journalctl -u openclaw --no-pager -n 30

# 2. 常见原因：
# - WorkingDirectory 路径不存在 → 确认 /opt/openclaw 目录存在
# - docker compose 命令路径不对 → which docker compose 确认路径
# - ExecStart 加了 -d → 去掉 -d，让 compose 前台运行

# 3. 修改 service 文件后重新加载
sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

---

## Q7：Docker 镜像拉取失败（国内网络问题）

**现象：** `docker compose pull` 超时或连接被拒绝

**解决方案：**
```bash
# 配置 Docker 镜像加速（任选其一）
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://registry.docker-cn.com"
  ]
}
EOF

sudo systemctl restart docker
docker compose pull
```

---

## Q8：Tailscale Serve 证书获取失败

**现象：** `tailscale cert` 报错 `i/o timeout`，或浏览器访问 Dashboard 时 TLS 握手卡住

**典型报错：**
```
500 Internal Server Error: acme.GetReg: Get "https://acme-v02.api.letsencrypt.org/directory": 
dial tcp: lookup acme-v02.api.letsencrypt.org on [fd7a:115c:a1e0::53]:53: i/o timeout
```

**原因：** Tailscale 的 MagicDNS 接管了服务器 DNS，导致出站访问 Let's Encrypt 时 DNS 解析超时。

**解决方案：**
```bash
# 1. 添加公网 DNS
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# 2. 手动获取证书
tailscale cert <你的设备名>.tailnet.ts.net
# 例如：tailscale cert openclaw-dev.tail909cb3.ts.net

# 3. 重启 Serve 加载新证书
tailscale serve 18789 off
tailscale serve --bg 18789

# 4. 验证
curl https://<你的设备名>.tailnet.ts.net
```

---

## Q9：笔记本使用 Clash / V2Ray 等代理工具时无法访问 Dashboard

**现象：** curl 能访问但浏览器报 `ERR_CONNECTION_CLOSED`，关闭代理工具后恢复正常

**原因：** 代理工具（Clash Verge、V2RayN 等）劫持了浏览器流量，将本该走 Tailscale WireGuard 隧道的请求转发到了代理服务器，代理服务器不在你的 tailnet 中所以连接失败。

**解决方案（Clash Verge Rev）：**

编辑 Merge.yaml（路径因操作系统而异）：
- macOS: `~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles/Merge.yaml`
- Windows: `%APPDATA%\io.github.clash-verge-rev.clash-verge-rev\profiles\Merge.yaml`

添加以下内容：
```yaml
dns:
  nameserver-policy:
    "+.ts.net": system

prepend-rules:
  - DOMAIN-SUFFIX,ts.net,DIRECT
  - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve
```

如果使用 PAC 模式或系统代理，还需要添加系统代理旁路：

**macOS：**
```bash
CURRENT=$(networksetup -getproxybypassdomains Wi-Fi | tr '\n' ' ')
networksetup -setproxybypassdomains Wi-Fi $CURRENT "*.ts.net" "100.*"
```

**Windows：**
设置 → 网络和 Internet → 代理 → 手动设置代理 → "请勿对以下列条目开头的地址使用代理服务器"中添加：
```
*.ts.net;100.*
```

修改后重启代理工具，浏览器即可正常访问 Dashboard。

**其他代理工具的通用原则：**
让 `*.ts.net` 域名和 `100.64.0.0/10` IP 段走 DIRECT（直连），不经过代理。

---

## 通用排查思路

遇到任何问题，按这个顺序排查：

1. **看日志** — `docker compose logs -f` 或 `journalctl -u openclaw -f`
2. **看状态** — `docker compose ps` + `systemctl status openclaw` + `tailscale status`
3. **看端口** — `ss -tlnp | grep 18789`
4. **看网络** — `curl localhost:18789/health` + `tailscale ping`
5. **重启** — `docker compose restart` 或 `sudo systemctl restart openclaw`
