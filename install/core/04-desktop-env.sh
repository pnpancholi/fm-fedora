#!/usr/bin/env bash
set -euo pipefail

# Desktop layer: the launcher (Vicinae) and the terminal (Ghostty).
#
# PKG: vicinae, ghostty (COPR: scottames/vicinae, scottames/ghostty)
# REPO: Fedora default + scottames COPRs
source "$FM_FEDORA_PATH/lib/helpers.sh"

STEP_LABEL="Installing desktop apps"

# ── Hardcoded values (edit here, not inline) ──
VICINAE_PKG="vicinae"
GHOSTTY_PKG="ghostty"
CONTROL_CENTER_PKG="gnome-control-center"
THEME_ID="monochrome"
CONFIG_DIR="$FM_FEDORA_PATH/config/vicinae"
THEME_SRC="$CONFIG_DIR/themes/${THEME_ID}.toml"
GHOSTTY_CONFIG_SRC="$FM_FEDORA_PATH/config/ghostty/config"
GHOSTTY_CONFIG_DEST="$HOME/.config/ghostty/config"

USER_THEME_DIR="$HOME/.local/share/vicinae/themes"
THEME_DEST="$USER_THEME_DIR/${THEME_ID}.toml"
SETTINGS_DEST="$HOME/.config/vicinae/settings.json"

# Memory guard rails. The values are deliberately generous for a launcher:
# most of what `systemctl --user show vicinae -p MemoryCurrent` reports is
# reclaimable page cache (file index, extension bundles), which the kernel drops
# before MemoryHigh starts throttling, so the cap only bites when anonymous
# memory actually runs away. Restart=on-failure keeps a launcher available
# after a hard cap kill instead of leaving the keybind dead.
DROPIN_DIR="$HOME/.config/systemd/user/vicinae.service.d"
DROPIN="$DROPIN_DIR/memory.conf"

# 1. COPR + package
ui_step
enable_copr "scottames/vicinae"
ui_exec sudo dnf install -y "$VICINAE_PKG"

# 2. Theme. Vicinae drops files into the user theme dir at startup and hot
#    reloads on change; the id is the filename without .toml.
ui_step
if [[ ! -f "$THEME_SRC" ]]; then
    error "Theme missing in repo: $THEME_SRC"
    return 1
fi
write_config_ensure "$THEME_DEST" "$(cat "$THEME_SRC")"

# 3. Settings. "theme.*.name = monochrome" is what actually selects the theme;
#    `vicinae theme set` writes the same key through the running server.
ui_step
write_config_ensure "$SETTINGS_DEST" "$(cat "$CONFIG_DIR/settings.json")"

# 4. Memory guard rail
ui_step
write_config_ensure "$DROPIN" "[Service]
MemoryAccounting=yes
MemoryHigh=400M
MemoryMax=512M
Restart=on-failure
RestartSec=2"

# 5. One launch path only: the user service. No autostart entry, so a second
#    daemon never ends up running beside it.
ui_step
if systemctl --user show-environment >/dev/null 2>&1; then
    ui_exec systemctl --user daemon-reload
    ui_exec systemctl --user enable vicinae.service
    # Starting needs a live user manager + session; enable alone is enough at
    # install time, the unit comes up on next login.
    systemctl --user restart vicinae.service >/dev/null 2>&1 || true
else
    warn "No systemd user manager in this environment — enable vicinae.service after login"
fi

# 6. Ghostty. Optional: the COPR does not publish builds for every Fedora
#    release, so a failure here is logged and skipped instead of aborting the
#    desktop layer with a stack of dnf errors.
ui_step
GHOSTTY_OK=0
if enable_copr_try "scottames/ghostty" && ui_exec_quiet sudo dnf install -y "$GHOSTTY_PKG"; then
    GHOSTTY_OK=1
else
    warn "Ghostty unavailable on this Fedora release — skipping (Mod+Return will have no terminal)"
fi

# 6a. GNOME Settings. Noctalia owns the bar and control centre, but the Wi-Fi,
#     Bluetooth and power rows in bin/fm-settings shell out to this binary; no
#     other active module installs it.
ui_step
ui_exec sudo dnf install -y "$CONTROL_CENTER_PKG"

# 7. Ghostty config. Colours are inline (Monochrome palette), so no theme file
#    lookup can resolve to the wrong thing.
ui_step
if (( GHOSTTY_OK )); then
    if [[ ! -f "$GHOSTTY_CONFIG_SRC" ]]; then
        error "Ghostty config missing in repo: $GHOSTTY_CONFIG_SRC"
        return 1
    fi
    write_config_ensure "$GHOSTTY_CONFIG_DEST" "$(cat "$GHOSTTY_CONFIG_SRC")"
fi

# ── Verification ──
verify_desktop_env_install() {
    local failed=0

    for pkg in "$VICINAE_PKG" "$CONTROL_CENTER_PKG"; do
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            warn "Package missing: $pkg"
            failed=1
        fi
    done

    for bin in vicinae gnome-control-center; do
        if ! command -v "$bin" >/dev/null 2>&1; then
            warn "$bin binary not found"
            failed=1
        fi
    done

    # Ghostty is optional: only verify it when its install actually ran.
    if (( GHOSTTY_OK )); then
        if ! rpm -q "$GHOSTTY_PKG" >/dev/null 2>&1; then
            warn "Package missing: $GHOSTTY_PKG"
            failed=1
        fi
        if ! command -v ghostty >/dev/null 2>&1; then
            warn "ghostty binary not found"
            failed=1
        fi
    fi

    for f in "$SETTINGS_DEST" "$THEME_DEST" "$DROPIN"; do
        if [[ ! -f "$f" ]]; then
            warn "Missing: $f"
            failed=1
        fi
    done

    if (( GHOSTTY_OK )) && [[ ! -f "$GHOSTTY_CONFIG_DEST" ]]; then
        warn "Missing: $GHOSTTY_CONFIG_DEST"
        failed=1
    fi

    if systemctl --user show-environment >/dev/null 2>&1; then
        if ! systemctl --user is-enabled --quiet vicinae.service; then
            warn "vicinae.service not enabled"
            failed=1
        fi
    fi

    if [[ $failed -ne 0 ]]; then
        error "Desktop layer verification failed. Check warnings above."
        return 1
    fi
}

ui_step
verify_desktop_env_install
