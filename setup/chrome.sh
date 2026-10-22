#!/usr/bin/env bash
#
# chrome.sh — harden Google Chrome and provision four per-context profiles.
#
# Two layers:
#
#   1. System-wide mandatory policies, dropped into
#      /etc/opt/chrome/policies/managed/ (needs sudo; applies to every profile
#      and every future profile). Covers: telemetry off, HTTPS-only (strict),
#      third-party cookies blocked, notifications/location/motion/fonts
#      blocked by default, no background mode, no network prediction, no Cast,
#      no promo tabs, no sync, no Chrome password manager/autofill (Bitwarden
#      owns that), no Google AI data flows, no multi-GB model downloads.
#
#   2. Four isolated profiles — Personal, Consultancy, Brem, Lumin — added to
#      ~/.config/google-chrome only if a profile with that name doesn't exist
#      yet (existing profiles are never renamed or moved). There is ONE
#      launcher: the app grid shows a single "Google Chrome" and the profile
#      is picked inside Chrome (avatar menu). Bitwarden is force-installed
#      into every profile via the ExtensionSettings policy, so it needs no
#      manual store visits: https://bitwarden.com/help/browserext-deploy
#
# Deliberately NOT set (checked against Chrome 155's policy list):
#   - SafeBrowsingExtendedReportingEnabled  (no effect since M145)
#   - PrivacySandbox{AdTopics,AdMeasurement,Prompt}Enabled
#     (retired upstream in M144 along with the APIs they controlled)
#   - AutofillAddress/CreditCardEnabled + PromotionalTabsEnabled
#     (deprecated; AutofillSettings / PromotionsEnabled used instead)
#   - DnsOverHttpsMode secure: keep Chrome on the system resolver.
#
# Idempotent: every step checks first and only writes what's missing or
# changed. Chrome must be fully stopped only when a profile has to be added
# (Chrome rewrites Local State on exit and would drop the new entry).
# Re-run after editing PROFILES.
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Profile display name : preferred profile directory, in picker order. A
# profile is matched by NAME: if one called e.g. "Brem" already exists (in any
# directory) it is left untouched. A missing profile goes into its preferred
# dir when that slot is free (or still holds a never-renamed Chrome placeholder
# such as "Person 1"), else the next free "Profile N".
PROFILES=(
  "Personal:Default"
  "Consultancy:Profile 1"
  "Brem:Profile 2"
  "Lumin:Profile 3"
)

CHROME_CONFIG_DIR="$HOME/.config/google-chrome"
LAUNCHER_DIR="$HOME/.local/share/applications"
POLICY_DIR="/etc/opt/chrome/policies/managed"

# Bitwarden Password Manager (Chrome Web Store). ID and update URL per
# https://bitwarden.com/help/browserext-deploy
BITWARDEN_ID="nngceckbapebfimnlniiiahkandclblb"
BITWARDEN_UPDATE_URL="https://clients2.google.com/service/update2/crx"

# Flags appended to every Exec line of the single launcher (no policy covers
# these):
#   --no-first-run, --no-default-browser-check   first-run / default-browser noise
#   --no-pings                                   drop <a ping> tracking requests
#   --disable-domain-reliability                 no connectivity reports to Google
LAUNCH_FLAGS=(--no-first-run --no-default-browser-check --no-pings --disable-domain-reliability)

# ===========================================================================
# Preflight
# ===========================================================================

CHROME_RUNNING=0
pgrep -x chrome >/dev/null 2>&1 && CHROME_RUNNING=1

CHROME_BIN="$(command -v google-chrome-stable || command -v google-chrome || true)"
[ -n "$CHROME_BIN" ] \
  || error "Google Chrome not found — run setup/packages/chrome.sh first."

# No upfront `sudo -v`: sudo is only needed (and prompted for) when a policy
# file actually has to change.

# ===========================================================================
# Managed policies  (system, needs sudo)
# ===========================================================================

