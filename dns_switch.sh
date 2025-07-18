#!/bin/bash

# ====== 交互输入 ======

read -p "请输入主站 VPS IP: " PRIMARY_IP
read -p "请输入备用 VPS IP: " BACKUP_IP
read -p "请输入检测端口（默认80）: " PORT
PORT=${PORT:-80}
read -p "请输入保留日志时间（小时，默认2小时）: " LOG_HOURS
LOG_HOURS=${LOG_HOURS:-2}
read -p "请输入 Cloudflare Zone ID: " ZONE_ID
read -p "请输入 Cloudflare DNS 记录 ID: " RECORD_ID
read -p "请输入 DNS 记录名（例如 vps.jinqians.com）: " RECORD_NAME
read -s -p "请输入 Cloudflare API Token（输入时不显示）: " API_TOKEN
echo

# 日志文件路径
LOG_FILE="/tmp/dns_switch.log"

# ========== 日志清理 ==========
cleanup_logs() {
  echo "🧹 清理 $LOG_HOURS 小时前的日志记录..."
  if [ -f "$LOG_FILE" ]; then
    awk -v limit="$(date -d "-$LOG_HOURS hours" +"%Y-%m-%d %H:%M:%S")" '$0 ~ /^[0-9\-]+ [0-9:]+/ { if ($0 >= limit) print }' "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
}

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# ========== 依赖检查函数 ==========
check_install() {
  local cmd=$1
  local pkg=$2
  if ! command -v $cmd &>/dev/null; then
    log "⚠️ 未检测到 $cmd ，正在安装 $pkg ..."
    sudo apt update
    sudo apt install -y $pkg
  else
    log "✅ $cmd 已安装"
  fi
}

check_install nc netcat
check_install curl curl
check_install jq jq

# ========== TCP端口检测 ==========
check_tcp_port() {
  local ip=$1
  nc -z -w 3 $ip $PORT
  return $?
}

# ========== HTTP状态码检测 ==========
check_http() {
  local ip=$1
  local url="http://$ip/"
  local code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 $url)
  if [ "$code" == "200" ]; then
    return 0
  else
    return 1
  fi
}

# ========== VPS综合检测 ==========
check_vps() {
  local ip=$1
  log "🔍 检测 VPS $ip TCP端口 $PORT ..."
  check_tcp_port $ip
  if [ $? -ne 0 ]; then
    log "❌ TCP端口检测失败"
    return 1
  fi
  log "✅ TCP端口检测通过，开始HTTP检测..."
  check_http $ip
  if [ $? -ne 0 ]; then
    log "❌ HTTP检测失败"
    return 1
  fi
  log "✅ HTTP检测通过"
  return 0
}

# ========== 获取当前 DNS 记录 IP ==========
get_current_ip() {
  curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" | jq -r '.result.content'
}

# ========== 更新 DNS 记录 IP ==========
update_dns_ip() {
  local new_ip=$1
  log "🔄 更新 DNS 记录 $RECORD_NAME 指向 IP $new_ip"
  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{
      "type":"A",
      "name":"""$RECORD_NAME""",
      "content":"""$new_ip""",
      "ttl":120,
      "proxied":true
    }'
  log "✅ DNS 更新请求已发送"
}

# ========== 主流程 ==========
main() {
  cleanup_logs
  check_vps $PRIMARY_IP
  if [ $? -eq 0 ]; then
    TARGET_IP=$PRIMARY_IP
    log "✅ 选择主站 VPS"
  else
    log "⚠️ 主站 VPS 不可用，检测备用 VPS"
    check_vps $BACKUP_IP
    if [ $? -eq 0 ]; then
      TARGET_IP=$BACKUP_IP
      log "✅ 选择备用 VPS"
    else
      log "❌ 主站和备用 VPS 都不可用，退出"
      exit 1
    fi
  fi

  CURRENT_IP=$(get_current_ip)
  log "ℹ️ 当前 DNS IP: $CURRENT_IP"
  if [ "$CURRENT_IP" != "$TARGET_IP" ]; then
    update_dns_ip $TARGET_IP
  else
    log "✅ DNS IP 已经是目标 IP，无需更新"
  fi
}

main
