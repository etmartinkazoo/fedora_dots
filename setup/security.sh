#!/usr/bin/env bash
#
# security.sh — shrink the network attack surface and keep third-party apps
# patched. Target: Fedora 44 Workstation (GNOME) on a laptop that roams onto
# untrusted Wi-Fi.
# Idempotent. System changes need sudo. Runnable standalone or via bootstrap.sh.
#
# Tradeoffs (intentional):
#   - No inbound ports on Wi-Fi: dev servers bound to 0.0.0.0 are unreachable
#     from the LAN. To share one, drop shields temporarily and use
#     `tailscale serve` rather than reopening ports.
#   - Tailscale shields-up: no inbound tailnet connections to this laptop
#     (outbound to beebox etc. unaffected; Taildrop receive is blocked).
#     Undo: sudo tailscale set --shields-up=false
#   - DNS-over-TLS is opportunistic so captive portals still work; strict mode
#     would hide hotel/café login pages.
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

sudo -n true 2>/dev/null || sudo -v

# ===========================================================================
# Firewall: close the FedoraWorkstation zone  (system, needs sudo)
# ===========================================================================

# Fedora's Workstation zone accepts every TCP/UDP port from 1025-65535 plus
# ssh and samba-client. dhcpv6-client stays: IPv6 address assignment needs it.
ZONE=FedoraWorkstation
if command -v firewall-cmd >/dev/null 2>&1 &&
  firewall-cmd --permanent --get-zones 2>/dev/null | grep -qw "$ZONE"; then
  log "Closing inbound ports in the $ZONE firewall zone"
  fw_changed=0
  for p in 1025-65535/tcp 1025-65535/udp; do
    if sudo firewall-cmd --permanent --zone="$ZONE" --query-port="$p" >/dev/null 2>&1; then
      sudo firewall-cmd --permanent --zone="$ZONE" --remove-port="$p" >/dev/null
      echo "  removed port $p"
      fw_changed=1
    fi
  done
  for s in ssh samba-client; do
    if sudo firewall-cmd --permanent --zone="$ZONE" --query-service="$s" >/dev/null 2>&1; then
      sudo firewall-cmd --permanent --zone="$ZONE" --remove-service="$s" >/dev/null
      echo "  removed service $s"
      fw_changed=1
    fi
  done
  if [ "$fw_changed" -eq 1 ]; then
    sudo firewall-cmd --reload >/dev/null
  else
    echo "  $ZONE already closed"
  fi
else
  warn "firewalld zone $ZONE not found — skipping firewall hardening"
fi

# ===========================================================================
# DNS: Cloudflare over TLS, no LLMNR  (system, needs sudo)
# ===========================================================================

# 1.1.1.2 / 1.0.0.2 is Cloudflare's malware-blocking resolver. Domains=~.
# routes every lookup to these servers instead of the DHCP-provided ISP
# resolver; Tailscale keeps its own routing domain, so MagicDNS still works.
# Chrome's DnsOverHttpsMode stays "off" (chrome.sh) because the system
# resolver is now the encrypted one. LLMNR answers name lookups from anyone on
# the LAN and is a classic spoofing vector on shared Wi-Fi.
log "Routing DNS to Cloudflare over TLS (resolved)"
if sync_root_file /etc/systemd/resolved.conf.d/90-dotfiles-dns.conf <<'EOF'; then
# Managed by dotfiles security.sh
[Resolve]
DNS=1.1.1.2#security.cloudflare-dns.com 1.0.0.2#security.cloudflare-dns.com 2606:4700:4700::1112#security.cloudflare-dns.com 2606:4700:4700::1002#security.cloudflare-dns.com
FallbackDNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
Domains=~.
DNSOverTLS=opportunistic
LLMNR=no
EOF
  sudo systemctl restart systemd-resolved
fi

# ===========================================================================
# Third-party repo updates  (system, needs sudo)
# ===========================================================================

