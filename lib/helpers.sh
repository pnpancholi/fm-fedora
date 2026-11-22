#!/usr/bin/env bash

c_reset="\033[0m"
c_brand="\033[38;2;220;20;60m"   # crimson
c_dim="\033[2m"

# for logging colors
c_info="\033[1;34m"; c_ok="\033[1;32m"; c_warn="\033[1;33m"; c_err="\033[1;31m"

info() {
    if (( ${FM_UI_ACTIVE:-0} )); then
        return 0
    fi
    echo -e "${c_info}==>${c_reset} $*"
}

success() {
    if (( ${FM_UI_ACTIVE:-0} )); then
        return 0
    fi
    echo -e "${c_ok}✔${c_reset} $*"
}

warn() {
    FM_UI_WARN_COUNT=$(( ${FM_UI_WARN_COUNT:-0} + 1 ))
    if (( ${FM_UI_ACTIVE:-0} )); then
        ui_note "${c_warn}⚠${c_reset} $*"
    else
        echo -e "${c_warn}⚠${c_reset} $*"
    fi
}

error() {
    if (( ${FM_UI_ACTIVE:-0} )); then
        ui_note "${c_err}✖${c_reset} $*"
    else
        echo -e "${c_err}✖${c_reset} $*" >&2
    fi
}

print_banner() {
    printf '\n%s  fm-fedora%s — your Fedora box, set up your way.\n\n' \
        "$c_brand" "$c_reset"
}

write_config_if_missing() {
    local dest="$1"
    local content="$2"
    if [[ ! -f "$dest" ]]; then
        mkdir -p "$(dirname "$dest")"
        printf "%s\n" "$content" > "$dest"
        info "Created config: $dest"
    fi
}

write_config_ensure() {
    local dest="$1"
    local expected_content="$2"

    if [[ ! -f "$dest" ]]; then
        mkdir -p "$(dirname "$dest")"
        printf "%s\n" "$expected_content" > "$dest"
        info "Created config: $dest"
        return
    fi

    local current_content
    current_content="$(cat "$dest")"
    if [[ "$current_content" != "$expected_content" ]]; then
        mkdir -p "$(dirname "$dest")"
        printf "%s\n" "$expected_content" > "$dest"
        info "Updated config: $dest"
    fi
}

enable_copr() {
    local copr_name="$1"
    local repo_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${copr_name//\//:}.repo"
    if [[ -f "$repo_file" ]]; then
        info "COPR already enabled: $copr_name"
    else
        ui_exec sudo dnf copr enable -y "$copr_name"
    fi
}

# shellcheck source=lib/installer-ui.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/installer-ui.sh"
