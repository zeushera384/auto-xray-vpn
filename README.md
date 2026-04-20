# xray-setup

Ubuntu / Debian 服务器上一键部署 **Xray VLESS + Reality** 代理节点，并自动生成 Clash 客户端配置。

> 📖 **还没有云主机？** 请先阅读 [云主机购买与配置教程](vps-guide.md)，以阿里云国际版和 Vultr 为例，从注册账号到登录服务器手把手说明。

---

## 特性

- 全程自动：安装 Xray、生成密钥对、写入配置、启动服务、放行防火墙
- 只需回答两个问题（端口 & 伪装域名），其余无需手动操作
- 兼容 Xray 各版本的密钥输出格式
- 自动检测服务器公网 IP
- 安装完成后在服务器端生成现成的 Clash 配置文件，直接复制即可使用
- 启动失败时自动打印日志，便于排查

---

## 环境要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Ubuntu 20.04 / 22.04 / 24.04，Debian 10 / 11 / 12 |
| 权限 | root 或 sudo |
| 客户端 | 支持 VLESS + Reality 的 Clash（Clash.Meta / Mihomo 内核） |

---

## ⚠️ 运行脚本前：云主机配置清单

这是最容易被忽略的部分，建议逐项确认后再执行安装脚本。

### 1. 在云控制台开放安全组端口

绝大多数云服务商在系统防火墙之外还有一层**安全组（Security Group）**，必须在控制台手动放行，否则外部流量无法到达服务器，即使 Xray 正常运行也无法连接。

在你的云控制台找到"安全组"或"防火墙规则"，添加一条入站规则：

| 方向 | 协议 | 端口 | 来源 |
|------|------|------|------|
| 入站 | TCP | 你设置的端口（默认 443） | 0.0.0.0/0 |

各云厂商入口：

- **阿里云**：云服务器 ECS → 安全组 → 配置规则
- **腾讯云**：云服务器 CVM → 安全组 → 添加规则
- **AWS**：EC2 → Security Groups → Inbound rules → Edit
- **Vultr / DigitalOcean / Hetzner**：通常无额外安全组，系统防火墙（ufw）由脚本自动处理

### 2. 确认端口未被占用

默认端口 443 可能已被 nginx、Apache 或其他服务占用，Xray 将无法绑定该端口。

```bash
# 查看 443 端口是否已被占用
ss -tlnp | grep :443
```

如果有输出，说明端口已被占用，安装时请换一个其他端口（如 8443、2053 等）。

### 3. 检查系统时间是否准确

Reality 协议对时间误差敏感，**服务端与客户端时间差超过 90 秒**会导致握手失败、无法连接。

```bash
# 查看当前系统时间
date

# 如果时间不准，安装并启用时间同步
apt-get install -y systemd-timesyncd
timedatectl set-ntp true

# 验证同步状态（应显示 System clock synchronized: yes）
timedatectl status
```

### 4. 确认以 root 身份运行

脚本需要 root 权限来安装软件和修改系统配置。

```bash
# 切换到 root 后再运行
sudo -i
bash xray-setup.sh
```

### 5. 修改防火墙规则前确保 SSH 端口已放行

如果你手动操作了 ufw / iptables，请确保 SSH 端口始终在放行列表中，否则将无法重新连接服务器。

```bash
# 确保 SSH 端口已放行（默认 22）
ufw allow 22/tcp
```

---

## 快速开始

### 1. 下载脚本到服务器

```bash
curl -O https://raw.githubusercontent.com/<你的用户名>/<仓库名>/main/xray-setup.sh
chmod +x xray-setup.sh
```

### 2. 执行脚本

```bash
bash xray-setup.sh
```

运行后按提示输入两个参数：

```
监听端口 [默认 443]: 
Reality 伪装域名 [默认 www.microsoft.com]: 
```

直接回车即使用默认值，脚本随后全自动完成所有步骤。

### 3. 获取 Clash 配置

脚本执行成功后，配置文件自动保存在服务器的 `/root/clash-proxy.yaml`：

```bash
cat /root/clash-proxy.yaml
```

将输出内容复制到本地 Clash 的 `config.yaml` 中，切换到该节点即可。

---

## 生成的 Clash 配置示例

```yaml
proxies:
  - name: "MyVPS-Reality"
    type: vless
    server: <服务器IP>
    port: 443
    uuid: <自动生成>
    flow: xtls-rprx-vision
    tls: true
    network: tcp
    reality-opts:
      public-key: <自动生成>
      short-id: <自动生成>
    servername: www.microsoft.com
    client-fingerprint: chrome
```

---

## 常用管理命令

```bash
# 查看运行状态
systemctl status xray

# 查看实时日志
journalctl -u xray -f

# 重启服务
systemctl restart xray

# 查看 Xray 配置
cat /usr/local/etc/xray/config.json

# 查看 Clash 配置
cat /root/clash-proxy.yaml
```

---

## 卸载

```bash
bash -c "$(curl -sSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
```

---

## 常见问题

**Q: Xray 启动失败怎么办？**  
脚本会自动打印最近 30 条日志。最常见的原因是端口被占用（如 443 被 nginx 占用），换一个端口重新运行脚本即可。也可手动查看：
```bash
journalctl -u xray -n 50 --no-pager
```

**Q: Xray 运行正常但客户端连接超时？**  
99% 是云控制台安全组没有放行端口，回到「云主机配置清单 → 第 1 步」操作。

**Q: 连接不稳定，频繁握手失败？**  
检查服务端系统时间是否准确，参考「云主机配置清单 → 第 3 步」同步时间。

**Q: 支持 Shadowrocket / V2rayN 吗？**  
目前脚本只生成 Clash 格式配置。节点参数（IP、端口、UUID、PublicKey、ShortId）也会在终端汇总显示，可据此手动填写其他客户端。

**Q: 已经安装过 Xray，能重新运行脚本吗？**  
可以。脚本检测到 Xray 已安装会跳过安装步骤，直接生成新的密钥和配置并重启服务。

---

## 协议

MIT
