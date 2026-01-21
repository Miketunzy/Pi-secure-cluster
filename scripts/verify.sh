#!/usr/bin/env bash
set -euo pipefail

echo "[*] Effective SSH authentication settings:"
sshd -T | grep -E 'authenticationmethods|passwordauthentication|kbdinteractiveauthentication'

echo
echo "[*] If passwordauthentication is not 'no', STOP."
