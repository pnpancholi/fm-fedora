#!/usr/bin/env bash
set -euo pipefail

# PKG: umbriel-nightly xdg-desktop-portal-umbriel-nightly
#      swaybg swayidle swayimg slurp grim wlopm
#      xdg-desktop-portal xdg-desktop-portal-gtk
#      brightnessctl playerctl pavucontrol wl-clipboard cliphist
#      [spice-vdagent xclip in VMs]
# REPO: terra (repos.fyralabs.com; disabled by default, enabled per-command)
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing Umbriel core packages..."

# ── Hardcoded values (edit here, not inline) ──
# Umbriel has no upstream releases or tags yet: every Fedora build is a git
# snapshot. Terra rebuilds this nightly, so there is no version to pin. Terra
# stays disabled outside this module, so the compositor only moves when the
# installer is re-run.
UMBRIEL_PKG="umbriel-nightly"
UMBRIEL_PORTAL_PKG="xdg-desktop-portal-umbriel-nightly"
TERRA_REPO_ID="terra"
TERRA_URL="https://repos.fyralabs.com/terra\$releasever"
CONFIG_DIR="$FM_FEDORA_PATH/config/umbriel"

# 1. Terra repository — Umbriel has no Fedora package.
if ! rpm -q terra-release >/dev/null 2>&1; then
    info "Adding Terra repository (bootstrap of the repo RPM only)..."
    # --nogpgcheck here applies ONLY to fetching terra-release itself.
    # Package installs below are GPG-checked and gated in step 1b.
    sudo dnf install -y --nogpgcheck \
        --repofrompath "${TERRA_REPO_ID},${TERRA_URL}" terra-release
fi

# 1a. Keep Terra out of routine `dnf upgrade`: enabled only per-command.
for repo_file in /etc/yum.repos.d/terra*.repo; do
    [[ -f "$repo_file" ]] || continue
    sudo sed -i -E 's/^enabled=1/enabled=0/' "$repo_file"
done
info "Terra repo disabled by default; it is enabled only when installing Umbriel"

# 1b. Gate: never install from a third-party repo that skips signature checks.
if grep -rhqE '^gpgcheck=0' /etc/yum.repos.d/terra*.repo 2>/dev/null; then
    error "Terra repo has gpgcheck=0 — refusing to install from it"
    error "Fix /etc/yum.repos.d/terra*.repo before re-running"
    return 1
fi
if ! grep -rhqE '^gpgcheck=1' /etc/yum.repos.d/terra*.repo 2>/dev/null; then
    error "Terra repo does not declare gpgcheck=1 — refusing to install from it"
    error "Fix /etc/yum.repos.d/terra*.repo before re-running"
    return 1
fi

# 1c. Drop the abandoned swaylock-effects COPR and the old generated swaylock
#     config; the lock screen is gtklock (07-gtklock.sh).
sudo rm -f "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:pheeef:swaylock-effects.repo"
rm -f "$HOME/.config/swaylock/config" 2>/dev/null || true
rmdir "$HOME/.config/swaylock" 2>/dev/null || true

# 2. Install compositor and its portal backend, then session tools
sudo dnf install -y --enablerepo='terra*' "$UMBRIEL_PKG" "$UMBRIEL_PORTAL_PKG"

CLIP_PKGS=(wl-clipboard cliphist)
if systemd-detect-virt --quiet 2>/dev/null; then
    CLIP_PKGS+=(spice-vdagent xclip)
fi

# No xdg-desktop-portal-wlr: Umbriel ships its own ScreenCast/Screenshot backend.
sudo dnf install -y --allowerasing --skip-unavailable \
    swaybg swayidle swayimg slurp grim wlopm \
    xdg-desktop-portal xdg-desktop-portal-gtk \
    brightnessctl playerctl pavucontrol "${CLIP_PKGS[@]}"

# Lock screen is installed separately by 07-gtklock.sh (gtklock).
command -v umbriel >/dev/null 2>&1 || { error "umbriel binary not found after install"; return 1; }
success "Umbriel $(rpm -q --qf '%{VERSION}' "$UMBRIEL_PKG") installed"

