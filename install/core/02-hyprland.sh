#!/usr/bin/env bash
set -euo pipefail

# PKG: hyprland xdg-desktop-portal-hyprland hyprpaper polkit-gnome brightnessctl playerctl pavucontrol
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing Hyprland core packages..."

# Enable Hyprland COPR (required for hyprland, xdg-desktop-portal-hyprland, hyprpaper)
enable_copr "solopasha/hyprland"

sudo dnf install -y hyprland xdg-desktop-portal-hyprland hyprpaper \
    polkit-gnome brightnessctl playerctl pavucontrol

info "Enabling xdg-desktop-portal-hyprland..."
systemctl --user enable --now xdg-desktop-portal-hyprland

CONFIG_DIR="$FM_FEDORA_PATH/config/hypr"

# Write base configs
write_config_if_missing "$HOME/.config/hypr/hyprland.conf" "$(cat "$CONFIG_DIR/hyprland.conf")"
write_config_if_missing "$HOME/.config/hypr/hyprpaper.conf" "$(cat "$CONFIG_DIR/hyprpaper.conf")"

# Dynamic: NVIDIA detection -> append env vars
if lspci | grep -qi nvidia; then
    info "NVIDIA GPU detected, adding NVIDIA env vars..."
    cat >> "$HOME/.config/hypr/hyprland.conf" <<'EOF'

# NVIDIA (auto-detected)
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
env = GBM_BACKEND,nvidia-drm
EOF
fi

# Environment.d for systemd/user services
mkdir -p "$HOME/.config/environment.d"
write_config_if_missing "$HOME/.config/environment.d/hyprland.conf" "QT_QPA_PLATFORM=wayland
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_DESKTOP=Hyprland
"

# Verification
verify_hyprland_install() {
    info "Verifying Hyprland installation..."

    local failed=0

    # 1. Check packages installed
    for pkg in hyprland xdg-desktop-portal-hyprland hyprpaper polkit-gnome brightnessctl playerctl pavucontrol; do
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            warn "Package missing: $pkg"
            failed=1
        fi
    done

    # 2. Check configs exist
    for f in "$HOME/.config/hypr/hyprland.conf" "$HOME/.config/hypr/hyprpaper.conf"; do
        if [[ ! -f "$f" ]]; then
            warn "Config missing: $f"
            failed=1
        fi
    done

    # 3. Check portal service
    if ! systemctl --user is-enabled xdg-desktop-portal-hyprland >/dev/null 2>&1; then
        warn "xdg-desktop-portal-hyprland not enabled"
        failed=1
    fi

    # 4. Syntax check hyprland.conf
    if command -v hyprctl >/dev/null 2>&1; then
        if ! hyprctl -c "$HOME/.config/hypr/hyprland.conf" version >/dev/null 2>&1; then
            warn "hyprland.conf syntax check failed"
            failed=1
        fi
    fi

    if [[ $failed -eq 0 ]]; then
        success "Hyprland core installation verified."
        info "Next: run 'Hyprland' from a TTY to test (Ctrl+Alt+F3, login, type 'Hyprland')"
        info "Note: Terminal (Super+Return) and launcher (Super+R) require modules 03-ghostty.sh and 04-vicinae.sh"
    else
        error "Verification failed. Check warnings above."
        return 1
    fi
}

verify_hyprland_install

success "Hyprland core configured."