#!/usr/bin/env bash
# Ghostty default terminal + JetBrainsMono Nerd Font.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

# Ghostty comes from packages/dnf.sh (scottames/ghostty COPR); its config is the
# stowed `ghostty` package. The Alt+T launcher keybinding lives in
# keybindings.sh, which owns the whole custom-keybindings list.
#
# This module only (a) points GNOME's default-terminal setting at Ghostty and
# (b) installs the shared Nerd Font.
#
# Ptyxis (Fedora Workstation's stock terminal) is left installed on purpose as
# a fallback that ships with the desktop; it is simply no longer configured or
# launched.
if has_schema org.gnome.desktop.default-applications.terminal; then
  log "Setting Ghostty as the default terminal"
  gset org.gnome.desktop.default-applications.terminal exec 'ghostty'
fi

FONT_VERSION="v3.4.0"
FONT_SHA256="76f05ff3ace48a464a6ca57977998784ff7bdbb65a6d915d7e401cd3927c493c"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
tmp=""
cleanup() {
  if [ -n "${tmp:-}" ]; then
    rm -rf "$tmp"
  fi
}
trap cleanup EXIT

if [ -d "$FONT_DIR" ] && ls "$FONT_DIR"/*.ttf &>/dev/null; then
  log "JetBrainsMono Nerd Font already installed"
else
  log "Installing JetBrainsMono Nerd Font ($FONT_VERSION)"
  mkdir -p "$FONT_DIR"
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/JetBrainsMono.zip" \
    -o "$tmp/JetBrainsMono.zip"
  # Verify against the SHA-256 published in the release's SHA-256.txt before trusting the archive.
  echo "${FONT_SHA256}  $tmp/JetBrainsMono.zip" | sha256sum -c - \
    || error "JetBrainsMono.zip checksum mismatch — refusing to install (expected $FONT_SHA256)"
  unzip -o -q "$tmp/JetBrainsMono.zip" '*.ttf' -d "$FONT_DIR"
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1
fi
