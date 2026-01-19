#!/usr/bin/env bash
set -e

echo "[+] Updating package lists"
sudo apt update

echo "[+] Upgrading installed packages"
sudo apt upgrade -y

echo "[+] Installing base utilities"
sudo apt install -y \
  curl \
  git \
  ufw \
  ca-certificates

echo "[+] Bootstrap complete"

