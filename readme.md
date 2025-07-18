# 🌐 VPS DNS 自动切换脚本

该脚本用于监控主站与备用 VPS 的可用性，并根据健康检查结果自动更新 Cloudflare 上的 DNS A 记录，确保网站始终保持可访问状态。支持用户交互输入、自定义检测端口、保留日志时长等功能。

---

## 🧰 功能特色

* ✅ 支持 **主/备 VPS IP 动态切换**
* ✅ 检测方式：TCP端口 + HTTP 状态码双重保障
* ✅ 自动更新 **Cloudflare DNS A 记录**
* ✅ 可交互设置参数，灵活方便
* ✅ 自动清理日志，仅保留最近 **N 小时内记录**

---

## ⚙️ 环境要求

支持以下系统：

* Ubuntu / Debian 等 Linux 系统

依赖工具：

* `curl`
* `jq`
* `nc`（netcat）

> 脚本会自动检测并安装缺失的依赖。

---

## 📥 使用方法

### 1. 下载脚本

```bash
snell.sh
wget https://raw.githubusercontent.com/jinqians/cloudflare_ddns/refs/heads/main/dns_switch.sh
chmod +x dns_switch.sh
```

### 2. 运行脚本

```bash
./dns_switch.sh
```

执行后将提示你输入以下信息：

| 参数说明                 | 示例                    |
| -------------------- | --------------------- |
| 主站 IP                | `192.168.1.10`        |
| 备用 IP                | `192.168.1.20`        |
| 检测端口（默认80）           | `443`                 |
| 保留日志时间（小时）           | `2`                   |
| Cloudflare Zone ID   | `23fd3f5a21c3dfaa...` |
| DNS 记录 ID            | `d2a83cbbd3fd92aa...` |
| DNS 域名               | `yourdomain.com`  |
| Cloudflare API Token | `输入时不会显示`             |

---

## 📄 日志说明

日志文件路径：

```
/tmp/dns_switch.log
```

默认保留最近 **2 小时内的记录**，可以通过运行时输入修改。

---

## 🔁 建议自动执行

搭配 `cron` 每 2 分钟执行一次，可实现持续自动切换：

```bash
crontab -e
```

添加：

```bash
*/2 * * * * /path/to/dns_switch.sh >> /tmp/dns_cron.log 2>&1
```

---

## 🛡️ 安全建议

* 建议将脚本部署在可信的 VPS 上
* Cloudflare API Token 请务必妥善保管，可使用 `dotenv` 文件或权限隔离方式调用

---

## 🧪 示例运行结果

```
🔍 检测 VPS 192.0.2.10 TCP端口 80 ...
✅ TCP端口检测通过，开始HTTP检测...
✅ HTTP检测通过
✅ 选择主站 VPS
ℹ️ 当前 DNS IP: 192.0.2.20
🔄 更新 DNS 记录 vps.example.com 指向 IP 192.0.2.10
✅ DNS 更新请求已发送
```

---

## 📌 注意事项

* 若主站不可用，备用 IP 会自动接管，恢复后自动切回
* DNS TTL 建议设置为较低值以加速切换生效
* 本脚本不更改系统 DNS，仅更新 Cloudflare 公网记录

---

## 📬 联系反馈

如有改进建议或问题欢迎反馈至作者邮箱或提交 Issue。
