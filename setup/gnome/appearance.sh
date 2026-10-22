#!/usr/bin/env bash
# GNOME appearance: dark mode, night light, clock, animations.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

log "Enabling dark mode"
gset org.gnome.desktop.interface color-scheme 'prefer-dark'
gset org.gnome.desktop.interface gtk-theme 'Adwaita'

log "Enabling Night Light (always on)"
gset org.gnome.settings-daemon.plugins.color night-light-enabled true
gset org.gnome.settings-daemon.plugins.color night-light-schedule-automatic false
gset org.gnome.settings-daemon.plugins.color night-light-schedule-from 0.0
gset org.gnome.settings-daemon.plugins.color night-light-schedule-to 24.0

log "Setting 12-hour clock"
gset org.gnome.desktop.interface clock-format '12h'

log "Disabling animations"
gset org.gnome.desktop.interface enable-animations false
