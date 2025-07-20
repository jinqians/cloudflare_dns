#!/bin/bash
# =========================================
# 作者: jinqians
# 日期: 2025年7月
# 网站：jinqians.com
# 描述: 这个脚本用于检测VPS状态，并根据状态切换DNS记录IP
# =========================================


# 配置文件路径
CONFIG_FILE="/etc/dns_switch.conf"

# 日志文件路径（临时定义，配置加载后会重新设置）
LOG_FILE="/var/log/dns_switch.log"

# ========== 基础日志函数 ==========
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# ========== 配置文件管理 ==========
load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    log "📋 加载配置文件: $CONFIG_FILE"
    source "$CONFIG_FILE"
    return 0
  else
    log "⚠️ 配置文件不存在，将进行交互式配置"
    return 1
  fi
}

save_config() {
  log "💾 保存配置到文件: $CONFIG_FILE"
  sudo mkdir -p "$(dirname "$CONFIG_FILE")"
  cat > "$CONFIG_FILE" << EOF
# DNS Switch 配置文件
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# VPS 配置
PRIMARY_IP="$PRIMARY_IP"
BACKUP_IP="$BACKUP_IP"
PORT="$PORT"

# 日志配置
LOG_FILE="$LOG_FILE"
LOG_HOURS="$LOG_HOURS"

# Cloudflare 配置
ZONE_ID="$ZONE_ID"
RECORD_ID="$RECORD_ID"
RECORD_NAME="$RECORD_NAME"
API_TOKEN="$API_TOKEN"

# Telegram 配置
ENABLE_TG="$ENABLE_TG"
TG_BOT_TOKEN="$TG_BOT_TOKEN"
TG_CHAT_ID="$TG_CHAT_ID"
EOF
  sudo chmod 600 "$CONFIG_FILE"
  log "✅ 配置文件已保存"
}

# ========== 交互输入 ==========
interactive_config() {
  echo "🔧 开始交互式配置..."
  
  read -p "请输入主站 VPS IP: " PRIMARY_IP
  read -p "请输入备用 VPS IP: " BACKUP_IP
  read -p "请输入检测端口（默认80）: " PORT
  PORT=${PORT:-80}
  read -p "请输入日志文件路径（默认/var/log/dns_switch.log）: " LOG_FILE
  LOG_FILE=${LOG_FILE:-/var/log/dns_switch.log}
  read -p "请输入保留日志时间（小时，默认2小时）: " LOG_HOURS
  LOG_HOURS=${LOG_HOURS:-2}
  read -p "请输入 Cloudflare Zone ID: " ZONE_ID
  read -p "请输入 Cloudflare DNS 记录 ID: " RECORD_ID
  read -p "请输入 DNS 记录名（例如 ex.a.com）: " RECORD_NAME
  read -s -p "请输入 Cloudflare API Token（输入时不显示）: " API_TOKEN
  echo

  # Telegram 配置（可选）
  read -p "是否启用 Telegram 通知？(y/n，默认n): " ENABLE_TG
  ENABLE_TG=${ENABLE_TG:-n}

  if [[ "$ENABLE_TG" == "y" || "$ENABLE_TG" == "Y" ]]; then
    read -p "请输入 Telegram Bot Token: " TG_BOT_TOKEN
    read -p "请输入 Telegram Chat ID: " TG_CHAT_ID
  else
    TG_BOT_TOKEN=""
    TG_CHAT_ID=""
  fi
  
  # 询问是否保存配置
  read -p "是否保存配置到文件？(y/n，默认y): " SAVE_CONFIG
  SAVE_CONFIG=${SAVE_CONFIG:-y}
  
  if [[ "$SAVE_CONFIG" == "y" || "$SAVE_CONFIG" == "Y" ]]; then
    save_config
  fi
}

