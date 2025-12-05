# SNP Chain - 生产环境部署包

🚀 **企业级 SNP Chain 验证者部署解决方案**

版本: 1.0.0  
最后更新: 2024-12-05

---

## 📦 包含内容

这个综合部署包包含了启动安全、生产就绪的 SNP Chain 验证者节点所需的一切。

### 📁 目录结构

```
snp-production-deployment/
├── scripts/
│   ├── initialize_production_chain.sh    # 主初始化脚本
│   ├── backup.sh                          # 自动备份脚本
│   └── health_check.sh                    # 节点健康监控
├── config/
│   ├── production.env.example             # 环境配置模板
│   ├── snp-node.service                   # Systemd 服务文件
│   └── crontab.example                    # 自动化任务示例
├── monitoring/
│   ├── prometheus.yml                     # Prometheus 配置
│   └── snp_alerts.yml                     # 告警规则
└── docs/
    ├── DEPLOYMENT_GUIDE.md                # 完整部署指南
    └── SECURITY_CHECKLIST.md              # 安全验证检查清单
```

---

## 🎯 快速开始

### 1. 前置要求

- Ubuntu 20.04 LTS 或更高版本
- 16+ GB 内存（推荐 32+ GB）
- 500+ GB SSD（推荐 1+ TB）
- Go 1.21+
- seid 二进制文件已编译并安装

### 2. 初始设置

```bash
# 克隆或下载此包
cd ~
# [将 snp-production-deployment 目录复制到您的服务器]

# 使脚本可执行
chmod +x snp-production-deployment/scripts/*.sh

# 进入配置目录
cd snp-production-deployment/config

# 复制并自定义配置
cp production.env.example production.env
nano production.env
```

### 3. 配置您的环境

**在 `production.env` 中需要检查的关键设置：**

```bash
# 链标识
CHAIN_ID="snp-mainnet-1"
VALIDATOR_MONIKER="your-validator-name"

# 安全性（生产环境中永远不要使用 'test'！）
KEYRING_BACKEND="file"

# 代币经济学（仔细检查！）
GENESIS_ACCOUNT_BALANCE="1000000000000"
VALIDATOR_STAKE="1000000000"

# 治理（生产环境值）
GOV_VOTING_PERIOD="604800s"  # 7 天
GOV_DEPOSIT_PERIOD="1209600s"  # 14 天

# 网络
SEEDS="node1@ip1:26656,node2@ip2:26656"
PERSISTENT_PEERS="peer1@ip1:26656"
```

### 4. 运行初始化

```bash
cd ~/snp-production-deployment
./scripts/initialize_production_chain.sh
```

### 5. 启动您的节点

```bash
# 设置 systemd 服务
sudo cp config/snp-node.service /etc/systemd/system/
sudo nano /etc/systemd/system/snp-node.service  # 更新 YOUR_USERNAME

# 启用并启动
sudo systemctl daemon-reload
sudo systemctl enable snp-node
sudo systemctl start snp-node

# 监控
sudo journalctl -u snp-node -f
```

---

## 🔒 安全第一

### 部署前，您必须：

1. ✅ **加固您的服务器**（防火墙、SSH 加固、Fail2Ban）
2. ✅ **使用加密密钥环**（`keyring-backend = file`，不是 `test`）
3. ✅ **审核代币经济学**（确保您的链的值正确）
4. ✅ **设置生产治理参数**（不是测试值！）
5. ✅ **配置备份**（自动化、加密、异地）
6. ✅ **设置监控**（Prometheus + Grafana + 告警）
7. ✅ **测试恢复程序**（在您需要之前！）

### 安全检查清单

参见 [`docs/SECURITY_CHECKLIST.md`](docs/SECURITY_CHECKLIST.md) 获取全面的安全验证检查清单。

---

## 📊 主要功能

### 🔐 安全加固

- 加密密钥环（file 或 OS 后端）
- 生产级治理参数
- 防火墙配置指南
- SSH 加固说明
- DDoS 防护指导

### 💾 自动备份

- 每日自动备份
- AES-256 加密支持
- 远程备份能力
- 自动清理旧备份
- 备份完整性验证
- 简便的恢复程序

### 📈 全面监控

- Prometheus 指标收集
- Grafana 仪表板
- 自定义告警规则
- 健康检查自动化
- 实时节点状态
- 系统资源监控

