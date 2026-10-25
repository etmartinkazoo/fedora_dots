#!/usr/bin/env bash
#
# bootstrap.sh — provision a fresh Fedora 44 Workstation by running setup
# modules in order. Idempotent: safe to re-run.
#
# Symlinks dotfiles first (via stow.sh), then provisions packages, desktop,
# privacy, network, and app prefs.
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Cache sudo credentials up front so all module subprocesses run without prompting.
log "Checking sudo access"
sudo -v

# Keep sudo alive during long-running bootstrap (refresh every 4 min).
while true; do sudo -n true 2>/dev/null; sleep 240; done &
SUDO_KEEPER=$!
trap 'kill "$SUDO_KEEPER" 2>/dev/null || true' EXIT

log "Symlinking dotfiles with stow"
bash "$REPO_ROOT/stow.sh"

# Explicit ordered list. The grouped runners (packages.sh, dev_tools.sh,
# gnome.sh) own their own sub-module lists — this is the single source of truth
# for what a full provision runs, so there's no leaf list to keep in sync here.
MODULES=(
  packages.sh      # dnf + flatpaks + vscodium + chrome
  dev_tools.sh     # mise, rootless podman, third-party tools (Docker: USE_DOCKER=1)
  gnome.sh         # dock, power, appearance, keybindings, terminal, icons, peripherals
  privacy.sh
  security.sh      # firewall, DNS-over-TLS, third-party updates, tailscale, git signing
  profiles.sh      # ~/Profiles walls + rootless Podman shells (personal/consultancy/brem/lumin)
  chrome.sh        # system policies + 4 profiles (Bitwarden)
  battery.sh
)

for mod in "${MODULES[@]}"; do
  sudo -v      # refresh credential before each module
  run_module "$mod"
done

log "Bootstrap complete"
