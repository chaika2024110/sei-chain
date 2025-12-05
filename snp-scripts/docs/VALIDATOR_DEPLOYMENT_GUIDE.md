# SNP Chain - 验证者节点部署指南

## 🎯 两种部署场景

### 场景 1: 创世节点（Genesis Node）
**什么时候使用**：
- ✅ 你正在启动一条**全新的链**
- ✅ 你是**第一个验证者**
- ✅ 需要创建 genesis.json 文件
- ✅ 需要定义代币经济学和初始参数

**使用脚本**：`scripts/initialize_production_chain.sh`  
**配置文件**：`config/production.env`

---

### 场景 2: 额外验证者节点（Additional Validator Node）
**什么时候使用**：
- ✅ 链**已经在运行**
- ✅ 你想**加入现有网络**作为新验证者
- ✅ 已经有 genesis.json 文件
- ✅ 需要连接到现有网络

**使用脚本**：`scripts/setup_validator_node.sh`  ⭐ **新增！**  
**配置文件**：`config/validator.env`  ⭐ **新增！**

---

## 📊 两种部署方式对比

| 方面 | 创世节点部署 | 额外验证者部署 |
|------|------------|-------------|
| **Genesis.json** | ✅ 创建新的 | ❌ 从网络获取现有的 |
| **网络状态** | 🆕 启动新链 | 🔗 加入现有网络 |
| **初始代币** | ✅ 在 genesis 中分配 | ❌ 需要后续获取 |
| **验证者创建** | ✅ 通过 gentx | ❌ 通过 create-validator 交易 |
| **同步需求** | ❌ 无需同步 | ✅ 必须同步到最新区块 |
| **种子节点** | ❌ 不需要 | ✅ 必需 |
| **State Sync** | ❌ 不适用 | ✅ 强烈推荐 |
| **部署时间** | 5-10 分钟 | 30 分钟 - 数小时（取决于同步） |

---

## 🚀 场景 1: 创世节点部署

### 适用情况
- 你在启动自己的 SNP 链
- 你是第一个验证者
- 你需要定义整个链的初始状态

### 快速步骤

```bash
# 1. 配置
cd config
cp production.env.example production.env
nano production.env

# 2. 运行初始化脚本
cd ..
./scripts/initialize_production_chain.sh

# 3. 启动节点
sudo systemctl start snp-node
```

### 详细文档
参考：`docs/DEPLOYMENT_GUIDE.md` 或 `QUICKSTART.md`

---

## 🌐 场景 2: 额外验证者部署（新增！）

### 适用情况
- 链已经在运行
- 你想成为第 2、3、4... 个验证者
- 你有现有网络的 genesis.json

### 完整步骤指南

#### 📋 准备阶段（必读！）

**1. 获取网络信息**

联系现有网络运营者或查看文档，获取：
- ✅ `genesis.json` 文件或下载 URL
- ✅ Chain ID（例如：`snp-mainnet-1`）
- ✅ 种子节点信息（node_id@ip:port）
- ✅ 持久节点信息
- ✅ RPC 端点（用于 state sync）
- ✅ 最低质押要求

**获取 genesis.json 的方式**：
```bash
# 方式 1: 从现有节点复制
scp user@node-ip:~/.snp/config/genesis.json ./

# 方式 2: 从 URL 下载
curl -L https://example.com/genesis.json -o genesis.json

# 方式 3: 从 GitHub 获取
wget https://raw.githubusercontent.com/YOUR_ORG/snp-chain/main/genesis.json
```

**获取节点 ID**：
```bash
# 在现有节点上运行
seid tendermint show-node-id --home ~/.snp

# 输出示例：8f3c8f9a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e
# 完整格式：8f3c8f9a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e@192.168.1.100:26656
```

**验证 genesis.json**：
```bash
# 计算 genesis 文件哈希
sha256sum genesis.json

# 与网络运营者确认哈希值匹配！
# 不匹配的 genesis 会导致无法连接到网络
```

