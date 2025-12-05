#!/bin/bash
################################################################################
# SNP Chain - 节点健康检查脚本
# 版本: 1.0.0
# 描述: 全面的验证者节点健康监控
################################################################################

# 配置
CHAIN_HOME="${CHAIN_HOME:-$HOME/.snp}"
RPC_PORT="${RPC_PORT:-26657}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-26660}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
ALERT_SLACK_WEBHOOK="${ALERT_SLACK_WEBHOOK:-}"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"

# 阈值
CPU_THRESHOLD="${CPU_THRESHOLD:-80}"  # CPU 使用率 %
MEMORY_THRESHOLD="${MEMORY_THRESHOLD:-80}"  # 内存使用率 %
DISK_THRESHOLD="${DISK_THRESHOLD:-85}"  # 磁盘使用率 %
MIN_PEERS="${MIN_PEERS:-3}"  # 最小对等节点数
MAX_BLOCK_LAG="${MAX_BLOCK_LAG:-50}"  # 最大区块滞后

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 状态码
STATUS_OK=0
STATUS_WARNING=1
STATUS_CRITICAL=2
STATUS_UNKNOWN=3

OVERALL_STATUS=$STATUS_OK

################################################################################
# 日志函数
################################################################################

log_ok() {
    echo -e "${GREEN}[✓ 正常]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[⚠ 警告]${NC} $1"
    if [ $OVERALL_STATUS -lt $STATUS_WARNING ]; then
        OVERALL_STATUS=$STATUS_WARNING
    fi
}

log_critical() {
    echo -e "${RED}[✗ 严重]${NC} $1"
    if [ $OVERALL_STATUS -lt $STATUS_CRITICAL ]; then
        OVERALL_STATUS=$STATUS_CRITICAL
    fi
}

log_info() {
    echo -e "${BLUE}[ℹ 信息]${NC} $1"
}

log_unknown() {
    echo -e "${BLUE}[? 未知]${NC} $1"
    if [ $OVERALL_STATUS -lt $STATUS_UNKNOWN ]; then
        OVERALL_STATUS=$STATUS_UNKNOWN
    fi
}

################################################################################
# 检查函数
################################################################################

# 检查进程是否运行
check_process() {
    log_info "检查 seid 进程..."
    
    if pgrep -x "seid" > /dev/null; then
        PID=$(pgrep -x "seid")
        UPTIME=$(ps -p $PID -o etime= | tr -d ' ')
        log_ok "seid 进程正在运行 (PID: $PID, 运行时间: $UPTIME)"
        return 0
    else
        log_critical "seid 进程未运行！"
        return 1
    fi
}