# ========== 配置验证 ==========
validate_config() {
  local missing_vars=()
  
  # 检查必需变量
  [[ -z "$PRIMARY_IP" ]] && missing_vars+=("PRIMARY_IP")
  [[ -z "$BACKUP_IP" ]] && missing_vars+=("BACKUP_IP")
  [[ -z "$ZONE_ID" ]] && missing_vars+=("ZONE_ID")
  [[ -z "$RECORD_ID" ]] && missing_vars+=("RECORD_ID")
  [[ -z "$RECORD_NAME" ]] && missing_vars+=("RECORD_NAME")
  [[ -z "$API_TOKEN" ]] && missing_vars+=("API_TOKEN")
  
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "❌ 配置验证失败，缺少以下变量: ${missing_vars[*]}"
    return 1
  fi
  
  # 设置默认值
  PORT=${PORT:-80}
  LOG_FILE=${LOG_FILE:-/var/log/dns_switch.log}
  LOG_HOURS=${LOG_HOURS:-2}
  ENABLE_TG=${ENABLE_TG:-n}
  
  echo "✅ 配置验证通过"
  return 0
}

# ========== 主配置流程 ==========
# 尝试加载配置文件
if ! load_config || ! validate_config; then
  # 配置文件不存在或无效，进行交互式配置
  interactive_config
fi

# 最终验证
if ! validate_config; then
  echo "❌ 配置验证失败，请检查配置文件或重新运行脚本"
  exit 1
fi

# 重新设置日志文件路径（使用配置中的值）
LOG_FILE="${LOG_FILE:-/var/log/dns_switch.log}"

# 确保日志文件目录存在并可写
sudo mkdir -p "$(dirname "$LOG_FILE")"
sudo touch "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"

# 状态文件路径
STATUS_FILE="/tmp/dns_switch_status.json"

# ========== 状态管理函数 ==========
save_status() {
  local current_ip=$1
  local vps_status=$2
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  cat > "$STATUS_FILE" << EOF
{
  "current_ip": "$current_ip",
  "vps_status": "$vps_status",
  "last_update": "$timestamp",
  "primary_ip": "$PRIMARY_IP",
  "backup_ip": "$BACKUP_IP"
}
EOF
}

load_status() {
  if [ -f "$STATUS_FILE" ]; then
    local last_ip=$(jq -r '.current_ip' "$STATUS_FILE" 2>/dev/null)
    local last_status=$(jq -r '.vps_status' "$STATUS_FILE" 2>/dev/null)
    local last_update=$(jq -r '.last_update' "$STATUS_FILE" 2>/dev/null)
    
    if [[ "$last_ip" != "null" && "$last_status" != "null" ]]; then
      echo "$last_ip|$last_status|$last_update"
    fi
  fi
}

# ========== 日志清理 ==========
cleanup_logs() {
  log "🧹 清理 $LOG_HOURS 小时前的日志记录..."
  if [ -f "$LOG_FILE" ]; then
    awk -v limit="$(date -d "-$LOG_HOURS hours" +"%Y-%m-%d %H:%M:%S")" '$0 ~ /^[0-9\-]+ [0-9:]+/ { if ($0 >= limit) print }' "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
}

# ========== Telegram 通知函数 ==========
send_telegram_notification() {
  local message="$1"
  
  if [[ "$ENABLE_TG" == "y" || "$ENABLE_TG" == "Y" ]]; then
    if [[ -n "$TG_BOT_TOKEN" && -n "$TG_CHAT_ID" ]]; then
      log "📱 发送 Telegram 通知..."
      local encoded_message=$(echo "$message" | sed 's/"/\\"/g')
      local response=$(curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
        -H "Content-Type: application/json" \
        --data "{
          \"chat_id\": \"$TG_CHAT_ID\",
          \"text\": \"$encoded_message\",
          \"parse_mode\": \"HTML\"
        }")
      
      if echo "$response" | jq -e '.ok' > /dev/null; then
        log "✅ Telegram 通知发送成功"
      else
        log "❌ Telegram 通知发送失败: $(echo "$response" | jq -r '.description // "未知错误"')"
      fi
    else
      log "⚠️ Telegram 配置不完整，跳过通知"
    fi
  fi
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
      "name":"'"$RECORD_NAME"'",
      "content":"'"$new_ip"'",
      "ttl":120,
      "proxied":true
    }'
  log "✅ DNS 更新请求已发送"
}

