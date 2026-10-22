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

Log out / back in after bootstrap (Docker group, GNOME settings, Dash to Dock).

## Layout

```
setup/
  lib.sh                 # log/warn/error, gset, dnf_install, sync_root_file, run_module
  bootstrap.sh           # explicit ordered module list
  packages/              # dnf, flatpaks, vscodium, chrome
  dev/                   # mise, docker, opencode/herdr/claude/tailscale/starship
  gnome/                 # dock, power, appearance, keys, terminal, icons, peripherals
  privacy.sh security.sh chrome.sh battery.sh
```

Thin runners still work standalone:

| Runner | Runs |
|---|---|
| `./setup/packages.sh` | `packages/{dnf,flatpaks,vscodium,chrome}.sh` |
| `./setup/dev_tools.sh` | `dev/{mise,docker,tools}.sh` |
| `./setup/gnome.sh` | `gnome/{dock,power,appearance,keybindings,terminal,icons,peripherals}.sh` |

## `setup/` modules

| Module | What it does |
|---|---|
| `packages/dnf.sh` | Ghostty COPR + dnf tools (incl. Ghostty, Neovim); full `upgrade` only if `UPGRADE=1` / `--upgrade` |
| `packages/flatpaks.sh` | Flathub remote + Slack |
| `packages/chrome.sh` | Google Chrome via Google's rpm repo (enables Fedora's bundled `google-chrome` repo) |
| `packages/vscodium.sh` | VSCodium via its upstream rpm repo + extensions (Vim) |
| `dev/mise.sh` | mise + node@24 + go + ruby (precompiled; paranoid mode, versions + checksums pinned in the stowed `mise.lock`) |
| `dev/docker.sh` | Docker Engine (official repo) + group + enable on boot |
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
| `chrome.sh` | Managed Chrome policies (telemetry/HTTPS/cookies/permissions/AI hardening) + four profiles (Personal, Consultancy, Brem, Lumin) with Bitwarden forced |
| `battery.sh` | power-saver profile; 80% charge threshold when supported |

## App delivery (Fedora)

| App | Source | Why |
|---|---|---|
| Slack | **Flatpak** (Flathub) | Sandboxed third-party app; nightly update timer |
| Neovim | **dnf** (Fedora) | Current release in the Fedora repos |
| Google Chrome | **Google rpm repo** | Official packages; repo ships disabled in Fedora Workstation |
| VSCodium | **VSCodium rpm repo** | Native install so host toolchains, LSPs, mise and Docker just work |
| Ghostty | **COPR** (`scottames/ghostty`) | Terminal; upstream's documented Fedora source |
| Dash to Dock | **dnf** (Fedora) | Vanilla GNOME has no dock |
| Docker Engine | **docker-ce repo** | Official Fedora packages |
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

```bash
./setup/chrome.sh   # apply / refresh (idempotent; needs sudo)
```

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