---

#### ⚙️ 配置阶段

**1. 复制配置模板**
```bash
cd config
cp validator.env.example validator.env
```

**2. 编辑配置文件**
```bash
nano validator.env
```

**3. 关键配置项（必须修改！）**

```bash
# 链信息（必须与现有网络完全匹配）
CHAIN_ID="snp-mainnet-1"
VALIDATOR_MONIKER="my-validator-2"

# Genesis 文件
GENESIS_FILE_URL="https://example.com/genesis.json"
# 或
GENESIS_FILE_PATH="/path/to/genesis.json"

# 网络连接（至关重要！）
SEEDS="node1_id@seed1.example.com:26656,node2_id@seed2.example.com:26656"
PERSISTENT_PEERS="peer1_id@node1.example.com:26656,peer2_id@node2.example.com:26656"

# State Sync（强烈推荐）
ENABLE_STATE_SYNC="true"
STATE_SYNC_RPC_SERVERS="rpc1.example.com:26657,rpc2.example.com:26657"

# 验证者配置
VALIDATOR_STAKE="1000000000"
COMMISSION_RATE="0.10"
```

**配置检查清单**：
- [ ] CHAIN_ID 与网络匹配
- [ ] 至少配置了 2 个种子节点
- [ ] 至少配置了 2 个持久节点
- [ ] Genesis 文件 URL 或路径正确
- [ ] State sync RPC 端点可访问
- [ ] 验证者质押金额足够

---

#### 🔧 部署阶段

**1. 运行部署脚本**
```bash
cd ~/snp-production-deployment
chmod +x scripts/setup_validator_node.sh
./scripts/setup_validator_node.sh
```

脚本会：
1. ✅ 验证所有配置
2. ✅ 初始化节点
3. ✅ 创建/导入密钥
4. ✅ 获取 genesis.json
5. ✅ 配置网络连接
6. ✅ 设置 state sync
7. ✅ 创建初始备份

**2. 启动节点**

使用 systemd（推荐）：
```bash
# 配置 systemd 服务
sudo cp config/snp-node.service /etc/systemd/system/
sudo sed -i "s/YOUR_USERNAME/$USER/g" /etc/systemd/system/snp-node.service

# 启动服务
sudo systemctl daemon-reload
sudo systemctl enable snp-node
sudo systemctl start snp-node

# 查看日志
sudo journalctl -u snp-node -f
```

或直接启动（测试用）：
```bash
seid start --home ~/.snp
```

---

#### 🔄 同步阶段（重要！）

**1. 监控同步状态**

```bash
# 检查同步状态
curl -s localhost:26657/status | jq '.result.sync_info'

# 关键字段解释：
# - catching_up: true = 还在同步，false = 同步完成
# - latest_block_height: 当前区块高度
# - latest_block_time: 最新区块时间
```

**2. 等待同步完成**

```bash
# 持续监控（每5秒刷新）
watch -n 5 'curl -s localhost:26657/status | jq ".result.sync_info"'

# 检查节点连接
curl -s localhost:26657/net_info | jq '.result.n_peers'
# 应该显示至少 3 个对等节点
```

**同步时间估计**：
- 使用 State Sync：10-30 分钟
- 从 Genesis 同步：数小时到数天（取决于链的历史长度）

⚠️ **在同步完成前不要创建验证者！**

---

#### 💰 资金阶段

**1. 获取你的验证者地址**
```bash
seid keys show validator -a --keyring-backend file --home ~/.snp

# 输出示例：
# snp1abcdef1234567890abcdef1234567890abcdef
```

**2. 向地址转账**

需要获取代币来：
- 质押创建验证者
- 支付交易费用

**获取代币的方式**：
```bash
# 方式 1: 从其他账户转账
seid tx bank send \
  from-address \
  YOUR_VALIDATOR_ADDRESS \
  1000000000usnp \
  --chain-id snp-mainnet-1 \
  --gas auto \
  --gas-prices 0.025usnp

# 方式 2: 使用水龙头（如果是测试网）
# 访问水龙头网站并输入你的地址

# 方式 3: 联系团队成员
# 提供你的地址并请求初始代币
```

