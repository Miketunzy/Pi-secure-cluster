
#!/bin/bash
cat > ~/lock_ssh_to_tailscale.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[*] Installing ufw (if missing)..."
sudo apt-get update -y
sudo apt-get install -y ufw

echo "[*] Resetting ufw..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "[*] Allow SSH ONLY from Tailscale CGNAT range (100.64.0.0/10)..."
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp

# OPTIONAL SAFETY NET (recommended while you're still learning):
# allow SSH from your home LAN too. Uncomment + set your subnet.
# sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp

echo "[*] Enable ufw..."
sudo ufw --force enable

echo "[*] Current rules:"
sudo ufw status verbose
EOF

chmod +x ~/lock_ssh_to_tailscale.sh
cat > ~/lock_ssh_to_tailscale.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[*] Installing ufw (if missing)..."
sudo apt-get update -y
sudo apt-get install -y ufw

echo "[*] Resetting ufw..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "[*] Allow SSH ONLY from Tailscale CGNAT range (100.64.0.0/10)..."
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp

# OPTIONAL SAFETY NET (recommended while you're still learning):
# allow SSH from your home LAN too. Uncomment + set your subnet.
# sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp

echo "[*] Enable ufw..."
sudo ufw --force enable

echo "[*] Current rules:"
sudo ufw status verbose
EOF

chmod +x ~/lock_ssh_to_tailscale.sh

