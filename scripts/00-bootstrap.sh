#!/usr/bin/env bash
# bootstrap.sh
#
# Purpose:
#   Bootstrap a fresh Ubuntu Server 24.04 Raspberry Pi node for your secure cluster:
#   - Baseline packages
#   - Tailscale install (optionally auto-join)
#   - Create a dedicated user (optional)
#   - Install SSH public key for that user
#   - Harden sshd using an sshd_config.d drop-in (cloud-init aware)
#   - Verify effective sshd settings
#
# Philosophy:
#   - Readable > clever
#   - No silent magic
#   - Fails loud
#   - Explicitly overrides merged SSH configs (Ubuntu 24.04 + cloud-init)
#
# Usage examples:
#   1) Create user + install key + harden SSH (no auto Tailscale join):
#      sudo ./bootstrap.sh --user mike-1 --pubkey-file ./id_ed25519.pub
#
#   2) Same as above, and auto-join Tailscale using an auth key (recommended for bootstrap):
#      sudo TS_AUTHKEY="tskey-auth-..." ./bootstrap.sh --user mike-1 --pubkey-file ./id_ed25519.pub
#
#   3) If user already exists, just harden + install key:
#      sudo ./bootstrap.sh --user mike-1 --pubkey-file ./id_ed25519.pub --no-create-user
#
# Notes:
#   - You should keep at least one active SSH session open while testing changes.
#   - This script reloads sshd (not restart) to reduce risk.
#
set -euo pipefail

# -----------------------------
# Helpers
# -----------------------------
log()  { printf "\n[+] %s\n" "$*"; }
warn() { printf "\n[!] %s\n" "$*" >&2; }
die()  { printf "\n[ERROR] %s\n" "$*" >&2; exit 1; }

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Run as root: sudo $0 ..."
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# -----------------------------
# Defaults / Args
# -----------------------------
TARGET_USER=""
PUBKEY_FILE=""
CREATE_USER="yes"
ADD_SUDO="yes"
ALLOW_PASSWORD_SSH="no"   # we enforce key-only by default
TAILSCALE_INSTALL="yes"
TAILSCALE_UP="auto"       # auto if TS_AUTHKEY is set, otherwise "manual"
UPDATE_PACKAGES="yes"
INSTALL_BASE_TOOLS="yes"

usage() {
  cat <<'EOF'
bootstrap.sh (Ubuntu Server 24.04) - Raspberry Pi Secure Cluster Bootstrap

Required:
  --user <username>              Target Linux user to configure (e.g., mike-1)
  --pubkey-file <path>           Path to an SSH public key to add to authorized_keys

Optional:
  --no-create-user               Do not create the user if missing
  --no-sudo                      Do not add user to sudo group
  --allow-password-ssh           DO NOT enforce key-only SSH (not recommended)
  --no-tailscale                 Skip Tailscale install
  --tailscale-up manual          Always require manual `tailscale up` even if TS_AUTHKEY exists
  --no-update                    Skip apt update/upgrade
  --no-tools                     Skip installing baseline tools
  -h, --help                     Show help

Environment:
  TS_AUTHKEY                     If set, script will run `tailscale up --authkey ...` (unless tailscale-up manual)

Examples:
  sudo ./bootstrap.sh --user mike-1 --pubkey-file ./id_ed25519.pub
  sudo TS_AUTHKEY="tskey-auth-..." ./bootstrap.sh --user mike-2 --pubkey-file ./id_ed25519.pub
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user) TARGET_USER="${2:-}"; shift 2;;
      --pubkey-file) PUBKEY_FILE="${2:-}"; shift 2;;
      --no-create-user) CREATE_USER="no"; shift;;
      --no-sudo) ADD_SUDO="no"; shift;;
      --allow-password-ssh) ALLOW_PASSWORD_SSH="yes"; shift;;
      --no-tailscale) TAILSCALE_INSTALL="no"; shift;;
      --tailscale-up) TAILSCALE_UP="${2:-}"; shift 2;;
      --no-update) UPDATE_PACKAGES="no"; shift;;
      --no-tools) INSTALL_BASE_TOOLS="no"; shift;;
      -h|--help) usage; exit 0;;
      *) die "Unknown argument: $1 (use --help)";;
    esac
  done

  [[ -n "$TARGET_USER" ]] || die "Missing --user (use --help)"
  [[ -n "$PUBKEY_FILE" ]] || die "Missing --pubkey-file (use --help)"
  [[ -f "$PUBKEY_FILE" ]] || die "Public key file not found: $PUBKEY_FILE"

  if [[ "$TAILSCALE_UP" != "auto" && "$TAILSCALE_UP" != "manual" ]]; then
    die "--tailscale-up must be 'auto' or 'manual'"
  fi
}

