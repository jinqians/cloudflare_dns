# Cloudflare DNS Failover System

An intelligent DNS failover solution based on Cloudflare API that supports automatic switching between primary and backup VPS servers, working seamlessly even with Cloudflare proxy (orange cloud) enabled.

## 🌟 Key Features

- **Intelligent Health Monitoring**: Health checks based on TCP ports and HTTP status codes
- **Automatic Failover**: Seamless switching to backup VPS when primary server fails
- **Cloudflare Proxy Compatible**: Failover works perfectly with Cloudflare proxy mode enabled
- **Telegram Notifications**: Automatic notifications when IP addresses change
- **Comprehensive Logging**: Detailed operation logs for easy troubleshooting
- **Configuration Management**: Support for configuration files to avoid repetitive input
- **Cron Job Integration**: Perfect integration with crontab for scheduled execution

## 🚀 Quick Start

### 1. Download the Script
```bash
wget https://raw.githubusercontent.com/jinqians/cloudflare_dns/refs/heads/main/dns_switch.sh && chmod +x dns_switch.sh
```

### 2. Initial Configuration
```bash
./dns_switch.sh
```
The script will guide you through all configurations:
- Cloudflare API Token
- Domain and DNS records
- Primary and backup VPS information
- Telegram Bot configuration (optional)

### 3. Test Run
```bash
./dns_switch.sh
```
The script will automatically detect VPS status and perform failover operations.

## 📋 Configuration Guide

### Cloudflare Configuration
- **API Token**: Must include Zone:Zone:Read and Zone:DNS:Edit permissions
- **Zone ID**: Domain zone ID obtained from Cloudflare dashboard
- **Record ID**: DNS record ID obtained from the DNS record details page
- **Record Name**: DNS record name (e.g., www.example.com or example.com)

#### Quick Guide to Get Zone ID and Record ID
**Get Zone ID:**
```bash
# Replace with your domain and API Token
curl -X GET "https://api.cloudflare.com/client/v4/zones?name=${example.com}" \
  -H "Authorization: Bearer ${YOUR_API_TOKEN}" \
  -H "Content-Type: application/json" | jq '.result[0].id'
```

**Get Record ID:**
```bash
# Replace with your Zone ID, record name, and API Token
curl -X GET "https://api.cloudflare.com/client/v4/zones/${YOUR_ZONE_ID}/dns_records?name=${www.example.com}" \
  -H "Authorization: Bearer ${YOUR_API_TOKEN}" \
  -H "Content-Type: application/json" | jq '.result[0].id'
```

**One-Click ID Retrieval Script:**
```bash
#!/bin/bash
# Save as get_cf_ids.sh
DOMAIN="example.com"
RECORD_NAME="www"
API_TOKEN="YOUR_API_TOKEN"

echo "Getting Zone ID for $DOMAIN..."
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

echo "Zone ID: $ZONE_ID"

echo "Getting Record ID for $RECORD_NAME.$DOMAIN..."
RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME.$DOMAIN" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

echo "Record ID: $RECORD_ID"
```

### VPS Configuration
- **Primary VPS**: Priority server IP and port
- **Backup VPS**: Backup server IP and port for failover scenarios
- **Health Check Port**: Port used for health monitoring (e.g., 80, 443)
- **HTTP Path**: Path for HTTP status checks (e.g., /)

### Telegram Configuration (Optional)
- **Bot Token**: Telegram Bot API Token
- **Chat ID**: Chat ID for receiving notifications

## 🔧 How It Works

### Health Monitoring Mechanism
1. **TCP Connection Check**: Verifies if specified ports are accessible
2. **HTTP Status Check**: Validates HTTP response status codes
3. **Dual Verification**: Ensures services are truly available

### Failover Process
```
Primary VPS Check → Failed → Check Backup VPS → Success → Update DNS Record → Send Notification
    ↓
  Success → Check DNS Record → Update Needed → Update DNS Record → Send Notification
    ↓
  No Update Needed → Complete
```

### Cloudflare Proxy Mode Support
The script works perfectly even with Cloudflare proxy (orange cloud) enabled:
- Directly monitors source server IPs
- Bypasses Cloudflare proxy layer
- Ensures accurate failover operations

## 📊 Logging System

### Log Format
```
========== Health Check Started ==========
Time: 2024-01-01 12:00:00
Primary VPS Status: Healthy
Backup VPS Status: Healthy
Current DNS IP: 1.2.3.4
Target IP: 1.2.3.4
Action: No Update Required
========== Health Check Completed ==========
```

### Log Locations
- **Default Path**: `/var/log/dns_switch.log`
- **Configurable**: Custom path in configuration file
- **Auto Cleanup**: Regular cleanup of old log entries

## ⏰ Scheduled Execution

### Crontab Configuration
```bash
# Check every 5 minutes
*/5 * * * * /path/to/dns_switch.sh >> /root/failover.log 2>&1
```

### Recommended Frequencies
- **High Availability**: Check every 1-2 minutes
- **Standard Usage**: Check every 5 minutes
- **Low Frequency**: Check every 10-15 minutes

## 🔍 Troubleshooting

### Common Issues

#### 1. API Token Error
```
Error: Cloudflare API authentication failed
Solution: Check API Token permissions and format
```

#### 2. DNS Record Not Found
```
Error: Specified DNS record not found
Solution: Verify domain and record name are correct
```

#### 3. VPS Connection Timeout
```
Error: Unable to connect to VPS
Solution: Check firewall settings and port accessibility
```

### Debug Mode
```bash
# Enable verbose output
DEBUG=1 ./dns_switch.sh
```

## 📱 Telegram Notifications

### Notification Content
- **IP Changes**: Detailed notifications when records are switched
- **Failure Detection**: Notifications when primary VPS fails
- **Recovery Notifications**: Notifications when primary VPS recovers

### Notification Format
```
🔄 DNS Failover Notification

📊 Status Change: Primary VPS → Backup VPS
🌐 Domain: example.com
📝 Record: www
🔗 New IP: 2.3.4.5
⏰ Time: 2024-01-01 12:00:00
```

## 🛡️ Security Considerations

### API Token Security
- Follow principle of least privilege
- Rotate tokens regularly
- Limit token usage scope

### Network Security
- Use HTTPS for API communications
- Restrict VPS access sources
- Keep script versions updated

## 📈 Performance Optimization

### Monitoring Optimization
- Parallel monitoring of primary and backup VPS
- Set reasonable timeout values
- Cache DNS query results

### Resource Usage
- Lightweight script design
- Minimal system resource consumption
- Efficient log management

## 🔄 Version Updates

### Current Version
- **Version**: 2.0
- **Update Date**: 2025-07-20
- **Key Features**: Cloudflare proxy support, Telegram notifications, configuration management

### Changelog
- ✅ Added Cloudflare proxy mode support
- ✅ Implemented Telegram notification functionality
- ✅ Added configuration file support
- ✅ Improved logging system
- ✅ Optimized health monitoring logic

### Issue Reporting
- Submit issues to GitHub repository
- Provide detailed error logs
- Include system environment and configuration details

### Contributing
- Fork the project repository
- Create feature branches
- Submit Pull Requests

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for details.

---

**Note**: Please ensure you have a Cloudflare account with appropriate API permissions before using this script. We recommend testing the configuration in a test environment first to verify everything works correctly.
