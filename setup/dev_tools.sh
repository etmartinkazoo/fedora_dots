#!/usr/bin/env bash
# dev_tools.sh — mise, rootless Podman, and third-party tools.
# Idempotent. Runnable standalone or via bootstrap.sh.
#
# Docker Engine is opt-in (rootful daemon; the docker group is root-equivalent):
#   USE_DOCKER=1 ./setup/dev_tools.sh
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# vocalinux is opt-in (niche offline dictation) — run it standalone with
# ./setup/dev/vocalinux.sh; it is intentionally not part of a full provision.
run_module "dev/mise.sh"
run_module "dev/podman.sh"
if [ "${USE_DOCKER:-0}" = "1" ]; then
  run_module "dev/docker.sh"
else
  log "Docker Engine skipped (set USE_DOCKER=1 to install the rootful daemon)"
fi
run_module "dev/tools.sh"

log "Dev tools module complete"
