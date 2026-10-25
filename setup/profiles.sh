#!/usr/bin/env bash
#
# profiles.sh — directory walls and rootless Podman shells for four contexts.
#
# Contexts: personal, consultancy, brem, lumin. Each gets a directory under
# ~/Profiles that is the only host path mounted into its container at /work,
# plus host launchers in ~/bin. Browser identity stays in Chrome
# (setup/chrome.sh): this module does not create Firefox profiles, Chrome
# profiles, or extra browser launchers.
#
# Containers are created with --userns=keep-id and a private SELinux volume
# label (:Z). They are not privileged, they do not disable SELinux, and they
# do not mount the Docker socket or the rest of $HOME. Existing containers are
# left in place; a re-run warns when one is privileged, turns container
# labeling off, or mounts anything other than its profile directory.
#
# Idempotent. Runnable standalone or via bootstrap.sh. sudo is needed only
# when podman or neomutt is missing (podman setup delegates to dev/podman.sh).
#
# Opt-in:
#   INSTALL_PROFILE_FLATPAKS=1   Zoom, Obsidian, and Signal as user Flatpaks,
#                                then drop home/host filesystem access
#   INSTALL_HYLKI=1              Hylki GUI mail from Hyprlab's Flatpak repo
#   FEDORA_PROFILE_IMAGE         override the container image
#                                (default: registry.fedoraproject.org/fedora:<this Fedora>)
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

PROFILES=(personal consultancy brem lumin)
BASE="${HOME}/Profiles"
BIN="${HOME}/bin"

fedora_version=44
if [ -r /etc/os-release ]; then
  os_version="$(. /etc/os-release && printf '%s' "${VERSION_ID:-}")"
  if [[ "$os_version" =~ ^[0-9]+$ ]]; then
    fedora_version="$os_version"
  fi
fi
IMAGE="${FEDORA_PROFILE_IMAGE:-registry.fedoraproject.org/fedora:${fedora_version}}"

if [ "$(id -u)" -eq 0 ]; then
  error "Run profiles.sh as your normal user so the containers are rootless."
fi

# Write stdin to a user-owned file only when the content differs. Mode is
# corrected even when the bytes are unchanged. Returns 0 in both cases so a
# re-run is a clean no-op under set -e.
sync_user_file() {
  local dest="$1" mode="${2:-0644}" tmp cur want
  tmp="$(mktemp)"
  cat >"$tmp"
  want="$(printf '%o' "$mode")"
  if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
    cur="$(stat -c '%a' "$dest")"
    if [ "$cur" != "$want" ]; then
      chmod "$mode" "$dest"
      echo "  updated mode on ${dest}"
    fi
    return 0
  fi
  install -D "${INSTALL_Z[@]}" -m "$mode" "$tmp" "$dest"
  rm -f "$tmp"
  echo "  wrote ${dest}"
}

ensure_podman() {
  local user
  user="$(id -un)"
  if ! command -v podman >/dev/null 2>&1 ||
    ! grep -q "^${user}:" /etc/subuid 2>/dev/null ||
    ! grep -q "^${user}:" /etc/subgid 2>/dev/null; then
    bash "${SETUP_DIR}/dev/podman.sh"
  fi
  command -v podman >/dev/null 2>&1 || error "podman is not on PATH after setup/dev/podman.sh"
  rootless="$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || true)"
  [ "$rootless" = true ] || error "Podman is not rootless for $(id -un). Run ./setup/dev/podman.sh and check /etc/subuid."
}

make_profile_dirs() {
  local p
  mkdir -p "$BIN" "$BASE"
  chmod 700 "$BASE"
  for p in "${PROFILES[@]}"; do
    mkdir -p \
      "${BASE}/${p}/Documents" \
      "${BASE}/${p}/Downloads" \
      "${BASE}/${p}/Projects" \
      "${BASE}/${p}/Mail" \
      "${BASE}/${p}/.ssh" \
      "${BASE}/${p}/.config/neomutt" \
      "${BASE}/${p}/.cache/neomutt"
    chmod 700 "${BASE}/${p}" "${BASE}/${p}/.ssh" "${BASE}/${p}/Mail"
  done
}