# dnf5-automatic (privacy.sh) only applies "security" advisories, and only
# Fedora's repos publish advisories — Chrome, Docker (when USE_DOCKER=1 has
# installed it), Tailscale, VSCodium and the Ghostty COPR would otherwise
# never update until UPGRADE=1. This timer upgrades only packages from those
# repos (dependencies may still come from Fedora), nightly in the same window
# as Flatpak updates. Re-run this module after adding a repo so it is picked up.
log "Scheduling nightly updates for third-party repos"
mapfile -t third_party < <(
  dnf repolist --enabled --quiet 2>/dev/null | awk 'NR > 1 { print $1 }' |
    grep -vxE 'fedora|updates|fedora-cisco-openh264|updates-testing|fedora-modular|updates-modular' || true
)
if [ "${#third_party[@]}" -eq 0 ]; then
  echo "  no third-party repos enabled — skipping"
else
  repos="$(IFS=,; echo "${third_party[*]}")"
  echo "  repos: $repos"
  changed=0
  sync_root_file /etc/systemd/system/dotfiles-thirdparty-update.service <<EOF && changed=1
[Unit]
Description=Upgrade packages from third-party repos (managed by dotfiles security.sh)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/dnf upgrade -y --refresh --from-repo=$repos
EOF
  sync_root_file /etc/systemd/system/dotfiles-thirdparty-update.timer <<'EOF' && changed=1
[Unit]
Description=Nightly third-party repo update window (managed by dotfiles security.sh)

[Timer]
OnCalendar=*-*-* 04:00
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF
  [ "$changed" -eq 1 ] && sudo systemctl daemon-reload
  enable_unit dotfiles-thirdparty-update.timer
fi

# ===========================================================================
# Tailscale: no inbound tailnet connections  (needs sudo)
# ===========================================================================

if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
  if tailscale debug prefs 2>/dev/null | grep -q '"ShieldsUp": true'; then
    log "Tailscale shields already up"
  else
    log "Raising Tailscale shields (block inbound tailnet connections)"
    sudo tailscale set --shields-up=true
  fi
fi

# ===========================================================================
# Git commit signing  (per-user, no sudo)
# ===========================================================================

# Written outside the stowed git package (which is shared across machines) and
# pulled in by the [include] in git/.gitconfig; git ignores a missing include,
# so nothing changes until an ed25519 key exists. Hardware-backed (-sk) keys
# win when both are present.
signing_key=""
for k in "$HOME/.ssh/id_ed25519_sk.pub" "$HOME/.ssh/id_ed25519.pub"; do
  [ -f "$k" ] && signing_key="$k" && break
done
if [ -n "$signing_key" ]; then
  log "Configuring SSH commit signing ($signing_key)"
  email="$(git config --global user.email)"
  mkdir -p "$HOME/.config/git"
  signers="$email $(cut -d' ' -f1,2 "$signing_key")"
  if [ "$(cat "$HOME/.config/git/allowed_signers" 2>/dev/null)" != "$signers" ]; then
    printf '%s\n' "$signers" >"$HOME/.config/git/allowed_signers"
    echo "  wrote ~/.config/git/allowed_signers"
  fi
  signing_conf="$(cat <<EOF
# Generated by dotfiles security.sh — do not edit; re-run to refresh.
[gpg]
  format = ssh
[gpg "ssh"]
  allowedSignersFile = ~/.config/git/allowed_signers
[user]
  signingkey = ${signing_key/#$HOME/\~}
[commit]
  gpgsign = true
[tag]
  gpgsign = true
EOF
)"
  if [ "$(cat "$HOME/.config/git/signing" 2>/dev/null)" != "$signing_conf" ]; then
    printf '%s\n' "$signing_conf" >"$HOME/.config/git/signing"
    echo "  wrote ~/.config/git/signing"
    echo "  add it to GitHub as a signing key: gh ssh-key add --type signing $signing_key"
  fi
else
  log "No ~/.ssh/id_ed25519{,_sk}.pub yet — skipping commit signing (re-run after ssh-keygen)"
fi

log "Security hardening complete"
