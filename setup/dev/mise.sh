#!/usr/bin/env bash
# mise + language runtimes (node, ruby) from ~/.config/mise/config.toml.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

MISE_BIN="$HOME/.local/bin/mise"
if [ ! -x "$MISE_BIN" ]; then
  log "Installing mise"
  curl -fsSL https://mise.run | sh
else
  log "mise already installed ($("$MISE_BIN" --version 2>/dev/null || true))"
fi

# Activation lives in bash/.config/bashrc.d/path.bash (stowed); do not append to ~/.bashrc.
eval "$("$MISE_BIN" activate bash)"

if [ -n "$("$MISE_BIN" ls --missing 2>/dev/null)" ]; then
  log "Installing missing tools from mise config"
  "$MISE_BIN" install
else
  log "All mise tools already installed"
fi

if command -v npm >/dev/null 2>&1; then
  if npm list -g neovim >/dev/null 2>&1; then
    echo "  neovim npm package already installed"
  else
    log "Installing neovim npm package"
    npm install -g neovim
  fi
else
  echo "  npm not available — skipping neovim package"
fi
