#!/usr/bin/env bash
#
# privacy.sh — disable telemetry, crash reporting, phone-home, and background
# tasks. Goals: privacy, battery, efficiency, less heat.
# Target: Fedora 44 Workstation (GNOME).
# Idempotent. System changes need sudo. Runnable standalone or via bootstrap.sh.
#
# Tradeoffs (intentional quiet machine):
#   - Automatic dnf upgrades limited to SECURITY only (feature upgrades stay manual)
#   - Flatpak updates confined to a nightly window (security updates still land)
#   - CUPS masked (re-enable: sudo systemctl unmask --now cups.service cups.socket)
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Cache sudo credentials — works both standalone and from bootstrap parent.
sudo -n true 2>/dev/null || sudo -v

# mask_unit / mask_user_unit / gset / sync_root_file come from lib.sh.

# ===========================================================================
# Crash reporting / telemetry  (system, needs sudo)
# ===========================================================================

log "Disabling ABRT crash reporting"
for u in abrtd.service abrt-journal-core.service abrt-oops.service \
  abrt-pstoreoops.service abrt-vmcore.service abrt-xorg.service; do
  mask_unit "$u"
done

# Every Fedora repo ships countme=1, which sends a weekly anonymous "count me"
# flag with metadata requests. A glob override applies to all repos, including
# ones added later (COPRs, Docker, Chrome), without touching packaged files.
log "Disabling dnf countme (weekly install-base ping)"
printf '# Managed by dotfiles privacy.sh\n[*]\ncountme=0\n' \
  | sync_root_file /etc/dnf/repos.override.d/80-dotfiles-no-countme.repo || true

log "Disabling systemd coredump collection"
if printf '[Coredump]\nStorage=none\nProcessSizeMax=0\n' \
  | sync_root_file /etc/systemd/coredump.conf.d/99-disable.conf; then
  sudo systemctl daemon-reload
fi

# NetworkManager connectivity check stays ON: without it, hotel/café captive
# portal login pages never pop up. Remove the drop-in older runs installed.
if [ -f /etc/NetworkManager/conf.d/20-no-connectivity-check.conf ]; then
  log "Re-enabling NetworkManager connectivity check (captive portals)"
  sudo rm -f /etc/NetworkManager/conf.d/20-no-connectivity-check.conf
  sudo systemctl reload NetworkManager 2>/dev/null || true
fi

# ===========================================================================
# Background activity: battery / efficiency / heat  (system, needs sudo)
# ===========================================================================

log "Enabling automatic SECURITY updates (dnf5-automatic)"
# Only advisories of type "security" are applied; feature/full upgrades stay
# manual (UPGRADE=1 ./setup/packages/dnf.sh). Never reboots on its own. The
# file only carries overrides — distro defaults live in
# /usr/share/dnf5/dnf5-plugins/automatic.conf.
if rpm_installed dnf5-plugin-automatic; then
  printf '# Managed by dotfiles privacy.sh\n[commands]\nupgrade_type = security\napply_updates = yes\nreboot = never\n' \
    | sync_root_file /etc/dnf/automatic.conf || true
  enable_unit dnf5-automatic.timer
else
  warn "dnf5-plugin-automatic not installed — security auto-updates won't run until:"
  warn "  sudo dnf install dnf5-plugin-automatic"
fi

log "Disabling PackageKit offline updates"
mask_unit packagekit-offline-update.service

log "Disabling CUPS printing"
mask_unit cups.service
mask_unit cups.socket
mask_unit cups.path
mask_unit cups-browsed.service

log "Disabling ModemManager (no modem on this hardware)"
mask_unit ModemManager.service

log "Disabling systemd-pstore (persistent kernel panic storage)"
mask_unit systemd-pstore.service

# ===========================================================================
# Flatpak update window  (needs sudo, idempotent)
# ===========================================================================

log "Confining Flatpak updates to a nightly window (security updates keep flowing)"
# GNOME Software's background updates are off (below), so this timer is what
# keeps system Flatpaks patched: once a night between 03:00 and 05:00.
# Persistent=true catches up on a missed run when the laptop was off/asleep,
# so patches still land within a day.
changed=0
sync_root_file /etc/systemd/system/dotfiles-flatpak-update.service <<'EOF' && changed=1
[Unit]
Description=Update system Flatpak apps (managed by dotfiles privacy.sh)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak update --system --noninteractive -y
EOF
sync_root_file /etc/systemd/system/dotfiles-flatpak-update.timer <<'EOF' && changed=1
[Unit]
Description=Nightly Flatpak update window (managed by dotfiles privacy.sh)

[Timer]
OnCalendar=*-*-* 03:00
RandomizedDelaySec=2h
Persistent=true

[Install]
WantedBy=timers.target
EOF
[ "$changed" -eq 1 ] && sudo systemctl daemon-reload
enable_unit dotfiles-flatpak-update.timer

# ===========================================================================
# Per-user GNOME privacy + background indexer  (no sudo)
# ===========================================================================

log "GNOME privacy settings (telemetry + location + recent files/app history off)"
gset org.gnome.desktop.privacy report-technical-problems false
gset org.gnome.desktop.privacy send-software-usage-stats false
gset org.gnome.desktop.privacy remember-recent-files false
gset org.gnome.desktop.privacy remember-app-usage false
gset org.gnome.system.location enabled false
# Slack/email previews stay off the lock screen (the count still shows).
gset org.gnome.desktop.notifications show-in-lock-screen false

log "Disabling GNOME Software background updates"
gset org.gnome.software download-updates false
gset org.gnome.software download-updates-notify false

log "Masking file-indexer services (localsearch/tracker)"
for svc in \
  localsearch-3.service localsearch-control-3.service localsearch-writeback-3.service \
  tracker-miner-fs-3.service tracker-extract-3.service tracker-miner-rss-3.service \
  tracker-miner-fs-control-3.service; do
  mask_user_unit "$svc"
done

log "Privacy hardening complete"