# -----------------------------
# System checks
# -----------------------------
check_ubuntu_2404() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == "ubuntu" ]] || die "This script expects Ubuntu. Detected: ${ID:-unknown}"
    [[ "${VERSION_ID:-}" == "24.04" ]] || die "This script expects Ubuntu 24.04. Detected: ${VERSION_ID:-unknown}"
  else
    die "Cannot detect OS version (/etc/os-release missing)"
  fi
}

# -----------------------------
# Packages
# -----------------------------
apt_update_upgrade() {
  if [[ "$UPDATE_PACKAGES" == "yes" ]]; then
    log "Updating packages (apt update && apt -y upgrade)"
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  else
    warn "Skipping apt update/upgrade (--no-update)"
  fi
}

install_base_tools() {
  if [[ "$INSTALL_BASE_TOOLS" == "yes" ]]; then
    log "Installing baseline tools"
    apt-get install -y \
      ca-certificates \
      curl \
      git \
      openssh-server \
      ufw \
      fail2ban \
      jq
  else
    warn "Skipping baseline tools install (--no-tools)"
  fi
}

# -----------------------------
# User + SSH key
# -----------------------------
ensure_user() {
  if id -u "$TARGET_USER" >/dev/null 2>&1; then
    log "User exists: $TARGET_USER"
    return 0
  fi

  if [[ "$CREATE_USER" != "yes" ]]; then
    die "User '$TARGET_USER' does not exist and --no-create-user was set"
  fi

  log "Creating user: $TARGET_USER"
  adduser --disabled-password --gecos "" "$TARGET_USER"

  if [[ "$ADD_SUDO" == "yes" ]]; then
    log "Adding $TARGET_USER to sudo group"
    usermod -aG sudo "$TARGET_USER"
  else
    warn "Not adding $TARGET_USER to sudo (--no-sudo)"
  fi
}

install_authorized_key() {
  log "Installing SSH public key for user: $TARGET_USER"

  local home_dir
  home_dir="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  [[ -n "$home_dir" ]] || die "Could not determine home dir for $TARGET_USER"

  local ssh_dir="${home_dir}/.ssh"
  local auth_keys="${ssh_dir}/authorized_keys"

  install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$ssh_dir"

  # Append only if not already present (keeps it safe for reruns)
  if [[ -f "$auth_keys" ]] && grep -qF "$(cat "$PUBKEY_FILE")" "$auth_keys"; then
    log "Key already present in authorized_keys"
  else
    cat "$PUBKEY_FILE" >> "$auth_keys"
    log "Key appended to authorized_keys"
  fi

  chown "$TARGET_USER":"$TARGET_USER" "$auth_keys"
  chmod 600 "$auth_keys"
}

# -----------------------------
# Tailscale
# -----------------------------
install_tailscale() {
  if [[ "$TAILSCALE_INSTALL" != "yes" ]]; then
    warn "Skipping Tailscale install (--no-tailscale)"
    return 0
  fi

  if command_exists tailscale; then
    log "Tailscale already installed"
    return 0
  fi

  log "Installing Tailscale"
  # Official installer script (common, but still explicit)
  curl -fsSL https://tailscale.com/install.sh | sh

  systemctl enable --now tailscaled
}

