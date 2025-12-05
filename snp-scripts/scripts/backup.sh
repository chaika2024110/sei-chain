#!/bin/bash
################################################################################
# SNP Chain - 自动备份脚本
# 版本: 1.0.0
# 描述: 验证者节点的全面备份解决方案
################################################################################

set -e

# 配置
CHAIN_HOME="${CHAIN_HOME:-$HOME/.snp}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/snp_backups}"
MAX_BACKUPS="${MAX_BACKUPS:-7}"  # 保留最近 7 个备份
BACKUP_CHAIN_DATA="${BACKUP_CHAIN_DATA:-false}"  # 备份整个链数据（慎用！）
ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"  # 用于加密的 GPG 密钥（可选）
REMOTE_BACKUP="${REMOTE_BACKUP:-false}"  # 启用远程备份
REMOTE_HOST="${REMOTE_HOST:-}"  # 远程主机（user@host）
REMOTE_DIR="${REMOTE_DIR:-/backup}"  # 远程备份目录

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[信息]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

################################################################################
# 前置检查
################################################################################

if [ ! -d "$CHAIN_HOME" ]; then
    log_error "链目录不存在: $CHAIN_HOME"
    exit 1
fi

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 生成备份标识符
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="snp_backup_${TIMESTAMP}"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

log_info "开始备份: $BACKUP_NAME"

################################################################################
# 创建备份目录结构
################################################################################

mkdir -p "$BACKUP_PATH"
log_info "创建备份目录: $BACKUP_PATH"

################################################################################
# 备份关键配置文件
################################################################################

log_info "备份配置文件..."

CONFIG_DIR="$BACKUP_PATH/config"
mkdir -p "$CONFIG_DIR"

# 关键文件列表
CRITICAL_FILES=(
    "config/priv_validator_key.json"
    "config/node_key.json"
    "config/genesis.json"
    "config/config.toml"
    "config/app.toml"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$CHAIN_HOME/$file" ]; then
        cp "$CHAIN_HOME/$file" "$CONFIG_DIR/"
        log_info "  ✓ $(basename $file)"
    else
        log_warn "  ✗ $(basename $file) - 未找到"
    fi
done

################################################################################
# 备份密钥环
################################################################################

log_info "备份密钥环..."

if [ -d "$CHAIN_HOME/keyring-file" ]; then
    cp -r "$CHAIN_HOME/keyring-file" "$BACKUP_PATH/"
    log_info "  ✓ 密钥环（file 后端）"
elif [ -d "$CHAIN_HOME/keyring-test" ]; then
    cp -r "$CHAIN_HOME/keyring-test" "$BACKUP_PATH/"
    log_warn "  ⚠ 密钥环（test 后端 - 不安全！）"
else
    log_warn "  ✗ 未找到密钥环目录"
fi

################################################################################
# 备份链数据（可选）
################################################################################

if [ "$BACKUP_CHAIN_DATA" == "true" ]; then
    log_warn "备份链数据（这可能需要很长时间）..."
    
    DATA_DIR="$BACKUP_PATH/data"
    mkdir -p "$DATA_DIR"
    
    if [ -d "$CHAIN_HOME/data" ]; then
        tar -czf "$DATA_DIR/chain_data.tar.gz" -C "$CHAIN_HOME" data
        log_info "  ✓ 链数据已压缩"
    else
        log_warn "  ✗ 数据目录未找到"
    fi
else
    log_info "跳过链数据备份（BACKUP_CHAIN_DATA=false）"
fi

################################################################################
# 创建备份清单
################################################################################

log_info "创建备份清单..."

MANIFEST="$BACKUP_PATH/MANIFEST.txt"
cat > "$MANIFEST" << EOF
SNP Chain 备份清单
==========================================
备份时间: $(date '+%Y-%m-%d %H:%M:%S')
主机名: $(hostname)
链目录: $CHAIN_HOME
备份名称: $BACKUP_NAME

关键文件:
EOF

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$CHAIN_HOME/$file" ]; then
        SIZE=$(du -h "$CHAIN_HOME/$file" | cut -f1)
        CHECKSUM=$(sha256sum "$CHAIN_HOME/$file" | cut -d' ' -f1)
        echo "  $(basename $file): $SIZE (SHA256: $CHECKSUM)" >> "$MANIFEST"
    fi
done

log_info "  ✓ 清单已创建"

################################################################################
# 生成校验和
################################################################################

log_info "生成校验和..."

cd "$BACKUP_PATH"
find . -type f -exec sha256sum {} \; > ../checksums_${TIMESTAMP}.txt
cd - > /dev/null

log_info "  ✓ 校验和已保存"

################################################################################
# 加密备份（可选）
################################################################################

if [ -n "$ENCRYPTION_KEY" ]; then
    log_info "加密备份..."
    
    if command -v gpg &> /dev/null; then
        tar -czf - -C "$BACKUP_DIR" "$BACKUP_NAME" | \
            gpg --encrypt --recipient "$ENCRYPTION_KEY" \
            > "${BACKUP_PATH}.tar.gz.gpg"
        
        if [ $? -eq 0 ]; then
            log_info "  ✓ 备份已加密: ${BACKUP_NAME}.tar.gz.gpg"
            
            # 删除未加密版本
            rm -rf "$BACKUP_PATH"
            BACKUP_PATH="${BACKUP_PATH}.tar.gz.gpg"
        else
            log_error "  ✗ 加密失败"
        fi
    else
        log_warn "  ✗ GPG 未安装，跳过加密"
    fi
else
    # 压缩未加密的备份
    log_info "压缩备份..."
    tar -czf "${BACKUP_PATH}.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME"
    
    if [ $? -eq 0 ]; then
        log_info "  ✓ 备份已压缩: ${BACKUP_NAME}.tar.gz"
        rm -rf "$BACKUP_PATH"
        BACKUP_PATH="${BACKUP_PATH}.tar.gz"
    fi
fi

################################################################################
# 远程备份（可选）
################################################################################

if [ "$REMOTE_BACKUP" == "true" ] && [ -n "$REMOTE_HOST" ]; then
    log_info "上传到远程服务器..."
    
    if command -v scp &> /dev/null; then
        scp "$BACKUP_PATH" "${REMOTE_HOST}:${REMOTE_DIR}/"
        
        if [ $? -eq 0 ]; then
            log_info "  ✓ 已上传到 $REMOTE_HOST:$REMOTE_DIR"
            
            # 可选：同步校验和
            scp "$BACKUP_DIR/checksums_${TIMESTAMP}.txt" "${REMOTE_HOST}:${REMOTE_DIR}/"
        else
            log_error "  ✗ 远程备份失败"
        fi
    else
        log_warn "  ✗ SCP 未安装，跳过远程备份"
    fi
else
    log_info "跳过远程备份（REMOTE_BACKUP=false）"
fi

################################################################################
# 清理旧备份
################################################################################

log_info "清理旧备份（保留最近 $MAX_BACKUPS 个）..."

cd "$BACKUP_DIR"
BACKUP_COUNT=$(ls -t snp_backup_*.tar.gz* 2>/dev/null | wc -l)

if [ $BACKUP_COUNT -gt $MAX_BACKUPS ]; then
    OLD_BACKUPS=$(ls -t snp_backup_*.tar.gz* | tail -n +$((MAX_BACKUPS + 1)))
    for old_backup in $OLD_BACKUPS; do
        rm -f "$old_backup"
        log_info "  ✗ 已删除旧备份: $old_backup"
    done
    
    # 清理旧校验和文件
    OLD_CHECKSUMS=$(ls -t checksums_*.txt 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)))
    for old_checksum in $OLD_CHECKSUMS; do
        rm -f "$old_checksum"
    done
