#!/usr/bin/env bash
set -euo pipefail

# User software layer: acts on the answers collected by ui_collect_answers
# (dock / password manager / dev intent), plus the General Software categories.
# Answers are saved to ~/.config/fm-fedora/install.conf and sourced before
# every module, so they are always set by the time we get here.
#
# PKG: google-chrome-stable (Google RPM repo), opera-stable (Opera RPM repo)
# REPO: Fedora default + vendor repos written by this module (left enabled)
source "$FM_FEDORA_PATH/lib/helpers.sh"

STEP_LABEL="Installing user software"

# ── Hardcoded values (edit here, not inline) ──

# Chrome: Google's own RPM repo. Not in Fedora or RPM Fusion.
# Key: Google, Inc. (Linux Package Signing Authority)
#       EB4C 1BFD 4F04 2F6D DDCC EC91 7721 F63B D38B 4796 → rpm key id d38b4796
CHROME_REPO_ID="google-chrome"
CHROME_REPO_FILE="/etc/yum.repos.d/google-chrome.repo"
CHROME_BASEURL="https://dl.google.com/linux/chrome/rpm/stable/x86_64"
CHROME_GPGKEY="https://dl.google.com/linux/linux_signing_key.pub"
CHROME_KEY_PKG="gpg-pubkey-d38b4796"
CHROME_PKG="google-chrome-stable"
CHROME_BIN="google-chrome"

# Opera: Opera's own RPM repo. Not in Fedora or RPM Fusion.
# Key: Opera Software Archive Automatic Signing Key 2025
#       6C86 BE21 4648 3766 80CA 957B 11EE 8C00 B693 A745 → rpm key id b693a745
#       expires 2027-05-19 — re-pin here if Opera rotates it again.
OPERA_REPO_ID="opera"
OPERA_REPO_FILE="/etc/yum.repos.d/opera.repo"
OPERA_BASEURL="https://rpm.opera.com/rpm"
OPERA_GPGKEY="https://rpm.opera.com/rpmrepo.key"
OPERA_KEY_PKG="gpg-pubkey-b693a745"
OPERA_PKG="opera-stable"
OPERA_BIN="opera"

# Web apps — disabled. Opera has no PWA subsystem: no install prompt, no
# chrome://apps, and `opera --app=URL` is silently ignored (Omarchy issue
# #8298, confirmed against Opera 137: the flag reaches the process, the
# window still shows Speed Dial). Without an install path there is nothing
# for the installer's project-management question to create, so the question
# and this category are both commented out together.
#
# Re-enable: uncomment the constants below, remove the FM_PM_DISABLED guard
# around add_opera_webapp, restore the "# b. Web apps" block and its verify
# section, and uncomment the question in lib/installer-ui.sh.
#
# `--new-window` is the flag Omarchy settled on after testing `--app=`; a bare
# URL would land as a tab in whatever Opera window is already open.
# OPERA_PWA_EXEC="--new-window"
# OPERA_APP_DIR="$HOME/.local/share/applications"
# OPERA_ICON_DIR="$HOME/.local/share/icons"

# name|url — created only for the entries the installer's project-management
# question put in FM_ANSWER_PM. Add a line here to offer another app.
# PWA_APPS=(
#     "Notion|https://www.notion.so"
#     "Linear|https://linear.app"
# )

# ── Bookkeeping ──
# Parallel arrays: one entry per browser we actually tried to install.
# FM_FAILED_SOFTWARE holds just the names, for the end-of-run summary.
FM_SOFTWARE_PKGS=()
FM_SOFTWARE_KEYS=()
FM_SOFTWARE_BINS=()
FM_FAILED_SOFTWARE=()

fm_record_failure() {
    FM_FAILED_SOFTWARE+=("$1")
    warn "Unable to install software: \"$1\""
}

