#!/usr/bin/env bash
# gnome.sh — run all GNOME desktop modules. Idempotent.
# Runnable standalone or via bootstrap.sh.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

for mod in dock power appearance keybindings terminal icons peripherals; do
  run_module "gnome/${mod}.sh"
done

log "GNOME tweaks complete"
