#!/usr/bin/env bash
set -euo pipefail

# PKG: mangowm swaybg swayidle swaylock-effects swayimg slurp grim wlopm
#      xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
#      brightnessctl playerctl pavucontrol wl-clipboard cliphist [swaylock if
#      swaylock-effects is unavailable] [spice-vdagent xclip in VMs]
# REPO: terra (repos.fyralabs.com; disabled by default, enabled per-command),
#       COPR pheeef/swaylock-effects
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing mango core packages..."

# ── Hardcoded values (edit here, not inline) ──
MANGO_VERSION="0.18.2"                                  # pinned: bump deliberately
TERRA_REPO_ID="terra"
TERRA_URL="https://repos.fyralabs.com/terra\$releasever"
CONFIG_DIR="$FM_FEDORA_PATH/config/mango"

# 1. Terra repository — mango has no Fedora package and no first-party COPR.
if ! rpm -q terra-release >/dev/null 2>&1; then
    info "Adding Terra repository (bootstrap of the repo RPM only)..."
    # --nogpgcheck here applies ONLY to fetching terra-release itself.
    # Package installs below are GPG-checked and gated in step 1b.
    sudo dnf install -y --nogpgcheck \
        --repofrompath "${TERRA_REPO_ID},${TERRA_URL}" terra-release
fi

# 1a. Keep Terra out of routine `dnf upgrade`: enabled only per-command.
#     This is also why mangowm needs no `dnf versionlock` to stay pinned.
for repo_file in /etc/yum.repos.d/terra*.repo; do
    [[ -f "$repo_file" ]] || continue
    sudo sed -i -E 's/^enabled=1/enabled=0/' "$repo_file"
done
info "Terra repo disabled by default; it is enabled only when installing mango"

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

# 2. swaylock-effects (COPR) — replaces plain swaylock
enable_copr "pheeef/swaylock-effects"

# 3. Install compositor (pinned), then session/portal tools
if ! sudo dnf install -y --enablerepo='terra*' "mangowm-${MANGO_VERSION}"; then
    warn "mangowm-${MANGO_VERSION} unavailable in Terra, installing latest instead"
    warn "Re-check the version and update MANGO_VERSION in this module"
    sudo dnf install -y --enablerepo='terra*' mangowm
fi

CLIP_PKGS=(wl-clipboard cliphist)
if systemd-detect-virt --quiet 2>/dev/null; then
    CLIP_PKGS+=(spice-vdagent xclip)
fi

sudo dnf install -y --allowerasing --skip-unavailable \
    swaybg swayidle swayimg slurp grim wlopm \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
    brightnessctl playerctl pavucontrol "${CLIP_PKGS[@]}"

# 3b. Lock screen. The pheeef/swaylock-effects COPR only has builds up to
#     Fedora 41, so newer releases fall back to Fedora's plain swaylock.
if sudo dnf install -y --allowerasing swaylock-effects 2>/dev/null; then
    SWAYLOCK_CONFIG="image=$HOME/Pictures/wallpapers/nordic-wp.png
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
key-hl-color=7aa2f7
text-clear=
text-ver=Verifying...
text-wrong=Wrong
"
else
    warn "swaylock-effects has no build for this Fedora release; using plain swaylock"
    sudo dnf install -y swaylock
    SWAYLOCK_CONFIG="color=1e1e1e
indicator
indicator-radius=60
indicator-thickness=4
ring-color=7aa2f7
inside-color=1e1e1e
line-color=1e1e1e
key-hl-color=7aa2f7
text-color=ffffff
"
fi

command -v mango >/dev/null 2>&1 || { error "mango binary not found after install"; return 1; }
success "mangowm $(rpm -q --qf '%{VERSION}' mangowm) installed"

# 4. Configs. theme.conf is sourced by config.conf, so write it first.
write_config_ensure "$HOME/.config/mango/theme.conf" "$(cat "$CONFIG_DIR/theme.conf")"
write_config_ensure "$HOME/.config/mango/config.conf" "$(cat "$CONFIG_DIR/config.conf")"

# 5. XDG portals — screen sharing via wlr, everything else via gtk
write_config_ensure "$HOME/.config/xdg-desktop-portal/mango-portals.conf" "[preferred]
default=gtk
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.Screenshot=wlr
"

# 6. Lock screen config (chosen in step 3b)
write_config_ensure "$HOME/.config/swaylock/config" "$SWAYLOCK_CONFIG"

