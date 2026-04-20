# 云主机购买与配置教程

本教程以 **阿里云国际版** 和 **Vultr** 为例，从注册账号到登录服务器，一步步完成云主机的购买和初始配置。完成后即可回到主文档执行一键安装脚本。

---

## 目录

- [阿里云国际版](#一阿里云国际版)
  - [注册账号](#1-注册账号)
  - [购买服务器](#2-购买服务器)
  - [配置安全组](#3-配置安全组)
  - [连接服务器](#4-连接服务器)
- [Vultr](#二vultr)
  - [注册账号](#1-注册账号-1)
  - [购买服务器](#2-购买服务器-1)
  - [配置防火墙](#3-配置防火墙)
  - [连接服务器](#4-连接服务器-1)
- [连接服务器通用说明（Windows）](#三连接服务器通用说明windows)

---

## 一、阿里云国际版

> 阿里云国际版（international.aliyun.com）与国内版账号体系独立，建议用境外邮箱注册，使用 PayPal 或国际信用卡付款。

### 1. 注册账号

1. 访问 [https://www.alibabacloud.com](https://www.alibabacloud.com)，点击右上角 **Free Account**
2. 填写境外邮箱（Gmail、Outlook 等）和密码
3. 完成邮箱验证
4. 绑定支付方式：支持 Visa / MasterCard / PayPal

> 💡 不要使用国内支付宝账号直接登录，那会关联到国内账号体系。

### 2. 购买服务器

1. 登录后进入控制台，顶部菜单选择 **Products → Elastic Compute Service (ECS)**
2. 点击 **Create Instance**，按以下推荐配置选择：

   | 配置项 | 推荐选择 |
   |--------|----------|
   | Region（地域） | China (Hong Kong) 或 Singapore |
   | Instance Type | ecs.t6-c1m1.large（1核1G，够用） |
   | Image（系统镜像） | Ubuntu 22.04 64-bit |
   | Storage | 40GB SSD（默认即可） |
   | Network | 默认 VPC |
   | Bandwidth | 按使用流量（Pay-By-Traffic），设置峰值 100Mbps |

3. 设置登录方式：
   - 选择 **Key Pair**（推荐）或 **Password**
   - 如选 Password，设置一个强密码并记好
4. 确认配置，点击 **Create Instance**，等待约 1 分钟创建完成
5. 进入实例列表，记下服务器的**公网 IP 地址**

> 💡 按流量计费比按带宽计费便宜很多，日常代理使用流量不大。

### 3. 配置安全组

ECS 实例默认只开放了 22 端口（SSH），需要手动放行 Xray 使用的端口。

1. 进入实例详情页，左侧菜单点击 **Security Groups**
2. 找到绑定的安全组，点击 **Add Rule**
3. 按如下填写：

   | 字段 | 填写内容 |
   |------|----------|
   | Direction | Inbound |
   | Action | Allow |
   | Protocol | TCP |
   | Port Range | 443（或你自定义的端口） |
   | Source | 0.0.0.0/0 |

4. 点击 **OK** 保存

### 4. 连接服务器

**Windows 用户**请跳到文末「[连接服务器通用说明](#三连接服务器通用说明windows)」章节。

**Mac / Linux 用户**直接用终端：

```bash
ssh root@<你的服务器IP>
# 如使用密钥文件
ssh -i /path/to/your-key.pem root@<你的服务器IP>
```

连接成功后即可回到主文档，执行一键安装脚本。

---

## 二、Vultr

> Vultr 按小时计费，随时可以销毁重建，IP 被封换一台即可，非常适合个人使用。支持国际信用卡和 PayPal 付款。

### 1. 注册账号

1. 访问 [https://www.vultr.com](https://www.vultr.com)，点击右上角 **Sign Up**
2. 填写邮箱和密码完成注册，验证邮箱
3. 进入 **Billing** 页面充值，最低充值 $10
   - 支持 Visa / MasterCard / PayPal / 加密货币
4. 充值完成后即可购买服务器

### 2. 购买服务器

1. 点击左侧菜单 **Products → Compute → Deploy Server**
2. 按如下推荐配置选择：

   | 配置项 | 推荐选择 |
   |--------|----------|
   | Choose Server | Cloud Compute - Shared CPU |
   | Server Location | Tokyo（日本东京，延迟约 60~80ms） |
   | Server Image | Ubuntu 22.04 x64 |
   | Server Size | 1 vCPU / 1GB RAM / 25GB SSD，$6/月 |
   | Additional Features | 全部不勾选即可 |
   | Server Hostname | 随便填，如 `my-vps` |

3. 点击 **Deploy Now**，等待约 2 分钟，状态变为 **Running** 即完成
4. 点击实例名称进入详情页，记下 **IP Address**、**Username**（root）和 **Password**

> 💡 如果 IP 被封，在实例列表点击 **Destroy** 销毁后重新部署一台即可，只收已使用时间的费用。

### 3. 配置防火墙

Vultr 的 Cloud Compute 实例默认没有额外的安全组，端口由系统防火墙（ufw）控制。安装脚本会自动处理 ufw，**通常无需手动操作**。

如果想提前确认或手动放行：

```bash
# 确认 ufw 状态
ufw status

# 手动放行端口（脚本会自动执行，一般不需要手动做）
ufw allow 443/tcp
ufw allow 22/tcp
ufw enable
```

> 💡 如果你在 Vultr 控制台的 **Settings → Firewall** 中绑定了 Firewall Group，则需要在那里额外放行端口，方法和阿里云安全组类似。

### 4. 连接服务器

**Windows 用户**请看下方「[连接服务器通用说明](#三连接服务器通用说明windows)」。

**Mac / Linux 用户**：

```bash
ssh root@<你的服务器IP>
# 输入 Vultr 控制台显示的 Password
```

连接成功后即可回到主文档，执行一键安装脚本。

---

## 三、连接服务器通用说明（Windows）

Windows 推荐使用 **PowerShell**（自带，无需安装）或 **Windows Terminal** 连接服务器，也可以使用图形化工具 PuTTY。

### 方法 A：PowerShell（推荐）

Windows 10 / 11 自带 OpenSSH 客户端，直接打开 PowerShell：

```powershell
ssh root@<你的服务器IP>
```

输入密码即可登录。第一次连接会提示 `Are you sure you want to continue connecting? (yes/no)`，输入 `yes` 回车。

### 方法 B：PuTTY（图形化）

1. 下载 PuTTY：[https://www.putty.org](https://www.putty.org)
2. 打开 PuTTY，在 **Host Name** 填入服务器 IP，**Port** 填 `22`，**Connection type** 选 SSH
3. 点击 **Open**，弹窗点击 **Accept**
4. 登录名输入 `root`，回车后输入密码

---

## 完成后

服务器连接成功后，回到 [主文档](../README.md) 执行一键安装脚本：

```bash
curl -O https://github.com/zeushera384/auto-xray-vpn/blob/main/xray-setup.sh
chmod +x xray-setup.sh
bash xray-setup.sh
```
