#!/usr/bin/env bash
set -euo pipefail

# User software layer: acts on the answers collected by ui_collect_answers
# (dock / password manager / dev intent), plus the General Software categories.
# Answers are saved to ~/.config/fm-fedora/install.conf and sourced before
# every module, so they are always set by the time we get here.
#
# PKG: google-chrome-stable (Google RPM repo), opera-stable (Opera RPM repo),
#      obsidian (COPR: kmf/Obsidian), blip (official tarball installer — no RPM)
# REPO: Fedora default + vendor repos written by this module (left enabled),
#       plus the kmf/Obsidian COPR (left enabled — see ADR-007)
source "$FM_FEDORA_PATH/lib/helpers.sh"

STEP_LABEL="Installing user software"

# ── Hardcoded values (edit here, not inline) ──

# Chrome: Google's own RPM repo. Not in Fedora or RPM Fusion.
# Key: Google, Inc. (Linux Package Signing Authority)
#       EB4C 1BFD 4F04 2F6D DDCC EC91 7721 F63B D38B 4796
CHROME_REPO_ID="google-chrome"
CHROME_REPO_FILE="/etc/yum.repos.d/google-chrome.repo"
CHROME_BASEURL="https://dl.google.com/linux/chrome/rpm/stable/x86_64"
CHROME_GPGKEY="https://dl.google.com/linux/linux_signing_key.pub"
CHROME_KEY_FP="EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796"
CHROME_PKG="google-chrome-stable"
CHROME_BIN="google-chrome"

# Opera: Opera's own RPM repo. Not in Fedora or RPM Fusion.
# Key: Opera Software Archive Automatic Signing Key 2025
#       6C86 BE21 4648 3766 80CA 957B 11EE 8C00 B693 A745
#       expires 2027-05-19 — re-pin here if Opera rotates it again.
OPERA_REPO_ID="opera"
OPERA_REPO_FILE="/etc/yum.repos.d/opera.repo"
OPERA_BASEURL="https://rpm.opera.com/rpm"
OPERA_GPGKEY="https://rpm.opera.com/rpmrepo.key"
OPERA_KEY_FP="6C86BE214648376680CA957B11EE8C00B693A745"
OPERA_PKG="opera-stable"
OPERA_BIN="opera"

# Obsidian: no official Fedora RPM exists. Terra shipped one for a few hours
# on 2026-08-09 and removed it the same day across every branch over
# redistribution terms, so the only RPM route left is the kmf COPR, which
# repackages the official GitHub tarball on Fedora's own build infrastructure
# (ADR-007). It ships the .desktop file itself, including the
# x-scheme-handler/obsidian registration, so there is nothing for us to write.
# Since 1.13.6-2 the basename matches the Wayland app_id
# (md.obsidian.Obsidian.desktop); older builds shipped obsidian.desktop.
OBSIDIAN_COPR="kmf/Obsidian"
OBSIDIAN_PKG="obsidian"
OBSIDIAN_BIN="obsidian"
OBSIDIAN_DESKTOP="/usr/share/applications/md.obsidian.Obsidian.desktop"
OBSIDIAN_DESKTOP_LEGACY="/usr/share/applications/obsidian.desktop"

# Blip: no Fedora RPM exists and no COPR builds one, so the only route the
# vendor supports on Fedora is its own installer script — the "Other" tab on
# blip.net/download/linux (ADR-008). The script runs as the normal user
# (it refuses root, so no sudo here), unpacks to ~/.local/opt/blip, symlinks
# ~/.local/bin/blip and writes the .desktop itself. It is idempotent: a re-run
# upgrades to the latest release and refuses to touch anything it does not own,
# so `fm upgrade` keeps Blip current without a repo of ours.
BLIP_INSTALL_URL="https://static.blip.net/linux/install.sh"
BLIP_APP_DIR="$HOME/.local/opt/blip"
BLIP_BIN_LINK="$HOME/.local/bin/blip"
BLIP_DESKTOP="$HOME/.local/share/applications/net.blip.Blip.desktop"

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

# rpm_has_key <fingerprint>
#
# True when the vendor key is in rpm's keyring. rpm 6 (Fedora 45+) records the
# full fingerprint in the gpg-pubkey VERSION field; rpm 4 recorded only the
# last 8 hex digits. Match either form exactly — a substring grep would accept
# any fingerprint that merely happens to contain those digits.
rpm_has_key() {
    local fp versions
    fp="$(printf '%s' "$1" | tr 'A-F' 'a-f')"
    versions="$(rpm -q gpg-pubkey --qf '%{VERSION}\n' 2>/dev/null || true)"
    grep -qxF -- "$fp" <<<"$versions" \
        || grep -qxF -- "${fp: -8}" <<<"$versions"
}

# ── Vendor repo helper ──
#
# add_vendor_repo <name> <repo_file> <repo_id> <baseurl> <gpgkey_url>
#                 <key_fp> <pkg> <bin>
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
    local gpgkey_url="$5" key_fp="$6" pkg="$7" bin="$8"

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
    FM_SOFTWARE_KEYS+=("$key_fp")
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
#   c. Notes (Obsidian)
#   d. File sharing (Blip)
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
    "$CHROME_BASEURL" "$CHROME_GPGKEY" "$CHROME_KEY_FP" \
    "$CHROME_PKG" "$CHROME_BIN"

