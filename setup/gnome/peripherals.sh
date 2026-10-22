#!/usr/bin/env bash
# Input devices, Nautilus, titlebar.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

log "Titlebar buttons, Nautilus view"
gset org.gnome.desktop.wm.preferences button-layout ':close'
gset org.gnome.nautilus.preferences default-folder-viewer 'list-view'

log "Setting traditional (non-natural) scroll direction on trackpad and mouse"
gset org.gnome.desktop.peripherals.touchpad natural-scroll false
gset org.gnome.desktop.peripherals.mouse natural-scroll false

log "Tuning keyboard repeat; swapping Ctrl/Caps Lock"
gset org.gnome.desktop.peripherals.keyboard repeat true
gset org.gnome.desktop.peripherals.keyboard delay 'uint32 150'
gset org.gnome.desktop.peripherals.keyboard repeat-interval 'uint32 10'
gset org.gnome.desktop.input-sources xkb-options "['ctrl:swapcaps']"
