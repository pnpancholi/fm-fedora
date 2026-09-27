#!/usr/bin/env bash
set -euo pipefail

# PKG: swayfx swaybg swayidle swaylock swayimg slurp grim xdg-desktop-portal-wlr brightnessctl playerctl pavucontrol
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing swayfx core packages..."

# 1. Ensure sway.desktop exists for GDM (create before package install)
if [[ ! -f /usr/share/wayland-sessions/sway.desktop ]]; then
    info "Creating sway.desktop for GDM..."
    if sudo -n tee /usr/share/wayland-sessions/sway.desktop >/dev/null <<'EOF'; then
[Desktop Entry]
Name=Sway
Comment=An i3-compatible Wayland compositor
TryExec=sway
Exec=sway
Type=Application
DesktopNames=Sway
EOF
        sudo -n restorecon /usr/share/wayland-sessions/sway.desktop 2>/dev/null || true
        success "Created sway.desktop for GDM"
    else
        warn "Could not create sway.desktop non-interactively"
        warn "Run after install: fm-create-sway-desktop"
    fi
fi

# 2. Enable swayfx COPR (official)
enable_copr "swayfx/swayfx"

# 3. Install packages (swayfx replaces sway)
sudo dnf install -y --skip-unavailable swayfx swaybg swayidle swaylock swayimg slurp grim \
    xdg-desktop-portal-wlr brightnessctl playerctl pavucontrol

info "xdg-desktop-portal-wlr installed (D-Bus activated on demand)"

CONFIG_DIR="$FM_FEDORA_PATH/config/sway"

# 4. Write main sway config
write_config_if_missing "$HOME/.config/sway/config" "$(cat "$CONFIG_DIR/config")"

# 5. Environment.d for systemd/user services
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

# 6. NVIDIA-specific env vars (only if NVIDIA GPU detected)
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

# 7. Create wallpapers directory (for future wallpaper URL)
mkdir -p "$HOME/Pictures/wallpapers"

# Verification
verify_swayfx_install() {
    info "Verifying swayfx installation..."

    local failed=0

    # 1. Check packages installed
    for pkg in swayfx swaybg swayidle swaylock swayimg slurp grim \
               xdg-desktop-portal-wlr brightnessctl playerctl pavucontrol; do
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            warn "Package missing: $pkg"
            failed=1
        fi
    done

    # 2. Check sway.desktop exists and has content
    if [[ ! -f /usr/share/wayland-sessions/sway.desktop ]]; then
        warn "sway.desktop missing (GDM won't show Sway)"
        failed=1
    elif [[ ! -s /usr/share/wayland-sessions/sway.desktop ]]; then
        warn "sway.desktop is empty"
        failed=1
    fi

    # 3. Check config exists
    if [[ ! -f "$HOME/.config/sway/config" ]]; then
        warn "Config missing: $HOME/.config/sway/config"
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
