#!/usr/bin/env bash
set -euo pipefail

SSH_DROPIN="/etc/ssh/sshd_config.d/99-secure.conf"

cat <<'EOF' > "$SSH_DROPIN"
AuthenticationMethods publickey
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
EOF

chmod 644 "$SSH_DROPIN"

echo "[+] SSH hardening config written to $SSH_DROPIN"

echo "[+] Reloading sshd"
systemctl reload sshd
