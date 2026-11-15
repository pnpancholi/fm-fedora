#!/usr/bin/env bash
set -euo pipefail

# PKG: noctalia (Fedora 44+ default repos; git snapshots via lionheartp/Hyprland)
# REPO: Fedora default only — module 02 leaves Terra disabled, and Noctalia does
#       not need it.
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing Noctalia shell (Umbriel's bar, wallpaper and panels)..."

# ── Hardcoded values (edit here, not inline) ──
NOCTALIA_PKG="noctalia"
CONFIG_DIR="$FM_FEDORA_PATH/config/noctalia"
WALLPAPER_SRC="$FM_FEDORA_PATH/assets/dw.jpg"
WALLPAPER_DEST="$HOME/Pictures/wallpapers/dw.jpg"
# Vendored copy of the community "Monochrome" palette, pinned so the shell
# never has to fetch it. Format 2 JSON, both dark and light variants.
PALETTE_SRC="$CONFIG_DIR/palettes/Monochrome.json"
PALETTE_DEST="$HOME/.config/noctalia/palettes/Monochrome.json"

# Noctalia is in Fedora's own repos from 44 on; the project targets 45.
FEDORA_RELEASE="$(rpm -E %fedora)"
if [[ "$FEDORA_RELEASE" -lt 44 ]]; then
    error "Noctalia needs Fedora 44+ (this is Fedora $FEDORA_RELEASE)"
    return 1
fi

# 1. Package
if ! sudo dnf install -y "$NOCTALIA_PKG"; then
    error "Noctalia install failed — check 'dnf info noctalia' for the repo (Fedora 45+ ships it)"
    error "Fallback: sudo dnf copr enable lionheartp/Hyprland && sudo dnf install noctalia-git"
    return 1
fi

# 2. Wallpaper. Wired into config.toml as wallpaper.default.path.
mkdir -p "$HOME/Pictures/wallpapers"
if [[ ! -f "$WALLPAPER_DEST" ]]; then
    if [[ -f "$WALLPAPER_SRC" ]]; then
        cp "$WALLPAPER_SRC" "$WALLPAPER_DEST"
        info "Installed wallpaper: $WALLPAPER_DEST"
    else
        warn "Wallpaper missing: $WALLPAPER_SRC"
    fi
fi

# 3. Palette. Must exist before the shell loads config.toml, which selects it
#    with [theme] source = "custom".
if [[ ! -f "$PALETTE_SRC" ]]; then
    error "Palette missing in repo: $PALETTE_SRC"
    return 1
fi
write_config_ensure "$PALETTE_DEST" "$(cat "$PALETTE_SRC")"

# 4. Config. Declarative layer only — Noctalia's GUI-managed
#    ~/.local/state/noctalia/settings.toml still wins over this file.
write_config_ensure "$HOME/.config/noctalia/config.toml" "$(cat "$CONFIG_DIR/config.toml")"

# ── Verification ──
verify_noctalia_install() {
    info "Verifying Noctalia installation..."

    local failed=0

    if ! rpm -q "$NOCTALIA_PKG" >/dev/null 2>&1; then
        warn "Package missing: $NOCTALIA_PKG"
        failed=1
    fi

    if ! command -v noctalia >/dev/null 2>&1; then
        warn "noctalia binary not found"
        failed=1
    fi

    if [[ ! -f "$HOME/.config/noctalia/config.toml" ]]; then
        warn "Config missing: $HOME/.config/noctalia/config.toml"
        failed=1
    fi

    if [[ ! -f "$WALLPAPER_DEST" ]]; then
        warn "Wallpaper missing: $WALLPAPER_DEST"
        failed=1
    fi

    if [[ ! -f "$PALETTE_DEST" ]]; then
        warn "Palette missing: $PALETTE_DEST"
        failed=1
    fi

    # Offline config validation
    if command -v noctalia >/dev/null 2>&1; then
        if ! noctalia config validate "$HOME/.config/noctalia/config.toml" >/dev/null 2>&1; then
            warn "Noctalia config check failed — run: noctalia config validate ~/.config/noctalia/config.toml"
            failed=1
        fi
    fi

    if [[ $failed -eq 0 ]]; then
        success "Noctalia installation verified."
    else
        error "Verification failed. Check warnings above."
        return 1
    fi
}

verify_noctalia_install

success "Noctalia installed. Umbriel starts it via autostart; log out to pick it up."
