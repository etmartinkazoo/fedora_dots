# dotfiles

Personal configuration and provisioning for a **Fedora 44 Workstation (GNOME)**
laptop. Two halves:

- **Dotfiles** — per-app config (`bash`, `ghostty`, `git`, `gtk`, `herdr`, `mise`,
  `npm`, `nvim`, `opencode`, `vscodium`), symlinked into `$HOME` with [GNU Stow](https://www.gnu.org/software/stow/).
- **`setup/`** — modular, idempotent provisioning scripts (packages, desktop,
  privacy, power, app prefs).

Everything is biased toward **privacy, battery life, and a quiet machine**.

## Quick start

On a fresh Fedora 44 Workstation install:

```bash
sudo dnf install -y git stow  # bootstrap deps
git clone <this-repo> ~/.dotfiles
cd ~/.dotfiles

# Full provision (stow + all modules)
./setup/bootstrap.sh

# Or: symlink only, then run modules selectively
./stow.sh
./setup/gnome.sh
```

Log out / back in after bootstrap (GNOME settings, Dash to Dock). Opting into Docker Engine (`USE_DOCKER=1`) needs a new login before the `docker` group applies.

## Layout

```
setup/
  lib.sh                 # log/warn/error, gset, dnf_install, sync_root_file, run_module
  bootstrap.sh           # explicit ordered module list
  packages/              # dnf, flatpaks, vscodium, chrome
  dev/                   # mise, podman, optional docker, opencode/herdr/claude/tailscale/starship
  gnome/                 # dock, power, appearance, keys, terminal, icons, peripherals
  privacy.sh security.sh profiles.sh chrome.sh battery.sh
```

Thin runners still work standalone:

| Runner | Runs |
|---|---|
| `./setup/packages.sh` | `packages/{dnf,flatpaks,vscodium,chrome}.sh` |
| `./setup/dev_tools.sh` | `dev/{mise,podman,tools}.sh`, plus `dev/docker.sh` when `USE_DOCKER=1` |
| `./setup/profiles.sh` | profile directory walls + rootless Podman shells (also run from bootstrap) |
| `./setup/gnome.sh` | `gnome/{dock,power,appearance,keybindings,terminal,icons,peripherals}.sh` |

## `setup/` modules

| Module | What it does |
|---|---|
| `packages/dnf.sh` | Ghostty COPR + dnf tools (incl. Ghostty, Neovim); full `upgrade` only if `UPGRADE=1` / `--upgrade` |
| `packages/flatpaks.sh` | Flathub remote + Slack |
| `packages/chrome.sh` | Google Chrome via Google's rpm repo (enables Fedora's bundled `google-chrome` repo) |
| `packages/vscodium.sh` | VSCodium via its upstream rpm repo + extensions (Vim) |
| `dev/mise.sh` | mise + node@24 + go + ruby (precompiled; paranoid mode, versions + checksums pinned in the stowed `mise.lock`) |
| `dev/podman.sh` | Rootless Podman (Fedora package) + subordinate UID/GID ranges. No docker group, no Docker socket |
| `dev/docker.sh` | **Opt-in** (`USE_DOCKER=1`): Docker Engine + `docker` group + enable on boot. The group is root-equivalent |
| `dev/tools.sh` | opencode, herdr, Claude Code, Tailscale, starship (opt out per tool: `SKIP_TOOLS="tailscale"`) |
| `gnome/dock.sh` | Installs + enables Dash to Dock: auto-hide, bottom (centered), non-panel; Super+num off |
| `gnome/power.sh` | No suspend/dim; auto-lock; battery %; ambient off |
| `gnome/appearance.sh` | Dark mode, Night Light, 12h clock, no animations |
| `gnome/keybindings.sh` | WM keys, 4 workspaces, app launchers (browser/files, Slack), Alt-click move |
| `gnome/terminal.sh` | Ghostty as default terminal + JetBrainsMono Nerd Font (Ghostty config stowed from `ghostty/`) |
| `gnome/icons.sh` | Tela icon theme (upstream install script) + set as GNOME icon theme |
| `gnome/peripherals.sh` | Scroll, keyboard/caps, Nautilus, titlebar |
| `privacy.sh` | Masks ABRT/coredumps; dnf countme off; security-only dnf5-automatic; nightly Flatpak update window; CUPS off; GNOME privacy (no lock-screen notifications); no indexer |
| `security.sh` | Closes the Workstation firewall zone; Cloudflare DNS-over-TLS, LLMNR off; nightly third-party repo updates; Tailscale shields-up; SSH commit signing once an ed25519 key exists |
| `profiles.sh` | `~/Profiles/{personal,consultancy,brem,lumin}` directory walls, rootless Podman shells, neomutt stubs, Flatpak lock helper |
| `chrome.sh` | Managed Chrome policies (telemetry/HTTPS/cookies/permissions/AI hardening) + four profiles (Personal, Consultancy, Brem, Lumin) with Bitwarden forced |
| `battery.sh` | power-saver profile; 80% charge threshold when supported |

