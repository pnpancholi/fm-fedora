#!/usr/bin/env bash
set -euo pipefail

# PKG: vicinae (COPR: scottames/vicinae)
source "$FM_FEDORA_PATH/lib/helpers.sh"

info "Installing vicinae terminal..."

# 1. Enable COPR (idempotent)
enable_copr "scottames/vicinae"

# 2. Install package
sudo dnf install -y vicinae

# 3. Write config from template
CONFIG_DIR="$FM_FEDORA_PATH/config/vicinae"
write_config_ensure "$HOME/.config/vicinae/settings.json" "$(cat "$CONFIG_DIR/settings.json")"

# 4. Verify
verify_vicinae_install() {
    info "Verifying vicinae installation..."
    local failed=0
    if ! rpm -q vicinae >/dev/null 2>&1; then
        warn "Package missing: vicinae"
        failed=1
    fi
    if [[ ! -f "$HOME/.config/vicinae/settings.json" ]]; then
        warn "Config missing"
        failed=1
    fi
    if ! vicinae version >/dev/null 2>&1; then
        warn "vicinae binary not working"
        failed=1
    fi
    if [[ $failed -eq 0 ]]; then
        success "vicinae verified."
    else
        return 1
    fi
}

verify_vicinae_install

success "vicinae configured."