### 🚨 告警系统

- 邮件通知
- Slack/Discord webhooks
- 自定义告警阈值
- 多级严重程度
- 升级程序

### 🛠 生产就绪配置

- 5 秒出块时间（稳定）
- 7 天投票周期（安全）
- 33% 最大验证者权力（去中心化）
- Oracle 投票周期：30 个区块
- 社区税：2%（可配置）
- 21 天解绑期

---

## 📖 文档

### 完整指南

1. **[DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)** - 逐步部署说明
    - 前置要求
    - 安全加固
    - 安装步骤
    - 配置详情
    - 监控设置
    - 备份/恢复程序
    - 故障排除指南

2. **[SECURITY_CHECKLIST.md](docs/SECURITY_CHECKLIST.md)** - 全面的安全验证
    - 部署前检查清单
    - 密钥管理验证
    - 网络安全检查
    - 操作安全
    - 持续安全任务

---

## 🛠 脚本概览

### initialize_production_chain.sh

主初始化脚本，执行以下操作：
- 验证环境配置
- 使用生产参数创建创世账户
- 配置具有安全设置的验证者
- 设置生产治理参数
- 应用安全最佳实践
- 创建初始备份

**使用方法：**
```bash
./scripts/initialize_production_chain.sh
```

### backup.sh

自动备份脚本，执行以下操作：
- 备份关键配置文件
- 备份验证者密钥（加密）
- 备份密钥环
- 可选择备份链数据
- 创建加密存档
- 上传到远程位置（可选）
- 清理旧备份
- 验证备份完整性

**使用方法：**
```bash
# 标准备份
./scripts/backup.sh

# 带加密
ENCRYPT_BACKUP=true BACKUP_PASSWORD="your-password" ./scripts/backup.sh

# 包含链数据（较慢）
BACKUP_CHAIN_DATA=true ./scripts/backup.sh

# 远程上传
REMOTE_BACKUP=true REMOTE_BACKUP_HOST="user@server" REMOTE_BACKUP_PATH="/path" ./scripts/backup.sh
```

### health_check.sh

节点健康监控脚本，执行以下操作：
- 检查节点是否运行
- 验证 RPC 连接
- 监控同步状态
- 检查验证者状态
- 监控对等连接
- 监控系统资源
- 检查日志错误
- 检测到问题时发送告警

**使用方法：**
```bash
# 手动检查
./scripts/health_check.sh

# 详细模式
VERBOSE=true ./scripts/health_check.sh

# 设置自动检查（每 5 分钟）
crontab -e
# 添加：*/5 * * * * /path/to/health_check.sh >> /path/to/logs/health.log 2>&1
```

---

## ⚙️ 配置参考

### production.env

完整的环境配置文件，包含：
- 链标识设置
- 验证者配置
- 代币经济学参数
- 治理参数
- 安全设置
- 网络配置
- 资源限制
- 监控设置

**所有设置都有内联文档和示例。**

### 系统要求

| 组件 | 最低配置 | 推荐配置 |
|-----------|---------|-------------|
| CPU | 4 核 | 8+ 核 |
| 内存 | 16 GB | 32+ GB |
| 存储 | 500 GB SSD | 1+ TB NVMe |
| 网络 | 100 Mbps | 1 Gbps |

---

## 📊 监控设置

### 快速监控设置

1. **安装 Prometheus**
   ```bash
   # 详细说明请参见 docs/DEPLOYMENT_GUIDE.md
   ```

2. **配置 Prometheus**
   ```bash
   sudo cp monitoring/prometheus.yml /opt/prometheus/
   sudo cp monitoring/snp_alerts.yml /opt/prometheus/
   ```

3. **安装 Grafana**
   ```bash
   # 详细说明请参见 docs/DEPLOYMENT_GUIDE.md
   ```

4. **设置自动健康检查**
   ```bash
   crontab -e
   # 添加：*/5 * * * * /path/to/health_check.sh
   ```

---

## 🔄 维护任务

### 每日
- [ ] 检查节点状态
- [ ] 查看监控仪表板
- [ ] 验证备份已完成
- [ ] 检查关键告警

### 每周
- [ ] 查看所有告警
- [ ] 检查更新
- [ ] 测试备份恢复
- [ ] 查看验证者性能