**3. 验证余额**
```bash
seid query bank balances YOUR_VALIDATOR_ADDRESS --home ~/.snp

# 应该显示：
# balances:
# - amount: "1000000000"
#   denom: usnp
```

---

#### 🎯 创建验证者阶段

**⚠️ 前提条件检查**：
- [ ] 节点已完全同步（catching_up: false）
- [ ] 有足够的代币余额（质押金额 + gas 费用）
- [ ] 已备份所有密钥
- [ ] 监控系统已配置

**1. 创建验证者交易**

```bash
# 基本命令
seid tx staking create-validator \
  --amount=1000000000usnp \
  --pubkey=$(seid tendermint show-validator --home ~/.snp) \
  --moniker="my-validator" \
  --chain-id=snp-mainnet-1 \
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1" \
  --gas="auto" \
  --gas-adjustment="1.5" \
  --gas-prices="0.025usnp" \
  --from=validator \
  --keyring-backend=file \
  --home=~/.snp
```

**参数说明**：
- `--amount`: 质押数量
- `--pubkey`: 验证者公钥（自动获取）
- `--moniker`: 验证者名称（公开可见）
- `--commission-rate`: 佣金率（你收取的费用）
- `--commission-max-rate`: 最大佣金率
- `--commission-max-change-rate`: 每天可更改的最大幅度
- `--min-self-delegation`: 最小自我委托

**2. 等待交易确认**

```bash
# 查询交易状态
seid query tx TX_HASH --home ~/.snp

# 或查看最新区块
curl -s localhost:26657/block | jq
```

**3. 验证验证者已创建**

```bash
# 获取验证者地址（valoper 地址）
VALOPER=$(seid keys show validator --bech val -a --keyring-backend file --home ~/.snp)

# 查询验证者信息
seid query staking validator $VALOPER --home ~/.snp

# 检查验证者状态
seid query staking validators --home ~/.snp | grep -A 10 "my-validator"
```

**4. 验证你在验证者集合中**

```bash
# 查看所有活跃验证者
seid query tendermint-validator-set --home ~/.snp

# 你的验证者应该出现在列表中
```

---

#### ✅ 后续维护

**1. 设置监控**
```bash
# 配置健康检查
crontab -e
# 添加：*/5 * * * * ~/snp-production-deployment/scripts/health_check.sh

# 配置自动备份
# 添加：0 3 * * * ~/snp-production-deployment/scripts/backup.sh
```

**2. 监控验证者状态**
```bash
# 检查验证者是否在线
curl -s localhost:26657/status | jq '.result.validator_info'

# 检查是否在签名
tail -f ~/.snp/seid.log | grep "Signed and published"

# 检查投票权
seid query staking validator $VALOPER --home ~/.snp | jq '.tokens'
```

**3. 避免双签**
⚠️ **永远不要**在两台服务器上同时运行相同的 priv_validator_key.json！
这会导致：
- 立即被罚没（slashing）
- 验证者被监禁（jailing）
- 损失质押代币

---

## 🆚 详细对比：两种脚本的区别

### initialize_production_chain.sh（创世节点）

**流程**：
1. 初始化链
2. 创建密钥
3. 创建 genesis 账户（添加到 genesis.json）
4. 创建 gentx（创世交易）
5. 收集 gentx
6. 配置 genesis 参数
7. 验证 genesis
8. 启动节点

**输出**：
- 新的 genesis.json
- 验证者已经在创世块中

---

### setup_validator_node.sh（额外验证者）⭐ 新增

**流程**：
1. 初始化节点
2. 创建密钥
3. **从网络获取** genesis.json
4. 配置网络连接（seeds, peers）
5. 配置 state sync（可选但推荐）
6. 启动节点并同步
7. **等待同步完成**
8. 获取代币
9. **发送 create-validator 交易**

