#!/bin/bash
################################################################################
# SNP Chain - 额外验证者节点部署脚本
# 版本: 1.0.0
# 描述: 部署额外验证者节点（非创世节点）
# 
# 使用场景:
# - 链已经在运行
# - 您想添加新验证者到网络
# - 您有现有网络的 genesis.json 文件
################################################################################

set -e
set -u

# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[步骤]${NC} $1"
}

################################################################################
# 加载配置
################################################################################

if [ ! -f "config/validator.env" ]; then
    log_error "找不到配置文件: config/validator.env"
    log_info "请复制 config/validator.env.example 并自定义配置"
    exit 1
fi

source config/validator.env

log_info "配置加载成功"

################################################################################
# 验证配置
################################################################################

if [ -z "${CHAIN_ID:-}" ]; then
    log_error "CHAIN_ID 未设置"
    exit 1
fi

if [ -z "${VALIDATOR_MONIKER:-}" ]; then
    log_error "VALIDATOR_MONIKER 未设置"
    exit 1
fi

if [ -z "${GENESIS_FILE_URL:-}" ] && [ ! -f "${GENESIS_FILE_PATH:-}" ]; then
    log_error "必须提供 GENESIS_FILE_URL 或 GENESIS_FILE_PATH"
    exit 1
fi

if [ -z "${SEEDS:-}" ] && [ -z "${PERSISTENT_PEERS:-}" ]; then
    log_warn "未配置种子节点或持久节点。您可能无法连接到网络。"
    read -p "仍要继续吗? (yes/no): " continue_confirm
    if [ "$continue_confirm" != "yes" ]; then
        exit 1
    fi
fi

# Python 命令检测
PYTHON_CMD=python3
if ! command -v $PYTHON_CMD &> /dev/null; then
    PYTHON_CMD=python
fi

# 检查 seid 二进制文件
if [ ! -f "$SEID_BINARY" ]; then
    log_error "找不到 seid 二进制文件: $SEID_BINARY"
    exit 1
fi

log_info "所有验证通过"

################################################################################
# 部署前检查
################################################################################

log_warn "========================================"
log_warn "验证者节点部署检查清单"
log_warn "========================================"
echo ""
read -p "是否已备份私钥? (yes/no): " backup_confirm
if [ "$backup_confirm" != "yes" ]; then
    log_error "请在继续之前备份密钥"
    exit 1
fi

read -p "服务器是否已正确加固? (yes/no): " security_confirm
if [ "$security_confirm" != "yes" ]; then
    log_warn "请在运行验证者节点前加固服务器"
    exit 1
fi

read -p "您是否有正确的 genesis.json 文件? (yes/no): " genesis_confirm
if [ "$genesis_confirm" != "yes" ]; then
    log_error "请从网络获取正确的 genesis.json"
    exit 1
fi

################################################################################
# 清理旧数据 (如果存在)
################################################################################

if [ -d "$CHAIN_HOME" ]; then
    log_warn "发现现有链数据: $CHAIN_HOME"
    read -p "删除现有数据并重新开始? (yes/no): " delete_confirm
    if [ "$delete_confirm" == "yes" ]; then
        log_info "删除旧链数据..."
        rm -rf $CHAIN_HOME
        log_info "旧数据已删除"
    else
        log_error "无法继续处理现有数据"
        exit 1
    fi
fi

################################################################################
# 初始化节点
################################################################################

log_step "步骤 1: 初始化节点"
log_info "链 ID: $CHAIN_ID"
log_info "验证者名称: $VALIDATOR_MONIKER"

$SEID_BINARY init $VALIDATOR_MONIKER --chain-id $CHAIN_ID --home $CHAIN_HOME

################################################################################
# 密钥管理
################################################################################

log_step "步骤 2: 设置验证者密钥"

$SEID_BINARY config keyring-backend $KEYRING_BACKEND --home $CHAIN_HOME

