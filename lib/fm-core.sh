#!/usr/bin/env bash

# fm-core.sh — shared functions for fm CLI

fm_usage() {
    cat <<'EOF'
Usage: fm <command>

Commands:
  upgrade    Re-run install modules (pull latest, apply changes)
  inspect    Verify system state (packages, configs, services)
  uninstall  Remove fm-fedora packages, COPRs, and configs

Run 'fm <command> --help' for more info.
EOF
}

fm_upgrade() {
    info "Upgrading fm-fedora..."
    if [[ ! -d "$FM_FEDORA_PATH/.git" ]]; then
        error "Not a git repo: $FM_FEDORA_PATH"
        exit 1
    fi

    # sudo keepalive (same as boot.sh) so module sudo commands don't fail on TTY
    if ! sudo -v; then
        error "sudo authentication failed"
        exit 1
    fi
    ( while true; do sudo -v; sleep 60; done ) &
    local sudo_keepalive_pid=$!
    trap 'kill "$sudo_keepalive_pid" 2>/dev/null' EXIT

    git -C "$FM_FEDORA_PATH" pull --quiet
    source "$FM_FEDORA_PATH/install.sh"
    success "Upgrade complete."
}

fm_inspect() {
    info "Inspecting system state..."
    warn "Not yet implemented."
}

fm_uninstall() {
    local uninstall_script="$FM_FEDORA_PATH/uninstall.sh"
    if [[ ! -f "$uninstall_script" ]]; then
        error "Uninstall script not found: $uninstall_script"
        error "Re-clone repo or run bootstrap again."
        exit 1
    fi
    exec bash "$uninstall_script" "$@"
}