# ========== 主流程 ==========
main() {
  cleanup_logs
  
  # 添加开始分隔线
  log "────────── 开始新的检查 ──────────"
  
  # 记录切换前的状态
  local previous_ip=$(get_current_ip)
  local vps_status=""
  local switch_reason=""
  
  # 加载上次状态
  local last_status=$(load_status)
  local last_ip=""
  local last_vps_status=""
  local last_update=""
  
  if [[ -n "$last_status" ]]; then
    IFS='|' read -r last_ip last_vps_status last_update <<< "$last_status"
    log "📋 上次状态: $last_vps_status VPS ($last_ip) - $last_update"
  fi
  
  log "🔍 开始检测 VPS 状态..."
  log "📱 当前 DNS 记录 IP: $previous_ip"
  
  # ========== 探测主站 VPS ==========
  check_vps $PRIMARY_IP
  if [ $? -eq 0 ]; then
    TARGET_IP=$PRIMARY_IP
    vps_status="主站"
    log "✅ 主站 VPS 可用，使用主站"
  else
    log "⚠️ 主站 VPS 不可用，检测备用 VPS"
    # ========== 探测备用 VPS ==========
    check_vps $BACKUP_IP
    if [ $? -eq 0 ]; then
      TARGET_IP=$BACKUP_IP
      vps_status="备用"
      log "✅ 备用 VPS 可用，切换到备用"
    else
      log "❌ 主站和备用 VPS 都不可用，退出"
      # 发送故障通知
      local error_message="🚨 <b>VPS 故障通知</b>

❌ 主站和备用 VPS 都不可用
🌐 域名: $RECORD_NAME
📱 当前 DNS IP: $previous_ip
📱 上次状态: $last_vps_status VPS ($last_ip)
⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')
🔍 检测端口: $PORT"
      send_telegram_notification "$error_message"
      
      # 添加分隔线
      log "────────── 检查异常结束 ──────────"
      exit 1
    fi
  fi

  # ========== 获取当前 DNS IP ==========
  CURRENT_IP=$(get_current_ip)
  log "ℹ️ 目标 IP: $TARGET_IP"
  log "ℹ️ 当前 DNS IP: $CURRENT_IP"
  
  # ========== 判断是否需要更新 ==========
  if [ "$CURRENT_IP" != "$TARGET_IP" ]; then
    log "🔄 DNS IP 与目标 IP 不一致，执行切换：$CURRENT_IP → $TARGET_IP"
    
    # 判断切换原因
    if [[ -n "$last_vps_status" && "$last_vps_status" == "备用" && "$vps_status" == "主站" ]]; then
      switch_reason="主站恢复，从备站切换回主站"
    elif [[ -n "$last_vps_status" && "$last_vps_status" == "主站" && "$vps_status" == "备用" ]]; then
      switch_reason="主站故障，切换到备站"
    else
      switch_reason="DNS记录与目标IP不匹配，进行切换"
    fi
    
    log "📝 切换原因: $switch_reason"
    
    update_dns_ip $TARGET_IP
    
    # 保存新状态
    save_status "$TARGET_IP" "$vps_status"
    
    # 发送IP切换通知
    local switch_message="🔄 <b>DNS IP 切换通知</b>

✅ VPS 状态: $vps_status VPS 正常
🌐 域名: $RECORD_NAME
📱 原 IP: $CURRENT_IP
📱 新 IP: $TARGET_IP
📝 切换原因: $switch_reason
📱 上次状态: $last_vps_status VPS ($last_ip)
⏰ 切换时间: $(date '+%Y-%m-%d %H:%M:%S')
🔍 检测端口: $PORT"
    
    send_telegram_notification "$switch_message"
    
    log "✅ DNS 切换完成，当前指向 $TARGET_IP"
  else
    log "✅ 当前 DNS IP 已是 $TARGET_IP，无需更新"
    log "📝 当前状态: $vps_status VPS 正常运行，DNS记录正确"
    
    # 即使没有切换，也更新状态文件（以防状态文件丢失）
    save_status "$CURRENT_IP" "$vps_status"
    
    # IP没有切换，不发送通知
  fi
  
  # 添加分隔线
  log "────────── 本次检查完成 ──────────"
}

main
