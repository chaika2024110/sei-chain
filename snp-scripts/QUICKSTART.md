# SNP Chain - Quick Start Guide (5 Minutes)

⚡ **Get your production validator running in 5 minutes**

---

## 🚀 Prerequisites Check

Before starting, ensure you have:

```bash
# Check Go installation
go version  # Should be 1.21+

# Check seid binary
seid version

# Check system resources
free -h  # Should have 16+ GB RAM
df -h    # Should have 500+ GB free space
```

---

## 📝 Step 1: Prepare Configuration (2 minutes)

```bash
# Navigate to deployment directory
cd ~/snp-production-deployment/config

# Copy configuration template
cp production.env.example production.env

# Edit critical settings
nano production.env
```

**Edit these 5 critical settings:**

```bash
# 1. Your chain ID
CHAIN_ID="snp-mainnet-1"

# 2. Your validator name
VALIDATOR_MONIKER="my-validator"

# 3. Security (NEVER use 'test')
KEYRING_BACKEND="file"

# 4. Your initial balance (adjust to your tokenomics)
GENESIS_ACCOUNT_BALANCE="1000000000000"

# 5. Your validator stake
VALIDATOR_STAKE="1000000000"
```

Save and exit (Ctrl+X, Y, Enter)

---

## 🔧 Step 2: Initialize Chain (2 minutes)

```bash
# Make scripts executable
chmod +x ~/snp-production-deployment/scripts/*.sh

# Run initialization
cd ~/snp-production-deployment
./scripts/initialize_production_chain.sh
```

**Important:** The script will ask you 3 questions:
1. "Have you backed up your private keys?" → Type `yes`
2. "Is this server properly secured?" → Type `yes`
3. "Have you reviewed the tokenomics?" → Type `yes`

**CRITICAL:** When you create a new key, save the mnemonic phrase securely!

---

## 🏃 Step 3: Start Node (1 minute)

```bash
# Setup systemd service
sudo cp config/snp-node.service /etc/systemd/system/

# Edit service file with your username
sudo sed -i "s/YOUR_USERNAME/$USER/g" /etc/systemd/system/snp-node.service

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable snp-node
sudo systemctl start snp-node

# Check status
sudo systemctl status snp-node
```

---

## ✅ Step 4: Verify (30 seconds)

```bash
# Check node is running
ps aux | grep seid

# Check sync status
curl -s http://localhost:26657/status | jq '.result.sync_info'

# Check peers
curl -s http://localhost:26657/net_info | jq '.result.n_peers'

# View logs
sudo journalctl -u snp-node -f --lines 50
```

**Expected output:**
- `catching_up: false` (after sync completes)
- `n_peers: "3"` or higher
- No errors in logs

---

## 💾 Step 5: Backup Immediately!

```bash
# Run first backup
./scripts/backup.sh

# Verify backup created
ls -lh ~/snp_backups/
```

**CRITICAL:** Download this backup to a secure location!

```bash
# On your local machine:
scp user@server:~/snp_backups/backup_*.tar.gz* ~/safe-location/
```

---

## 🎉 Done! What's Next?

### Immediate Tasks (Next Hour)

1. **Configure Firewall**
   ```bash
   sudo ufw allow 22/tcp
   sudo ufw allow 26656/tcp
   sudo ufw enable
   ```

2. **Setup Automated Backups**
   ```bash
   crontab -e
   # Add: 0 3 * * * ~/snp-production-deployment/scripts/backup.sh
   ```

3. **Setup Health Monitoring**
   ```bash
   crontab -e
   # Add: */5 * * * * ~/snp-production-deployment/scripts/health_check.sh
   ```

### Next 24 Hours

- [ ] Setup Prometheus monitoring (see DEPLOYMENT_GUIDE.md)
- [ ] Configure Grafana dashboards
- [ ] Setup alert notifications (email/Slack)
- [ ] Test backup restoration
- [ ] Review security checklist
- [ ] Join validator community channels

### Full Setup Checklist

See `docs/SECURITY_CHECKLIST.md` for comprehensive production requirements.

---

## 🆘 Quick Troubleshooting

### Node Won't Start

```bash
# Check logs
sudo journalctl -u snp-node -n 50

# Common fix: Port already in use
sudo lsof -i :26656
sudo lsof -i :26657
# Kill conflicting process and restart
```

### Can't Create Key

```bash
# Check keyring backend
seid config keyring-backend --home ~/.snp

# Should be 'file' not 'test'
```

### Node Not Syncing

```bash
# Check if you have peers
curl -s http://localhost:26657/net_info | jq '.result.n_peers'

# If 0 peers, add seeds/peers in config
nano ~/.snp/config/config.toml
# Update: seeds = "..."
# Restart: sudo systemctl restart snp-node
```

---

## 📞 Need Help?

- **Full Guide**: See `docs/DEPLOYMENT_GUIDE.md`
- **Security**: See `docs/SECURITY_CHECKLIST.md`
- **Support**: support@snp-chain.com
- **Discord**: https://discord.gg/YOUR_DISCORD

---

## ⚠️ Critical Reminders

1. **BACKUP YOUR KEYS!** Without backups, if server fails, you lose everything
2. **Use encrypted keyring** (file/os, NEVER test)
3. **Secure your server** (firewall, SSH keys, no root login)
4. **Monitor your node** (setup alerts for downtime)
5. **Test recovery** (before you need it!)

---

## 📊 Quick Reference Commands

```bash
# Node status
sudo systemctl status snp-node

# View logs
sudo journalctl -u snp-node -f

# Restart node
sudo systemctl restart snp-node

# Check sync
curl -s localhost:26657/status | jq '.result.sync_info'

# Backup
./scripts/backup.sh

# Health check
./scripts/health_check.sh
```

---

**🎯 You're now running a production SNP Chain validator!**

Next: Complete the full security checklist in `docs/SECURITY_CHECKLIST.md`
