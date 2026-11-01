#!/usr/bin/env bash
set -euo pipefail

# PKG: gtklock
# gtklock is in the official Fedora repos (4.0.0 on F44/F45): GTK3, PAM,
# ext-session-lock. It provides the clock/date/username UI that swaylock lacks.
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing gtklock lock screen..."

CONFIG_DIR="$FM_FEDORA_PATH/config/gtklock"
LOCK_WALLPAPER_SRC="$FM_FEDORA_PATH/assets/nordic-wp-lock.jpg"
LOCK_WALLPAPER_DEST="$HOME/Pictures/wallpapers/nordic-wp-lock.jpg"
LOCK_USER="$(id -un)"

# 1. Package (official Fedora repo)
sudo dnf install -y gtklock

# 2. Lock background. The asset is pre-blurred/dimmed in the repo so the
#    installer needs no image tooling.
mkdir -p "$HOME/Pictures/wallpapers"
if [[ ! -f "$LOCK_WALLPAPER_DEST" ]]; then
    if [[ -f "$LOCK_WALLPAPER_SRC" ]]; then
        cp "$LOCK_WALLPAPER_SRC" "$LOCK_WALLPAPER_DEST"
        info "Installed lock wallpaper"
    else
        warn "Lock wallpaper missing: $LOCK_WALLPAPER_SRC"
    fi
fi

# 3. Configs. gtklock does not expand ~ in config values, so substitute
#    $HOME and the current username before writing the files.
mkdir -p "$HOME/.config/gtklock"

# Write the files config.ini points at first, so a failed install never
# leaves gtklock configured with a missing layout or stylesheet.
LAYOUT_CONTENT="$(cat "$CONFIG_DIR/layout.xml")"
LAYOUT_CONTENT="${LAYOUT_CONTENT//@USER@/$LOCK_USER}"
write_config_ensure "$HOME/.config/gtklock/layout.xml" "$LAYOUT_CONTENT"

write_config_ensure "$HOME/.config/gtklock/style.css" "$(cat "$CONFIG_DIR/style.css")"

CONFIG_CONTENT="$(cat "$CONFIG_DIR/config.ini")"
CONFIG_CONTENT="${CONFIG_CONTENT//@HOME@/$HOME}"
write_config_ensure "$HOME/.config/gtklock/config.ini" "$CONFIG_CONTENT"

# 4. PAM service. The Fedora package ships /etc/pam.d/gtklock; refuse to
#    continue silently if it is missing.
if [[ ! -f /etc/pam.d/gtklock ]]; then
    error "PAM service /etc/pam.d/gtklock is missing"
    error "Reinstall gtklock: sudo dnf reinstall gtklock"
    return 1
fi

# 5. Verification
verify_gtklock_install() {
    info "Verifying gtklock installation..."
    local failed=0

    if ! rpm -q gtklock >/dev/null 2>&1; then
        warn "Package missing: gtklock"
        failed=1
    fi
    if ! command -v gtklock >/dev/null 2>&1; then
        warn "gtklock binary not found"
        failed=1
    elif ! gtklock --version >/dev/null 2>&1; then
        warn "gtklock --version failed"
        failed=1
    fi
    if [[ ! -f /etc/pam.d/gtklock ]]; then
        warn "PAM service missing: /etc/pam.d/gtklock"
        failed=1
    fi

    for file in \
        "$HOME/.config/gtklock/config.ini" \
        "$HOME/.config/gtklock/layout.xml" \
        "$HOME/.config/gtklock/style.css"; do
        if [[ ! -f "$file" ]]; then
            warn "Config missing: $file"
            failed=1
        fi
    done

    if [[ ! -f "$LOCK_WALLPAPER_DEST" ]]; then
        warn "Lock wallpaper missing: $LOCK_WALLPAPER_DEST"
        failed=1
    fi

    if grep -q '@HOME@' "$HOME/.config/gtklock/config.ini" 2>/dev/null; then
        warn "gtklock config still contains @HOME@ placeholder"
        failed=1
    fi
    if grep -q '@USER@' "$HOME/.config/gtklock/layout.xml" 2>/dev/null; then
        warn "gtklock layout still contains @USER@ placeholder"
        failed=1
    fi

    # Layout is GTK Builder XML. Validate it when a parser is available;
    # the real acceptance test is locking the session.
    if command -v gtk-builder-tool >/dev/null 2>&1; then
        if ! gtk-builder-tool validate "$HOME/.config/gtklock/layout.xml" >/dev/null 2>&1; then
            warn "gtklock layout validation failed"
            failed=1
        fi
    elif command -v xmllint >/dev/null 2>&1; then
        if ! xmllint --noout "$HOME/.config/gtklock/layout.xml" >/dev/null 2>&1; then
            warn "gtklock layout is not well-formed XML"
            failed=1
        fi
    fi

    if [[ $failed -eq 0 ]]; then
        success "gtklock verified."
        info "Lock with SUPER+Escape, or let swayidle lock after 5 minutes."
    else
        error "Verification failed. Check warnings above."
        return 1
    fi
}

verify_gtklock_install

success "gtklock configured."