## App delivery (Fedora)

| App | Source | Why |
|---|---|---|
| Slack | **Flatpak** (Flathub) | Sandboxed third-party app; nightly update timer |
| Neovim | **dnf** (Fedora) | Current release in the Fedora repos |
| Google Chrome | **Google rpm repo** | Official packages; repo ships disabled in Fedora Workstation |
| VSCodium | **VSCodium rpm repo** | Native install so host toolchains, LSPs, mise and Podman just work |
| Ghostty | **COPR** (`scottames/ghostty`) | Terminal; upstream's documented Fedora source |
| Dash to Dock | **dnf** (Fedora) | Vanilla GNOME has no dock |
| Podman | **dnf** (Fedora) | Rootless containers for the four profiles. No `docker` group |
| Docker Engine | **docker-ce repo**, opt-in `USE_DOCKER=1` | Rootful daemon. The `docker` group is root-equivalent; leave it off unless a tool still needs the Docker API |
| node, ruby | **mise** | Per-user runtimes; precompiled ruby via mise config |
| opencode, herdr, Claude Code, starship | **upstream installers** | Official install scripts |
| Tela icons | **upstream install script** | Not in the Fedora repos |

## Chrome

`setup/chrome.sh` hardens Chrome and provisions four per-context profiles —
**Personal**, **Consultancy**, **Brem**, **Lumin** — each with the Bitwarden
extension force-installed.

- **Policies** are system-wide (sudo) in
  `/etc/opt/chrome/policies/managed/` — telemetry off, HTTPS-only (strict),
  third-party cookies blocked, notifications/location/motion/fonts blocked by
  default, no sync, no Chrome password manager/autofill (Bitwarden owns
  those), no Google AI data flows, no Cast, no background mode. Secure DNS
  stays **off** so Chrome uses the system resolver.
- **Profiles** are matched by name: one that already exists is left alone
  (wherever it lives), and only missing ones are added to
  `~/.config/google-chrome/Local State` (backup: `Local State.pre-dotfiles`).
  There is a **single** launcher in `~/.local/share/applications/` —
  `google-chrome.desktop`, re-derived from Chrome's own desktop file with the
  launch flags appended — so the app grid shows one Chrome and the profile is
  picked inside Chrome from the avatar menu.
- Bitwarden (`nngceckbapebfimnlniiiahkandclblb`) is `force_installed` via the
  `ExtensionSettings` policy; flip to `normal_installed` in `setup/chrome.sh`
  to allow removal.
- **Close Chrome** only when a profile needs adding — the script stops and
  tells you (Chrome rewrites profile state on exit). Re-run after editing
  `PROFILES` in `setup/chrome.sh`; verify at `chrome://policy`.
- Chrome profiles isolate cookies, logins, and the Bitwarden vault. They do
  not isolate the filesystem. The matching directory wall is `setup/profiles.sh`.

```bash
./setup/chrome.sh   # apply / refresh (idempotent; needs sudo)
```

## Profiles

Four contexts — **personal**, **consultancy**, **brem**, **lumin** — share one
login. Each one has a directory, a rootless container, and a Chrome profile.
`setup/profiles.sh` builds the directory and the container. `setup/chrome.sh`
already builds the Chrome profile. Bootstrap runs both.

| Boundary | What it isolates |
|---|---|
| `~/Profiles/<name>/` | Files: Documents, Downloads, Projects, Mail, `.ssh`, and `.config` for that context |
| Podman container `<name>` | Shell and tools. `shell-<name>` and `tmux-<name>` enter a Fedora container whose only host mount is that directory at `/work` |
| Chrome profile | Browser state: cookies, logins, Bitwarden. One launcher; pick the profile inside Chrome |
| Flatpak override | GUI apps. `flatpak-lock-to-profile <app-id> <name>` drops home and host filesystem access and grants that one directory |

A download from the Brem Chrome profile still lands in the host `~/Downloads`
until that profile's download directory is set to `~/Profiles/brem/Downloads`.
The container does not see Chrome's cookie store. Chrome sees another
profile's files only if you pick them in a file dialog.

