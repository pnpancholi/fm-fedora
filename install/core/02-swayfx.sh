#!/usr/bin/env bash
set -euo pipefail

# PKG: swayfx swaybg swayidle swaylock swayimg slurp grim xdg-desktop-portal-wlr polkit-gnome brightnessctl playerctl pavucontrol
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing swayfx core packages..."

# 1. Enable swayfx COPR (official)
enable_copr "swayfx/swayfx"

# 2. Install packages (swayfx replaces sway)
sudo dnf install -y swayfx swaybg swayidle swaylock swayimg slurp grim \
    xdg-desktop-portal-wlr polkit-gnome brightnessctl playerctl pavucontrol

info "Enabling xdg-desktop-portal-wlr..."
systemctl --user enable --now xdg-desktop-portal-wlr

# Ensure sway.desktop exists for GDM (create if swayfx package didn't provide it)
if [[ ! -f /usr/share/wayland-sessions/sway.desktop ]]; then
    info "Creating sway.desktop for GDM..."
    sudo tee /usr/share/wayland-sessions/sway.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Sway
Comment=An i3-compatible Wayland compositor
Exec=sway
Type=Application
DesktopNames=Sway
EOF
fi

CONFIG_DIR="$FM_FEDORA_PATH/config/sway"

# 3. Write main sway config
write_config_if_missing "$HOME/.config/sway/config" "$(cat "$CONFIG_DIR/config")"

# 4. Environment.d for systemd/user services
mkdir -p "$HOME/.config/environment.d"

# Universal Wayland env vars (all GPUs)
write_config_if_missing "$HOME/.config/environment.d/sway.conf" "QT_QPA_PLATFORM=wayland
XDG_CURRENT_DESKTOP=sway
XDG_SESSION_DESKTOP=sway
QT_QPA_PLATFORMTHEME=qt5ct
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
GBM_BACKEND=nvidia-drm
"

# 5. NVIDIA-specific env vars (only if NVIDIA GPU detected)
if lspci | grep -qi nvidia; then
    info "NVIDIA GPU detected, adding NVIDIA env vars..."
    cat >> "$HOME/.config/environment.d/sway.conf" <<'EOF'

# NVIDIA (auto-detected)
LIBVA_DRIVER_NAME=nvidia
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
GBM_BACKEND=nvidia-drm
__GL_GSYNC_ALLOWED=0
__GL_VRR_ALLOWED=0
EOF
fi

# 6. Create wallpapers directory (for future wallpaper URL)
mkdir -p "$HOME/Pictures/wallpapers"

# Verification
verify_swayfx_install() {
    info "Verifying swayfx installation..."

    local failed=0

    # 1. Check packages installed
    for pkg in swayfx swaybg swayidle swaylock swayimg slurp grim \
               xdg-desktop-portal-wlr polkit-gnome brightnessctl playerctl pavucontrol; do
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            warn "Package missing: $pkg"
            failed=1
        fi
    done

    # 2. Check config exists
    if [[ ! -f "$HOME/.config/sway/config" ]]; then
        warn "Config missing: $HOME/.config/sway/config"
        failed=1
    fi

    # 3. Check portal service
    if ! systemctl --user is-enabled xdg-desktop-portal-wlr >/dev/null 2>&1; then
        warn "xdg-desktop-portal-wlr not enabled"
        failed=1
    fi

    # 4. Syntax check sway config (swayfx provides sway binary)
    if command -v sway >/dev/null 2>&1; then
        if ! sway -c "$HOME/.config/sway/config" -C >/dev/null 2>&1; then
            warn "sway config syntax check failed"
            failed=1
        fi
    fi

    if [[ $failed -eq 0 ]]; then
        success "swayfx core installation verified."
        info "Next: run 'sway' from a TTY to test (Ctrl+Alt+F3, login, type 'sway')"
    else
        error "Verification failed. Check warnings above."
        return 1
    fi
}

verify_swayfx_install

success "swayfx core configured."