write_launchers() {
  local p
  for p in "${PROFILES[@]}"; do
    sync_user_file "${BIN}/shell-${p}" 0755 <<EOF
#!/usr/bin/env bash
# Managed by setup/profiles.sh. Re-run that module to refresh.
set -euo pipefail
name="${p}"
if ! podman container exists "\${name}"; then
  printf 'Container %s is missing. Run ./setup/profiles.sh from the dotfiles repo.\\n' "\${name}" >&2
  exit 1
fi
if [ "\$(podman inspect --format '{{.State.Running}}' "\${name}")" != true ]; then
  podman start "\${name}" >/dev/null
fi
args=(-i -e "TERM=\${TERM:-xterm-256color}" -e HOME=/work -w /work)
if [ -t 0 ] && [ -t 1 ]; then
  args+=(-t)
fi
exec podman exec "\${args[@]}" "\${name}" bash
EOF

    sync_user_file "${BIN}/tmux-${p}" 0755 <<EOF
#!/usr/bin/env bash
# Managed by setup/profiles.sh. Re-run that module to refresh.
set -euo pipefail
name="${p}"
session="\${name}"
if ! podman container exists "\${name}"; then
  printf 'Container %s is missing. Run ./setup/profiles.sh from the dotfiles repo.\\n' "\${name}" >&2
  exit 1
fi
if [ "\$(podman inspect --format '{{.State.Running}}' "\${name}")" != true ]; then
  podman start "\${name}" >/dev/null
fi
args=(-i -e "TERM=\${TERM:-xterm-256color}" -e HOME=/work -w /work)
if [ -t 0 ] && [ -t 1 ]; then
  args+=(-t)
fi
if podman exec "\${name}" tmux has-session -t "\${session}" 2>/dev/null; then
  exec podman exec "\${args[@]}" "\${name}" tmux attach-session -t "\${session}"
fi
exec podman exec "\${args[@]}" "\${name}" tmux new-session -s "\${session}"
EOF

    # Host neomutt, reading only this profile's config. The rc is created once
    # (below) and is not refreshed, so account settings survive a re-run.
    sync_user_file "${BIN}/mutt-${p}" 0755 <<EOF
#!/usr/bin/env bash
# Managed by setup/profiles.sh. Re-run that module to refresh the launcher.
# Account settings live in the profile neomuttrc; this script does not embed them.
exec neomutt -F "\${HOME}/Profiles/${p}/.config/neomutt/neomuttrc" "\$@"
EOF
  done
}

write_mutt_stubs() {
  local p rc
  for p in "${PROFILES[@]}"; do
    rc="${BASE}/${p}/.config/neomutt/neomuttrc"
    if [ -f "$rc" ]; then
      echo "  neomutt config already present (${rc})"
      continue
    fi
    sync_user_file "$rc" 0600 <<EOF
# Neomutt stub for the ${p} profile.
# This file lives under ~/Profiles, outside the dotfiles repo. Put account
# details here on the machine. Keep passwords in a per-profile secret store:
#   set imap_pass = \`pass show ${p}/email\`
# Example Fastmail (replace the address):
#   set imap_user = "you@example.com"
#   set folder = "imaps://imap.fastmail.com/"
#   set smtp_url = "smtps://you@example.com@smtp.fastmail.com:465/"
set realname = "CHANGE_ME"
set from = "CHANGE_ME@example.com"
set spoolfile = "+INBOX"
set record = "+Sent"
set postponed = "+Drafts"
set header_cache = "${BASE}/${p}/.cache/neomutt/headers"
set message_cachedir = "${BASE}/${p}/.cache/neomutt/bodies"
EOF
  done
}

write_flatpak_helpers() {
  sync_user_file "${BIN}/flatpak-lock-to-profile" 0755 <<'EOF'
#!/usr/bin/env bash
# Grant one Flatpak a single profile directory and drop home/host filesystem access.
# Usage: flatpak-lock-to-profile <app-id> <personal|consultancy|brem|lumin>
set -euo pipefail
app="${1:?usage: flatpak-lock-to-profile <app-id> <personal|consultancy|brem|lumin>}"
profile="${2:?usage: flatpak-lock-to-profile <app-id> <personal|consultancy|brem|lumin>}"
case "$profile" in
  personal|consultancy|brem|lumin) ;;
  *)
    printf 'unknown profile: %s\n' "$profile" >&2
    exit 1
    ;;
esac
base="${HOME}/Profiles/${profile}"
[ -d "$base" ] || {
  printf 'missing %s — run ./setup/profiles.sh\n' "$base" >&2
  exit 1
}
command -v flatpak >/dev/null 2>&1 || {
  printf 'flatpak is not installed\n' >&2
  exit 1
}
args=(--user --nofilesystem=home --nofilesystem=host)
for other in personal consultancy brem lumin; do
  if [ "$other" != "$profile" ]; then
    args+=(--nofilesystem="${HOME}/Profiles/${other}")
  fi
done
args+=(--filesystem="$base" "$app")
flatpak override "${args[@]}"
printf 'Locked %s to %s (home and host filesystem access removed).\n' "$app" "$base"
printf 'Flatpak keeps its private data under ~/.var/app/%s.\n' "$app"
EOF

  sync_user_file "${BIN}/install-profile-flatpaks" 0755 <<'EOF'
