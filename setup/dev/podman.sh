#!/usr/bin/env bash
# Rootless Podman from the Fedora repos. This is the default container runtime.
#
# Docker Engine is a separate, opt-in path (setup/dev/docker.sh, USE_DOCKER=1).
# The docker group is root-equivalent: any process in it can ask the rootful
# daemon to mount the host and run as root. Rootless Podman keeps container
# UIDs inside this user's subordinate range.
#
# Does not install podman-docker, does not enable a Docker-compatible socket,
# and does not change SELinux mode.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

if [ "$(id -u)" -eq 0 ]; then
  error "Run as your normal user so Podman is configured rootless, not as root."
fi

dnf_install podman

# Rootless Podman needs a subordinate UID and GID range for the user namespace.
# `keep-id` (used by profiles.sh) maps this user through as themselves and still
# needs the range for every other ID in the container. Fedora's useradd normally
# allocates one; this covers accounts created without it. Ranges already listed
# in the file are skipped so a re-run does not overlap them.
ensure_subids() {
  local user="$1" file flag range max end start count
  ensure_one() {
    file="$1"
    flag="$2"
    if [ -f "$file" ] && grep -q "^${user}:" "$file"; then
      echo "  ${user} already in ${file}"
      return 0
    fi
    # /etc/subuid and /etc/subgid are "name:start:count". usermod wants
    # FIRST-LAST. Start the next block after the highest ID already listed
    # so a re-run cannot overlap an existing range.
    range="100000-165535"
    max=99999
    if [ -f "$file" ]; then
      while IFS=: read -r _ start count _; do
        if [[ "${start:-}" =~ ^[0-9]+$ ]] && [[ "${count:-}" =~ ^[0-9]+$ ]]; then
          end=$((start + count - 1))
        else
          continue
        fi
        if [ "$end" -gt "$max" ]; then
          max="$end"
        fi
      done <"$file"
      if [ "$max" -ge 100000 ]; then
        range="$((max + 1))-$((max + 65536))"
      fi
    fi
    log "Granting ${user} subordinate IDs ${range} in ${file}"
    sudo usermod "$flag" "$range" "$user"
  }
  ensure_one /etc/subuid --add-subuids
  ensure_one /etc/subgid --add-subgids
}

ensure_subids "$(id -un)"

rootless="$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || true)"
if [ "$rootless" != true ]; then
  log "Initializing rootless Podman storage"
  podman system migrate
  rootless="$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || true)"
fi
if [ "$rootless" != true ]; then
  error "Podman is installed but is not rootless for $(id -un). Check /etc/subuid and /etc/subgid, then re-run."
fi
echo "  rootless Podman is available"

if rpm_installed docker-ce || rpm_installed docker-ce-cli; then
  warn "Docker Engine is installed alongside rootless Podman. Membership in the docker group is root-equivalent. This module leaves that install in place."
fi
if rpm_installed podman-docker; then
  warn "podman-docker is installed (docker CLI shim). Rootless Podman does not need it; this module leaves it in place."
fi
