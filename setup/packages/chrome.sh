#!/usr/bin/env bash
# Google Chrome (official Google rpm repository).
# https://www.google.com/linuxrepositories/
# Fedora Workstation already ships the repo definition, disabled, in
# fedora-workstation-repositories (/etc/yum.repos.d/google-chrome.repo); it is
# enabled through a dnf override (the packaged file stays untouched) or written
# from scratch when missing. The repo only ships x86_64 builds.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

REPO_FILE="/etc/yum.repos.d/google-chrome.repo"

# Checked even when Chrome is installed: with the repo disabled it never updates.
if dnf -q repo list --enabled 2>/dev/null | awk '{print $1}' | grep -qx google-chrome; then
  echo "  google-chrome repo already enabled"
elif [ -f "$REPO_FILE" ]; then
  log "Enabling the google-chrome repo"
  sudo dnf config-manager setopt google-chrome.enabled=1
else
  log "Adding the google-chrome repo"
  sync_root_file "$REPO_FILE" <<'EOF' || true
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
enabled=1
EOF
fi

if rpm_installed google-chrome-stable; then
  log "Google Chrome already installed ($(google-chrome --version 2>/dev/null || echo google-chrome-stable)) — skipping"
else
  log "Installing Google Chrome from the official Google rpm repository"
  sudo dnf install -y google-chrome-stable
fi
