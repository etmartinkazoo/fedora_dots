# AGENTS.md

## Design philosophy

Ultra productivity on **Fedora 44 Workstation (GNOME)** — email, web, development.
Everything is tuned toward focus, privacy, and a quiet machine with zero
ambient distraction. If a privacy measure breaks a productivity service,
**find an alternative approach** rather than accepting the breakage.

## Repo structure

- **Stow packages** (`stow.sh`): `bash/`, `ghostty/`, `git/`, `gtk/`, `herdr/`, `mise/`, `npm/`, `nvim/`, `opencode/`, `vscodium/`  
  Pre-creates target dirs and moves real files that would block stow aside to `<file>.pre-stow`. Validates symlinks after.
- **Setup modules** (`setup/`): idempotent, standalone bash scripts sourcing `setup/lib.sh`.
  **Check before acting**: every step tests current state first and only installs/writes what is missing or different (so a re-run on a provisioned machine changes nothing and needs no sudo prompt where avoidable). Use the `lib.sh` helpers rather than raw commands: `gset` (skips if schema absent or value already set), `sync_root_file` (writes a root file only when content differs; returns 1 if unchanged — call from `if` or with `|| true`), `mask_unit`/`mask_user_unit` (skip if already masked), `enable_unit` (skip if already enabled/active). `rpm_installed` (an RPM provides the name) and `dnf_install` (installs only missing packages). Installers guard with `command -v`/`rpm_installed`/file checks. `sync_root_file` writes with `install -Z` under SELinux so files keep their policy label.
- **Orchestrators**: `bootstrap.sh` (full provision), `packages.sh`, `gnome.sh`, `dev_tools.sh`.

## Must-know commands

```bash
./stow.sh                       # symlink dotfiles into $HOME
./setup/bootstrap.sh            # full provision (stow + all modules)

# Standalone module runners
./setup/packages.sh             # dnf + flatpaks + vscodium + chrome
./setup/gnome.sh                # all GNOME sub-modules
./setup/dev_tools.sh            # mise + rootless podman + opencode/herdr/claude/tailscale/starship
SKIP_TOOLS="tailscale" ./setup/dev_tools.sh   # skip listed third-party installers
USE_DOCKER=1 ./setup/dev_tools.sh # also install rootful Docker Engine (docker group is root-equivalent)

# Single modules
./setup/dev/vocalinux.sh        # offline voice dictation (opt-in; not in bootstrap)
./setup/profiles.sh             # ~/Profiles walls + rootless Podman shells
./setup/chrome.sh               # Chrome policies + profiles (Chrome must be closed)

# Full dnf upgrade
UPGRADE=1 ./setup/packages/dnf.sh
```

## Sudo in bootstrap

`bootstrap.sh` delegates to the grouped runners (`packages.sh`, `dev_tools.sh`, `gnome.sh`) plus the standalone privacy/security/profiles/chrome/battery modules, so the leaf lists live in exactly one place each. A full provision is long and late modules (e.g. `battery.sh`) still need sudo, so a background loop (`SUDO_KEEPER`) refreshes the timestamp every 4 minutes and `sudo -v` runs before each top-level module. Modules called via `bash "$path"` subprocesses inherit cached credentials.

If a module fails early from `set -euo pipefail`, bootstrap aborts — no partial state recovery.

## Per-app gotchas

