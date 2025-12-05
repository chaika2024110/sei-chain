# SNP Chain - Production Deployment Guide

Version: 1.0.0  
Last Updated: 2024-12-05

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Server Requirements](#server-requirements)
4. [Security Hardening](#security-hardening)
5. [Installation Steps](#installation-steps)
6. [Configuration](#configuration)
7. [Running the Node](#running-the-node)
8. [Monitoring Setup](#monitoring-setup)
9. [Backup and Recovery](#backup-and-recovery)
10. [Maintenance](#maintenance)
11. [Troubleshooting](#troubleshooting)
12. [Security Best Practices](#security-best-practices)

---

## 🎯 Overview

This guide provides step-by-step instructions for deploying a production SNP Chain validator node with enterprise-grade security and monitoring.

### Key Features

- ✅ Secure key management with encrypted keyring
- ✅ Production-ready governance parameters
- ✅ Automated backups with encryption
- ✅ Comprehensive health monitoring
- ✅ Prometheus/Grafana integration
- ✅ Systemd service management
- ✅ Firewall configuration
- ✅ DDoS protection guidelines

---

## 🔧 Prerequisites

### Software Requirements

- **Operating System**: Ubuntu 20.04 LTS or later (recommended)
- **Go**: Version 1.21 or later
- **Build Tools**: gcc, make, git
- **System Tools**: jq, curl, wget

### Installation Commands

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y build-essential git curl wget jq

# Install Go (check latest version)
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc

# Verify installation
go version
```

### Build SNP Chain Binary

```bash
# Clone repository (replace with your fork)
cd ~
git clone https://github.com/YOUR_ORG/snp-chain.git
cd snp-chain

# Build binary
make install

# Verify installation
seid version
```

---

## 💻 Server Requirements

### Minimum Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 16 GB | 32+ GB |
| Storage | 500 GB SSD | 1+ TB NVMe SSD |
| Network | 100 Mbps | 1 Gbps |
| Bandwidth | Unmetered | Unmetered |

### Recommended Providers

- AWS (c5.2xlarge or better)
- Google Cloud (n2-standard-8 or better)
- Hetzner (Dedicated servers)
- OVH (Dedicated servers)

---

## 🔒 Security Hardening

### 1. Firewall Configuration

```bash
# Install UFW
sudo apt install ufw -y

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (change port if needed)
sudo ufw allow 22/tcp

# Allow P2P port
sudo ufw allow 26656/tcp

# Restrict RPC/API (only for specific IPs if needed)
# sudo ufw allow from YOUR_IP to any port 26657
# sudo ufw allow from YOUR_IP to any port 9090

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

### 2. SSH Hardening

```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Recommended settings:
# - PermitRootLogin no
# - PasswordAuthentication no (use SSH keys)
# - Port 2222 (change from default 22)
# - AllowUsers YOUR_USERNAME

# Restart SSH
sudo systemctl restart sshd
```

### 3. Fail2Ban Setup

```bash
# Install Fail2Ban
sudo apt install fail2ban -y

# Create custom config
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Edit config
sudo nano /etc/fail2ban/jail.local

# Enable SSH jail
[sshd]
enabled = true
port = 2222
maxretry = 3
bantime = 3600

# Restart Fail2Ban
sudo systemctl restart fail2ban
```

### 4. Enable Automatic Security Updates

```bash
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

---

## 🚀 Installation Steps

### Step 1: Download Deployment Package

```bash
cd ~
# Download or copy the snp-production-deployment directory
# Ensure all scripts are executable
chmod +x snp-production-deployment/scripts/*.sh
```

### Step 2: Configure Environment

```bash
cd snp-production-deployment/config

# Copy example config
cp production.env.example production.env

# Edit configuration
nano production.env
```

### Step 3: Review Configuration

**CRITICAL SETTINGS TO REVIEW:**

```bash
# Chain Configuration
CHAIN_ID="snp-mainnet-1"  # Your unique chain ID
VALIDATOR_MONIKER="my-validator"

# Security
KEYRING_BACKEND="file"  # NEVER use "test"

# Tokenomics (VERY IMPORTANT)
GENESIS_ACCOUNT_BALANCE="1000000000000"  # Total supply allocation
VALIDATOR_STAKE="1000000000"  # Initial validator stake

# Governance
GOV_VOTING_PERIOD="604800s"  # 7 days
GOV_DEPOSIT_PERIOD="1209600s"  # 14 days

# Consensus
MAX_VOTING_POWER_RATIO="0.330000000000000000"  # 33% max
BLOCK_TIME="5000ms"  # 5 seconds

# Network
SEEDS=""  # Add your seed nodes
PERSISTENT_PEERS=""  # Add your persistent peers
```

### Step 4: Run Initialization Script

```bash
cd ~/snp-production-deployment

# Run initialization
./scripts/initialize_production_chain.sh
```

**Follow the prompts carefully:**

1. Confirm you've backed up keys
2. Confirm server is secured
3. Confirm you've reviewed tokenomics
4. Save your mnemonic phrase (CRITICAL!)
5. Wait for initialization to complete

### Step 5: Backup Initial Configuration

```bash
# Run initial backup
./scripts/backup.sh

# Verify backup
ls -lh ~/snp_backups/
```

---

## ⚙️ Configuration

### Network Configuration

#### For Genesis Node (First Validator)

1. Initialize chain using the script
2. Share genesis.json with other validators
3. Collect gentx from other validators
4. Update genesis.json with all validators
5. Distribute final genesis.json

#### For Additional Validators

```bash
# After receiving genesis.json
cp genesis.json ~/.snp/config/

# Add seeds and persistent peers
nano ~/.snp/config/config.toml

# Find and update:
seeds = "node_id@ip:26656,..."
persistent_peers = "node_id@ip:26656,..."
```

### Port Configuration

| Service | Default Port | Description |
|---------|-------------|-------------|
| P2P | 26656 | Peer-to-peer communication |
| RPC | 26657 | RPC endpoint |
| gRPC | 9090 | gRPC endpoint |
| Prometheus | 26660 | Metrics endpoint |
| API | 1317 | REST API |

---

## 🏃 Running the Node

### Option 1: Systemd Service (Recommended)

```bash
# Copy service file
sudo cp ~/snp-production-deployment/config/snp-node.service /etc/systemd/system/

# Edit service file with your username
sudo nano /etc/systemd/system/snp-node.service
# Replace YOUR_USERNAME with your actual username

# Reload systemd
sudo systemctl daemon-reload

# Enable service (start on boot)
sudo systemctl enable snp-node

# Start service
sudo systemctl start snp-node

# Check status
sudo systemctl status snp-node

# View logs
sudo journalctl -u snp-node -f
```

### Option 2: Manual Start (For Testing)

```bash
# Start node directly
~/go/bin/seid start --home ~/.snp

# Or with log file
~/go/bin/seid start --home ~/.snp > ~/.snp/seid.log 2>&1 &
```

### Verify Node is Running

```bash
# Check process
ps aux | grep seid

# Check sync status
curl -s http://localhost:26657/status | jq '.result.sync_info'

# Check peers
curl -s http://localhost:26657/net_info | jq '.result.n_peers'
```

---

## 📊 Monitoring Setup

### 1. Install Prometheus

```bash
# Download Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xvfz prometheus-2.45.0.linux-amd64.tar.gz
sudo mv prometheus-2.45.0.linux-amd64 /opt/prometheus

# Copy config
sudo cp ~/snp-production-deployment/monitoring/prometheus.yml /opt/prometheus/
sudo cp ~/snp-production-deployment/monitoring/snp_alerts.yml /opt/prometheus/

# Create systemd service
sudo nano /etc/systemd/system/prometheus.service
```

```ini
[Unit]
Description=Prometheus
After=network.target

[Service]
Type=simple
User=prometheus
ExecStart=/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data

Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# Create user
sudo useradd --no-create-home --shell /bin/false prometheus
sudo chown -R prometheus:prometheus /opt/prometheus

# Start Prometheus
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

# Access Prometheus UI
# http://YOUR_SERVER_IP:9090
```

### 2. Install Grafana

```bash
# Add Grafana repository
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

# Install Grafana
sudo apt-get update
sudo apt-get install grafana -y

# Start Grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

# Access Grafana UI
# http://YOUR_SERVER_IP:3000
# Default: admin/admin
```

### 3. Configure Grafana

1. Login to Grafana
2. Add Prometheus data source (http://localhost:9090)
3. Import dashboard for Cosmos SDK chains
4. Create custom dashboard for SNP metrics

### 4. Setup Alerting

```bash
# Configure email alerts in Grafana
sudo nano /etc/grafana/grafana.ini

[smtp]
enabled = true
host = smtp.gmail.com:587
user = your-email@gmail.com
password = your-app-password
from_address = your-email@gmail.com
from_name = SNP Alerts
```

### 5. Run Health Checks

```bash
# Setup cron for automated health checks
crontab -e

# Add line:
*/5 * * * * ~/snp-production-deployment/scripts/health_check.sh >> ~/snp-production-deployment/logs/health.log 2>&1
```

---

## 💾 Backup and Recovery

### Automated Backups

```bash
# Setup daily backups
crontab -e

# Add line for 3 AM daily backup:
0 3 * * * ~/snp-production-deployment/scripts/backup.sh >> ~/snp-production-deployment/logs/backup.log 2>&1

# Weekly full backup (including chain data):
0 4 * * 0 BACKUP_CHAIN_DATA=true ~/snp-production-deployment/scripts/backup.sh >> ~/snp-production-deployment/logs/full_backup.log 2>&1
```

### Manual Backup

```bash
# Run backup script
cd ~/snp-production-deployment
./scripts/backup.sh

# With encryption
ENCRYPT_BACKUP=true BACKUP_PASSWORD="your-secure-password" ./scripts/backup.sh

# With remote upload
REMOTE_BACKUP=true REMOTE_BACKUP_HOST="user@backup-server" REMOTE_BACKUP_PATH="/backups" ./scripts/backup.sh
```

### Recovery Procedure

```bash
# Stop node
sudo systemctl stop snp-node

# Locate backup
ls -lh ~/snp_backups/

# Decrypt backup (if encrypted)
openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"your-password" \
    -in backup_TIMESTAMP.tar.gz.enc | tar -xzf -

# Or extract unencrypted backup
tar -xzf backup_TIMESTAMP.tar.gz

# Restore critical files
cp backup_TIMESTAMP/config/priv_validator_key.json ~/.snp/config/
cp backup_TIMESTAMP/config/node_key.json ~/.snp/config/
cp backup_TIMESTAMP/data/priv_validator_state.json ~/.snp/data/

# Restore configuration
cp backup_TIMESTAMP/config/genesis.json ~/.snp/config/
cp backup_TIMESTAMP/config/config.toml ~/.snp/config/
cp backup_TIMESTAMP/config/app.toml ~/.snp/config/

# Restore keyring
cp -r backup_TIMESTAMP/keyring/keyring-file ~/.snp/

# Set correct permissions
chmod 600 ~/.snp/config/priv_validator_key.json
chmod 600 ~/.snp/config/node_key.json

# Start node
sudo systemctl start snp-node
```

---

## 🔧 Maintenance

### Regular Tasks

#### Daily
- ✅ Check node status
- ✅ Monitor logs for errors
- ✅ Verify backups completed
- ✅ Check disk space

#### Weekly
- ✅ Review security logs
- ✅ Update dependencies
- ✅ Test backup restoration
- ✅ Review validator performance

#### Monthly
- ✅ Security audit
- ✅ Performance optimization
- ✅ Update documentation
- ✅ Disaster recovery drill

### Log Management

```bash
# View logs
sudo journalctl -u snp-node -f

# Last 100 lines
sudo journalctl -u snp-node -n 100

# Logs from today
sudo journalctl -u snp-node --since today

# Save logs
sudo journalctl -u snp-node > snp-node-logs.txt

# Setup log rotation
sudo nano /etc/logrotate.d/snp-node
```

```
/var/log/snp-node/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 snp snp
}
```

### Updating the Node

```bash
# Stop node
sudo systemctl stop snp-node

# Backup current state
./scripts/backup.sh

# Pull latest code
cd ~/snp-chain
git pull origin main

# Rebuild
make install

# Verify new version
seid version

# Restart node
sudo systemctl start snp-node

# Monitor startup
sudo journalctl -u snp-node -f
```

---

## 🐛 Troubleshooting

### Node Won't Start

```bash
# Check logs
sudo journalctl -u snp-node -n 100

# Common issues:
# 1. Genesis file mismatch
seid validate-genesis --home ~/.snp

# 2. Port already in use
sudo lsof -i :26656
sudo lsof -i :26657

# 3. Permission issues
ls -la ~/.snp/config/
chmod 600 ~/.snp/config/priv_validator_key.json

# 4. Corrupted database
seid unsafe-reset-all --home ~/.snp  # WARNING: Deletes all data!
```

### Node Not Syncing

```bash
# Check peers
curl -s http://localhost:26657/net_info | jq '.result.n_peers'

# Add more peers
nano ~/.snp/config/config.toml
# Update persistent_peers

# Restart node
sudo systemctl restart snp-node

# Use state sync (faster)
# Configure in config.toml:
[statesync]
enable = true
rpc_servers = "rpc1:26657,rpc2:26657"
trust_height = TRUST_HEIGHT
trust_hash = "TRUST_HASH"
```

### High Resource Usage

```bash
# Check resource usage
htop

# Disk I/O
iostat -x 1

# Network usage
iftop

# Reduce concurrency workers
nano ~/.snp/config/app.toml
# concurrency-workers = 100

# Restart node
sudo systemctl restart snp-node
```

### Lost Validator Key

**If you have a backup:**
```bash
# Restore from backup (see Recovery Procedure)
```

**If you DON'T have a backup:**
- Your validator is unrecoverable
- You'll lose your stake
- This is why backups are CRITICAL!

---

## 🛡️ Security Best Practices

### 1. Key Management

- ✅ **NEVER** use `keyring-backend test` in production
- ✅ Store validator keys offline
- ✅ Use hardware security modules (HSM) for high-value validators
- ✅ Keep multiple encrypted backups in different locations
- ✅ Never share your `priv_validator_key.json`
- ✅ Use different keys for different environments

### 2. Network Security

- ✅ Use firewall to restrict access
- ✅ Only expose P2P port (26656) publicly
- ✅ Use VPN or private network for RPC/API
- ✅ Implement DDoS protection (Cloudflare, AWS Shield)
- ✅ Use TLS/SSL for all public endpoints
- ✅ Regular security audits

### 3. Operational Security

- ✅ Use separate servers for validator and sentry nodes
- ✅ Implement monitoring and alerting
- ✅ Regular backups (automated)
- ✅ Test recovery procedures
- ✅ Keep software updated
- ✅ Use strong, unique passwords
- ✅ Enable 2FA where possible
- ✅ Limit sudo access

### 4. Validator Best Practices

- ✅ Start with small stake
- ✅ Gradually increase stake as confidence grows
- ✅ Maintain high uptime (>99%)
- ✅ Participate in governance
- ✅ Communicate with delegators
- ✅ Have redundancy plan
- ✅ Monitor competition

---

## 📞 Support and Resources

### Documentation
- Official Docs: https://docs.snp-chain.com
- GitHub: https://github.com/YOUR_ORG/snp-chain
- Discord: https://discord.gg/YOUR_DISCORD

### Emergency Contacts
- Technical Support: tech@snp-chain.com
- Security Issues: security@snp-chain.com

### Community
- Telegram: @snp_chain
- Twitter: @snp_chain
- Forum: https://forum.snp-chain.com

---

## ✅ Pre-Launch Checklist

- [ ] Server secured and hardened
- [ ] Firewall configured
- [ ] SSH hardened with key-based auth
- [ ] Fail2Ban installed and configured
- [ ] Automatic updates enabled
- [ ] Node software built and tested
- [ ] Configuration reviewed and customized
- [ ] Validator keys generated and backed up (multiple locations)
- [ ] Node initialized with production parameters
- [ ] Genesis file validated
- [ ] Systemd service configured and tested
- [ ] Monitoring setup (Prometheus + Grafana)
- [ ] Health check cron jobs configured
- [ ] Backup automation configured and tested
- [ ] Recovery procedure tested
- [ ] Alerting configured (email/Slack)
- [ ] Documentation reviewed
- [ ] Team trained on operations
- [ ] Emergency procedures documented
- [ ] Communication channels established

---

## 📄 License

This deployment package is provided as-is for SNP Chain validators. Use at your own risk.

---

**Last Updated**: 2024-12-05  
**Version**: 1.0.0  
**Maintainer**: SNP Chain Team
