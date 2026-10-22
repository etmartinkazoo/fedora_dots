#!/usr/bin/env bash
# dev_tools.sh — mise, docker, and third-party tools.
# Idempotent. Runnable standalone or via bootstrap.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# vocalinux is opt-in (niche offline dictation) — run it standalone with
# ./setup/dev/vocalinux.sh; it is intentionally not part of a full provision.
for mod in mise docker tools; do
  run_module "dev/${mod}.sh"
done

log "Dev tools module complete"