tailscale_join_if_possible() {
  if [[ "$TAILSCALE_INSTALL" != "yes" ]]; then
    return 0
  fi

  if [[ "$TAILSCALE_UP" == "manual" ]]; then
    warn "tailscale up is set to manual. Skipping auto-join."
    warn "Run: sudo tailscale up"
    return 0
  fi

  if [[ -n "${TS_AUTHKEY:-}" ]]; then
    log "Joining tailnet using TS_AUTHKEY"
    # You can add more flags later when you know exactly what you want:
    # --ssh, --accept-dns, --advertise-exit-node, etc.
    tailscale up --authkey="${TS_AUTHKEY}"
  else
    warn "TS_AUTHKEY not set, so skipping auto-join."
    warn "Run: sudo tailscale up"
  fi
}

# -----------------------------
# SSH hardening (Ubuntu 24.04 merged config aware)
# -----------------------------
backup_file_if_exists() {
  local f="$1"
  if [[ -f "$f" ]]; then
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    cp -a "$f" "${f}.bak.${ts}"
    log "Backed up $f -> ${f}.bak.${ts}"
  fi
}

harden_sshd() {
  log "Hardening SSH server (sshd_config.d drop-in)"

  # Make sure sshd is installed
  command_exists sshd || die "sshd not found. Is openssh-server installed?"

  local dropin="/etc/ssh/sshd_config.d/99-secure.conf"
  backup_file_if_exists "$dropin"

  # Key-only by default.
  # The big lever is AuthenticationMethods publickey
  # This survives cloud-init or other layered config decisions.
  if [[ "$ALLOW_PASSWORD_SSH" == "yes" ]]; then
    warn "Password SSH allowed by flag (--allow-password-ssh). Not recommended for your lab goals."
    cat > "$dropin" <<'EOF'
# 99-secure.conf
# NOTE: password SSH intentionally allowed (not recommended)

PasswordAuthentication yes
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
EOF
  else
    cat > "$dropin" <<'EOF'
# 99-secure.conf
# Enforce public key authentication only (Ubuntu 24.04 + cloud-init aware)

AuthenticationMethods publickey
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
EOF
  fi

  chmod 644 "$dropin"

  # Reload, don’t restart, to reduce the chance of dropping active sessions
  log "Reloading sshd"
  systemctl reload sshd
}

verify_sshd_effective_config() {
  log "Verifying effective sshd config (sshd -T)"

  local out
  out="$(sshd -T 2>/dev/null || true)"
  [[ -n "$out" ]] || die "Failed to read effective sshd config with sshd -T"

  echo "$out" | grep -E 'authenticationmethods|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication' || true

  if [[ "$ALLOW_PASSWORD_SSH" != "yes" ]]; then
    # Hard requirements for your desired posture
    echo "$out" | grep -q '^passwordauthentication no$' || die "Expected: passwordauthentication no (but it isn't)"
    echo "$out" | grep -q '^kbdinteractiveauthentication no$' || die "Expected: kbdinteractiveauthentication no (but it isn't)"
    echo "$out" | grep -q '^authenticationmethods publickey$' || die "Expected: authenticationmethods publickey (but it isn't)"
  fi

  log "SSHD effective config checks passed"
}

print_next_steps() {
  log "Next steps / sanity checks"

  cat <<EOF
1) Keep this SSH session open while testing a NEW session.

2) From your laptop (or another machine), test key auth:
   ssh ${TARGET_USER}@<pi-hostname-or-tailscale-ip>

3) Confirm password auth fails (expected):
   ssh -o PreferredAuthentications=password ${TARGET_USER}@<host>

4) Confirm effective server settings:
   sudo sshd -T | grep -E 'authenticationmethods|passwordauthentication|kbdinteractiveauthentication'

5) If you skipped Tailscale join:
   sudo tailscale up

EOF
}

# -----------------------------
# Main
# -----------------------------
main() {
  need_root
  parse_args "$@"
  check_ubuntu_2404

  log "Bootstrap starting (Ubuntu 24.04 verified)"
  apt_update_upgrade
  install_base_tools

  ensure_user
  install_authorized_key

  install_tailscale
  tailscale_join_if_possible

  harden_sshd
  verify_sshd_effective_config

  print_next_steps
  log "Bootstrap complete"
}

main "$@"

