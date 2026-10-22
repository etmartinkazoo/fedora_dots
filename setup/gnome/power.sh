#!/usr/bin/env bash
# GNOME power / session: no suspend, auto-lock, ambient off.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

log "Disabling auto-suspend and dimming"
gset org.gnome.settings-daemon.plugins.power idle-dim false
gset org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gset org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gset org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery false

# Auto-lock: blank + lock after idle. Machine still never suspends (above).
log "Enabling screen auto-lock (10 min idle)"
gset org.gnome.desktop.session idle-delay 'uint32 600'
gset org.gnome.desktop.screensaver lock-enabled true
gset org.gnome.desktop.screensaver lock-delay 'uint32 0'

log "Disabling auto-brightness; showing battery percentage"
gset org.gnome.settings-daemon.plugins.power ambient-enabled false
gset org.gnome.desktop.interface show-battery-percentage true
