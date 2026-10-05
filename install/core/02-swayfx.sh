#!/usr/bin/env bash
set -euo pipefail

# PKG: swayfx swaybg swayidle swaylock-effects swayimg slurp grim xdg-desktop-portal-wlr brightnessctl playerctl pavucontrol wl-clipboard [spice-vdagent xclip in VMs]
# COPR: swayfx/swayfx, pheeef/swaylock-effects
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing swayfx core packages..."

# 1. Ensure swayfx.desktop exists for GDM (create before package install)
if [[ ! -f /usr/share/wayland-sessions/swayfx.desktop ]]; then
    info "Creating swayfx.desktop for GDM..."
    if sudo -n tee /usr/share/wayland-sessions/swayfx.desktop >/dev/null <<'EOF'; then
[Desktop Entry]
Name=SwayFX
Comment=An i3-compatible Wayland compositor with effects
Exec=sway
Type=Application
DesktopNames=SwayFX
EOF
        sudo -n restorecon /usr/share/wayland-sessions/swayfx.desktop 2>/dev/null || true
        success "Created swayfx.desktop for GDM"
    else
        warn "Could not create swayfx.desktop non-interactively"
        warn "Run after install: fm-create-sway-desktop"
    fi
fi

# 2. Enable COPRs
enable_copr "swayfx/swayfx"
enable_copr "pheeef/swaylock-effects"

# 3. Install packages (swayfx replaces sway, swaylock-effects replaces swaylock)
CLIP_PKGS=(wl-clipboard)
if systemd-detect-virt --quiet 2>/dev/null; then
    CLIP_PKGS+=(spice-vdagent xclip)
fi
sudo dnf install -y --allowerasing --skip-unavailable swayfx swaybg swayidle swaylock-effects swayimg slurp grim \
    xdg-desktop-portal-wlr brightnessctl playerctl pavucontrol "${CLIP_PKGS[@]}"

info "xdg-desktop-portal-wlr installed (D-Bus activated on demand)"

# 3b. Verify swayfx actually replaced sway
if ! sway -v 2>&1 | grep -qi swayfx; then
    error "swayfx installation failed: 'sway' binary is not swayfx"
    error "Check COPR enable and dnf install output above"
    return 1
fi
success "swayfx confirmed as active compositor"

CONFIG_DIR="$FM_FEDORA_PATH/config/sway"

# Read theme primary color from theme.conf
THEME_PRIMARY=$(grep -E '^\s*set\s+\$theme_primary\s+' "$CONFIG_DIR/theme.conf" | head -1 | awk '{print $3}')
if [[ -z "$THEME_PRIMARY" ]]; then
    THEME_PRIMARY="#7aa2f7"  # Tokyo Night default fallback
    warn "Could not read theme color from theme.conf, using default: $THEME_PRIMARY"
fi

# 4. Write main sway config with theme substitution
sway_config_content="$(cat "$CONFIG_DIR/config")"
sway_config_content="${sway_config_content//@THEME_PRIMARY@/$THEME_PRIMARY}"
write_config_ensure "$HOME/.config/sway/config" "$sway_config_content"

# 5. Copy theme.conf for user reference/editing
write_config_ensure "$HOME/.config/sway/theme.conf" "$(cat "$CONFIG_DIR/theme.conf")"

# 6. swaylock-effects config: wallpaper + blur, clock, username, ringless input field
write_config_ensure "$HOME/.config/swaylock/config" "image=$HOME/Pictures/wallpapers/nordic-wp.png
scaling=fill
effect-blur=7x5
clock
timestr=%H:%M
datestr=$USER
text-color=ffffff
indicator
indicator-radius=60
indicator-thickness=4
ring-color=00000000
inside-color=00000088
line-color=00000000
key-hl-color=${THEME_PRIMARY#\#}
text-clear=
text-ver=Verifying...
text-wrong=Wrong
"

# 7. Environment.d for systemd/user services
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

# 8. NVIDIA-specific env vars (only if NVIDIA GPU detected)
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

# 9. Create wallpapers directory
mkdir -p "$HOME/Pictures/wallpapers"

# 10. Copy default wallpaper
WALLPAPER_SRC="$FM_FEDORA_PATH/assets/nordic-wp.png"
WALLPAPER_DEST="$HOME/Pictures/wallpapers/nordic-wp.png"
if [[ -f "$WALLPAPER_SRC" && ! -f "$WALLPAPER_DEST" ]]; then
    cp "$WALLPAPER_SRC" "$WALLPAPER_DEST"
    info "Installed default wallpaper"
fi

# Verification
verify_swayfx_install() {
    info "Verifying swayfx installation..."

    local failed=0

    # 1. Check packages installed
    for pkg in swayfx swaybg swayidle swaylock-effects swayimg slurp grim \
               xdg-desktop-portal-wlr brightnessctl playerctl pavucontrol wl-clipboard; do
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            warn "Package missing: $pkg"
            failed=1
        fi
    done

    # 2. Check swayfx.desktop exists and has content
    if [[ ! -f /usr/share/wayland-sessions/swayfx.desktop ]]; then
        warn "swayfx.desktop missing (GDM won't show SwayFX)"
        failed=1
    elif [[ ! -s /usr/share/wayland-sessions/swayfx.desktop ]]; then
        warn "swayfx.desktop is empty"
        failed=1
    fi

    # 3. Check config exists
    if [[ ! -f "$HOME/.config/sway/config" ]]; then
        warn "Config missing: $HOME/.config/sway/config"
        failed=1
    fi
    if [[ ! -f "$HOME/.config/sway/theme.conf" ]]; then
        warn "Theme config missing: $HOME/.config/sway/theme.conf"
        failed=1
    fi

    # 4. Syntax check sway config (swayfx provides sway binary)
    if command -v sway >/dev/null 2>&1; then
        if ! sway -v 2>&1 | grep -qi swayfx; then
            warn "sway binary is not swayfx (vanilla sway detected)"
            failed=1
        elif ! sway -c "$HOME/.config/sway/config" -C >/dev/null 2>&1; then
            warn "sway config syntax check failed"
            failed=1
        fi
    else
        warn "sway binary not found"
        failed=1
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