if [ "$CREATE_NEW_KEY" == "true" ]; then
    log_info "创建新验证者密钥: $VALIDATOR_KEY_NAME"
    log_warn "重要提示: 安全保存助记词！"
    echo ""
    $SEID_BINARY keys add $VALIDATOR_KEY_NAME --keyring-backend $KEYRING_BACKEND --home $CHAIN_HOME
    echo ""
    log_warn "密钥已创建。确保已备份助记词！"
    read -p "备份后按回车键继续..."
else
    log_info "请导入现有验证者密钥"
    log_info "运行: $SEID_BINARY keys add $VALIDATOR_KEY_NAME --recover --keyring-backend $KEYRING_BACKEND --home $CHAIN_HOME"
    read -p "导入密钥后按回车键..."
fi

VALIDATOR_ADDRESS=$($SEID_BINARY keys show $VALIDATOR_KEY_NAME -a --keyring-backend $KEYRING_BACKEND --home $CHAIN_HOME)
log_info "验证者地址: $VALIDATOR_ADDRESS"

################################################################################
# 获取 Genesis 文件
################################################################################

log_step "步骤 3: 获取 genesis 文件"

if [ -n "${GENESIS_FILE_URL:-}" ]; then
    log_info "从以下位置下载 genesis 文件: $GENESIS_FILE_URL"
    curl -L "$GENESIS_FILE_URL" -o "$CHAIN_HOME/config/genesis.json"
    
    if [ $? -eq 0 ]; then
        log_info "Genesis 文件下载成功"
    else
        log_error "Genesis 文件下载失败"
        exit 1
    fi
elif [ -f "${GENESIS_FILE_PATH:-}" ]; then
    log_info "从以下位置复制 genesis 文件: $GENESIS_FILE_PATH"
    cp "$GENESIS_FILE_PATH" "$CHAIN_HOME/config/genesis.json"
else
    log_error "未指定 genesis 文件源"
    exit 1
fi

# 验证 genesis 文件
log_info "验证 genesis 文件..."
$SEID_BINARY validate-genesis --home $CHAIN_HOME

if [ $? -eq 0 ]; then
    log_info "Genesis 文件验证成功"
else
    log_error "Genesis 文件验证失败"
    exit 1
fi

################################################################################
# 配置 app.toml
################################################################################

log_step "步骤 4: 配置 app.toml"

APP_TOML="$CHAIN_HOME/config/app.toml"

# 启用 OCC 和 SeiDB 以提高性能
sed -i.bak "s/concurrency-workers = .*/concurrency-workers = $CONCURRENCY_WORKERS/" $APP_TOML
sed -i.bak 's/occ-enabled = .*/occ-enabled = true/' $APP_TOML
sed -i.bak 's/sc-enable = .*/sc-enable = true/' $APP_TOML
sed -i.bak 's/ss-enable = .*/ss-enable = true/' $APP_TOML

# API 配置
if [ "$ENABLE_API" == "true" ]; then
    sed -i.bak 's/enable = false/enable = true/' $APP_TOML
fi
sed -i.bak 's/swagger = true/swagger = false/' $APP_TOML

# 启用 Prometheus
sed -i.bak 's/prometheus-retention-time = .*/prometheus-retention-time = 3600/' $APP_TOML

# gRPC 配置
sed -i.bak "s/address = \"0.0.0.0:9090\"/address = \"$GRPC_ADDRESS\"/" $APP_TOML

log_info "app.toml 配置完成"

################################################################################
# 配置 config.toml
################################################################################

log_step "步骤 5: 配置 config.toml"

CONFIG_TOML="$CHAIN_HOME/config/config.toml"

# 设置模式为验证者
sed -i.bak 's/mode = "full"/mode = "validator"/' $CONFIG_TOML

# 启用索引器
sed -i.bak 's/indexer = \["null"\]/indexer = \["kv"\]/' $CONFIG_TOML

# 配置种子节点和持久节点
if [ -n "${SEEDS:-}" ]; then
    log_info "配置种子节点..."
    sed -i.bak "s/seeds = \"\"/seeds = \"$SEEDS\"/" $CONFIG_TOML
