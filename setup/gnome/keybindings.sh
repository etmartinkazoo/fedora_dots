#!/usr/bin/env bash
# Window management, workspaces, and media keybindings.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

log "Setting window management keybindings"
WM='org.gnome.desktop.wm.keybindings'
MUTTER='org.gnome.mutter.keybindings'
gset $WM     show-desktop       "['<Alt>d']"
gset $WM     close              "['<Alt>w']"
gset $WM     minimize           "['<Alt>h']"
gset $WM     toggle-maximized   "['<Alt>m']"
gset $WM     toggle-fullscreen  "['<Alt>f']"
gset $MUTTER toggle-tiled-left  "['<Alt>a']"
gset $MUTTER toggle-tiled-right "['<Alt>s']"

log "Configuring 4 static workspaces"
gset org.gnome.mutter dynamic-workspaces false
gset org.gnome.desktop.wm.preferences num-workspaces 4
for i in $(seq 1 4); do
  gset $WM switch-to-workspace-"${i}" "['<Super>${i}']"
  gset $WM move-to-workspace-"${i}"   "['<Super><Shift>${i}']"
done

log "Enabling Alt+click move and Alt+right-click resize"
gset org.gnome.desktop.wm.preferences mouse-button-modifier '<Alt>'
gset org.gnome.desktop.wm.preferences resize-with-right-button true

log "Binding Ctrl+Alt+W (browser), Ctrl+Alt+F (files)"
gset org.gnome.settings-daemon.plugins.media-keys www  "['<Control><Alt>w']"
gset org.gnome.settings-daemon.plugins.media-keys home "['<Control><Alt>f']"

log "Binding app-launcher shortcuts (Alt+T Ghostty, Ctrl+Alt+S Slack)"
# This file owns the whole custom-keybindings list AND every entry's fields, so
# there's no cross-file dependency (the terminal-launcher entry used to be split
# into terminal.sh).
CK='org.gnome.settings-daemon.plugins.media-keys.custom-keybinding'
CK_BASE='/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings'

gset "$CK:$CK_BASE/ghostty/" name    'Ghostty'
gset "$CK:$CK_BASE/ghostty/" command 'ghostty'
gset "$CK:$CK_BASE/ghostty/" binding '<Alt>t'

gset "$CK:$CK_BASE/slack/" name    'Slack'
gset "$CK:$CK_BASE/slack/" command 'flatpak run com.slack.Slack'
gset "$CK:$CK_BASE/slack/" binding '<Control><Alt>s'

gset org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
  "['$CK_BASE/ghostty/', '$CK_BASE/slack/']"
