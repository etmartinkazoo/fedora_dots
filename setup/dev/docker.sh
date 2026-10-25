#!/usr/bin/env bash
# Docker Engine (official Fedora rpm repo) + post-install.
# https://docs.docker.com/engine/install/fedora/
# https://docs.docker.com/engine/install/linux-postinstall/
#
# Opt-in. Rootless Podman (setup/dev/podman.sh) is the default runtime.
# Docker Engine runs a rootful daemon, and every member of the docker group
# can talk to it — that is root-equivalent on the host (mount the filesystem,
# start privileged containers). Install it only when a tool still needs the
# Docker API:
#   USE_DOCKER=1 ./setup/dev/docker.sh
#
# This does not remove Podman. It does remove podman-docker when present,
# because that shim and docker-ce both ship a docker CLI.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

if [ "${USE_DOCKER:-0}" != "1" ]; then
  log "Docker Engine skipped"
  echo "  Rootless Podman is the default (setup/dev/podman.sh)."
  echo "  Set USE_DOCKER=1 to install the rootful Docker Engine and join the docker group."
  exit 0
fi

log "Docker Engine opted in (USE_DOCKER=1). The docker group is root-equivalent."

DOCKER_REPO_URL="https://download.docker.com/linux/fedora/docker-ce.repo"

if rpm_installed docker-ce; then
  log "Docker Engine already installed ($(docker --version 2>/dev/null || echo docker-ce)) — skipping install"
else
  log "Removing conflicting Docker packages (if any)"
  # Official docs: uninstall distro/unofficial packages before installing CE.
  conflict_pkgs=()
  for pkg in docker docker-client docker-client-latest docker-common docker-latest \
    docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux \
    docker-engine moby-engine podman-docker; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      conflict_pkgs+=("$pkg")
    fi
  done
  if [ "${#conflict_pkgs[@]}" -gt 0 ]; then
    sudo dnf remove -y "${conflict_pkgs[@]}"
  else
    echo "  no conflicting packages found"
  fi

  log "Installing Docker Engine from Docker rpm repository"
  dnf_install dnf5-plugins
  if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
    sudo dnf config-manager addrepo --from-repofile="$DOCKER_REPO_URL"
  fi

  # dnf imports Docker's signing key on first install (-y accepts it).
  sudo dnf install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
fi

if ! getent group docker >/dev/null 2>&1; then
  log "Creating the docker group"
  sudo groupadd docker
fi

target_user="${SUDO_USER:-$USER}"
if [ -n "$target_user" ] && [ "$target_user" != "root" ]; then
  if ! id -nG "$target_user" | grep -qw docker; then
    log "Adding $target_user to the docker group"
    sudo usermod -aG docker "$target_user"
    echo "  log out and back in (or run 'newgrp docker') for group membership to take effect"
  else
    echo "  $target_user already in docker group"
  fi
fi

# Unlike Debian/Ubuntu, Fedora's docker-ce package doesn't start the daemon.
log "Ensuring docker and containerd are enabled and running"
enable_unit docker.service
enable_unit containerd.service

if systemctl is-active --quiet docker.service; then
  echo "  docker.service is active"
else
  error "docker.service failed to start"
fi