**输出**：
- 使用现有 genesis.json
- 验证者通过交易创建（需要同步后）

---

## 🔧 常见问题

### Q: 我应该使用哪个脚本？

**A: 根据你的情况选择**：

- **启动新链** → 使用 `initialize_production_chain.sh`
- **加入现有网络** → 使用 `setup_validator_node.sh` ⭐

### Q: 可以用创世脚本加入现有网络吗？

**A: 不可以！**

创世脚本会创建新的 genesis.json，这会导致：
- Chain ID 不匹配
- 创世块哈希不同
- 无法连接到现有网络
- 实际上你会创建一条新链

### Q: State Sync 是必需的吗？

**A: 不是必需的，但强烈推荐**

- **使用 State Sync**: 10-30 分钟同步
- **不使用**: 可能需要数天同步（取决于链历史）

### Q: 我需要多少代币来创建验证者？

**A: 取决于你的配置**

```
所需代币 = 质押金额 + gas 费用
         = VALIDATOR_STAKE + ~10,000 usnp（gas）
```

例如：质押 1,000,000,000 usnp，至少需要 1,000,010,000 usnp

### Q: 创建验证者后多久能开始出块？

**A: 通常在 1-2 个区块周期后**

- 交易确认后，验证者加入活跃集合
- 需要等到下一个区块周期
- 开始接收委托和出块奖励

### Q: 如何知道我的验证者在正常工作？

**A: 检查以下指标**：

```bash
# 1. 验证者状态
seid query staking validator $VALOPER --home ~/.snp

# 2. 签名状态
curl -s localhost:26657/status | jq '.result.validator_info'

# 3. 最近签名
seid query slashing signing-info $(seid tendermint show-validator --home ~/.snp) --home ~/.snp
```

### Q: 能否将创世节点变成额外验证者？

**A: 不能直接转换**

创世节点已经有特定的配置和状态。如果需要：
1. 停止创世节点
2. 部署新的额外验证者节点
3. 使用不同的密钥

---

## 📚 相关文档

- **创世节点部署**: `QUICKSTART.md` 或 `docs/DEPLOYMENT_GUIDE.md`
- **验证者节点配置**: `config/validator.env.example`
- **安全检查清单**: `docs/SECURITY_CHECKLIST.md`
- **健康监控**: 使用 `scripts/health_check.sh`
- **备份恢复**: 使用 `scripts/backup.sh`

---

## 🎯 快速决策树

```
开始部署
    |
    ├─ 链是否已存在？
    │   ├─ 否 → 使用 initialize_production_chain.sh
    │   │        ↓
    │   │      创世节点部署
    │   │        ↓
    │   │      链启动完成！
    │   │
    │   └─ 是 → 使用 setup_validator_node.sh ⭐
    │            ↓
    │          1. 获取 genesis.json
    │            ↓
    │          2. 获取网络信息
    │            ↓
    │          3. 运行脚本
    │            ↓
    │          4. 等待同步
    │            ↓
    │          5. 获取代币
    │            ↓
    │          6. 创建验证者
    │            ↓
    │          验证者部署完成！
```

---

## ⚡ 快速命令参考

### 创世节点
```bash
# 配置
cp config/production.env.example config/production.env
nano config/production.env

# 部署
./scripts/initialize_production_chain.sh

# 启动
sudo systemctl start snp-node
```

### 额外验证者 ⭐
```bash
# 配置
cp config/validator.env.example config/validator.env
nano config/validator.env

# 部署
./scripts/setup_validator_node.sh

# 启动
sudo systemctl start snp-node

# 监控同步
watch -n 5 'curl -s localhost:26657/status | jq ".result.sync_info"'

# 创建验证者（同步完成后）
seid tx staking create-validator [参数...]
```

---

**文档版本**: 1.0.0  
**最后更新**: 2024-12-05  
**适用于**: SNP Chain (SEI fork)
