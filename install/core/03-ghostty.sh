#!/usr/bin/env bash
set -euo pipefail

# PKG: ghostty (COPR: scottames/ghostty)
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing ghostty terminal..."

# 1. Enable COPR (idempotent)
enable_copr "scottames/ghostty"

# 2. Install package
sudo dnf install -y ghostty

# 3. Write config from template
CONFIG_DIR="$FM_FEDORA_PATH/config/ghostty"
write_config_if_missing "$HOME/.config/ghostty/config" "$(cat "$CONFIG_DIR/config")"

# 4. Verify
verify_ghostty_install() {
    info "Verifying ghostty installation..."
    local failed=0
    if ! rpm -q ghostty >/dev/null 2>&1; then
        warn "Package missing: ghostty"
        failed=1
    fi
    if [[ ! -f "$HOME/.config/ghostty/config" ]]; then
        warn "Config missing"
        failed=1
    fi
    if ! ghostty --version >/dev/null 2>&1; then
        warn "ghostty binary not working"
        failed=1
    fi
    if [[ $failed -eq 0 ]]; then
        success "ghostty verified."
    else
        return 1
    fi
}

verify_ghostty_install

success "ghostty configured."