fi

if [ -n "${PERSISTENT_PEERS:-}" ]; then
    log_info "配置持久节点..."
    sed -i.bak "s/persistent_peers = \"\"/persistent_peers = \"$PERSISTENT_PEERS\"/" $CONFIG_TOML
fi

# 连接限制
sed -i.bak "s/max_num_inbound_peers =.*/max_num_inbound_peers = $MAX_INBOUND_PEERS/" $CONFIG_TOML
sed -i.bak "s/max_num_outbound_peers =.*/max_num_outbound_peers = $MAX_OUTBOUND_PEERS/" $CONFIG_TOML

# 启用 PEX
sed -i.bak 's/pex = .*/pex = true/' $CONFIG_TOML

# RPC 配置
sed -i.bak "s/laddr = \"tcp:\/\/0.0.0.0:26657\"/laddr = \"tcp:\/\/$RPC_LISTEN_ADDRESS\"/" $CONFIG_TOML

# 禁用不安全的 RPC
sed -i.bak 's/unsafe = .*/unsafe = false/' $CONFIG_TOML

# CORS 配置
if [ -n "${CORS_ALLOWED_ORIGINS:-}" ]; then
    sed -i.bak "s/cors_allowed_origins = \[\]/cors_allowed_origins = $CORS_ALLOWED_ORIGINS/" $CONFIG_TOML
fi

# 启用 Prometheus
sed -i.bak 's/prometheus = .*/prometheus = true/' $CONFIG_TOML
sed -i.bak "s/prometheus_listen_addr = \":26660\"/prometheus_listen_addr = \"$PROMETHEUS_LISTEN_ADDRESS\"/" $CONFIG_TOML

# 日志级别
sed -i.bak "s/log_level = \"info\"/log_level = \"$LOG_LEVEL\"/" $CONFIG_TOML

log_info "config.toml 配置完成"

################################################################################
# State Sync 配置（可选但推荐）
################################################################################

if [ "$ENABLE_STATE_SYNC" == "true" ]; then
    log_step "步骤 6: 配置 State Sync（快速同步）"
    
    if [ -z "${STATE_SYNC_RPC_SERVERS:-}" ]; then
        log_warn "已启用 state sync 但未提供 RPC 服务器"
        log_warn "跳过 state sync 配置"
    else
        log_info "配置 state sync..."
        log_info "RPC 服务器: $STATE_SYNC_RPC_SERVERS"
        
        # 从 RPC 获取信任高度和哈希
        if [ -n "${STATE_SYNC_TRUST_HEIGHT:-}" ] && [ -n "${STATE_SYNC_TRUST_HASH:-}" ]; then
            TRUST_HEIGHT=$STATE_SYNC_TRUST_HEIGHT
            TRUST_HASH=$STATE_SYNC_TRUST_HASH
        else
            log_info "从 RPC 获取信任高度和哈希..."
            FIRST_RPC=$(echo $STATE_SYNC_RPC_SERVERS | cut -d',' -f1)
            LATEST_HEIGHT=$(curl -s "http://$FIRST_RPC/block" | jq -r .result.block.header.height)
            TRUST_HEIGHT=$((LATEST_HEIGHT - 1000))
            TRUST_HASH=$(curl -s "http://$FIRST_RPC/block?height=$TRUST_HEIGHT" | jq -r .result.block_id.hash)
            
            log_info "信任高度: $TRUST_HEIGHT"
            log_info "信任哈希: $TRUST_HASH"
        fi
        
        # 在 config.toml 中配置 state sync
        sed -i.bak "s/enable = false/enable = true/" $CONFIG_TOML
        sed -i.bak "s/rpc_servers = \"\"/rpc_servers = \"$STATE_SYNC_RPC_SERVERS\"/" $CONFIG_TOML
        sed -i.bak "s/trust_height = 0/trust_height = $TRUST_HEIGHT/" $CONFIG_TOML
        sed -i.bak "s/trust_hash = \"\"/trust_hash = \"$TRUST_HASH\"/" $CONFIG_TOML
        
        log_info "State sync 已配置 - 节点将从快照快速同步"
    fi