# ── Vendor repo helper ──
#
# add_vendor_repo <name> <repo_file> <repo_id> <baseurl> <gpgkey_url>
#                 <key_pkg> <pkg> <bin>
#
# Clean-source rules, applied to every vendor repo in this module:
#   * gpgcheck=1 always, with an explicit gpgkey= URL — never --nogpgcheck.
#   * An existing repo file with an explicit gpgcheck=0 is refused, not
#     patched: same gate module 02 puts on Terra. We do not silently trust a
#     repo someone else turned verification off on.
#   * No repo_gpgcheck. Neither Google nor Opera signs repodata, so enabling
#     it would fail every makecache — a key failure with no key at fault.
#   * The repo file is written only when absent, so local edits survive a
#     re-run and the step stays idempotent.
#   * Any failure records the app and returns; the run always continues.
add_vendor_repo() {
    local name="$1" repo_file="$2" repo_id="$3" baseurl="$4"
    local gpgkey_url="$5" key_pkg="$6" pkg="$7" bin="$8"

    if [[ -f "$repo_file" ]] && grep -qE '^gpgcheck[[:space:]]*=[[:space:]]*0' "$repo_file"; then
        warn "$repo_file has gpgcheck=0 — refusing to install $name from it"
        fm_record_failure "$name"
        return 0
    fi

    if [[ ! -f "$repo_file" ]]; then
        if ! ui_exec sudo tee "$repo_file" <<EOF
[$repo_id]
name=$name packages
type=rpm-md
baseurl=$baseurl
enabled=1
gpgcheck=1
gpgkey=$gpgkey_url
EOF
        then
            warn "Could not write $repo_file"
            fm_record_failure "$name"
            return 0
        fi
        info "Added repository: $repo_file"
    else
        info "Repository already present: $repo_file"
    fi

    # Record before the install so a failure still lands in the verify pass.
    FM_SOFTWARE_PKGS+=("$pkg")
    FM_SOFTWARE_KEYS+=("$key_pkg")
    FM_SOFTWARE_BINS+=("$bin")

    # -y lets dnf pull the key from gpgkey= without prompting; with
    # gpgcheck=1 a mismatched or unreadable key fails here, cleanly, and we
    # record it rather than aborting the install.
    if ! ui_exec sudo dnf install -y "$pkg"; then
        fm_record_failure "$name"
        return 0
    fi
}

# ── Web app helper ──
# Disabled with the category below — guarded by FM_PM_DISABLED rather than
# deleted, so re-enabling is two lines instead of a rewrite.
#
# add_opera_webapp <name> <url>
#
# Writes ~/.local/share/applications/fm-<slug>.desktop so the site shows up
# in the launcher and the overview as its own app. Uses write_config_ensure,
# so a re-run only rewrites when the content actually changed.
#
# Icon: best effort. The site's favicon is pulled to ~/.local/share/icons/
# and referenced by absolute path; any failure removes the file and falls
# back to `Icon=opera` so the desktop entry never points at a missing image.
: <<'FM_PM_DISABLED'
add_opera_webapp() {
    local name="$1" url="$2"
    local slug desktop icon_path icon_ref
    slug="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-')"
    slug="${slug%-}"
    desktop="$OPERA_APP_DIR/fm-$slug.desktop"
    icon_path="$OPERA_ICON_DIR/fm-$slug.png"

    if ! command -v "$OPERA_BIN" >/dev/null 2>&1; then
        warn "Opera not installed — cannot create web app: \"$name\""
        fm_record_failure "$name"
        return 0
    fi

    icon_ref="opera"
    mkdir -p "$OPERA_APP_DIR" "$OPERA_ICON_DIR"
    if curl -fsSL --max-time 15 "$url/favicon.ico" -o "$icon_path" 2>/dev/null \
        && [[ -s "$icon_path" ]]; then
        icon_ref="$icon_path"
    else
        rm -f "$icon_path"
        info "No favicon for $name — using the Opera icon"
    fi

    # Unconditional: write_config_ensure reports and never fails, so there is
    # nothing to guard — a failure here would be a permissions problem that
    # the verify pass catches as a missing file.
    write_config_ensure "$desktop" "[Desktop Entry]
Type=Application
Name=$name
Comment=$name web app (opened by Opera)
Exec=$OPERA_BIN $OPERA_PWA_EXEC $url
Icon=$icon_ref
Terminal=false
StartupNotify=true
Categories=Network;WebBrowser;
StartupWMClass=opera"

    # Make it visible without a logout. Best effort: the file is already on
    # disk, so a missing update-desktop-database only delays the listing.
    if command -v update-desktop-database >/dev/null 2>&1; then
        ui_exec update-desktop-database "$OPERA_APP_DIR" || true
    fi
    info "Web app created: $name → $desktop"
}
FM_PM_DISABLED