fi

cd - > /dev/null

################################################################################
# 验证备份完整性
################################################################################

log_info "验证备份完整性..."

if [ -f "$BACKUP_PATH" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
    BACKUP_CHECKSUM=$(sha256sum "$BACKUP_PATH" | cut -d' ' -f1)
    
    log_info "  ✓ 备份大小: $BACKUP_SIZE"
    log_info "  ✓ SHA256: $BACKUP_CHECKSUM"
else
    log_error "  ✗ 备份文件未找到！"
    exit 1
fi

################################################################################
# 备份报告
################################################################################

log_info "========================================"
log_info "备份完成"
log_info "========================================"
log_info "备份名称: $BACKUP_NAME"
log_info "备份路径: $BACKUP_PATH"
log_info "备份大小: $BACKUP_SIZE"
log_info "校验和: $BACKUP_CHECKSUM"
log_info ""
log_info "备份包含:"
log_info "  ✓ 验证者密钥 (priv_validator_key.json)"
log_info "  ✓ 节点密钥 (node_key.json)"
log_info "  ✓ 创世文件 (genesis.json)"
log_info "  ✓ 配置文件 (config.toml, app.toml)"
log_info "  ✓ 密钥环"
if [ "$BACKUP_CHAIN_DATA" == "true" ]; then
    log_info "  ✓ 链数据"
fi
log_info ""

if [ -n "$ENCRYPTION_KEY" ]; then
    log_info "✓ 备份已加密"
fi

if [ "$REMOTE_BACKUP" == "true" ]; then
    log_info "✓ 备份已上传到远程服务器"
fi

log_info ""
log_warn "重要提醒:"
log_warn "  - 将此备份存储在安全的离线位置"
log_warn "  - 定期测试恢复过程"
log_warn "  - 永远不要共享 priv_validator_key.json"
log_warn "  - 保持多个备份副本在不同位置"
echo ""

################################################################################
# 恢复说明
################################################################################

log_info "恢复说明:"
log_info "----------------------------------------"

if [ -n "$ENCRYPTION_KEY" ]; then
    cat << EOF
1. 解密备份:
   gpg --decrypt ${BACKUP_NAME}.tar.gz.gpg > ${BACKUP_NAME}.tar.gz

2. 解压备份:
   tar -xzf ${BACKUP_NAME}.tar.gz

3. 停止节点:
   sudo systemctl stop snp-node

4. 恢复文件:
   cp -r ${BACKUP_NAME}/config/* $CHAIN_HOME/config/
   cp -r ${BACKUP_NAME}/keyring-* $CHAIN_HOME/

5. 启动节点:
   sudo systemctl start snp-node
EOF
else
    cat << EOF
1. 解压备份:
   tar -xzf ${BACKUP_NAME}.tar.gz

2. 停止节点:
   sudo systemctl stop snp-node

3. 恢复文件:
   cp -r ${BACKUP_NAME}/config/* $CHAIN_HOME/config/
   cp -r ${BACKUP_NAME}/keyring-* $CHAIN_HOME/

4. 启动节点:
   sudo systemctl start snp-node
EOF
fi

log_info "----------------------------------------"
log_info "备份脚本执行成功完成！"

exit 0
