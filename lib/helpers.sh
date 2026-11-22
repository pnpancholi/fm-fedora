#!/usr/bin/env bash

# Real escape bytes, not literal backslash sequences: these are passed through
# printf %s arguments, which do not interpret escapes.
c_reset=$'\033[0m'
c_brand=$'\033[38;2;167;139;250m'   # violet
c_dim=$'\033[2m'

# for logging colors
c_info=$'\033[1;34m'; c_ok=$'\033[1;32m'; c_warn=$'\033[1;33m'; c_err=$'\033[1;31m'

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
        # During an install the reason belongs in the log: install.sh's ERR
        # trap reports the failure as a single line on screen.
        mkdir -p "$(dirname "${FM_UI_LOG:-$PWD/install.log}")" 2>/dev/null || true
        printf 'error: %s\n' "$*" >> "${FM_UI_LOG:-$PWD/install.log}" 2>/dev/null || true
    else
        echo -e "${c_err}✖${c_reset} $*" >&2
    fi
}

# One line for any failure: install.sh and `fm upgrade` install this as an ERR
# trap, so the user never sees a command dump — the details go to $FM_UI_LOG.
fm_fail() {
    printf '\r\033[2K%s✖ Installation failed.%s\n' "$c_err" "$c_reset" >&2
    exit 1
}

print_banner() {
    # Callers stack (bin/fm sources install.sh), so print only once per run.
    if (( ${FM_BANNER_SHOWN:-0} )); then
        return 0
    fi
    FM_BANNER_SHOWN=1
    printf '\n%sfm-fedora%s — your Fedora box, set up your way.\n\n' \
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

# Same as enable_copr, but a failure is logged quietly and returned to the
# caller instead of printing the red "command failed" block. For optional
# packages (e.g. Ghostty) whose COPR does not build on every Fedora release.
enable_copr_try() {
    local copr_name="$1"
    local repo_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${copr_name//\//:}.repo"
    if [[ -f "$repo_file" ]]; then
        info "COPR already enabled: $copr_name"
        return 0
    fi
    ui_exec_quiet sudo dnf copr enable -y "$copr_name"
}

# shellcheck source=lib/installer-ui.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/installer-ui.sh"