# ── Answers ──
# ui_collect_answers runs before every module and exports these; the saved
# install.conf is sourced there, so they are always set (possibly to the
# default) by the time we get here.
FM_DOCK="${FM_ANSWER_DOCK:-no}"
FM_PASSWORD_MANAGER="${FM_ANSWER_PASSWORD_MANAGER:-Zoho Vault}"
FM_DEV="${FM_ANSWER_DEV:-no}"
# Set by ui_choose_multi; "Skip" when nothing was picked or the question was
# never asked (e.g. sourcing this module on its own). Disabled with the
# project-management layer — nothing reads it while that layer is off.
# FM_PM="${FM_ANSWER_PM:-Skip}"

# ── 1. Dock ──
# TODO: implement per guidance. Skipped for now — the answer is only read
# and reported so the wiring is visible in the install log.
ui_step
info "Dock preference: $FM_DOCK (not yet applied)"

# ── 2. Password manager ──
# TODO: map FM_PASSWORD_MANAGER to a package / note. Warn-and-continue on
# any install failure; the verify step reports what is missing.
ui_step
info "Password manager preference: $FM_PASSWORD_MANAGER (not yet applied)"

# ── 3. Dev toolchain ──
# TODO: package list TBD. Warn-and-continue on failure.
ui_step
if [[ "$FM_DEV" == "yes" ]]; then
    info "Dev toolchain requested (not yet applied)"
else
    info "Dev toolchain skipped (answer: no)"
fi

# ==============================================================================
# General Software
#
# Categories below. Each one is a comment block naming what belongs there, so
# the module reads as a checklist rather than a pile of dnf lines.
#
#   a. Browsers
#   b. Web apps — disabled (Opera has no PWA subsystem; see note above)
#   c. <next category — TBD>
# ==============================================================================

# ── a. Browsers ──
# Google Chrome and Opera. Neither ships in Fedora's official repos or RPM
# Fusion, so both get their own vendor RPM repository, left enabled so the
# browsers keep updating through a normal `dnf upgrade`.
# Firefox needs nothing: it is already on Fedora Workstation by default.
# A failure in either one logs `Unable to install software: "<name>"`,
# is recorded, and the module moves on.
ui_step
add_vendor_repo "Google Chrome" "$CHROME_REPO_FILE" "$CHROME_REPO_ID" \
    "$CHROME_BASEURL" "$CHROME_GPGKEY" "$CHROME_KEY_PKG" \
    "$CHROME_PKG" "$CHROME_BIN"

ui_step
add_vendor_repo "Opera" "$OPERA_REPO_FILE" "$OPERA_REPO_ID" \
    "$OPERA_BASEURL" "$OPERA_GPGKEY" "$OPERA_KEY_PKG" \
    "$OPERA_PKG" "$OPERA_BIN"

# ── a. Default browser ──
# Straight after the Opera install, while we know it just landed. Opera is
# the default for the desktop and for the http/https handlers.
#
# The desktop file id is read from the installed package rather than
# hardcoded: the rpm ships more than one .desktop (main entry plus a
# launcher/menu duplicate), so we take the one whose filename matches the
# binary instead of the first line in the list.
ui_step
if ! rpm -q "$OPERA_PKG" >/dev/null 2>&1; then
    # Opera never installed — there is nothing to make default, and recording
    # it again here would only duplicate the failure add_vendor_repo logged.
    warn "Opera not installed — skipping default browser step"
else
    # `|| true` on both lookups: pipefail + grep finding nothing would
    # otherwise abort the whole install through an assignment.
    OPERA_DESKTOP="$(rpm -ql "$OPERA_PKG" | grep -E "/${OPERA_BIN}(-stable)?\.desktop$" | head -n1 || true)"
    if [[ -z "$OPERA_DESKTOP" ]]; then
        OPERA_DESKTOP="$(rpm -ql "$OPERA_PKG" | grep -E '\.desktop$' | head -n1 || true)"
    fi
    OPERA_DESKTOP_ID="$(basename "${OPERA_DESKTOP:-}")"

    if [[ -z "$OPERA_DESKTOP_ID" ]]; then
        warn "No .desktop file found in $OPERA_PKG — Opera not set as default"
        fm_record_failure "Opera (default browser)"
    elif ! command -v xdg-settings >/dev/null 2>&1; then
        warn "xdg-settings not available — Opera not set as default"
        fm_record_failure "Opera (default browser)"
    elif ! ui_exec xdg-settings set default-web-browser "$OPERA_DESKTOP_ID"; then
        warn "xdg-settings failed — Opera not set as default"
        fm_record_failure "Opera (default browser)"
    else
        info "Default browser: $OPERA_DESKTOP_ID"
    fi
fi

