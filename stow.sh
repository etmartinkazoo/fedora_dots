#!/usr/bin/env bash
#
# stow.sh — symlink dotfiles into $HOME with GNU Stow.
#
# Run from the repo root:
#     ./stow.sh
#
# Idempotent (uses --restow). The pre-create / conflict-removal / validation
# lists are DERIVED by walking the stow package trees — add a file to a package
# and it is handled automatically, with no list in this script to keep in sync.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
source "$SCRIPT_DIR/setup/lib.sh"

# Stow packages: top-level dirs whose contents mirror $HOME. Single source of
# truth — everything below is derived from these trees.
PACKAGES=(bash ghostty git gtk herdr mise npm nvim opencode vscodium)

# Install stow if it isn't present.
if ! command -v stow >/dev/null 2>&1; then
  log "Installing GNU Stow"
  sudo dnf install -y stow
fi

# --- Derive targets from the package trees ---------------------------------
# A package file <pkg>/<rel> maps to the $HOME target $HOME/<rel>. GTK bookmarks
# are generated (sed __HOME__ substitution) rather than symlinked, so they are
# tracked separately.
symlink_targets=()
generated_targets=()
for pkg in "${PACKAGES[@]}"; do
  while IFS= read -r f; do
    rel="${f#"$pkg"/}"
    target="$HOME/$rel"
    if [ "$pkg" = gtk ] && [ "$(basename "$rel")" = bookmarks ]; then
      generated_targets+=("$target")
    else
      symlink_targets+=("$target")
    fi
  done < <(find "$pkg" \( -type f -o -type l \))
done

# --- Pre-create parent dirs (shallowest first) -----------------------------
# Real parent dirs force stow to link individual files instead of shortcutting
# to a whole-directory link. Processing shallowest-first also converts any dir a
# previous run whole-directory-symlinked back into a real dir.
declare -A dirs=()
for t in "${symlink_targets[@]}" "${generated_targets[@]}"; do
  dirs["$(dirname "$t")"]=1
done
while IFS= read -r d; do
  [ "$d" = "$HOME" ] && continue
  [ -L "$d" ] && rm -f "$d"
  mkdir -p "$d"
done < <(printf '%s\n' "${!dirs[@]}" | awk -F/ '{print NF, $0}' | sort -n | cut -d' ' -f2-)

# --- Remove conflicting real files that would block stow -------------------
# Moved aside (not deleted) so a pre-existing config is never lost.
log "Moving aside conflicting files that would block stow"
for t in "${symlink_targets[@]}"; do
  if [ -e "$t" ] && [ ! -L "$t" ]; then
    echo "  $t -> $t.pre-stow"
    mv -f "$t" "$t.pre-stow"
  fi
done

log "Stowing dotfiles into $HOME"
# Ignore the generated GTK bookmarks (regular files we write via sed below —
# otherwise a bookmarks conflict aborts the whole multi-package stow).
# --target is mandatory: without it stow defaults to the PARENT of the stow
# directory (~/Downloads), so every link would land outside $HOME.
stow --target "$HOME" --ignore='bookmarks' \
  --restow --verbose "${PACKAGES[@]}" 2>&1 \
  || echo "  (stow conflicts are non-fatal — resolve manually)"

# The global gitignore used to be a hand-made ~/.gitignore link; it now lives at
# git's default ~/.config/git/ignore, so drop the old link if it is ours.
if [ -L "$HOME/.gitignore" ] && [ "$(readlink "$HOME/.gitignore")" = "$SCRIPT_DIR/git/.gitignore" ]; then
  rm -f "$HOME/.gitignore"
fi

# Generate GTK bookmarks with the real home directory. A temp file avoids
# truncating the stow source if the target ever resolves back to it.
log "Generating GTK bookmarks"
for t in "${generated_targets[@]}"; do
  src="$SCRIPT_DIR/gtk/${t#"$HOME"/}"
  tmp="$(mktemp)"
  sed "s|__HOME__|$HOME|g" "$src" > "$tmp"
  if [ -f "$t" ] && [ ! -L "$t" ] && cmp -s "$tmp" "$t"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$t"
  fi
done

# --- Validate --------------------------------------------------------------
log "Validating symlinks"
missing=0
for t in "${symlink_targets[@]}"; do
  if [ ! -L "$t" ]; then
    echo "  MISSING: ${t#"$HOME"/}"
    missing=$((missing + 1))
  fi
done
for t in "${generated_targets[@]}"; do
  if [ ! -f "$t" ] || [ -L "$t" ]; then
    echo "  MISSING: ${t#"$HOME"/} (expected generated file)"
    missing=$((missing + 1))
  fi
done

if [ "$missing" -eq 0 ]; then
  log "All symlinks valid"
else
  echo "  $missing symlink(s) missing — check stow conflicts above"
fi
