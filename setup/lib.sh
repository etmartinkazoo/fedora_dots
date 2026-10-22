#!/usr/bin/env bash
# Shared helpers for setup modules. Source from any script under setup/:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
#   # or for nested modules (setup/gnome/foo.sh):
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
#
# Safe to source multiple times.

if [ -n "${DOTFILES_LIB_LOADED:-}" ]; then
  return 0 2>/dev/null || true
fi
DOTFILES_LIB_LOADED=1

# Resolve paths from the library's own location (setup/).
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SETUP_DIR/.." && pwd)"

log()   { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\n\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
error() { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# Cached gsettings schema names (normal + relocatable). The list is expensive to
# compute, so it's exported to the environment: since run_module spawns each
# module as a child `bash`, exporting lets the whole module tree reuse one
# computation instead of re-running `gsettings list-schemas` in every process.
_DOTFILES_SCHEMAS=""
_load_schemas() {
  [ -n "$_DOTFILES_SCHEMAS" ] && return 0
  if [ -n "${DOTFILES_SCHEMAS_CACHE:-}" ]; then
    _DOTFILES_SCHEMAS="$DOTFILES_SCHEMAS_CACHE"
    return 0
  fi
  _DOTFILES_SCHEMAS="$(
    { gsettings list-schemas 2>/dev/null; gsettings list-relocatable-schemas 2>/dev/null; } | sort -u
  )"
  export DOTFILES_SCHEMAS_CACHE="$_DOTFILES_SCHEMAS"
}

# True if a GSettings schema is installed (non-relocatable or relocatable).
has_schema() {
  _load_schemas
  printf '%s\n' "$_DOTFILES_SCHEMAS" | grep -qx "$1"
}

# Drop the cached schema list (in this process and for its children). Call after
# installing a package that ships schemas, e.g. a GNOME Shell extension RPM —
# the cache inherited from a parent runner predates the install.
refresh_schemas() {
  _DOTFILES_SCHEMAS=""
  unset DOTFILES_SCHEMAS_CACHE
  _load_schemas
}

# Set a gsettings key only if its schema is installed and the key doesn't
# already hold the value (clean no-op otherwise, so it never trips `set -e` in a
# caller). A genuine gsettings failure on an installed schema still propagates.
# SCHEMA may carry a relocatable path (schema:/path/).
#   gset SCHEMA KEY VALUE
gset() {
  has_schema "${1%%:*}" || return 0
  local cur
  cur="$(gsettings get "$1" "$2" 2>/dev/null || true)"
  # `gsettings get` quotes strings and types empty arrays; accept those forms.
  case "$cur" in
    "$3" | "'$3'") return 0 ;;
    "@as []") [ "$3" = "[]" ] && return 0 ;;
  esac
  gsettings set "$1" "$2" "$3"
}

# Fedora runs SELinux enforcing. `install` creates a fresh inode, so without -Z
# a file written into /etc inherits the generic etc_t label instead of its
# policy default (e.g. /etc/hosts must stay net_conf_t). Empty when disabled.
INSTALL_Z=()
command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled && INSTALL_Z=(-Z)

# True if an installed RPM provides NAME (a package name or a virtual
# provide such as `wget`, which wget2-wget satisfies).
rpm_installed() {
  rpm -q --whatprovides "$1" >/dev/null 2>&1
}

# dnf-install only the packages that aren't installed yet (no-op, and no sudo
# prompt, when everything is already present).
#   dnf_install PKG...
dnf_install() {
  local p missing=()
  for p in "$@"; do
    rpm_installed "$p" || missing+=("$p")
  done
  [ "${#missing[@]}" -eq 0 ] && return 0
  log "Installing missing packages: ${missing[*]}"
  sudo dnf install -y "${missing[@]}"
}

# Write stdin to a root-owned file (parent dirs created) only when its content
# differs. Returns 0 if the file was written, 1 if it was already up to date,
# so callers can react to a change — always call it from an `if` or with
# `|| true` so the "unchanged" status can't trip `set -e`:
#   if sync_root_file /etc/foo.conf <<<"x=1"; then sudo systemctl reload foo; fi
sync_root_file() {
  local dest="$1" mode="${2:-0644}" tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
    return 1
  fi
  sudo install -D "${INSTALL_Z[@]}" -m "$mode" "$tmp" "$dest"
  rm -f "$tmp"
  echo "  wrote $dest"
}

# Stop + mask a system unit when it exists and isn't masked yet.
mask_unit() {
  local u="$1"
  [ "$(systemctl is-enabled "$u" 2>/dev/null)" = masked ] && return 0
  if systemctl cat "$u" &>/dev/null; then
    log "Disabling $u"
    sudo systemctl stop "$u" 2>/dev/null || true
    sudo systemctl mask "$u" 2>/dev/null || true
  fi
}

# Stop + mask a per-user unit when it exists and isn't masked yet (no sudo).
mask_user_unit() {
  local u="$1"
  [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" = masked ] && return 0
  if systemctl --user cat "$u" &>/dev/null; then
    systemctl --user stop "$u" 2>/dev/null || true
    systemctl --user mask "$u" >/dev/null 2>&1 || true
  fi
}

# Enable + start a system unit, skipping whichever step is already true.
enable_unit() {
  local u="$1"
  systemctl is-enabled --quiet "$u" 2>/dev/null || sudo systemctl enable "$u"
  systemctl is-active --quiet "$u" 2>/dev/null || sudo systemctl start "$u"
}

# Run a module path relative to setup/ (e.g. packages/dnf.sh).
run_module() {
  local rel="$1"
  local path="$SETUP_DIR/$rel"
  [ -f "$path" ] || error "Module not found: $rel"
  # Warm + export the schema cache in this (parent) process so the spawned
  # module and its descendants inherit it instead of each recomputing.
  _load_schemas
  log "Running $rel"
  bash "$path"
}