#!/usr/bin/env bash
# Opt-in user Flatpaks for collaboration apps. Does not grant $HOME.
# After install, each app loses home and host filesystem access. Grant one
# profile directory with: flatpak-lock-to-profile <app-id> <profile>
set -euo pipefail
apps=(
  us.zoom.Zoom
  md.obsidian.Obsidian
  org.signal.Signal
)
command -v flatpak >/dev/null 2>&1 || {
  printf 'flatpak is not installed\n' >&2
  exit 1
}
if ! flatpak remotes --user --columns=name 2>/dev/null | grep -qx flathub; then
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi
for app in "${apps[@]}"; do
  if flatpak info --user "$app" >/dev/null 2>&1 || flatpak info --system "$app" >/dev/null 2>&1; then
    printf '  %s already installed\n' "$app"
  elif ! flatpak install -y --user --noninteractive flathub "$app"; then
    printf '  skip %s\n' "$app" >&2
    continue
  fi
  flatpak override --user --nofilesystem=home --nofilesystem=host "$app"
  printf '  %s has no home/host filesystem grant. Run: flatpak-lock-to-profile %s <profile>\n' "$app" "$app"
done
printf 'Slack (com.slack.Slack) is installed separately by packages/flatpaks.sh.\n'
printf 'Lock it the same way when you want it confined to one profile.\n'
EOF
}

write_profile_readme() {
  sync_user_file "${BASE}/README.md" 0644 <<'EOF'
# Profile directory walls

Managed by `setup/profiles.sh`. This file is rewritten on each run. Keep
account notes in the profile they belong to, not here.

## Contexts

personal, consultancy, brem, lumin

Each directory is one context. Shell work for that context runs in a rootless
Podman container of the same name. The container mounts only this directory,
at `/work`, with `--userns=keep-id` and a private SELinux label (`:Z`).

## Commands (on the host)

- `shell-<profile>` — bash in that container (`HOME=/work`)
- `tmux-<profile>` — tmux session in that container
- `mutt-<profile>` — host neomutt using this profile's neomuttrc
- `flatpak-lock-to-profile <app-id> <profile>` — one Flatpak, one directory

## Rules

1. Keep files for a context under that profile directory.
2. Do not grant a Flatpak all of `$HOME`.
3. Do not mount a second profile, `$HOME`, or the Docker socket into a container.
4. Keep a separate SSH key and password store per profile. The host Git
   signing key stays in `~/.ssh` (see `setup/security.sh`).
5. Chrome's four profiles isolate the browser. They do not isolate these
   directories. Point each Chrome profile's download directory at
   `~/Profiles/<profile>/Downloads`.
6. Leave SELinux enforcing. Do not recreate these containers with
   `--privileged` or `--security-opt label=disable`.
EOF
}

verify_container() {
  local p="$1" src="" dest="" found=0 mounts sec priv userns img mode
  mode="$(getenforce 2>/dev/null || true)"
  if ! mounts="$(podman inspect --format '{{range .Mounts}}{{.Source}}|{{.Destination}}{{"\n"}}{{end}}' "$p" 2>/dev/null)"; then
    warn "could not inspect container ${p}"
    return 0
  fi
  while IFS='|' read -r src dest; do
    [ -n "$dest" ] || continue
    if [ "$dest" != "/work" ]; then
      warn "container ${p} mounts ${src} at ${dest}. Only ${BASE}/${p} -> /work belongs there."
    elif [ "$src" != "${BASE}/${p}" ]; then
      warn "container ${p} mounts ${src} at /work; expected ${BASE}/${p}."
    else
      found=1
    fi
  done <<<"$mounts"
  if [ "$found" -ne 1 ]; then
    warn "container ${p} is missing the ${BASE}/${p} -> /work mount."
  fi
  userns="$(podman inspect --format '{{.HostConfig.UsernsMode}}' "$p" 2>/dev/null || true)"
  case "$userns" in
    *keep-id*) ;;
    *) warn "container ${p} user namespace is '${userns:-default}', not keep-id. Leave it; recreate it manually to pick up --userns=keep-id." ;;
  esac
  priv="$(podman inspect --format '{{.HostConfig.Privileged}}' "$p" 2>/dev/null || true)"
  if [ "$priv" = true ]; then
    warn "container ${p} is privileged. Recreate it without --privileged."
  fi
  if [ "$mode" = Enforcing ]; then
    sec="$(podman inspect --format '{{json .HostConfig.SecurityOpt}}' "$p" 2>/dev/null || true)"
    # `label=disable` also matches Podman's `label=disabled` spelling.
    case "$sec" in
      *label=disable*)
        warn "container ${p} disables SELinux separation. Recreate it without --security-opt label=disable."
        ;;
    esac
  fi
  img="$(podman inspect --format '{{.Config.Image}}' "$p" 2>/dev/null || true)"
  if [ -n "$img" ] && [ "$img" != "$IMAGE" ]; then
    warn "container ${p} was created from ${img}; this module uses ${IMAGE}. Leaving the existing container."
  fi
}

