#!/usr/bin/env bash
# Flatpak apps from Flathub (Slack).
# Fedora ships only its own `fedora` remote (and at most a filtered, disabled
# Flathub via fedora-third-party), so the full Flathub remote is added here.
# Apps are installed system-wide; privacy.sh confines their updates to a
# nightly window.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
APPS=(com.slack.Slack)

dnf_install flatpak

flathub="$(flatpak remotes --system --show-disabled --columns=name,options 2>/dev/null | awk '$1 == "flathub"')"
if [ -z "$flathub" ]; then
  log "Adding the Flathub remote"
  sudo flatpak remote-add --system --if-not-exists flathub "$FLATHUB_URL"
elif [[ $flathub == *disabled* || $flathub == *filtered* ]]; then
  log "Enabling the full (unfiltered) Flathub remote"
  sudo flatpak remote-modify --system --enable --no-filter flathub
else
  echo "  Flathub remote already enabled"
fi

log "Installing Flatpak apps (${APPS[*]})"
for app in "${APPS[@]}"; do
  if flatpak info --system "$app" >/dev/null 2>&1; then
    echo "  $app already installed — skipping"
  else
    sudo flatpak install --system -y --noninteractive flathub "$app"
  fi
done