The container runs with `--userns=keep-id` (files you create are owned by
you) and a private SELinux volume label (`:Z`). It is not privileged, it does
not pass `--security-opt label=disable`, and it does not mount the Docker
socket or the rest of `$HOME`. `HOME` inside the container is `/work`, so
per-profile SSH keys live at `~/Profiles/<name>/.ssh` and are the ones
`git`/`ssh` see in that shell. Host Git signing (`security.sh`) keeps using
`~/.ssh/id_ed25519`. The stowed host Neovim and bash configs are not mounted
in; put a copy under `~/Profiles/<name>/.config/` when a profile should have
its own editor config.

SELinux stays enforcing. Existing containers are left in place. A re-run
warns if one is privileged, disables SELinux separation, or mounts anything
other than its profile directory.

```bash
./setup/profiles.sh

shell-brem                 # bash in the brem container, cwd /work
tmux-consultancy           # tmux session inside that container
mutt-personal              # host neomutt; edit the stub before real mail

flatpak-lock-to-profile com.slack.Slack brem
INSTALL_PROFILE_FLATPAKS=1 ./setup/profiles.sh   # Zoom, Obsidian, Signal (user install, no $HOME)
INSTALL_HYLKI=1 ./setup/profiles.sh              # optional Hylki GUI mail
```

Launchers are rewritten each run into `~/bin`, which `bash/.config/bashrc.d/path.bash`
puts on `PATH`. Neomutt stubs are written only when the file is missing, so
account settings survive a re-run. Passwords stay in a per-profile secret
store (`pass show <profile>/email` is the hint in the stub), not in this repo.
`~/Profiles/README.md` is a short copy of these rules and is rewritten each run.

The image defaults to `registry.fedoraproject.org/fedora:<VERSION_ID>` from
`/etc/os-release`, or `fedora:44` when that id is not a plain integer (this
repo's target). Override with `FEDORA_PROFILE_IMAGE`.

### Podman, and Docker when you still need it

`setup/dev/podman.sh` installs rootless Podman from the Fedora repos and
gives this user a subordinate UID/GID range when one is missing. The default
path does not create a `docker` group and does not enable a Docker-compatible
socket.

Docker Engine remains available:

```bash
USE_DOCKER=1 ./setup/dev/docker.sh
# or, as part of the dev-tools runner:
USE_DOCKER=1 ./setup/dev_tools.sh
```

That is the previous install: Docker's rpm repo, the `docker` group, and the
daemon enabled on boot. A process in the `docker` group can ask that rootful
daemon to mount the host filesystem and run as root, so membership is
root-equivalent. Leave it off unless a tool still needs the Docker API.
Bootstrap without `USE_DOCKER=1` leaves an existing Docker install as it is.

### Flatpak confinement

Slack stays the system Flatpak from `packages/flatpaks.sh`. This module does
not give it home access. `install-profile-flatpaks` (or
`INSTALL_PROFILE_FLATPAKS=1`) installs Zoom, Obsidian, and Signal as user
Flatpaks and then sets `--nofilesystem=home` and `--nofilesystem=host`. A
profile directory is added only by `flatpak-lock-to-profile`, which also
clears the other three profile paths so an app is locked to one context.

**Hylki** (`co.hyprlab.Hylki`) is optional GUI mail next to the neomutt stubs.
It comes from Hyprlab's Flatpak repo (`INSTALL_HYLKI=1`), not from Flathub.
A fresh install gets the same home/host denial. Account data for the Flatpak
lives under `~/.var/app/co.hyprlab.Hylki/`. Neomutt uses
`~/Profiles/<name>/Mail` and `~/Profiles/<name>/.config/neomutt/`.

## Notes

- Targets **Fedora 44 Workstation (GNOME 50, dnf5)**. GNOME modules assume
  GNOME Shell.
- SELinux stays enforcing: root files are written with `install -Z` so they
  keep their policy labels (e.g. `/etc/hosts` stays `net_conf_t`).
- Battery charge thresholds only apply on supported hardware (e.g. Framework).
- `bash/.bashrc` sources the stock Fedora default (`/etc/skel/.bashrc`, which pulls in `/etc/bashrc`), then layers the `bash/.config/bashrc.d/*` modules on top.
- Shared helpers live in `setup/lib.sh`; every module sources it.
- **Privacy tradeoffs:** automatic dnf upgrades limited to **security** only
  (feature upgrades stay manual — `UPGRADE=1 ./setup/packages/dnf.sh`); Flatpak
  updates confined to a nightly window; CUPS masked (printing off until
  unmasked).
