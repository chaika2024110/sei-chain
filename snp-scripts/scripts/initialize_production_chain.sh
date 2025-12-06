#!/bin/bash
################################################################################
# SNP Chain - 生产环境初始化脚本
# 版本: 1.0.0
# 描述: SNP 区块链安全生产环境部署脚本
################################################################################

set -e  # 遇到错误立即退出
set -u  # 使用未定义变量时退出

# 输出颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 日志函数
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

# 检查配置文件是否存在
if [ ! -f "config/production.env" ]; then
    log_error "找不到配置文件: config/production.env"
    log_info "请复制 config/production.env.example 并自定义配置"
    exit 1
fi

# 加载环境变量
source config/production.env

log_info "配置加载成功"

################################################################################
# 验证配置
################################################################################

# 验证必需变量
if [ -z "${CHAIN_ID:-}" ]; then
    log_error "CHAIN_ID 未设置"
    exit 1
fi

if [ -z "${VALIDATOR_MONIKER:-}" ]; then
    log_error "VALIDATOR_MONIKER 未设置"
    exit 1
fi

# 检测 Python 命令
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
log_warn "生产环境部署检查清单"
log_warn "========================================"
echo ""
read -p "是否已备份现有的密钥? (yes/no): " backup_confirm
if [ "$backup_confirm" != "yes" ]; then
    log_error "请先备份密钥再继续"
    exit 1
fi

read -p "服务器是否已正确加固? (yes/no): " security_confirm
if [ "$security_confirm" != "yes" ]; then
    log_warn "请在运行验证者节点前加固服务器"
    exit 1
fi

read -p "是否已审核代币经济学参数? (yes/no): " tokenomics_confirm
if [ "$tokenomics_confirm" != "yes" ]; then
    log_warn "请仔细审核配置文件中的所有参数"
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
# 初始化链
################################################################################

log_step "步骤 1: 初始化链"
log_info "链 ID: $CHAIN_ID"
log_info "验证者名称: $VALIDATOR_MONIKER"

$SEID_BINARY init $VALIDATOR_MONIKER --chain-id $CHAIN_ID --home $CHAIN_HOME

################################################################################
# 密钥管理
################################################################################

log_step "步骤 2: 设置密钥环"

# 设置密钥环后端
$SEID_BINARY config keyring-backend $KEYRING_BACKEND --home $CHAIN_HOME

# 关键安全检查
if [ "$KEYRING_BACKEND" == "test" ]; then
    log_error "========================================"
    log_error "严重安全警告！"
    log_error "========================================"
    log_error "密钥环后端设置为 'test'（未加密）"
    log_error "这在生产环境中极其不安全！"
    log_error ""
    log_error "生产环境必须使用:"
    log_error "  - 'file' (加密密钥环)"
    log_error "  - 'os' (系统密钥环)"
    log_error ""
    log_error "在 config/production.env 中更改 KEYRING_BACKEND"
    exit 1
fi

log_info "密钥环后端: $KEYRING_BACKEND ✓"

################################################################################
# 创建验证者密钥
################################################################################

log_step "步骤 3: 创建验证者密钥"
log_warn "重要提示: 安全保存助记词！"
echo ""
$SEID_BINARY keys add $VALIDATOR_KEY_NAME --keyring-backend $KEYRING_BACKEND --home $CHAIN_HOME
echo ""
log_warn "密钥已创建。确保已备份助记词！"
read -p "按回车键继续（备份后）..."

VALIDATOR_ADDRESS=$($SEID_BINARY keys show $VALIDATOR_KEY_NAME -a --keyring-backend $KEYRING_BACKEND --home $CHAIN_HOME)
log_info "验证者地址: $VALIDATOR_ADDRESS"

################################################################################
# 配置 genesis.json
################################################################################

log_step "步骤 4: 配置 genesis"

GENESIS_FILE="$CHAIN_HOME/config/genesis.json"

# 添加创世账户
log_info "添加创世账户..."
for ACCOUNT_CONFIG in "${GENESIS_ACCOUNTS[@]}"; do
    IFS=':' read -r ADDRESS BALANCE <<< "$ACCOUNT_CONFIG"
    log_info "  $ADDRESS: $BALANCE$DENOM"
    $SEID_BINARY add-genesis-account $ADDRESS ${BALANCE}${DENOM} --home $CHAIN_HOME
done