bootstrap_container() {
  local name="$1"
  log "Installing shell tools in container ${name}"
  # Runs as container root (still this user's subordinate UID on the host) so
  # dnf can write the image. The profile directory itself stays user-owned
  # because the long-running process uses --userns=keep-id.
  # Last command: a non-zero podman exec must be this function's status
  # (callers invoke it from `if`, where set -e would not abort the script).
  podman exec --user 0 -i "$name" bash -s <<'EOF' || return $?
set -euo pipefail
dnf install -y \
  git \
  curl \
  neovim \
  tmux \
  ripgrep \
  fd-find \
  fzf \
  jq \
  findutils \
  diffutils \
  less \
  openssh-clients
touch /.dotfiles-profile-ready
EOF
}

create_container() {
  local p="$1"
  if ! podman image exists "$IMAGE"; then
    log "Pulling ${IMAGE}"
    podman pull "$IMAGE"
  else
    echo "  image ${IMAGE} already present"
  fi
  log "Creating rootless container ${p}"
  podman create \
    --name "$p" \
    --hostname "$p" \
    --label "fedora-dots.profile=${p}" \
    --userns=keep-id \
    --security-opt no-new-privileges \
    -e HOME=/work \
    -e TERM=xterm-256color \
    -v "${BASE}/${p}:/work:Z" \
    -w /work \
    "$IMAGE" \
    sleep infinity >/dev/null
}

provision_container() {
  local p="$1" running started_here=0
  if podman container exists "$p"; then
    echo "  container ${p} already exists"
  else
    create_container "$p"
  fi
  verify_container "$p"
  running="$(podman inspect --format '{{.State.Running}}' "$p")"
  if [ "$running" != true ]; then
    podman start "$p" >/dev/null
    started_here=1
  fi
  if podman exec "$p" test -f /.dotfiles-profile-ready; then
    echo "  container ${p} already has shell tools"
  else
    if ! bootstrap_container "$p"; then
      if [ "$started_here" -eq 1 ]; then
        podman stop "$p" >/dev/null || true
      fi
      error "Installing shell tools in container ${p} failed"
    fi
  fi
  if [ "$started_here" -eq 1 ]; then
    podman stop "$p" >/dev/null
  fi
}

install_hylki() {
  local repo="https://hylki.hyprlab.co/flatpak/co.hyprlab.Hylki.flatpakrepo"
  local app="co.hyprlab.Hylki"
  command -v flatpak >/dev/null 2>&1 || dnf_install flatpak
  if ! flatpak remotes --user --columns=name 2>/dev/null | grep -qx hylki; then
    log "Adding the Hylki Flatpak remote (user)"
    flatpak remote-add --user --if-not-exists hylki "$repo"
  else
    echo "  Hylki remote already configured"
  fi
  if flatpak info --user "$app" >/dev/null 2>&1; then
    echo "  ${app} already installed"
  else
    log "Installing ${app}"
    flatpak install --user -y --noninteractive hylki "$app"
    # Fresh install only. A later run must not strip a profile directory the
    # user already granted with flatpak-lock-to-profile.
    flatpak override --user --nofilesystem=home --nofilesystem=host "$app"
    echo "  Hylki has no home/host filesystem grant. Lock it with: flatpak-lock-to-profile ${app} <profile>"
  fi
}

ensure_podman
dnf_install neomutt
make_profile_dirs
write_launchers
write_mutt_stubs
write_flatpak_helpers
write_profile_readme

log "Provisioning rootless profile containers (${IMAGE})"
for profile in "${PROFILES[@]}"; do
  provision_container "$profile"
done

if [ "${INSTALL_PROFILE_FLATPAKS:-0}" = "1" ]; then
  dnf_install flatpak
  "${BIN}/install-profile-flatpaks"
fi
if [ "${INSTALL_HYLKI:-0}" = "1" ]; then
  install_hylki
fi

if command -v getenforce >/dev/null 2>&1; then
  selinux_mode="$(getenforce 2>/dev/null || true)"
  if [ "$selinux_mode" = Enforcing ]; then
    echo "  SELinux is enforcing"
  else
    warn "SELinux is ${selinux_mode:-unknown}. This module does not change it. Enforcing is the intended mode."
  fi
fi

log "Profile launchers are in ~/bin (on PATH via bash/.config/bashrc.d/path.bash)"
echo "  shell-<profile>, tmux-<profile>, mutt-<profile>, flatpak-lock-to-profile"
echo "  Each container mounts only ~/Profiles/<profile> at /work. Chrome profiles are unchanged."
