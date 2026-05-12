#!/usr/bin/env bash
cat > ~/ssh_tailscale_ufw.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[*] Installing UFW..."
sudo apt-get update -y
sudo apt-get install -y ufw

echo "[*] Setting UFW defaults..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "[*] Allow SSH only from Tailscale (100.64.0.0/10)..."
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp

# Optional safety net: allow SSH from LAN too (uncomment and set your subnet)
# sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp

echo "[*] Enabling UFW..."
sudo ufw --force enable

echo "[*] Status:"
sudo ufw status verbose
EOF

chmod +x ~/ssh_tailscale_ufw.sh