- **bash**: `bash/.bashrc` complements the stock Fedora default instead of replacing it — sources `/etc/skel/.bashrc` (the file `useradd` copies into a new home; it sources `/etc/bashrc` → `/etc/profile.d/*` for color aliases, less, bash-completion, and loads `~/.bashrc.d/*`) first, then layers the `bash/.config/bashrc.d/*` modules over it. Keep stock behavior in the default; personal tuning belongs in the modules (note: `~/.config/bashrc.d`, not Fedora's `~/.bashrc.d`).
- **git**: the global ignore is `git/.config/git/ignore` (git's default XDG path — no `core.excludesfile`). Per-repo patterns go in that repo's own `.gitignore`.
- **Ghostty**: not in the Fedora repos — `packages/dnf.sh` enables the `scottames/ghostty` COPR (upstream's documented Fedora source) before installing it.
- **Google Chrome**: Fedora Workstation ships `/etc/yum.repos.d/google-chrome.repo` disabled (`fedora-workstation-repositories`); `packages/chrome.sh` enables it with `dnf config-manager setopt` (override file, packaged repo untouched) or writes it if absent. Checked even when Chrome is installed, since a disabled repo means no updates. x86_64 only.
- **Chrome hardening**: `setup/chrome.sh` writes mandatory policies to `/etc/opt/chrome/policies/managed/dotfiles-chrome{,-extensions}.json` (sudo) and adds the four profiles (Personal/Consultancy/Brem/Lumin) to `~/.config/google-chrome/Local State` only if no profile with that name exists — existing profiles are never renamed or moved (one-time backup: `Local State.pre-dotfiles`). Refuses to add profiles while Chrome is open; policy/launcher checks run regardless. Bitwarden is `force_installed` via `ExtensionSettings`. **One launcher only**: `~/.local/share/applications/google-chrome.desktop` (and the NoDisplay `com.google.Chrome.desktop` the XDG portal opens URLs with) are re-derived each run from `/usr/share/applications` with `LAUNCH_FLAGS` spliced into every `Exec=` line — never hand-edit them, and never add per-profile `.desktop` entries; the profile is picked inside Chrome. Stale `chrome-*.desktop` per-profile launchers are deleted on run. Policies are declarative — edit the script and re-run; don't re-add the deprecated policies listed in its header (Privacy Sandbox toggles, SafeBrowsingExtendedReporting, AutofillAddress/CreditCard, PromotionalTabs). `DnsOverHttpsMode` is intentionally `off` so Chrome uses the system resolver.
- **Ghostty config**: default terminal; config is the stowed `ghostty` package (`~/.config/ghostty/config`), replacing the old Ptyxis gsettings.
- **Slack**: Flatpak from Flathub (`packages/flatpaks.sh` adds/unfilters the Flathub remote). Launch command is `flatpak run com.slack.Slack` (see `gnome/keybindings.sh`). Do not grant it all of `$HOME`; confine it with `flatpak-lock-to-profile com.slack.Slack <profile>` after `profiles.sh`.
- **Profiles**: `setup/profiles.sh` creates `~/Profiles/{personal,consultancy,brem,lumin}` and a rootless Podman container per name (`--userns=keep-id`, only that directory on `/work` with `:Z`, no `--privileged`, no `label=disable`, no docker.sock). Launchers in `~/bin` (`shell-<profile>`, `tmux-<profile>`, `mutt-<profile>`) are on PATH via `path.bash` and are rewritten each run. Neomutt stubs are written only when missing. Chrome profiles stay the browser boundary; these directories are the filesystem boundary. SELinux stays enforcing.
- **Podman**: default container runtime is rootless Podman (`dev/podman.sh`, Fedora package, subordinate UID/GID ranges). Docker Engine is opt-in (`USE_DOCKER=1`) because the docker group is root-equivalent. Do not install `podman-docker` or enable a Docker-compatible socket for the default path.
- **Dash to Dock**: Fedora GNOME is vanilla, so `gnome/dock.sh` installs `gnome-shell-extension-dash-to-dock`, appends it to `org.gnome.shell enabled-extensions`, and calls `refresh_schemas` (the inherited schema cache predates the install). Takes effect after re-login.
- **VSCodium**: `packages/vscodium.sh` writes the upstream repo `/etc/yum.repos.d/vscodium.repo` (`download.vscodium.com/rpms`, metadata + packages GPG-checked) and installs `codium`; extensions (`EXTENSIONS`) come from Open VSX via `codium --install-extension`. Settings are stowed from `vscodium/` into `~/.config/VSCodium/User/`. Third-party repo, so `dnf5-automatic` (security advisories only) won't update it — `dotfiles-thirdparty-update.timer` (`security.sh`) does, nightly.
- **starship**: installed per-user to `~/.local/bin` (no sudo) by `dev/tools.sh`; the bash prompt in `bash/.config/bashrc.d/prompt.bash` initializes it and falls back to the stock Fedora prompt (`/etc/bashrc`) if it is absent.
- **Claude Code**: installed per-user by `dev/tools.sh` via Anthropic's native installer (`https://claude.ai/install.sh` — refuses sudo). Launcher `~/.local/bin/claude` (PATH via `path.bash`), versions in `~/.local/share/claude/versions/`, downloads/backups in `~/.claude/`; self-updates in place and never edits shell rc files. Profile wrappers (`claude-brem`/`claude-lumin`) set `CLAUDE_CONFIG_DIR=~/.claude-<profile>`.
- **Tela icons**: `gnome/icons.sh` clones the upstream theme (`install.sh`) into `~/.local/share/icons` and sets `org.gnome.desktop.interface icon-theme`; the stowed `gtk` `settings.ini` uses it too.
- **Ptyxis**: Fedora's stock terminal; no longer configured or launched, but intentionally left installed as a fallback.
- **mise**: `paranoid = true` + `lockfile = true`; versions are pinned to minor lines (`go = "1.27"`, `ruby = "4.0"`, `node = "24"`) and resolved versions + checksums live in the stowed `mise/.config/mise/mise.lock`. Bump with `mise upgrade` (rewrites the lock through the symlink) and commit the lock.
- **npm**: stowed `~/.npmrc` sets `ignore-scripts=true` — no install/postinstall scripts anywhere. A package that truly needs its build step: `npm rebuild <pkg> --ignore-scripts=false`.
- **git secret scan**: `git/.gitconfig` registers a config-based `hook.gitleaks` (git ≥ 2.54) on `pre-commit`, which runs alongside repo hooks / `core.hooksPath` rather than replacing them. Don't switch it to a global `core.hooksPath` — that silently disables every repo's own hooks.
- **git signing**: `security.sh` generates `~/.config/git/signing` + `allowed_signers` (machine-local, not stowed) once `~/.ssh/id_ed25519{_sk,}.pub` exists; `.gitconfig` includes it and git skips the include when absent. Never put the key path in the stowed `.gitconfig`.
- **Claude yolo wrappers**: `claude-*-yolo` pass inline `--settings` that force the bubblewrap Bash sandbox (`allowUnsandboxedCommands: false`, `failIfUnavailable: true`) and deny reads of credential stores via both `sandbox.filesystem.denyRead` (Bash) and `permissions.deny` (file tools; deny holds under bypass). Needs `bubblewrap` + `socat` (in `packages/dnf.sh`).
- **Firewall / DNS**: `security.sh` strips the 1025–65535 port range, `ssh` and `samba-client` from the `FedoraWorkstation` zone. resolved routes all lookups (`Domains=~.`) to Cloudflare 1.1.1.2 over **opportunistic** DoT — strict mode would break captive portals. `wsdd` is a hard gvfs dependency and runs with `--no-host` (discovery only), so it is left alone.
- **Battery threshold**: Only works on supported hardware (Framework). Uses systemd tmpfiles.d for persistence.
- **GTK bookmarks**: Template uses `__HOME__` placeholder resolved by `stow.sh` via sed.

## Privacy tradeoffs (intentional)

- Automatic dnf upgrades limited to security only (`dnf5-automatic.timer` with
  `upgrade_type = security`; feature/full upgrades stay manual via `UPGRADE=1`)
- Flatpak updates confined to a nightly window (`dotfiles-flatpak-update.timer`, 03:00–05:00, `Persistent=true`); GNOME Software background updates off
- ABRT crash reporting masked; dnf `countme` disabled via a `[*]` repo override
- CUPS masked (no printing until unmasked)
- Tracker/localsearch file indexer masked
- Third-party repos (Chrome, Docker, Tailscale, VSCodium, Ghostty COPR) publish no advisories, so dnf5-automatic never touches them; `dotfiles-thirdparty-update.timer` (04:00–05:00, `Persistent=true`) upgrades only packages from those repos. Docker upgrades restart the daemon.
- No inbound connections: Workstation firewall zone closed, Tailscale shields-up (blocks Taildrop receive; undo with `sudo tailscale set --shields-up=false`). To share a dev server, drop shields temporarily and use `tailscale serve` rather than reopening Wi-Fi ports.

If a privacy measure breaks a service, **find an alternative** rather than
removing the protection outright.
