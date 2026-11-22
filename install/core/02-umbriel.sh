#!/usr/bin/env bash
set -euo pipefail

# PKG: umbriel-nightly xdg-desktop-portal-umbriel-nightly
#      xdg-desktop-portal xdg-desktop-portal-gtk
# REPO: terra (repos.fyralabs.com; enabled for this install, disabled after)
source "$FM_FEDORA_PATH/lib/helpers.sh"

STEP_LABEL="Installing Umbriel compositor"

# ── Hardcoded values (edit here, not inline) ──
# Umbriel has no upstream releases or tags yet: every Fedora build is a git
# snapshot. Terra rebuilds this nightly, so there is no version to pin.
UMBRIEL_PKG="umbriel-nightly"
UMBRIEL_PORTAL_PKG="xdg-desktop-portal-umbriel-nightly"
TERRA_REPO_ID="terra"
TERRA_URL="https://repos.fyralabs.com/terra\$releasever"
CONFIG_DIR="$FM_FEDORA_PATH/config/umbriel"

# Terra is needed only for this install. Disable it on every exit path —
# success, handled failure, or an unexpected abort — so routine `dnf upgrade`
# keeps the installed Umbriel build pinned. install.sh's EXIT trap calls this,
# and it is idempotent because it can also be called explicitly.
FM_TERRA_DISABLED=0
disable_terra() {
    if [[ "$FM_TERRA_DISABLED" == "1" ]]; then
        return 0
    fi
    FM_TERRA_DISABLED=1
    for repo_file in /etc/yum.repos.d/terra*.repo; do
        [[ -f "$repo_file" ]] || continue
        sudo sed -i -E 's/^enabled[[:space:]]*=[[:space:]]*1.*/enabled=0/' "$repo_file"
    done
}

# 1. Terra repository — Umbriel has no Fedora package.
ui_step
if ! rpm -q terra-release >/dev/null 2>&1; then
    # --nogpgcheck here applies ONLY to fetching terra-release itself.
    # Package installs below are GPG-checked and gated in step 1a.
    ui_exec sudo dnf install -y --nogpgcheck \
        --repofrompath "${TERRA_REPO_ID},${TERRA_URL}" terra-release
fi

# 1a. Gate: never install from a third-party repo that skips signature checks.
#     Terra's repo file may omit gpgcheck entirely; an absent setting inherits
#     dnf's default (gpgcheck=True), so only an explicit gpgcheck=0 blocks.
if grep -rhqE '^gpgcheck=0' /etc/yum.repos.d/terra*.repo 2>/dev/null; then
    error "Terra repo has gpgcheck=0 — refusing to install from it"
    error "Fix /etc/yum.repos.d/terra*.repo before re-running"
    disable_terra
    return 1
fi

# 2. Install compositor and its portal backend. No session tools: the shell
#    layers (Waybar, SwayNC, Ghostty, Vicinae, gtklock, …) are installed by
#    their own parked modules.
install_umbriel() {
    ui_exec sudo dnf install -y --enablerepo='terra*' \
        "$UMBRIEL_PKG" "$UMBRIEL_PORTAL_PKG" || return 1

    # xdg-desktop-portal is the front end Umbriel's backend plugs into; the GTK
    # backend covers the portals Umbriel does not implement itself.
    ui_exec sudo dnf install -y xdg-desktop-portal xdg-desktop-portal-gtk || return 1
}

ui_step
if ! install_umbriel; then
    disable_terra
    error "Umbriel installation failed — see the install log"
    return 1
fi
disable_terra

command -v umbriel >/dev/null 2>&1 || {
    disable_terra
    error "umbriel binary not found after install"
    return 1
}

# 3. Config. Umbriel never creates a user config on its own.
ui_step
write_config_ensure "$HOME/.config/umbriel/config.toml" "$(cat "$CONFIG_DIR/config.toml")"

# 4. environment.d for systemd/user services (all GPUs)
ui_step
mkdir -p "$HOME/.config/environment.d"
write_config_if_missing "$HOME/.config/environment.d/umbriel.conf" "QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=qt5ct
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
ELECTRON_OZONE_PLATFORM_HINT=auto
"

# 5. NVIDIA-specific env vars (only if NVIDIA GPU detected).
#    Guarded so re-running install.sh doesn't append the block twice.
ui_step
if lspci | grep -qi nvidia; then
    if grep -q '^# NVIDIA (auto-detected)$' "$HOME/.config/environment.d/umbriel.conf" 2>/dev/null; then
        info "NVIDIA env vars already present"
    else
        ui_exec sudo tee -a "$HOME/.config/environment.d/umbriel.conf" <<'EOF'

# NVIDIA (auto-detected)
LIBVA_DRIVER_NAME=nvidia
__GLX_VENDOR_LIBRARY_NAME=nvidia
GBM_BACKEND=nvidia-drm
__GL_GSYNC_ALLOWED=0
__GL_VRR_ALLOWED=0
EOF
    fi
fi

# ── Verification ──
verify_umbriel_install() {
    local failed=0

    for pkg in "$UMBRIEL_PKG" "$UMBRIEL_PORTAL_PKG" \
               xdg-desktop-portal xdg-desktop-portal-gtk; do
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

    if [[ $failed -ne 0 ]]; then
        error "Umbriel verification failed. Check warnings above."
        return 1
    fi
}

ui_step
verify_umbriel_install