# 添加验证者账户余额
log_info "添加验证者账户: $VALIDATOR_ADDRESS"
$SEID_BINARY add-genesis-account $VALIDATOR_ADDRESS ${VALIDATOR_BALANCE}${DENOM} --home $CHAIN_HOME

# 设置代币释放时间表
#if [ ${#TOKEN_VESTING_SCHEDULES[@]} -gt 0 ]; then
#    log_info "设置代币释放时间表..."
#    for VESTING_CONFIG in "${TOKEN_VESTING_SCHEDULES[@]}"; do
#        IFS=':' read -r ADDRESS START END AMOUNT <<< "$VESTING_CONFIG"
#        log_info "  $ADDRESS: $AMOUNT$DENOM (从 $START 到 $END)"
#        $SEID_BINARY add-genesis-account $ADDRESS ${AMOUNT}${DENOM} \
#            --vesting-amount ${AMOUNT}${DENOM} \
#            --vesting-start-time $START \
#            --vesting-end-time $END \
#            --home $CHAIN_HOME
#    done
#fi

################################################################################
# 设置 Genesis 参数
################################################################################

log_step "步骤 5: 配置 genesis 参数"

# 治理参数
log_info "设置治理参数..."
jq ".app_state.gov.voting_params.voting_period = \"${VOTING_PERIOD}s\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
jq ".app_state.gov.deposit_params.max_deposit_period = \"${DEPOSIT_PERIOD}s\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
jq ".app_state.gov.deposit_params.min_deposit[0].amount = \"$MIN_DEPOSIT\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
jq ".app_state.gov.deposit_params.min_deposit[0].denom = \"$DENOM\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE

# Oracle 参数
log_info "设置 Oracle 参数..."
jq ".app_state.oracle.params.vote_period = \"$ORACLE_VOTE_PERIOD\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
jq ".app_state.oracle.params.vote_threshold = \"$ORACLE_VOTE_THRESHOLD\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE

# Staking 参数
log_info "设置 Staking 参数..."
jq ".app_state.staking.params.unbonding_time = \"${UNBONDING_TIME}s\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
jq ".app_state.staking.params.bond_denom = \"$DENOM\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
jq ".app_state.staking.params.max_validators = $MAX_VALIDATORS" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE

# Distribution 参数
log_info "设置 Distribution 参数..."
jq ".app_state.distribution.params.community_tax = \"$COMMUNITY_TAX\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE

# Mint 参数
log_info "设置 Mint 参数..."
jq ".app_state.mint.params.mint_denom = \"$DENOM\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
#jq ".app_state.mint.params.inflation_rate_change = \"$INFLATION_RATE_CHANGE\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
#jq ".app_state.mint.params.inflation_max = \"$INFLATION_MAX\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
#jq ".app_state.mint.params.inflation_min = \"$INFLATION_MIN\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE

# Crisis 参数
log_info "设置 Crisis 参数..."
jq ".app_state.crisis.constant_fee.denom = \"$DENOM\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE

# 共识参数
log_info "设置共识参数..."
jq ".consensus_params.block.time_iota_ms = \"$BLOCK_TIME_IOTA_MS\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
jq ".consensus_params.block.max_bytes = \"$MAX_BLOCK_SIZE\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
jq ".consensus_params.block.max_gas = \"$MAX_GAS\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
#jq ".consensus_params.evidence.max_age_duration = \"${UNBONDING_TIME}\"" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE
jq ".consensus_params.validator.pub_key_types = [\"ed25519\"]" $GENESIS_FILE > temp.json && mv temp.json $GENESIS_FILE

# 验证者投票权限制 - 关键安全参数！
log_info "设置验证者投票权限制..."
$PYTHON_CMD -c "
import json
with open('$GENESIS_FILE', 'r') as f:
    genesis = json.load(f)
if 'tendermint' in genesis['consensus_params']:
    genesis['consensus_params']['tendermint']['max_voting_power_ratio'] = '$MAX_VOTING_POWER_RATIO'
else:
    genesis['consensus_params']['max_voting_power_ratio'] = '$MAX_VOTING_POWER_RATIO'
with open('$GENESIS_FILE', 'w') as f:
    json.dump(genesis, f, indent=2)
"

if [ "$MAX_VOTING_POWER_RATIO" == "1.0" ]; then
    log_warn "========================================"
    log_warn "安全警告"
    log_warn "========================================"
    log_warn "max_voting_power_ratio 设置为 1.0"
    log_warn "这允许单个验证者拥有 100% 投票权"
    log_warn "生产环境推荐: 0.33 (33%)"
    log_warn ""
    read -p "确认继续? (yes/no): " power_confirm
    if [ "$power_confirm" != "yes" ]; then
        exit 1
    fi
