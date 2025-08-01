# Cloudflare DNS 故障转移系统

一个基于Cloudflare API的智能DNS故障转移解决方案，支持主备VPS自动切换，即使在开启小黄云（Cloudflare代理）的情况下也能正常工作。

## 🌟 主要特性

- **智能故障检测**: 基于TCP端口和HTTP状态码的健康检查
- **自动故障转移**: 主VPS故障时自动切换到备用VPS
- **小黄云兼容**: 支持Cloudflare代理模式下的故障转移
- **Telegram通知**: IP变更时自动发送通知消息
- **详细日志记录**: 完整的操作日志，便于故障排查
- **配置化管理**: 支持配置文件，避免重复输入
- **定时任务支持**: 完美集成crontab定时执行

## 🚀 快速开始

### 1. 下载脚本
```bash
wget https://raw.githubusercontent.com/jinqians/cloudflare_dns/refs/heads/main/dns_switch.sh && chmod +x dns_switch.sh
```

### 2. 首次运行配置
```bash
./dns_switch.sh
```
脚本会引导您完成所有配置：
- Cloudflare API Token
- 域名和DNS记录
- 主备VPS信息
- Telegram Bot配置（可选）

### 3. 测试运行
```bash
./dns_switch.sh
```
脚本会自动检测VPS状态并执行故障转移。

## 📋 配置说明

### Cloudflare 配置
- **API Token**: 需要包含Zone:Zone:Read和Zone:DNS:Edit权限
- **Zone ID**: 在Cloudflare控制台获取的域名区域ID
- **Record ID**: 在DNS记录详情页获取的记录ID
- **记录名称**: DNS记录名称（如：www.a.com 或 a.com）

#### 快速获取Zone ID和Record ID
**获取Zone ID:**
```bash
# 替换为您的域名和API Token
curl -X GET "https://api.cloudflare.com/client/v4/zones?name=${example.com}" \
  -H "Authorization: Bearer ${YOUR_API_TOKEN}" \
  -H "Content-Type: application/json" | jq '.result[0].id'
```

**获取Record ID:**
```bash
# 替换为您的Zone ID、记录名称和API Token
curl -X GET "https://api.cloudflare.com/client/v4/zones/${YOUR_ZONE_ID}/dns_records?name=${www.example.com}" \
  -H "Authorization: Bearer ${YOUR_API_TOKEN}" \
  -H "Content-Type: application/json" | jq '.result[0].id'
```

**一键获取脚本:**
```bash
#!/bin/bash
# 保存为 get_cf_ids.sh
DOMAIN="example.com"
RECORD_NAME="www"
API_TOKEN="YOUR_API_TOKEN"

echo "获取 $DOMAIN 的Zone ID..."
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

echo "Zone ID: $ZONE_ID"

echo "获取 $RECORD_NAME.$DOMAIN 的Record ID..."
RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME.$DOMAIN" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

echo "Record ID: $RECORD_ID"
```


### VPS 配置
- **主VPS**: 优先使用的服务器IP和端口
- **备用VPS**: 故障时的备用服务器IP和端口
- **检测端口**: 用于健康检查的端口（如：80, 443）
- **HTTP路径**: 用于HTTP状态检查的路径（如：/）

### Telegram 配置（可选）
- **Bot Token**: Telegram Bot的API Token
- **Chat ID**: 接收通知的聊天ID

## 🔧 工作原理

### 故障检测机制
1. **TCP连接检测**: 检查指定端口是否可连接
2. **HTTP状态检测**: 验证HTTP响应状态码
3. **双重验证**: 确保服务真正可用

### 故障转移流程
```
主VPS检测 → 失败 → 检测备用VPS → 成功 → 更新DNS记录 → 发送通知
    ↓
  成功 → 检查DNS记录 → 需要更新 → 更新DNS记录 → 发送通知
    ↓
  无需更新 → 完成
```

### 小黄云模式支持
即使开启了Cloudflare代理（小黄云），脚本也能正常工作：
- 直接检测源服务器IP
- 绕过Cloudflare代理层
- 确保故障转移的准确性

## 📊 日志系统

### 日志格式
```
========== 开始检测 ==========
时间: 2024-01-01 12:00:00
主VPS状态: 正常
备用VPS状态: 正常
当前DNS IP: 1.2.3.4
目标IP: 1.2.3.4
操作: 无需更新
========== 检测完成 ==========
```

### 日志位置
- **默认路径**: `/var/log/dns_switch.log`
- **可配置**: 在配置文件中自定义路径
- **自动清理**: 定期清理旧日志记录

## ⏰ 定时执行

### Crontab 配置
```bash
# 每5分钟检查一次
*/5 * * * * /path/to/dns_switch.sh >> /root/failover.log 2>&1

```

### 推荐频率
- **高可用场景**: 每1-2分钟检查
- **一般场景**: 每5分钟检查
- **低频率场景**: 每10-15分钟检查

## 🔍 故障排查

### 常见问题

#### 1. API Token 错误
```
错误: Cloudflare API 认证失败
解决: 检查API Token权限和格式
```

#### 2. DNS记录不存在
```
错误: 找不到指定的DNS记录
解决: 确认域名和记录名称正确
```

#### 3. VPS连接超时
```
错误: 无法连接到VPS
解决: 检查防火墙设置和端口开放
```

### 调试模式
```bash
# 启用详细输出
DEBUG=1 ./dns_switch.sh
```

## 📱 Telegram 通知

### 通知内容
- **IP变更**: 记录切换时发送详细通知
- **故障检测**: 主VPS故障时通知
- **恢复通知**: 主VPS恢复时通知

### 通知格式
```
🔄 DNS故障转移通知

📊 状态变更: 主VPS → 备用VPS
🌐 域名: example.com
📝 记录: www
🔗 新IP: 2.3.4.5
⏰ 时间: 2024-01-01 12:00:00
```

## 🛡️ 安全考虑

### API Token 安全
- 使用最小权限原则
- 定期轮换Token
- 限制Token使用范围

### 网络安全
- 使用HTTPS进行API通信
- 限制VPS访问来源
- 定期更新脚本版本

## 📈 性能优化

### 检测优化
- 并行检测主备VPS
- 设置合理的超时时间
- 缓存DNS查询结果

### 资源使用
- 轻量级脚本设计
- 最小化系统资源占用
- 高效的日志管理

## 🔄 版本更新

### 当前版本
- **版本**: 2.0
- **更新日期**: 2025-07-20
- **主要特性**: 小黄云支持、Telegram通知、配置化管理

### 更新日志
- ✅ 支持Cloudflare代理模式
- ✅ 添加Telegram通知功能
- ✅ 配置文件支持
- ✅ 改进日志系统
- ✅ 优化故障检测逻辑

### 问题反馈
- 提交Issue到GitHub仓库
- 提供详细的错误日志
- 说明系统环境和配置

### 贡献代码
- Fork项目仓库
- 创建功能分支
- 提交Pull Request

## 📄 许可证

本项目采用MIT许可证，详见LICENSE文件。

---

**注意**: 使用前请确保您有Cloudflare账户和相应的API权限。建议在测试环境中先验证配置正确性。
