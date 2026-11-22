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
    trap fm_fail ERR

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
    FM_SUDO_KEEPALIVE_PID=$!
    export FM_SUDO_KEEPALIVE_PID
    trap 'kill "${FM_SUDO_KEEPALIVE_PID:-}" 2>/dev/null' EXIT

    git -C "$FM_FEDORA_PATH" pull --quiet
    FM_UPGRADE=1
    source "$FM_FEDORA_PATH/install.sh"
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