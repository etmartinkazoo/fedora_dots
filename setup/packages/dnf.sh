#!/usr/bin/env bash
# System update + dnf packages (Fedora repos + the Ghostty COPR).
# Full system upgrade only when UPGRADE=1 or --upgrade is passed.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

do_upgrade=0
if [ "${UPGRADE:-0}" = "1" ]; then
  do_upgrade=1
fi
for arg in "$@"; do
  case "$arg" in
    --upgrade) do_upgrade=1 ;;
  esac
done

# Ghostty is not in the Fedora repos; upstream's documented Fedora source is
# the scottames/ghostty COPR (https://ghostty.org/docs/install/binary).
# `dnf copr` comes from dnf5-plugins (installed on Workstation by default).
GHOSTTY_COPR="scottames/ghostty"
GHOSTTY_REPO="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${GHOSTTY_COPR/\//:}.repo"
if [ -f "$GHOSTTY_REPO" ]; then
  echo "  $GHOSTTY_COPR COPR already enabled"
else
  dnf_install dnf5-plugins
  log "Enabling the $GHOSTTY_COPR COPR (Ghostty)"
  sudo dnf copr enable -y "$GHOSTTY_COPR"
fi

PACKAGES=(
  autoconf
  bubblewrap # Claude Code bash sandbox (claude-*-yolo)
  cargo
  curl
  dnf5-plugin-automatic
  fastfetch
  fd-find
  fzf
  gcc
  gcc-c++
  gh
  ghostty
  gitleaks # global pre-commit secret scan (git/.gitconfig)
  gmp-devel
  libffi-devel
  libXScrnSaver
  libyaml-devel
  make
  neovim
  openssl-devel
  pkgconf-pkg-config
  ripgrep
  rustc
  socat # Claude Code bash sandbox network proxy
  stow
  tree-sitter-cli
  unzip
  wget
  wl-clipboard
  zlib-ng-compat-devel
)

if [ "$do_upgrade" -eq 1 ]; then
  log "Upgrading system packages (UPGRADE=1 / --upgrade)"
  sudo dnf upgrade -y --refresh
else
  echo "  skipping full upgrade (set UPGRADE=1 or pass --upgrade to enable)"
fi

# dnf refreshes stale metadata on its own, so there's no separate update step.
dnf_install "${PACKAGES[@]}"
log "All ${#PACKAGES[@]} dnf packages installed"