# 3. Config. Umbriel never creates a user config on its own.
write_config_ensure "$HOME/.config/umbriel/config.toml" "$(cat "$CONFIG_DIR/config.toml")"

# 4. environment.d for systemd/user services (all GPUs)
mkdir -p "$HOME/.config/environment.d"

# 4a. Retire the old mango env file: environment.d is applied across the whole
#     session, so a leftover mango.conf would keep XDG_CURRENT_DESKTOP=mango
#     for systemd services. Umbriel owns its own session variables.
if [[ -f "$HOME/.config/environment.d/mango.conf" ]]; then
    mv "$HOME/.config/environment.d/mango.conf" "$HOME/.config/environment.d/mango.conf.bak"
    info "Retired environment.d/mango.conf (backed up as .bak)"
fi
write_config_if_missing "$HOME/.config/environment.d/umbriel.conf" "QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=qt5ct
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
ELECTRON_OZONE_PLATFORM_HINT=auto
"

# 5. NVIDIA-specific env vars (only if NVIDIA GPU detected).
#    Guarded so re-running install.sh doesn't append the block twice.
if lspci | grep -qi nvidia; then
    if grep -q '^# NVIDIA (auto-detected)$' "$HOME/.config/environment.d/umbriel.conf" 2>/dev/null; then
        info "NVIDIA env vars already present"
    else
        info "NVIDIA GPU detected, adding NVIDIA env vars..."
        cat >> "$HOME/.config/environment.d/umbriel.conf" <<'EOF'

# NVIDIA (auto-detected)
LIBVA_DRIVER_NAME=nvidia
__GLX_VENDOR_LIBRARY_NAME=nvidia
GBM_BACKEND=nvidia-drm
__GL_GSYNC_ALLOWED=0
__GL_VRR_ALLOWED=0
EOF
    fi
fi

# 6. Wallpaper
mkdir -p "$HOME/Pictures/wallpapers"
WALLPAPER_SRC="$FM_FEDORA_PATH/assets/nordic-wp.png"
WALLPAPER_DEST="$HOME/Pictures/wallpapers/nordic-wp.png"
if [[ -f "$WALLPAPER_SRC" && ! -f "$WALLPAPER_DEST" ]]; then
    cp "$WALLPAPER_SRC" "$WALLPAPER_DEST"
    info "Installed default wallpaper"
fi

# ── Verification ──
verify_umbriel_install() {
    info "Verifying Umbriel installation..."

    local failed=0

    for pkg in "$UMBRIEL_PKG" "$UMBRIEL_PORTAL_PKG" swaybg swayidle swayimg slurp grim wlopm \
               xdg-desktop-portal xdg-desktop-portal-gtk \
               brightnessctl playerctl pavucontrol wl-clipboard cliphist; do
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            warn "Package missing: $pkg"
            failed=1
        fi
    done

    if ! command -v umbriel >/dev/null 2>&1; then
        warn "umbriel binary not found"
        failed=1
    fi
    if ! command -v start-umbriel >/dev/null 2>&1; then
        warn "start-umbriel session launcher not found"
        failed=1
    fi

    # The package ships its own session entry — no desktop-file hack needed.
    if [[ ! -s /usr/share/wayland-sessions/umbriel.desktop ]]; then
        warn "umbriel.desktop missing (GDM won't list Umbriel)"
        failed=1
    fi

    if [[ ! -f "$HOME/.config/umbriel/config.toml" ]]; then
        warn "Config missing: $HOME/.config/umbriel/config.toml"
        failed=1
    fi

    # Offline config validation
    if command -v umbriel >/dev/null 2>&1; then
        if ! umbriel config validate -c "$HOME/.config/umbriel/config.toml" >/dev/null 2>&1; then
            warn "Umbriel config check failed — run: umbriel config validate -c ~/.config/umbriel/config.toml"
            failed=1
        fi
    fi

    if [[ $failed -eq 0 ]]; then
        success "Umbriel core installation verified."
        info "Next: log out, then pick 'Umbriel' in GDM"
    else
        error "Verification failed. Check warnings above."
        return 1
    fi
}

verify_umbriel_install

success "Umbriel core configured."