ui_step
add_vendor_repo "Opera" "$OPERA_REPO_FILE" "$OPERA_REPO_ID" \
    "$OPERA_BASEURL" "$OPERA_GPGKEY" "$OPERA_KEY_FP" \
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

# ── c. Notes ──
# Obsidian. enable_copr_try rather than enable_copr: the COPR publishes one
# chroot per Fedora release and does not build for all of them, so a missing
# chroot degrades to a recorded failure instead of an abort — the same
# treatment Ghostty gets in module 04.
#
# The flag is what the verify pass keys off, so an unavailable COPR never
# makes the module fail on checks it never attempted.
ui_step
FM_OBSIDIAN_ATTEMPTED=0
if enable_copr_try "$OBSIDIAN_COPR"; then
    FM_OBSIDIAN_ATTEMPTED=1
    if ! ui_exec sudo dnf install -y "$OBSIDIAN_PKG"; then
        # Recorded before the verify pass so a failed install still lands in
        # the end-of-run summary, exactly like the browsers above.
        fm_record_failure "Obsidian"
    fi
else
    fm_record_failure "Obsidian"
fi

# ── d. File sharing ──
# Blip, from the vendor's own installer (ADR-008): no Fedora RPM, no COPR,
# and the store routes (Flatpak/Snap) were rejected in favour of the path
# blip.net/download/linux documents for "other" distros.
#
# Piping curl to bash is deliberate and mitigated upstream: HTTPS, a SHA-256
# check against latest.json before anything is extracted, and a hard refusal
# to overwrite an install or .desktop entry it does not own. The script dies
# if run as root, so it must NOT be wrapped in sudo.
#
# FM_BLIP_ATTEMPTED marks the category as run, so the verify pass reports a
# failed install instead of passing silently on a category that never ran.
ui_step
FM_BLIP_ATTEMPTED=1
# bash -o pipefail: without it a failed curl leaves an empty script and bash
# exits 0, so a dead network would read as a successful install.
if ! ui_exec bash -o pipefail -c "curl -fsSL '$BLIP_INSTALL_URL' | bash"; then
    # Recorded before the verify pass so a failed install lands in the
    # end-of-run summary, exactly like the browsers and Obsidian above.
    fm_record_failure "Blip"
fi

# Best effort: the installer writes ~/.local/share/applications itself but
# does not refresh the desktop database, so the launcher entry can lag until
# the next session. The file is already on disk either way.
if command -v update-desktop-database >/dev/null 2>&1; then
    ui_exec update-desktop-database "$HOME/.local/share/applications" || true
fi

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
        if ! rpm_has_key "${FM_SOFTWARE_KEYS[$i]}"; then
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

    # Obsidian — only checked when the Notes category above actually reached
    # the install, so a COPR that never enabled is reported once, by
    # fm_record_failure, and not again here.
    if (( ${FM_OBSIDIAN_ATTEMPTED:-0} )); then
        if ! rpm -q "$OBSIDIAN_PKG" >/dev/null 2>&1; then
            warn "Package missing: $OBSIDIAN_PKG"
            failed=1
        fi
        if ! command -v "$OBSIDIAN_BIN" >/dev/null 2>&1; then
            warn "Binary missing: $OBSIDIAN_BIN"
            failed=1
        fi
        # The RPM ships this itself — it is also what registers the
        # obsidian:// URI handler for the launcher. 1.13.6-2 renamed the file
        # to md.obsidian.Obsidian.desktop; accept the older name too.
        if [[ ! -f "$OBSIDIAN_DESKTOP" && ! -f "$OBSIDIAN_DESKTOP_LEGACY" ]]; then
            warn "Desktop entry missing: $OBSIDIAN_DESKTOP"
            failed=1
        fi
    fi

    # Blip — checked whenever the File sharing category above ran, which is
    # every install. Path checks rather than `command -v blip`: ~/.local/bin
    # only reaches PATH through the rc files install.sh appends to, so it may
    # not be exported in this shell yet.
    if (( ${FM_BLIP_ATTEMPTED:-0} )); then
        if [[ ! -x "$BLIP_APP_DIR/bin/blip" ]]; then
            warn "Binary missing: $BLIP_APP_DIR/bin/blip"
            failed=1
        fi
        # The PATH entry install.sh's rc additions rely on.
        if [[ ! -L "$BLIP_BIN_LINK" ]]; then
            warn "Launcher link missing: $BLIP_BIN_LINK"
            failed=1
        fi
        # Written by the installer; absent means the app dir is not its work.
        if [[ ! -f "$BLIP_APP_DIR/.blip-tarball-install" ]]; then
            warn "Install marker missing: $BLIP_APP_DIR/.blip-tarball-install"
            failed=1
        fi
        if [[ ! -f "$BLIP_DESKTOP" ]]; then
            warn "Desktop entry missing: $BLIP_DESKTOP"
            failed=1
        fi
    fi

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