# ── b. Web apps — disabled ──
# Commented out together with the question that fed it: Opera cannot install
# PWAs (no install prompt, no chrome://apps, `--app=` ignored), so the only
# thing the answer could produce was a windowed shortcut with an address bar
# — a launcher, not a web app. The category returns when there is a browser
# here that can actually install one.
#
# Only the apps the project-management question selected would be created.
# The answer arrives comma-joined ("Notion, Linear") or as "Skip", so
# membership is tested against a padded copy of it rather than a substring
# match — otherwise "Notion" would also match inside an unrelated name.
#
# One ui_step for the whole category: the loop is data-driven, and a step
# per app would make the total depend on how many the user picked.
# ui_step
# if [[ "$FM_PM" == "Skip" ]]; then
#     info "Web apps skipped (answer: Skip)"
# else
#     for entry in "${PWA_APPS[@]}"; do
#         app_name="${entry%%|*}"
#         app_url="${entry#*|}"
#         case ", $FM_PM," in
#             *", $app_name,"*)
#                 add_opera_webapp "$app_name" "$app_url"
#                 ;;
#             *)
#                 info "Web app not selected: $app_name"
#                 ;;
#         esac
#     done
# fi

# ── c. <next category — TBD> ──

# ── Verification ──
# Reports only what a block above actually attempted, so an unimplemented
# block never fails the module. Warn-and-continue everywhere: a miss is a
# warning plus a named failure, never an abort.
verify_software_installation() {
    local failed=0 i name

    for (( i = 0; i < ${#FM_SOFTWARE_PKGS[@]}; i++ )); do
        if ! rpm -q "${FM_SOFTWARE_PKGS[$i]}" >/dev/null 2>&1; then
            warn "Package missing: ${FM_SOFTWARE_PKGS[$i]}"
            failed=1
        fi
        if ! command -v "${FM_SOFTWARE_BINS[$i]}" >/dev/null 2>&1; then
            warn "Binary missing: ${FM_SOFTWARE_BINS[$i]}"
            failed=1
        fi
        # The vendor key must actually be in rpm's keyring, or the next
        # `dnf upgrade` trips over a NOKEY it has never seen before.
        if ! rpm -q "${FM_SOFTWARE_KEYS[$i]}" >/dev/null 2>&1; then
            warn "Signing key missing: ${FM_SOFTWARE_KEYS[$i]}"
            failed=1
        fi
    done

    # Web apps — disabled with the category above. Would check that each
    # selected app has a .desktop and that its Icon= resolves (the fetched
    # file, or the `opera` fallback).
    # if [[ "$FM_PM" != "Skip" ]]; then
    #     local slug desktop icon_ref
    #     for entry in "${PWA_APPS[@]}"; do
    #         app_name="${entry%%|*}"
    #         case ", $FM_PM," in
    #             *", $app_name,"*) ;;
    #             *) continue ;;
    #         esac
    #
    #         slug="$(printf '%s' "$app_name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-')"
    #         slug="${slug%-}"
    #         desktop="$OPERA_APP_DIR/fm-$slug.desktop"
    #
    #         if [[ ! -f "$desktop" ]]; then
    #             warn "Web app missing: $desktop"
    #             failed=1
    #             continue
    #         fi
    #
    #         icon_ref="$(sed -n 's/^Icon=//p' "$desktop" | head -n1)"
    #         if [[ -z "$icon_ref" ]]; then
    #             warn "Web app has no Icon=: $app_name"
    #             failed=1
    #         elif [[ "$icon_ref" == "opera" ]]; then
    #             :   # package-provided fallback; resolved by the icon theme
    #         elif [[ ! -s "$icon_ref" ]]; then
    #             warn "Web app icon missing: $icon_ref"
    #             failed=1
    #         fi
    #
    #         if command -v desktop-file-validate >/dev/null 2>&1 \
    #             && ! desktop-file-validate "$desktop" >/dev/null 2>&1; then
    #             warn "desktop-file-validate failed: $desktop"
    #             failed=1
    #         fi
    #     done
    # fi

    # TODO: per-block rpm -q / command -v checks for the answers above as
    # each block lands.

    if (( ${#FM_FAILED_SOFTWARE[@]} > 0 )); then
        printf '\n'
        for name in "${FM_FAILED_SOFTWARE[@]}"; do
            error "Unable to install software: \"$name\""
        done
        failed=1
    fi

    if (( failed )); then
        error "Software layer verification failed. Check warnings above."
        return 1
    fi
    success "Software layer verified."
}

ui_step
verify_software_installation
