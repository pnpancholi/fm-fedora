#!/usr/bin/env bash
set -euo pipefail

# PKG: waybar, jetbrains-mono-fonts, nerd-fonts
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing waybar..."

# 1. Install packages (official Fedora repos)
sudo dnf install -y waybar jetbrains-mono-fonts

# 2. Install Nerd Font for Waybar icons (COPR: che/nerd-fonts)
sudo rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:che:jetbrains-mono-nerd-fonts.repo
enable_copr "che/nerd-fonts"
sudo dnf install -y nerd-fonts

# 3. Write configs from templates
CONFIG_DIR="$FM_FEDORA_PATH/config/waybar"
write_config_ensure "$HOME/.config/waybar/config.jsonc" "$(cat "$CONFIG_DIR/config.jsonc")"
write_config_ensure "$HOME/.config/waybar/style.css" "$(cat "$CONFIG_DIR/style.css")"

# 4. Verify
verify_waybar_install() {
    info "Verifying waybar installation..."
    local failed=0
    if ! rpm -q waybar >/dev/null 2>&1; then
        warn "Package missing: waybar"
        failed=1
    fi
    if ! rpm -q jetbrains-mono-fonts >/dev/null 2>&1; then
        warn "Package missing: jetbrains-mono-fonts"
        failed=1
    fi
    if ! rpm -q nerd-fonts >/dev/null 2>&1; then
        warn "Package missing: nerd-fonts"
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

    # 5. Validate config + CSS by running waybar briefly (catches parse errors like invalid properties)
    info "Validating waybar config + CSS..."
    local waybar_output
    waybar_output=$(timeout 3 waybar 2>&1 || true)
    if [[ -n "$waybar_output" ]] && grep -qiE "is not a valid property name|Failed to parse|Error loading" <<<"$waybar_output"; then
        warn "waybar config/CSS validation failed:"
        echo "$waybar_output" | head -5 | while IFS= read -r line; do warn "  $line"; done
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