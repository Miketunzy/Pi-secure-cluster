#!/usr/bin/env bash
# 01-verify.sh
#
# Purpose:
#   Verify the state of a bootstrapped Ubuntu 24.04 node:
#   - Target user exists
#   - User has sudo access
#   - SSH directory permissions are correct
#   - authorized_keys permissions are correct
#   - sshd enforces public key authentication only
#   - Password authentication is disabled
#   - Tailscale is installed and running
#
# Philosophy:
#   - Trust but verify
#   - Every check is explicit and documented
#   - Fail fast with clear error messages
#
# Usage:
#   sudo ./01-verify.sh --user <username>

set -euo pipefail

# ─── Helpers ────────────────────────────────────────────────────────────────

PASS="\e[32m[PASS]\e[0m"
FAIL="\e[31m[FAIL]\e[0m"
INFO="\e[34m[INFO]\e[0m"

passed=0
failed=0

check() {
    local description="$1"
    local result="$2"

    if [[ "$result" == "pass" ]]; then
        echo -e "$PASS $description"
        ((passed++))
    else
        echo -e "$FAIL $description"
        ((failed++))
    fi
}

# ─── Argument Parsing ───────────────────────────────────────────────────────

TARGET_USER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user) TARGET_USER="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: sudo ./01-verify.sh --user <username>"
            exit 0
            ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$TARGET_USER" ]]; then
    echo "[ERROR] Missing --user (use --help)"
    exit 1
fi

echo ""
echo -e "$INFO Starting verification for user: $TARGET_USER"
echo ""

# ─── Checks ─────────────────────────────────────────────────────────────────

# 1. User exists
id "$TARGET_USER" &>/dev/null \
    && check "User '$TARGET_USER' exists" "pass" \
    || check "User '$TARGET_USER' exists" "fail"

# 2. User has sudo access
groups "$TARGET_USER" | grep -qw sudo \
    && check "User '$TARGET_USER' is in sudo group" "pass" \
    || check "User '$TARGET_USER' is in sudo group" "fail"

# 3. .ssh directory permissions
SSH_DIR="/home/$TARGET_USER/.ssh"
if [[ -d "$SSH_DIR" ]]; then
    perms=$(stat -c "%a" "$SSH_DIR")
    [[ "$perms" == "700" ]] \
        && check ".ssh directory permissions are 700" "pass" \
        || check ".ssh directory permissions are 700 (got $perms)" "fail"
else
    check ".ssh directory exists" "fail"
fi

# 4. authorized_keys permissions
AUTH_KEYS="$SSH_DIR/authorized_keys"
if [[ -f "$AUTH_KEYS" ]]; then
    perms=$(stat -c "%a" "$AUTH_KEYS")
    [[ "$perms" == "600" ]] \
        && check "authorized_keys permissions are 600" "pass" \
        || check "authorized_keys permissions are 600 (got $perms)" "fail"
else
    check "authorized_keys file exists" "fail"
fi

# 5. AuthenticationMethods is publickey
auth_methods=$(sshd -T 2>/dev/null | grep "^authenticationmethods")
echo "$auth_methods" | grep -q "publickey" \
    && check "AuthenticationMethods enforces publickey" "pass" \
    || check "AuthenticationMethods enforces publickey" "fail"

# 6. Password authentication is disabled
password_auth=$(sshd -T 2>/dev/null | grep "^passwordauthentication")
echo "$password_auth" | grep -q "no" \
    && check "PasswordAuthentication is disabled" "pass" \
    || check "PasswordAuthentication is disabled" "fail"

# 7. Tailscale installed
command -v tailscale &>/dev/null \
    && check "Tailscale is installed" "pass" \
    || check "Tailscale is installed" "fail"

# 8. Tailscale service running
systemctl is-active --quiet tailscaled \
    && check "Tailscale service is running" "pass" \
    || check "Tailscale service is running" "fail"

# ─── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────────"
echo -e "$INFO Results: $passed passed, $failed failed"
echo "─────────────────────────────────────"
echo ""

[[ "$failed" -eq 0 ]] && exit 0 || exit 1