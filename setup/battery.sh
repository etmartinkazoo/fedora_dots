#!/usr/bin/env bash
#
# battery.sh — set power profile to power-saver (default) and, if the kernel
# exposes it, cap battery charge at 80 % for longevity. Idempotent.
# Needs sudo for the charge threshold. Runnable standalone or via bootstrap.sh.
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# ------------------------------------------------------------------
# 1) Set GNOME / system power profile to power-saver
# ------------------------------------------------------------------
if ! command -v powerprofilesctl &>/dev/null; then
  log "  powerprofilesctl not found — skipping"
elif [ "$(powerprofilesctl get 2>/dev/null)" = power-saver ]; then
  log "Power profile already power-saver"
else
  log "Setting power profile to power-saver"
  powerprofilesctl set power-saver
fi

# ------------------------------------------------------------------
# 2) Battery charge threshold (80 %) — only on supported hardware.
# ------------------------------------------------------------------
BAT=""
for d in /sys/class/power_supply/BAT*; do
  [ -e "$d/charge_control_end_threshold" ] && BAT="$(basename "$d")" && break
done

if [ -n "$BAT" ]; then
  threshold="/sys/class/power_supply/${BAT}/charge_control_end_threshold"
  if [ "$(cat "$threshold")" = 80 ]; then
    log "$BAT charge already capped at 80 %"
  else
    log "Capping $BAT charge at 80 % (longevity)"
    echo 80 | sudo tee "$threshold" >/dev/null
  fi

  # Make it persistent across reboots via a systemd tmpfiles.d rule.
  printf 'w /sys/class/power_supply/%s/charge_control_end_threshold - - - - 80\n' "$BAT" \
    | sync_root_file /etc/tmpfiles.d/50-battery-charge-threshold.conf || true
else
  log "Battery charge threshold not supported by kernel/hardware — skipping"
fi

log "Battery optimization complete"
