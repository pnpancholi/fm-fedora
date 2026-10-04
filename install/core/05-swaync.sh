#!/usr/bin/env bash
set -euo pipefail

# PKG: SwayNotificationCenter
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing SwayNC control center..."

# 1. Install SwayNC (official Fedora repos)
sudo dnf install -y SwayNotificationCenter

# 2. Power profiles: Fedora 41+ ships tuned-ppd, which provides ppd-service
#    and conflicts with power-profiles-daemon. Reuse the existing provider.
if command -v powerprofilesctl >/dev/null 2>&1; then
    info "power-profiles-daemon already present"
elif rpm -q tuned-ppd >/dev/null 2>&1; then
    info "tuned-ppd detected (Fedora default); using it for power profiles"
    sudo systemctl enable --now tuned-ppd.service 2>/dev/null || true
elif rpm -q tlp >/dev/null 2>&1; then
    warn "TLP detected; skipping power-profiles-daemon to avoid conflict"
else
    info "Installing power-profiles-daemon..."
    if sudo dnf install -y power-profiles-daemon; then
        sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true
    else
        warn "Could not install power-profiles-daemon; battery mode toggles may not work"
    fi
fi

# 3. Stop competing notification daemons (best effort)
for daemon in mako dunst; do
    if pgrep -x "$daemon" >/dev/null 2>&1; then
        info "Stopping competing notification daemon: $daemon"
        pkill -x "$daemon" 2>/dev/null || true
    fi
done

# 4. Write configs from templates
CONFIG_DIR="$FM_FEDORA_PATH/config/swaync"
write_config_ensure "$HOME/.config/swaync/config.json" "$(cat "$CONFIG_DIR/config.json")"
write_config_ensure "$HOME/.config/swaync/style.css" "$(cat "$CONFIG_DIR/style.css")"

# 5. Verify
verify_swaync_install() {
    info "Verifying SwayNC installation..."
    local failed=0
    if ! rpm -q SwayNotificationCenter >/dev/null 2>&1; then
        warn "Package missing: SwayNotificationCenter"
        failed=1
    fi
    if ! command -v swaync >/dev/null 2>&1; then
        warn "Binary missing: swaync"
        failed=1
    fi
    if ! command -v swaync-client >/dev/null 2>&1; then
        warn "Binary missing: swaync-client"
        failed=1
    fi
    if ! command -v busctl >/dev/null 2>&1; then
        warn "Binary missing: busctl (systemd)"
        failed=1
    fi
    if [[ ! -f "$HOME/.config/swaync/config.json" ]]; then
        warn "Config missing: config.json"
        failed=1
    fi
    if [[ ! -f "$HOME/.config/swaync/style.css" ]]; then
        warn "Config missing: style.css"
        failed=1
    fi
    if [[ $failed -eq 0 ]]; then
        success "SwayNC verified."
    else
        error "Verification failed. Check warnings above."
        return 1
    fi
}

verify_swaync_install

success "SwayNC control center configured."