# Validate, then install a policy file (name, JSON on stdin) only if it differs
# from what's already there.
install_policy() {
  local name="$1" tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  python3 -m json.tool "$tmp" >/dev/null \
    || { rm -f "$tmp"; error "generated invalid JSON for policy $name (bug in chrome.sh)"; }
  sync_root_file "$POLICY_DIR/$name" <"$tmp" || echo "  $name already up to date"
  rm -f "$tmp"
}

log "Checking managed Chrome policies in $POLICY_DIR"

# Hardening. Rationale for the non-obvious values:
#   SafeBrowsingProtectionLevel 1  standard protection, locked so it can never
#                                  be switched off (2 = enhanced shares more
#                                  browsing data with Google — not wanted here)
#   ChromeVariations 1             variations limited to critical security/stability
#                                  fixes
#   HttpsOnlyMode force_enabled    strict HTTPS-only (force_balanced_enabled is the
#                                  softer alternative)
#   NetworkPredictionOptions 2     value 1 is deprecated upstream; 2 = never prefetch
#   DnsOverHttpsMode off           keep Chrome on the system resolver
#   *Settings 1 or 2               per-policy scales differ (Gemini 1 = off,
#                                  GenAI-model 1 = no download, others 2 = off)
install_policy dotfiles-chrome.json <<'JSON'
{
  "MetricsReportingEnabled": false,
  "UrlKeyedAnonymizedDataCollectionEnabled": false,
  "UserFeedbackAllowed": false,
  "SafeBrowsingProtectionLevel": 1,
  "ChromeVariations": 1,
  "HttpsOnlyMode": "force_enabled",
  "BlockThirdPartyCookies": true,
  "DefaultNotificationsSetting": 2,
  "DefaultGeolocationSetting": 2,
  "DefaultSensorsSetting": 2,
  "DefaultLocalFontsSetting": 2,
  "NetworkPredictionOptions": 2,
  "DnsOverHttpsMode": "off",
  "BackgroundModeEnabled": false,
  "PromotionsEnabled": false,
  "SearchSuggestEnabled": false,
  "SpellCheckServiceEnabled": false,
  "AlternateErrorPagesEnabled": false,
  "SyncDisabled": true,
  "PasswordManagerEnabled": false,
  "PasswordLeakDetectionEnabled": false,
  "AutofillSettings": [
    {
      "url_pattern": "*",
      "blocked_types": ["all"]
    }
  ],
  "DefaultBrowserSettingEnabled": false,
  "EnableMediaRouter": false,
  "BlockExternalExtensions": true,
  "GeminiSettings": 1,
  "HelpMeWriteSettings": 2,
  "CreateThemesSettings": 2,
  "HistorySearchSettings": 2,
  "DevToolsGenAiSettings": 2,
  "GenAILocalFoundationalModelSettings": 1
}
JSON

# Extensions: Bitwarden in every profile, no manual installs. To let users
# remove it again, change "force_installed" to "normal_installed"; delete this
# file to stop managing extensions entirely.
install_policy dotfiles-chrome-extensions.json <<JSON
{
  "ExtensionSettings": {
    "$BITWARDEN_ID": {
      "installation_mode": "force_installed",
      "update_url": "$BITWARDEN_UPDATE_URL",
      "toolbar_pin": "force_pinned"
    }
  }
}
JSON

# ===========================================================================
# Profiles  (per-user, no sudo)
# ===========================================================================

log "Checking Chrome profiles: ${PROFILES[*]%%:*}"

# Prints one "name<TAB>dir<TAB>status" line per profile (status: exists |
# added) and only writes Local State / Preferences when a profile is missing.
resolved="$(CHROME_RUNNING="$CHROME_RUNNING" python3 - "$CHROME_CONFIG_DIR" "${PROFILES[@]}" <<'PY'
import copy
import json
import os
import shutil
import sys

chrome_dir = sys.argv[1]
profiles = [p.split(":", 1) for p in sys.argv[2:]]
wanted_names = {name for name, _ in profiles}