# 7. environment.d for systemd/user services (all GPUs)
mkdir -p "$HOME/.config/environment.d"

# 7a. Retire the old sway env file: environment.d is applied across the whole
#     session, so a leftover sway.conf would override XDG_CURRENT_DESKTOP=mango.
if [[ -f "$HOME/.config/environment.d/sway.conf" ]]; then
    mv "$HOME/.config/environment.d/sway.conf" "$HOME/.config/environment.d/sway.conf.bak"
    info "Retired environment.d/sway.conf (backed up as .bak)"
fi
write_config_if_missing "$HOME/.config/environment.d/mango.conf" "QT_QPA_PLATFORM=wayland
XDG_CURRENT_DESKTOP=mango
XDG_SESSION_DESKTOP=mango
QT_QPA_PLATFORMTHEME=qt5ct
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
"

# 8. NVIDIA-specific env vars (only if NVIDIA GPU detected).
#    Guarded so re-running install.sh doesn't append the block twice.
if lspci | grep -qi nvidia; then
    if grep -q '^# NVIDIA (auto-detected)$' "$HOME/.config/environment.d/mango.conf" 2>/dev/null; then
        info "NVIDIA env vars already present"
    else
        info "NVIDIA GPU detected, adding NVIDIA env vars..."
        cat >> "$HOME/.config/environment.d/mango.conf" <<'EOF'

# NVIDIA (auto-detected)
LIBVA_DRIVER_NAME=nvidia
__GLX_VENDOR_LIBRARY_NAME=nvidia
GBM_BACKEND=nvidia-drm
__GL_GSYNC_ALLOWED=0
__GL_VRR_ALLOWED=0
EOF
    fi
fi

# 9. Wallpaper
mkdir -p "$HOME/Pictures/wallpapers"
WALLPAPER_SRC="$FM_FEDORA_PATH/assets/nordic-wp.png"
WALLPAPER_DEST="$HOME/Pictures/wallpapers/nordic-wp.png"
if [[ -f "$WALLPAPER_SRC" && ! -f "$WALLPAPER_DEST" ]]; then
    cp "$WALLPAPER_SRC" "$WALLPAPER_DEST"
    info "Installed default wallpaper"
fi

# ── Verification ──
verify_mango_install() {
    info "Verifying mango installation..."

    local failed=0

    for pkg in mangowm swaybg swayidle swayimg slurp grim wlopm \
               xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
               brightnessctl playerctl pavucontrol wl-clipboard cliphist; do
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            warn "Package missing: $pkg"
            failed=1
        fi
    done

    if ! command -v mango >/dev/null 2>&1; then
        warn "mango binary not found"
        failed=1
    fi
    if ! command -v mmsg >/dev/null 2>&1; then
        warn "mmsg (mango IPC client) not found"
        failed=1
    fi

    # mango ships its own session entry — no desktop-file hack needed
    if [[ ! -s /usr/share/wayland-sessions/mango.desktop ]]; then
        warn "mango.desktop missing (GDM won't list Mango)"
        failed=1
    fi

    if [[ ! -f "$HOME/.config/mango/config.conf" ]]; then
        warn "Config missing: $HOME/.config/mango/config.conf"
        failed=1
    fi
    if [[ ! -f "$HOME/.config/mango/theme.conf" ]]; then
        warn "Theme missing: $HOME/.config/mango/theme.conf"
        failed=1
    fi
    if [[ ! -f "$HOME/.config/xdg-desktop-portal/mango-portals.conf" ]]; then
        warn "Portal config missing"
        failed=1
    fi

    # Offline config validation (replaces `sway -c ... -C`)
    if command -v mango >/dev/null 2>&1; then
        if ! mango -c "$HOME/.config/mango/config.conf" -p >/dev/null 2>&1; then
            warn "mango config check failed — run: mango -c ~/.config/mango/config.conf -p"
            failed=1
        fi
    fi

    if [[ -f "$HOME/.config/sway/config" ]]; then
        info "Keeping ~/.config/sway/config for SwayFX rollback"
    fi

    if [[ $failed -eq 0 ]]; then
        success "mango core installation verified."
        info "Next: log out, then pick 'Mango' in GDM"
    else
        error "Verification failed. Check warnings above."
        return 1
    fi
}

verify_mango_install

success "mango core configured."