else
    log_info "State sync 已禁用 - 节点将从创世块同步（较慢）"
fi

################################################################################
# 创建备份
################################################################################

log_step "步骤 7: 创建初始备份"

BACKUP_DIR="$CHAIN_HOME/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR
cp $CHAIN_HOME/config/genesis.json $BACKUP_DIR/
cp $CHAIN_HOME/config/config.toml $BACKUP_DIR/
cp $CHAIN_HOME/config/app.toml $BACKUP_DIR/
cp $CHAIN_HOME/config/priv_validator_key.json $BACKUP_DIR/

log_info "备份创建于: $BACKUP_DIR"

################################################################################
# 总结和后续步骤
################################################################################

log_info "========================================"
log_info "验证者节点设置完成"
log_info "========================================"
echo ""
log_info "链 ID: $CHAIN_ID"
log_info "验证者名称: $VALIDATOR_MONIKER"
log_info "验证者地址: $VALIDATOR_ADDRESS"
log_info "链目录: $CHAIN_HOME"
echo ""
log_warn "========================================"
log_warn "重要的后续步骤"
log_warn "========================================"
echo ""
log_warn "1. 立即备份密钥！"
log_warn "   关键文件:"
log_warn "   - $CHAIN_HOME/config/priv_validator_key.json"
log_warn "   - 您的密钥环文件"
echo ""
log_warn "2. 启动节点:"
log_warn "   方式 A - 直接启动（用于测试）:"
log_warn "   $SEID_BINARY start --home $CHAIN_HOME"
echo ""
log_warn "   方式 B - Systemd 服务（推荐）:"
log_warn "   sudo systemctl start snp-node"
echo ""
log_warn "3. 等待同步完成:"
log_warn "   监控同步状态:"
log_warn "   curl -s http://localhost:26657/status | jq '.result.sync_info'"
echo ""
log_warn "4. 为验证者地址充值:"
log_warn "   您的地址: $VALIDATOR_ADDRESS"
log_warn "   在创建验证者之前需要代币！"
echo ""
log_warn "5. 创建验证者（同步并充值后）:"
log_warn "   运行 create-validator 命令:"
echo ""
cat << EOF
   $SEID_BINARY tx staking create-validator \\
     --amount=${VALIDATOR_STAKE}${DENOM} \\
     --pubkey=\$($SEID_BINARY tendermint show-validator --home $CHAIN_HOME) \\
     --moniker="$VALIDATOR_MONIKER" \\
     --chain-id=$CHAIN_ID \\
     --commission-rate="$COMMISSION_RATE" \\
     --commission-max-rate="$COMMISSION_MAX_RATE" \\
     --commission-max-change-rate="$COMMISSION_MAX_CHANGE_RATE" \\
     --min-self-delegation="$MIN_SELF_DELEGATION" \\
     --gas="auto" \\
     --gas-adjustment="1.5" \\
     --gas-prices="0.025${DENOM}" \\
     --from=$VALIDATOR_KEY_NAME \\
     --keyring-backend=$KEYRING_BACKEND \\
     --home=$CHAIN_HOME
EOF
echo ""
log_warn "6. 验证验证者已激活:"
log_warn "   $SEID_BINARY query staking validator \$($SEID_BINARY keys show $VALIDATOR_KEY_NAME --bech val -a --keyring-backend $KEYRING_BACKEND --home $CHAIN_HOME) --home $CHAIN_HOME"
echo ""
log_warn "========================================"
log_warn "安全提醒"
log_warn "========================================"
echo ""
log_warn "- 永远不要共享 priv_validator_key.json"
log_warn "- 保持多个加密备份"
log_warn "- 设置监控和告警"
log_warn "- 配置防火墙（允许 26656，限制 26657）"
log_warn "- 使用哨兵节点获得额外安全性"
echo ""
log_info "设置脚本执行成功完成！"
log_info "节点已准备好启动并与网络同步"
echo ""
