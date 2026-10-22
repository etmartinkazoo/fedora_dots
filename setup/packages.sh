#!/usr/bin/env bash
# packages.sh — dnf, Flatpaks (Slack), VSCodium, Google Chrome.
# Idempotent. Runnable standalone or via bootstrap.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

for mod in dnf flatpaks vscodium chrome; do
  run_module "packages/${mod}.sh"
done

log "Packages module complete"