def write_json(path, data):
    tmp = path + ".dotfiles-tmp"
    with open(tmp, "w") as fh:
        json.dump(data, fh, separators=(",", ":"), ensure_ascii=False)
    os.replace(tmp, path)
    os.chmod(path, 0o600)


def read_json(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        return {}
    except ValueError as exc:
        sys.exit(f"error: {path} is not valid JSON ({exc}) — fix or move it aside, then re-run")


state_path = os.path.join(chrome_dir, "Local State")
state = read_json(state_path)
profile = state.setdefault("profile", {})
cache = profile.setdefault("info_cache", {})
by_name = {e.get("name"): d for d, e in cache.items()}


def slot_free(d):
    """A dir is usable if Chrome doesn't know it and it isn't on disk, or if it
    only holds a placeholder profile the user never named (e.g. "Person 1")."""
    if d in cache:
        e = cache[d]
        return e.get("is_using_default_name", False) and e.get("name") not in wanted_names
    return not os.path.exists(os.path.join(chrome_dir, d))


resolved, added, claimed = [], [], set()
for name, wanted in profiles:
    if name in by_name:
        resolved.append((name, by_name[name], "exists"))
        continue
    d = wanted
    if d in claimed or not slot_free(d):
        n = 1
        while f"Profile {n}" in claimed or not slot_free(f"Profile {n}"):
            n += 1
        d = f"Profile {n}"
    claimed.add(d)
    resolved.append((name, d, "added"))
    added.append((name, d))

if added:
    if os.environ.get("CHROME_RUNNING") == "1":
        missing = ", ".join(n for n, _ in added)
        sys.exit(f"error: Chrome is running and profiles need adding ({missing}) — quit Chrome completely and re-run")

    backup = state_path + ".pre-dotfiles"
    if os.path.exists(state_path) and not os.path.exists(backup):
        shutil.copy2(state_path, backup)
        print("Backed up Local State → 'Local State.pre-dotfiles'", file=sys.stderr)

    # New entries copy the shape of an existing one so they match this Chrome
    # version's schema; volatile/identity fields are dropped.
    DROP = {
        "active_time", "ai_subscription_tier", "background_apps", "enterprise_label",
        "force_signin_profile_locked", "gaia_given_name", "gaia_id", "gaia_name",
        "hosted_domain", "is_consented_primary_account", "managed_user_id",
        "metrics_bucket_index", "signin.with_credential_provider", "user_name",
    }
    template = copy.deepcopy(next(iter(cache.values()), {}))
    for key in DROP:
        template.pop(key, None)

    order = profile.get("profiles_order") or list(cache)
    for name, d in added:
        entry = cache.setdefault(d, copy.deepcopy(template))
        entry["name"] = name
        entry["is_using_default_name"] = False
        entry.setdefault("is_using_default_avatar", True)
        if d not in order:
            order.append(d)

        os.makedirs(os.path.join(chrome_dir, d), mode=0o700, exist_ok=True)
        pref_path = os.path.join(chrome_dir, d, "Preferences")
        prefs = read_json(pref_path)
        p = prefs.setdefault("profile", {})
        if not os.path.exists(pref_path):
            p["exit_type"] = "Normal"
            p["exited_cleanly"] = True
        p["name"] = name
        write_json(pref_path, prefs)

    profile["profiles_order"] = order
    profile.setdefault("last_used", resolved[0][1])
    write_json(state_path, state)

for name, d, status in resolved:
    print(f"{name}\t{d}\t{status}")
PY
)" || error "Chrome profile provisioning failed (see message above)"

while IFS=$'\t' read -r name dir status; do
  log "  $name → $CHROME_CONFIG_DIR/$dir ($status)"
done <<<"$resolved"

