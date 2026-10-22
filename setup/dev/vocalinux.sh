#!/usr/bin/env bash
# Vocalinux — offline voice dictation. Installed via upstream installer.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

if [ -x "$HOME/.local/bin/vocalinux" ]; then
  ver="$("$HOME/.local/bin/vocalinux" --version 2>/dev/null || true)"
  log "Vocalinux already installed (${ver:-version unknown}) — skipping"
  exit 0
fi

log "Installing Vocalinux (voice dictation)"
log "  engine: whisper.cpp (default, offline, private)"
installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL "https://raw.githubusercontent.com/jatinkrmalik/vocalinux/main/install.sh" \
  -o "$installer"
bash "$installer" --auto

# Add user to input group for global keyboard shortcuts on Wayland.
if ! groups "$USER" 2>/dev/null | grep -qw input; then
  log "Adding $USER to input group (global hotkeys; log out/in to take effect)"
  sudo usermod -aG input "$USER"
fi
