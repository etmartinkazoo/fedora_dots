#!/usr/bin/env bash
# VSCodium (https://vscodium.com) — upstream rpm repository + extensions.
# https://vscodium.com/#install-on-fedora-rhel-centos-rockylinux-opensuse-rpm-package
# Settings are the stowed `vscodium` package (~/.config/VSCodium/User).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

EXTENSIONS=(vscodevim.vim)

# Repo definition as published upstream; dnf imports the key on first install
# (-y accepts it). Both packages and metadata are signature-checked.
log "Checking the VSCodium rpm repo"
sync_root_file /etc/yum.repos.d/vscodium.repo <<'REPO' || echo "  vscodium.repo already up to date"
[gitlab.com_paulcarroty_vscodium_repo]
name=download.vscodium.com
baseurl=https://download.vscodium.com/rpms/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg
metadata_expire=1h
REPO

if rpm_installed codium; then
  log "VSCodium already installed ($(codium --version 2>/dev/null | head -1 || echo codium)) — skipping"
else
  log "Installing VSCodium"
  sudo dnf install -y codium
fi

# Extensions come from Open VSX (VSCodium's marketplace).
installed="$(codium --list-extensions 2>/dev/null || true)"
for ext in "${EXTENSIONS[@]}"; do
  if grep -qix "$ext" <<<"$installed"; then
    echo "  $ext already installed"
  else
    log "Installing VSCodium extension $ext"
    codium --install-extension "$ext"
  fi
done