### 每月
- [ ] 应用安全更新
- [ ] 查看访问日志
- [ ] 灾难恢复演练
- [ ] 性能优化

---

## 🆘 常见问题

### 节点无法启动

```bash
# 检查日志
sudo journalctl -u snp-node -n 100

# 验证 genesis
seid validate-genesis --home ~/.snp

# 检查端口
sudo lsof -i :26656
sudo lsof -i :26657
```

### 节点不同步

```bash
# 检查对等节点
curl -s http://localhost:26657/net_info | jq '.result.n_peers'

# 在 config.toml 中添加更多对等节点
nano ~/.snp/config/config.toml
```

### 无法访问密钥

```bash
# 验证密钥环后端
seid config keyring-backend --home ~/.snp

# 列出密钥
seid keys list --keyring-backend file --home ~/.snp
```

**更多故障排除，请参见 docs/DEPLOYMENT_GUIDE.md**

---

## 🔐 关键安全警告

### ⚠️ 生产环境中永远不要这样做：

❌ 使用 `keyring-backend test`  
❌ 共享您的 `priv_validator_key.json`  
❌ 以 root 身份运行节点  
❌ 使用测试治理参数（30秒投票周期）  
❌ 将 `max_voting_power_ratio` 设置为 1.0  
❌ 跳过备份  
❌ 跳过监控  
❌ 允许 SSH 密码认证  
❌ 未经认证公开暴露 RPC/API 端口

### ✅ 始终这样做：

✅ 使用加密密钥环（`file` 或 `os` 后端）  
✅ 备份您的密钥（多个加密副本）  
✅ 使用生产治理参数  
✅ 限制验证者投票权（≤33%）  
✅ 配置防火墙  
✅ 启用监控和告警  
✅ 测试恢复程序  
✅ 保持软件更新  
✅ 使用 SSH 密钥（不是密码）  
✅ 限制 API 访问

---

## 🎓 学习资源

- [Cosmos SDK 文档](https://docs.cosmos.network/)
- [Tendermint Core 文档](https://docs.tendermint.com/)
- [验证者最佳实践](https://hub.cosmos.network/main/validators/validator-setup.html)
- [验证者安全最佳实践](https://kb.certus.one/)

---

## 📞 支持

### 获取帮助

- **文档**: 参见 `docs/` 目录
- **问题**: [GitHub Issues](https://github.com/YOUR_ORG/snp-chain/issues)
- **Discord**: https://discord.gg/YOUR_DISCORD
- **邮箱**: support@snp-chain.com

### 安全问题

**不要**公开报告安全问题。

将安全漏洞报告至：security@snp-chain.com

---

## 🤝 贡献

欢迎对此部署包的改进！请：

1. Fork 此仓库
2. 创建功能分支
3. 进行改进
4. 提交 Pull Request

---

## 📄 许可证

此部署包按原样提供给 SNP Chain 验证者使用。

---

## ⚡ 快速参考

### 启动节点
```bash
sudo systemctl start snp-node
```

### 停止节点
```bash
sudo systemctl stop snp-node
```

### 检查状态
```bash
sudo systemctl status snp-node
curl -s http://localhost:26657/status | jq
```

### 查看日志
```bash
sudo journalctl -u snp-node -f
```

### 运行备份
```bash
./scripts/backup.sh
```

### 健康检查
```bash
./scripts/health_check.sh
```

### 列出密钥
```bash
seid keys list --keyring-backend file --home ~/.snp
```

---

## 📊 版本历史

- **v1.0.0** (2024-12-05) - 初始生产版本
    - 完整的部署自动化
    - 安全加固
    - 监控和告警
    - 自动备份
    - 全面的文档

---

## ✅ 上线前检查清单

上线前，确保：

- [ ] 所有脚本已测试
- [ ] 配置已审核
- [ ] 安全检查清单已完成
- [ ] 备份正常工作并已测试
- [ ] 监控已配置
- [ ] 告警已测试
- [ ] 团队已培训
- [ ] 文档已审核
- [ ] 应急程序已记录
- [ ] 支持渠道已就绪

---

**准备好部署了吗？从 [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) 开始**

**有疑问？查看 [docs/SECURITY_CHECKLIST.md](docs/SECURITY_CHECKLIST.md)**

---

*用 ❤️ 为 SNP Chain 社区构建*