# 检查 RPC 响应
check_rpc() {
    log_info "检查 RPC 端点..."
    
    if ! command -v curl &> /dev/null; then
        log_unknown "curl 未安装，跳过 RPC 检查"
        return 1
    fi
    
    RPC_RESPONSE=$(curl -s --max-time 5 http://localhost:${RPC_PORT}/status 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$RPC_RESPONSE" ]; then
        log_ok "RPC 端点响应正常 (端口 $RPC_PORT)"
        return 0
    else
        log_critical "RPC 端点无响应！"
        return 1
    fi
}

# 检查同步状态
check_sync_status() {
    log_info "检查同步状态..."
    
    if ! command -v jq &> /dev/null; then
        log_unknown "jq 未安装，跳过同步检查"
        return 1
    fi
    
    STATUS=$(curl -s http://localhost:${RPC_PORT}/status 2>/dev/null)
    
    if [ -z "$STATUS" ]; then
        log_critical "无法获取节点状态"
        return 1
    fi
    
    CATCHING_UP=$(echo "$STATUS" | jq -r '.result.sync_info.catching_up')
    LATEST_BLOCK=$(echo "$STATUS" | jq -r '.result.sync_info.latest_block_height')
    LATEST_TIME=$(echo "$STATUS" | jq -r '.result.sync_info.latest_block_time')
    
    if [ "$CATCHING_UP" == "false" ]; then
        log_ok "节点已完全同步 (区块高度: $LATEST_BLOCK)"
    else
        log_warn "节点正在同步中... (当前高度: $LATEST_BLOCK)"
    fi
    
    # 检查最后区块时间
    if [ -n "$LATEST_TIME" ] && [ "$LATEST_TIME" != "null" ]; then
        BLOCK_TIME=$(date -d "$LATEST_TIME" +%s 2>/dev/null || echo "0")
        CURRENT_TIME=$(date +%s)
        TIME_DIFF=$((CURRENT_TIME - BLOCK_TIME))
        
        if [ $TIME_DIFF -lt 60 ]; then
            log_ok "最后区块时间: ${TIME_DIFF}秒前"
        elif [ $TIME_DIFF -lt 300 ]; then
            log_warn "最后区块时间: ${TIME_DIFF}秒前（有点旧）"
        else
            log_critical "最后区块时间: ${TIME_DIFF}秒前（可能已停止）"
        fi
    fi
    
    return 0
}

# 检查验证者状态
check_validator() {
    log_info "检查验证者状态..."
    
    STATUS=$(curl -s http://localhost:${RPC_PORT}/status 2>/dev/null)
    
    if [ -z "$STATUS" ]; then
        log_unknown "无法获取验证者状态"
        return 1
    fi
    
    VOTING_POWER=$(echo "$STATUS" | jq -r '.result.validator_info.voting_power')
    ADDRESS=$(echo "$STATUS" | jq -r '.result.validator_info.address')
    
    if [ "$VOTING_POWER" == "0" ] || [ "$VOTING_POWER" == "null" ]; then
        log_info "节点不是活跃验证者（投票权: 0）"
    else
        log_ok "验证者活跃 (投票权: $VOTING_POWER, 地址: $ADDRESS)"
    fi
    
    return 0
}

# 检查对等节点数量
check_peers() {
    log_info "检查对等节点..."
    
    NET_INFO=$(curl -s http://localhost:${RPC_PORT}/net_info 2>/dev/null)
    
    if [ -z "$NET_INFO" ]; then
        log_unknown "无法获取网络信息"
        return 1
    fi
    
    N_PEERS=$(echo "$NET_INFO" | jq -r '.result.n_peers')
    
    if [ -n "$N_PEERS" ] && [ "$N_PEERS" != "null" ]; then
        if [ $N_PEERS -ge $MIN_PEERS ]; then
            log_ok "对等节点数: $N_PEERS (>= $MIN_PEERS)"
        else
            log_warn "对等节点数较少: $N_PEERS (< $MIN_PEERS)"
        fi
    else
        log_unknown "无法获取对等节点数"
    fi
    
    return 0
}

# 检查 CPU 使用率
check_cpu() {
    log_info "检查 CPU 使用率..."
    
    if command -v top &> /dev/null; then
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
        CPU_USAGE=${CPU_USAGE%.*}  # 转换为整数
        
        if [ $CPU_USAGE -lt $CPU_THRESHOLD ]; then
            log_ok "CPU 使用率: ${CPU_USAGE}% (< ${CPU_THRESHOLD}%)"
        else
            log_warn "CPU 使用率过高: ${CPU_USAGE}% (>= ${CPU_THRESHOLD}%)"
        fi
    else
        log_unknown "无法检查 CPU 使用率（top 未安装）"
    fi
    
    return 0
}

# 检查内存使用率
check_memory() {
    log_info "检查内存使用率..."
    
    if command -v free &> /dev/null; then
        MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
        
        if [ $MEMORY_USAGE -lt $MEMORY_THRESHOLD ]; then
            log_ok "内存使用率: ${MEMORY_USAGE}% (< ${MEMORY_THRESHOLD}%)"
        else
            log_warn "内存使用率过高: ${MEMORY_USAGE}% (>= ${MEMORY_THRESHOLD}%)"
        fi
    else
        log_unknown "无法检查内存使用率（free 未安装）"
    fi
    
    return 0
}

# 检查磁盘使用率
check_disk() {
    log_info "检查磁盘使用率..."
    
    if [ -d "$CHAIN_HOME" ]; then
        DISK_USAGE=$(df "$CHAIN_HOME" | tail -1 | awk '{print $5}' | sed 's/%//')
        
        if [ $DISK_USAGE -lt $DISK_THRESHOLD ]; then
            log_ok "磁盘使用率: ${DISK_USAGE}% (< ${DISK_THRESHOLD}%)"
        else
            log_critical "磁盘使用率过高: ${DISK_USAGE}% (>= ${DISK_THRESHOLD}%)"
        fi
    else
        log_unknown "链目录不存在: $CHAIN_HOME"
    fi
    
    return 0
}

# 检查日志错误
check_logs() {
    log_info "检查最近的错误日志..."
    
    if [ -f "$CHAIN_HOME/seid.log" ]; then
        ERROR_COUNT=$(tail -n 1000 "$CHAIN_HOME/seid.log" | grep -i "error" | wc -l)
        
        if [ $ERROR_COUNT -eq 0 ]; then
            log_ok "最近 1000 行日志中没有错误"
        elif [ $ERROR_COUNT -lt 10 ]; then
            log_warn "最近 1000 行日志中发现 $ERROR_COUNT 个错误"
        else
            log_critical "最近 1000 行日志中发现大量错误: $ERROR_COUNT"
        fi
    else
        log_info "未找到日志文件，尝试使用 journalctl..."
        
        if command -v journalctl &> /dev/null; then
            ERROR_COUNT=$(journalctl -u snp-node -n 1000 --no-pager | grep -i "error" | wc -l)
            
            if [ $ERROR_COUNT -eq 0 ]; then
                log_ok "systemd 日志中没有错误"
            elif [ $ERROR_COUNT -lt 10 ]; then
                log_warn "systemd 日志中发现 $ERROR_COUNT 个错误"
            else
                log_critical "systemd 日志中发现大量错误: $ERROR_COUNT"
            fi
        else
            log_unknown "无法检查日志"
        fi
    fi
    
    return 0
}

################################################################################
# 告警函数
################################################################################

send_alert() {
    MESSAGE="$1"
    SEVERITY="$2"
    
    # 电子邮件告警
    if [ -n "$ALERT_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$MESSAGE" | mail -s "SNP Chain 告警: $SEVERITY" "$ALERT_EMAIL"
    fi
    
    # Slack 告警
    if [ -n "$ALERT_SLACK_WEBHOOK" ] && command -v curl &> /dev/null; then
        curl -X POST "$ALERT_SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"$MESSAGE\"}" \
            2>/dev/null
    fi
    
    # 自定义 Webhook
    if [ -n "$ALERT_WEBHOOK" ] && command -v curl &> /dev/null; then
        curl -X POST "$ALERT_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"message\":\"$MESSAGE\",\"severity\":\"$SEVERITY\"}" \
            2>/dev/null
    fi
}

################################################################################
# 主健康检查
################################################################################

echo "========================================"
echo "SNP Chain 节点健康检查"
echo "========================================"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "主机: $(hostname)"
echo "========================================"
echo ""

# 运行所有检查
check_process
check_rpc
check_sync_status
check_validator
check_peers
check_cpu
check_memory
check_disk
check_logs

echo ""
echo "========================================"
echo "健康检查摘要"
echo "========================================"

# 确定整体状态
case $OVERALL_STATUS in
    $STATUS_OK)
        echo -e "${GREEN}整体状态: ✓ 健康${NC}"
        ;;
    $STATUS_WARNING)
        echo -e "${YELLOW}整体状态: ⚠ 警告${NC}"
        send_alert "SNP Chain 节点健康检查警告
主机: $(hostname)
时间: $(date)
请检查节点状态。" "WARNING"
        ;;
    $STATUS_CRITICAL)
        echo -e "${RED}整体状态: ✗ 严重${NC}"
        send_alert "SNP Chain 节点健康检查严重问题！
主机: $(hostname)
时间: $(date)
需要立即关注！" "CRITICAL"
        ;;
    $STATUS_UNKNOWN)
        echo -e "${BLUE}整体状态: ? 未知${NC}"
        ;;
esac

echo "========================================"
echo ""

# 退出码
exit $OVERALL_STATUS
