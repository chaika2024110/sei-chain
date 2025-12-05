# 🎯 选择正确的部署方式

## 我应该使用哪个脚本？

SNP Chain 部署包提供了**两种不同的部署脚本**，用于不同的场景：

---

## 📊 快速对比

| 问题 | 答案 → | 使用脚本 |
|------|-------|---------|
| 你在启动一条全新的链吗？ | 是 → | `initialize_production_chain.sh` |
| 你是第一个验证者吗？ | 是 → | `initialize_production_chain.sh` |
| 需要创建 genesis.json 吗？ | 是 → | `initialize_production_chain.sh` |
| | | |
| 链已经在运行了吗？ | 是 → | `setup_validator_node.sh` ⭐ |
| 你想加入现有网络吗？ | 是 → | `setup_validator_node.sh` ⭐ |
| 已经有 genesis.json 了吗？ | 是 → | `setup_validator_node.sh` ⭐ |

---

## 🚀 场景 1: 创世节点（Genesis Node）

### 使用时机
- ✅ 启动全新的 SNP 链
- ✅ 你是第一个验证者
- ✅ 需要定义代币经济学
- ✅ 需要设置初始治理参数

### 使用脚本
```bash
./scripts/initialize_production_chain.sh
```

### 配置文件
```bash
config/production.env
```

### 快速开始
```bash
# 1. 配置
cp config/production.env.example config/production.env
nano config/production.env

# 2. 部署
./scripts/initialize_production_chain.sh

# 3. 启动
sudo systemctl start snp-node
```

### 详细文档
- 📖 `QUICKSTART.md` - 5分钟快速开始
- 📖 `docs/DEPLOYMENT_GUIDE.md` - 完整指南
- 📖 `docs/SECURITY_CHECKLIST.md` - 安全检查

---

## 🌐 场景 2: 额外验证者节点 ⭐ 新增！

### 使用时机
- ✅ 链已经在运行
- ✅ 想成为第 2/3/4... 个验证者
- ✅ 有现有的 genesis.json 文件
- ✅ 知道种子节点信息

### 使用脚本
```bash
./scripts/setup_validator_node.sh
```

### 配置文件
```bash
config/validator.env
```

### 快速开始
```bash
# 1. 配置
cp config/validator.env.example config/validator.env
nano config/validator.env
# 重点配置：
# - GENESIS_FILE_URL (genesis.json 下载地址)
# - SEEDS (种子节点)
# - PERSISTENT_PEERS (持久节点)

# 2. 部署
./scripts/setup_validator_node.sh

# 3. 启动并等待同步
sudo systemctl start snp-node
watch -n 5 'curl -s localhost:26657/status | jq ".result.sync_info"'

# 4. 同步完成后创建验证者
seid tx staking create-validator \
  --amount=1000000000usnp \
  --pubkey=$(seid tendermint show-validator --home ~/.snp) \
  --moniker="my-validator" \
  --chain-id=snp-mainnet-1 \
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1" \
  --from=validator \
  --keyring-backend=file \
  --home=~/.snp
```

### 详细文档
- 📖 `docs/VALIDATOR_DEPLOYMENT_GUIDE.md` - ⭐ 完整验证者部署指南
- 📖 `config/validator.env.example` - 详细配置说明

---

## 🔑 关键区别

### 创世节点部署
```
初始化 → 创建密钥 → 创建 genesis → 添加账户 
→ 创建 gentx → 配置参数 → 启动节点
✅ 节点立即开始出块
```

### 额外验证者部署
```
初始化 → 创建密钥 → 获取 genesis → 配置网络
→ 启动节点 → 等待同步 → 获取代币 → 创建验证者
⏱️ 需要等待同步完成（10分钟-数小时）
```

---

## ⚠️ 常见错误

### ❌ 错误：用创世脚本加入现有网络

**问题**：
```bash
# 链已运行，但错误地使用了：
./scripts/initialize_production_chain.sh
```

**结果**：
- 创建了新的 genesis.json
- Chain ID 可能不同
- 无法连接到现有网络
- 实际上启动了一条新链

