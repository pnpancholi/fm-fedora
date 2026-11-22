#!/usr/bin/env bash
set -euo pipefail

FM_FEDORA_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FM_FEDORA_PATH

source "$FM_FEDORA_PATH/lib/helpers.sh"

trap fm_fail ERR

print_banner

# sudo is needed by every module. boot.sh and `fm upgrade` already keep it
# alive; a direct install.sh run starts its own keepalive here.
if [[ -z "${FM_SUDO_KEEPALIVE_PID:-}" ]]; then
    sudo -n true 2>/dev/null || sudo -v
    ( while true; do sudo -v; sleep 60; done ) &
    FM_SUDO_KEEPALIVE_PID=$!
    export FM_SUDO_KEEPALIVE_PID
fi

# One exit path: disable Terra if module 02 enabled it, then stop the sudo
# keepalive. Modules do not install their own EXIT traps.
fm_cleanup() {
    if declare -F disable_terra >/dev/null 2>&1; then
        disable_terra
    fi
    kill "${FM_SUDO_KEEPALIVE_PID:-}" 2>/dev/null || true
}
trap fm_cleanup EXIT

# Questions are saved to ~/.config/fm-fedora/install.conf. They are asked on
# every run for now, including `fm upgrade`.
ui_collect_answers

# Core modules
# Parked while the new shell layers land; re-enable each module as its Umbriel
# replacement is ready.
#    install/core/05-swaync.sh
#    install/core/07-gtklock.sh
FM_MODULES=(
    "$FM_FEDORA_PATH/install/core/01-dnf-setup.sh"
    "$FM_FEDORA_PATH/install/core/02-umbriel.sh"
    "$FM_FEDORA_PATH/install/core/03-noctalia-env.sh"
    "$FM_FEDORA_PATH/install/core/04-desktop-env.sh"
    "$FM_FEDORA_PATH/install/core/05-software-installation.sh"
)

ui_init "$(ui_count_steps "${FM_MODULES[@]}" "$FM_FEDORA_PATH/install.sh")"

# Install fm CLI and helpers to PATH
STEP_LABEL="Installing fm CLI"
ui_step
mkdir -p "$HOME/.local/bin"

# Prune symlinks left behind by tools that no longer exist in bin/
for link in "$HOME/.local/bin"/*; do
    [[ -L "$link" && ! -e "$link" ]] || continue
    case "$(readlink "$link")" in
        "$FM_FEDORA_PATH"/*) rm -f "$link" ;;
    esac
done

for f in "$FM_FEDORA_PATH"/bin/*; do
    ln -sf "$f" "$HOME/.local/bin/$(basename "$f")"
done

ui_step
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc" ]] && ! grep -q '~/.local/bin' "$rc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    fi
done

# Core modules
for script in "${FM_MODULES[@]}"; do
    source "$script"
done

ui_finish
echo
if [[ "${FM_UPGRADE:-0}" == "1" ]]; then
    success "fm-fedora upgraded."
else
    success "fm-fedora installed."
fi
