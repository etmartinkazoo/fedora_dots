#!/usr/bin/env bash
# Tela icon theme (https://github.com/vinceliuice/Tela-icon-theme).
# Tela is not in the Fedora repos, so it comes from the upstream install
# script; themes land in ~/.local/share/icons.
# Mirrors terminal.sh, which installs its own asset (the Nerd Font) here too.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

ICON_DIR="$HOME/.local/share/icons/Tela"

tmp=""
cleanup() {
  if [ -n "${tmp:-}" ]; then
    rm -rf "$tmp"
  fi
}
trap cleanup EXIT

if [ -f "$ICON_DIR/index.theme" ]; then
  log "Tela icon theme already installed"
else
  log "Installing Tela icon theme (upstream install script)"
  tmp="$(mktemp -d)"
  git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git "$tmp/tela"
  "$tmp/tela/install.sh"
fi

log "Setting Tela as the GNOME icon theme"
gset org.gnome.desktop.interface icon-theme 'Tela'