**解决方案**：
```bash
# 应该使用：
./scripts/setup_validator_node.sh
```

---

### ❌ 错误：同步前创建验证者

**问题**：
```bash
# 节点还在同步，但立即发送：
seid tx staking create-validator ...
```

**结果**：
- 交易失败（节点还没同步到最新状态）
- 浪费 gas 费用

**解决方案**：
```bash
# 1. 先检查同步状态
curl -s localhost:26657/status | jq '.result.sync_info.catching_up'

# 2. 等待返回 false
# 3. 然后再创建验证者
```

---

## 📋 部署前准备清单

### 创世节点部署
- [ ] 定义好代币经济学参数
- [ ] 确定治理参数（投票周期等）
- [ ] 准备好服务器（16GB+ RAM, 500GB+ SSD）
- [ ] 配置好 `production.env`
- [ ] 阅读安全检查清单

### 额外验证者部署
- [ ] 获取 `genesis.json` 文件
- [ ] 获取种子节点信息
- [ ] 获取持久节点信息
- [ ] 获取 RPC 端点（用于 state sync）
- [ ] 确认 Chain ID
- [ ] 准备好质押代币
- [ ] 配置好 `validator.env`

---

## 🎯 决策流程图

```
开始
  │
  ├─ 链是否已经在运行？
  │   │
  │   ├─ 否 ──────────────────────┐
  │   │                           │
  │   │  这是全新的链吗？          │
  │   │     │                     │
  │   │     └─ 是                 │
  │   │         ↓                 │
  │   │    【使用创世脚本】        │
  │   │         ↓                 │
  │   │    config/production.env  │
  │   │         ↓                 │
  │   │    initialize_production_chain.sh
  │   │         ↓                 │
  │   │    直接启动和出块          │
  │   │                           │
  │   └─ 是 ──────────────────────┤
  │                               │
  │   想加入现有网络？              │
  │     │                         │
  │     └─ 是                     │
  │         ↓                     │
  │    【使用验证者脚本】 ⭐        │
  │         ↓                     │
  │    config/validator.env       │
  │         ↓                     │
  │    setup_validator_node.sh    │
  │         ↓                     │
  │    同步 → 获取代币 → 创建验证者 │
  │                               │
  └───────────────────────────────┘
```

---

## 📚 完整文档索引

### 创世节点相关
1. `QUICKSTART.md` - 5分钟快速开始
2. `docs/DEPLOYMENT_GUIDE.md` - 完整部署指南
3. `config/production.env.example` - 配置模板
4. `docs/SECURITY_CHECKLIST.md` - 安全检查清单

### 额外验证者相关 ⭐
1. `docs/VALIDATOR_DEPLOYMENT_GUIDE.md` - ⭐ 验证者部署完整指南
2. `config/validator.env.example` - ⭐ 验证者配置模板
3. `docs/SECURITY_CHECKLIST.md` - 安全检查清单（通用）

### 通用工具
1. `scripts/backup.sh` - 自动备份
2. `scripts/health_check.sh` - 健康监控
3. `monitoring/` - Prometheus 配置

---

## 🆘 需要帮助？

### 不确定用哪个脚本？

**回答这个问题**：链是否已经有其他验证者在运行？

- **是** → 使用 `setup_validator_node.sh` ⭐
- **否** → 使用 `initialize_production_chain.sh`

### 还是不确定？

查看详细对比：`docs/VALIDATOR_DEPLOYMENT_GUIDE.md`

---

## ✅ 快速检查

运行以下命令看看网络是否已存在：

```bash
# 如果有现有节点的 RPC 端点
curl -s http://existing-node:26657/status | jq

# 如果能看到结果，说明链已在运行
# → 使用 setup_validator_node.sh

# 如果看不到结果或没有现有节点
# → 使用 initialize_production_chain.sh
```

---

**记住**：
- 🆕 启动新链 = `initialize_production_chain.sh`
- 🔗 加入现有网络 = `setup_validator_node.sh` ⭐

---

**文档版本**: 1.1.0  
**最后更新**: 2024-12-05  
**新增内容**: 额外验证者部署支持
