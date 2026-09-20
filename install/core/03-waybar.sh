#!/usr/bin/env bash
set -euo pipefail

# PKG: waybar
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing waybar..."

# 1. Install package (official Fedora repo)
sudo dnf install -y waybar

# 2. Write configs from templates
CONFIG_DIR="$FM_FEDORA_PATH/config/waybar"
write_config_if_missing "$HOME/.config/waybar/config.jsonc" "$(cat "$CONFIG_DIR/config.jsonc")"
write_config_if_missing "$HOME/.config/waybar/style.css" "$(cat "$CONFIG_DIR/style.css")"

# 3. Verify
verify_waybar_install() {
    info "Verifying waybar installation..."
    local failed=0
    if ! rpm -q waybar >/dev/null 2>&1; then
        warn "Package missing: waybar"
        failed=1
    fi
    if [[ ! -f "$HOME/.config/waybar/config.jsonc" ]]; then
        warn "Config missing: config.jsonc"
        failed=1
    fi
    if [[ ! -f "$HOME/.config/waybar/style.css" ]]; then
        warn "Config missing: style.css"
        failed=1
    fi
    if ! waybar --version >/dev/null 2>&1; then
        warn "waybar binary not working"
        failed=1
    fi
    if [[ $failed -eq 0 ]]; then
        success "waybar verified."
    else
        return 1
    fi
}

verify_waybar_install

success "waybar configured."