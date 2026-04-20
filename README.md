# xray-setup

Ubuntu / Debian 服务器上一键部署 **Xray VLESS + Reality** 代理节点，并自动生成 Clash 客户端配置。

---

## 特性

- 全程自动：安装 Xray、生成密钥对、写入配置、启动服务、放行防火墙
- 只需回答两个问题（端口 & 伪装域名），其余无需手动操作
- 兼容 Xray 各版本的密钥输出格式
- 自动检测服务器公网 IP
- 安装完成后在服务器端生成现成的 Clash 配置文件，直接复制即可使用
- 启动失败时自动打印日志，便于排查

## 环境要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Ubuntu 20.04 / 22.04 / 24.04，Debian 10 / 11 / 12 |
| 权限 | root 或 sudo |
| 客户端 | 支持 VLESS + Reality 的 Clash（Clash.Meta / Mihomo 内核） |

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

> **云控制台安全组**：如果使用阿里云、腾讯云、AWS 等，还需在控制台手动放行对应 TCP 端口（脚本会提示）。

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

## 常用管理命令

```bash
# 查看运行状态
systemctl status xray

# 查看实时日志
journalctl -u xray -f

# 重启服务
systemctl restart xray

# 查看配置文件
cat /usr/local/etc/xray/config.json
```

## 卸载

```bash
bash -c "$(curl -sSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
```

## 常见问题

**Q: Xray 启动失败怎么办？**  
脚本会自动打印最近 30 条日志。常见原因是 443 端口被占用（如 nginx），换一个端口重新运行脚本即可。

**Q: 支持 Shadowrocket / V2rayN 吗？**  
目前脚本只生成 Clash 格式配置。节点参数（IP、端口、UUID、PublicKey、ShortId）也会在终端汇总显示，可据此手动填写其他客户端。

**Q: 已经安装过 Xray，能重新运行脚本吗？**  
可以。脚本检测到 Xray 已安装会跳过安装步骤，直接生成新的密钥和配置并重启服务。

## 协议

MIT
