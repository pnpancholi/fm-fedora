#!/usr/bin/env bash
set -euo pipefail

# PKG: noctalia (Fedora 44+ default repos; git snapshots via lionheartp/Hyprland)
# REPO: Fedora default only — module 02 leaves Terra disabled, and Noctalia does
#       not need it.
source "$FM_FEDORA_PATH/lib/helpers.sh"

STEP_LABEL="Installing Noctalia shell"

# ── Hardcoded values (edit here, not inline) ──
NOCTALIA_PKG="noctalia"
CONFIG_DIR="$FM_FEDORA_PATH/config/noctalia"
WALLPAPER_SRC="$FM_FEDORA_PATH/assets/wp.png"
WALLPAPER_DEST="$HOME/Pictures/wallpapers/wp.png"
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
ui_step
ui_exec sudo dnf install -y "$NOCTALIA_PKG"

# 2. Wallpaper. Wired into config.toml as wallpaper.default.path.
#    Always copy so re-runs and `fm upgrade` pick up a changed source file.
ui_step
mkdir -p "$HOME/Pictures/wallpapers"
if [[ -f "$WALLPAPER_SRC" ]]; then
    if ! cmp -s "$WALLPAPER_SRC" "$WALLPAPER_DEST" 2>/dev/null; then
        cp "$WALLPAPER_SRC" "$WALLPAPER_DEST"
        info "Installed wallpaper: $WALLPAPER_DEST"
    fi
else
    warn "Wallpaper missing: $WALLPAPER_SRC"
fi

# 3. Palette. Must exist before the shell loads config.toml, which selects it
#    with [theme] source = "custom".
ui_step
if [[ ! -f "$PALETTE_SRC" ]]; then
    error "Palette missing in repo: $PALETTE_SRC"
    return 1
fi
write_config_ensure "$PALETTE_DEST" "$(cat "$PALETTE_SRC")"

# 4. Config. Declarative layer only — Noctalia's GUI-managed
#    ~/.local/state/noctalia/settings.toml still wins over this file.
ui_step
write_config_ensure "$HOME/.config/noctalia/config.toml" "$(cat "$CONFIG_DIR/config.toml")"

# ── Verification ──
verify_noctalia_install() {
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

    if [[ $failed -ne 0 ]]; then
        error "Noctalia verification failed. Check warnings above."
        return 1
    fi
}

ui_step
verify_noctalia_install