# ===========================================================================
# Single launcher  (per-user, no sudo)
# ===========================================================================
# One "Google Chrome" in the app grid — the profile is picked inside Chrome
# (avatar menu / profile picker), never by a separate .desktop entry.
#
# The entry reuses Chrome's own desktop IDs so there is never a second icon:
# a file in $LAUNCHER_DIR shadows the system one of the same name, and it is
# re-derived from /usr/share/applications on every run (never hand-edited), so
# upstream changes to MimeType, desktop actions and translations flow through.
# LAUNCH_FLAGS are spliced into each Exec line — no policy covers them — with
# trailing field codes kept last. com.google.Chrome.desktop (NoDisplay=true,
# the ID the XDG portal opens URLs with) gets the same treatment so launches
# from other apps keep the flags, while staying out of the app grid.

SYSTEM_APPS_DIR="/usr/share/applications"

log "Checking Chrome launcher in $LAUNCHER_DIR"
[ -d "$LAUNCHER_DIR" ] || install -d -m 0755 "$LAUNCHER_DIR"

# Per-profile launchers written by earlier versions of this script.
for old in "$LAUNCHER_DIR"/chrome-*.desktop; do
  [ -e "$old" ] || continue
  if grep -q -- '--profile-directory=' "$old" && grep -q '^Name=Google Chrome (' "$old"; then
    rm -f "$old"
    echo "  removed $old"
  fi
done

# write_launcher <system src or ""> <destination>
# An empty src means Chrome shipped no stock desktop file: fall back to a
# minimal entry (MimeType included so default-browser registration still works).
write_launcher() {
  local src="$1" dst="$2" tmp
  tmp="$(mktemp)"
  if [ -n "$src" ]; then
    python3 - "$src" "$tmp" "${LAUNCH_FLAGS[@]}" <<'PY'
import sys

src, dst, flags = sys.argv[1], sys.argv[2], sys.argv[3:]
with open(src, encoding="utf-8") as fh:
    lines = fh.read().splitlines(keepends=True)

out = []
for line in lines:
    if line.startswith("Exec="):
        args = line[len("Exec="):].split()
        i = len(args)
        while i and args[i - 1].startswith("%"):   # field codes stay last
            i -= 1
        args[i:i] = flags
        line = "Exec=" + " ".join(args) + "\n"
    out.append(line)

with open(dst, "w", encoding="utf-8") as fh:
    fh.writelines(out)
PY
  else
    cat >"$tmp" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Chrome
Comment=Access the Internet
Exec=$CHROME_BIN ${LAUNCH_FLAGS[*]} %U
Icon=google-chrome
Terminal=false
StartupNotify=true
StartupWMClass=google-chrome
Categories=Network;WebBrowser;
MimeType=application/pdf;text/html;image/gif;image/jpeg;image/png;image/webp;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/google-chrome;
EOF
  fi
  if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
    rm -f "$tmp"
  else
    install -m 0644 "$tmp" "$dst"
    rm -f "$tmp"
    echo "  wrote $dst"
  fi
}

generated=("$LAUNCHER_DIR/google-chrome.desktop")
if [ -f "$SYSTEM_APPS_DIR/google-chrome.desktop" ]; then
  write_launcher "$SYSTEM_APPS_DIR/google-chrome.desktop" "${generated[0]}"
else
  write_launcher "" "${generated[0]}"
fi
if [ -f "$SYSTEM_APPS_DIR/com.google.Chrome.desktop" ]; then
  generated+=("$LAUNCHER_DIR/com.google.Chrome.desktop")
  write_launcher "$SYSTEM_APPS_DIR/com.google.Chrome.desktop" "${generated[-1]}"
fi

if command -v desktop-file-validate >/dev/null 2>&1; then
  for f in "${generated[@]}"; do
    desktop-file-validate "$f" || echo "  WARNING: $f has desktop-file issues (see above)"
  done
fi

log "Chrome hardening complete"
log "One 'Google Chrome' in the app grid — switch profiles from the avatar menu inside Chrome; Bitwarden installs itself into each profile on first start."
log "Verify anytime at chrome://policy"