fi

log_info "Genesis 参数配置完成"

################################################################################
# 创建 Gentx
################################################################################

log_step "步骤 6: 创建创世交易 (gentx)"

$SEID_BINARY  gentx $VALIDATOR_KEY_NAME \
    ${VALIDATOR_STAKE}${DENOM} \
    --chain-id=$CHAIN_ID \
    --moniker="$VALIDATOR_MONIKER" \
    --commission-rate="$COMMISSION_RATE" \
    --commission-max-rate="$COMMISSION_MAX_RATE" \
    --commission-max-change-rate="$COMMISSION_MAX_CHANGE_RATE" \
    --min-self-delegation="$MIN_SELF_DELEGATION" \
    --keyring-backend=$KEYRING_BACKEND \
    --home=$CHAIN_HOME

log_info "Gentx 创建成功"

################################################################################
# 收集 Gentx
################################################################################

log_step "步骤 7: 收集创世交易"

$SEID_BINARY  collect-gentxs --home $CHAIN_HOME

log_info "创世交易收集完成"

################################################################################
# 验证 Genesis
################################################################################

log_step "步骤 8: 验证 genesis 文件"

$SEID_BINARY validate-genesis --home $CHAIN_HOME

if [ $? -eq 0 ]; then
    log_info "Genesis 验证成功 ✓"
else
    log_error "Genesis 验证失败"
    exit 1
fi

################################################################################
# 配置 app.toml
################################################################################

log_step "步骤 9: 配置 app.toml"

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

log_info "app.toml 配置完成"

################################################################################
# 配置 config.toml
################################################################################

log_step "步骤 10: 配置 config.toml"

CONFIG_TOML="$CHAIN_HOME/config/config.toml"

# 设置模式为验证者
sed -i.bak 's/mode = "full"/mode = "validator"/' $CONFIG_TOML

# 禁用索引器以提高性能（生产环境）
sed -i.bak 's/indexer = \["kv"\]/indexer = \["null"\]/' $CONFIG_TOML

# RPC 配置
sed -i.bak 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' $CONFIG_TOML

# 禁用不安全的 RPC
sed -i.bak 's/unsafe = .*/unsafe = false/' $CONFIG_TOML

# CORS 配置
sed -i.bak 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["*"\]/' $CONFIG_TOML

# 启用 Prometheus
sed -i.bak 's/prometheus = .*/prometheus = true/' $CONFIG_TOML

# 日志级别
sed -i.bak 's/log_level = "info"/log_level = "error"/' $CONFIG_TOML

log_info "config.toml 配置完成"

################################################################################
# 创建备份
################################################################################

log_step "步骤 11: 创建初始备份"

BACKUP_DIR="$CHAIN_HOME/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR
cp $CHAIN_HOME/config/genesis.json $BACKUP_DIR/
cp $CHAIN_HOME/config/priv_validator_key.json $BACKUP_DIR/
cp $CHAIN_HOME/config/node_key.json $BACKUP_DIR/
cp $CHAIN_HOME/config/config.toml $BACKUP_DIR/
cp $CHAIN_HOME/config/app.toml $BACKUP_DIR/

log_info "备份创建于: $BACKUP_DIR"

################################################################################
# 总结和后续步骤
################################################################################

log_info "========================================"
log_info "初始化完成！"
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
log_warn "   - $CHAIN_HOME/config/node_key.json"
log_warn "   - 您的密钥环文件"
echo ""
log_warn "2. 将这些文件复制到安全位置!"
log_warn "   - 使用加密的离线存储"
log_warn "   - 多个备份位置"
log_warn "   - 测试恢复过程"
echo ""
log_warn "3. 启动节点:"
log_warn "   方式 A - 直接启动（用于测试）:"
log_warn "   $SEID_BINARY start --home $CHAIN_HOME"
echo ""
log_warn "   方式 B - Systemd 服务（推荐）:"
log_warn "   sudo systemctl start snp-node"
echo ""
log_warn "4. 验证节点正在运行:"
log_warn "   curl -s http://localhost:26657/status | jq"
echo ""
log_warn "5. 检查验证者状态:"
log_warn "   $SEID_BINARY query staking validators --home $CHAIN_HOME"
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
log_warn "- 定期测试灾难恢复程序"
echo ""
log_info "初始化脚本执行成功完成！"
log_info "链已准备好启动"
echo ""
