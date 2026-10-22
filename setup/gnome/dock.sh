#!/usr/bin/env bash
# Dash to Dock: auto-hide, bottom, centered, non-panel.
# Fedora's GNOME is vanilla (no dock), so the extension comes from the Fedora
# repo and is enabled here. A freshly installed extension is only picked up
# by GNOME Shell after logging out and back in (Wayland).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

DOCK_UUID='dash-to-dock@micxgx.gmail.com'

if ! rpm_installed gnome-shell-extension-dash-to-dock; then
  dnf_install gnome-shell-extension-dash-to-dock
  # The schema cache inherited from the runner predates the install.
  refresh_schemas
fi

enabled="$(gsettings get org.gnome.shell enabled-extensions)"
if [[ $enabled == *"'$DOCK_UUID'"* ]]; then
  echo "  Dash to Dock already enabled"
else
  log "Enabling Dash to Dock (takes effect after the next login)"
  case "$enabled" in
    "@as []" | "[]") enabled="['$DOCK_UUID']" ;;
    *) enabled="${enabled%]}, '$DOCK_UUID']" ;;
  esac
  gsettings set org.gnome.shell enabled-extensions "$enabled"
fi
gset org.gnome.shell disable-user-extensions false

log "Disabling Super+<num> app launch shortcuts"
gset org.gnome.shell.extensions.dash-to-dock hot-keys false
for i in $(seq 1 9); do
  gset org.gnome.shell.keybindings switch-to-application-"${i}" '[]'
done

# dock-fixed=true keeps the dock always visible and ignores autohide.
# With dock-position BOTTOM, extend-height=false keeps the dock a centered
# floating bar instead of stretching it edge to edge (extend-height=true).
if has_schema org.gnome.shell.extensions.dash-to-dock; then
  log "Configuring Dash to Dock (auto-hide, bottom, centered, non-panel)"
  gset org.gnome.shell.extensions.dash-to-dock dock-fixed false
  gset org.gnome.shell.extensions.dash-to-dock autohide true
  gset org.gnome.shell.extensions.dash-to-dock extend-height false
  gset org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
fi
