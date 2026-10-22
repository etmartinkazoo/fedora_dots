#!/usr/bin/env bash
# Third-party CLI/GUI tools: opencode, herdr, claude, tailscale, starship.
#
# Each comes from its upstream `curl | sh` installer. Skip any of them with
# SKIP_TOOLS (space-separated), e.g. for a quiet machine without Tailscale:
#   SKIP_TOOLS="tailscale" ./setup/dev_tools.sh
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

# True (and logs it) when the tool is listed in SKIP_TOOLS.
skipped() {
  case " ${SKIP_TOOLS:-} " in
    *" $1 "*) log "$1 skipped (SKIP_TOOLS)"; return 0 ;;
  esac
  return 1
}

mkdir -p "$HOME/.local/bin" "$HOME/.opencode/bin"

# opencode installer drops binary in ~/.opencode/bin (not always on PATH).
if skipped opencode; then
  :
elif command -v opencode >/dev/null 2>&1 || [ -x "$HOME/.opencode/bin/opencode" ]; then
  ver="$("$HOME/.opencode/bin/opencode" --version 2>/dev/null || opencode --version 2>/dev/null || true)"
  log "opencode already installed (${ver:-unknown}) — skipping"
else
  log "Installing opencode"
  curl -fsSL https://opencode.ai/install | bash
fi

# herdr installer drops binary in ~/.local/bin (not always on PATH during setup).
if skipped herdr; then
  :
elif command -v herdr >/dev/null 2>&1 || [ -x "$HOME/.local/bin/herdr" ]; then
  ver="$("$HOME/.local/bin/herdr" --version 2>/dev/null || herdr --version 2>/dev/null || true)"
  log "herdr already installed (${ver:-unknown}) — skipping"
else
  log "Installing herdr"
  curl -fsSL https://herdr.dev/install.sh | sh
fi

# Claude Code native installer: launcher in ~/.local/bin (on PATH via
# bash/.config/bashrc.d/path.bash); refuses sudo, self-updates in place.
if skipped claude; then
  :
elif command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
  ver="$("$HOME/.local/bin/claude" --version 2>/dev/null || claude --version 2>/dev/null || true)"
  log "Claude Code already installed (${ver:-unknown}) — skipping"
else
  log "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

if skipped tailscale; then
  :
elif command -v tailscale >/dev/null 2>&1; then
  log "Tailscale already installed ($(tailscale version 2>/dev/null | head -1)) — skipping"
else
  log "Installing Tailscale"
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# starship: installer -y skips the prompt; -b keeps it in ~/.local/bin (on PATH
# via bash/.config/bashrc.d/path.bash) instead of needing sudo for /usr/local.
if skipped starship; then
  :
elif command -v starship >/dev/null 2>&1 || [ -x "$HOME/.local/bin/starship" ]; then
  ver="$("$HOME/.local/bin/starship" --version 2>/dev/null || starship --version 2>/dev/null || true)"
  log "starship already installed (${ver:-unknown}) — skipping"
else
  log "Installing starship"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
fi
