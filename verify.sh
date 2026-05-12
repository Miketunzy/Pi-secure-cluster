#!/usr/bin/env bash
# verify.sh
# Purpose: Verify state of a bootstrapped Ubuntu 24.04 node

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

TARGET_USER=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user) TARGET_USER="$2"; shift 2 ;;
        -h|--help) echo "Usage: sudo ./verify.sh --user <username>"; exit 0 ;;
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

# 1. User exists
if id "$TARGET_USER" &>/dev/null; then
    check "User '$TARGET_USER' exists" "pass"
else
    check "User '$TARGET_USER' exists" "fail"
fi

# 2. User has sudo access
if groups "$TARGET_USER" | grep -qw sudo; then
    check "User '$TARGET_USER' is in sudo group" "pass"
else
    check "User '$TARGET_USER' is in sudo group" "fail"
fi

# 3. .ssh directory permissions
SSH_DIR="/home/$TARGET_USER/.ssh"
if [[ -d "$SSH_DIR" ]]; then
    perms=$(stat -c "%a" "$SSH_DIR")
    if [[ "$perms" == "700" ]]; then
        check ".ssh directory permissions are 700" "pass"
    else
        check ".ssh directory permissions are 700 (got $perms)" "fail"
    fi
else
    check ".ssh directory exists" "fail"
fi

# 4. authorized_keys permissions
AUTH_KEYS="$SSH_DIR/authorized_keys"
if [[ -f "$AUTH_KEYS" ]]; then
    perms=$(stat -c "%a" "$AUTH_KEYS")
    if [[ "$perms" == "600" ]]; then
        check "authorized_keys permissions are 600" "pass"
    else
        check "authorized_keys permissions are 600 (got $perms)" "fail"
    fi
else
    check "authorized_keys file exists" "fail"
fi

# 5. AuthenticationMethods is publickey
if sshd -T 2>/dev/null | grep "^authenticationmethods" | grep -q "publickey"; then
    check "AuthenticationMethods enforces publickey" "pass"
else
    check "AuthenticationMethods enforces publickey" "fail"
fi

# 6. Password authentication disabled
if sshd -T 2>/dev/null | grep "^passwordauthentication" | grep -q "no"; then
    check "PasswordAuthentication is disabled" "pass"
else
    check "PasswordAuthentication is disabled" "fail"
fi

# 7. Tailscale installed
if command -v tailscale &>/dev/null; then
    check "Tailscale is installed" "pass"
else
    check "Tailscale is installed" "fa