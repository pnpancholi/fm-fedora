#!/usr/bin/env bash
set -euo pipefail

FM_FEDORA_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FM_FEDORA_PATH

source "$FM_FEDORA_PATH/lib/helpers.sh"

print_banner

# Install fm CLI and helpers to PATH
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

# Ensure ~/.local/bin in PATH
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc" ]] && ! grep -q '~/.local/bin' "$rc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    fi
done

info "fm CLI installed. Restart shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\""

# Core modules
# Parked while the compositor switch settles; re-enable as the new shell layers
# land. 02-mango.sh is also parked so the old session can be restored by
# swapping it back in for 02-umbriel.sh.
#    install/core/02-mango.sh
#    install/core/03-waybar.sh
#    install/core/04-ghostty.sh
#    install/core/05-swaync.sh
#    install/core/06-vicinae.sh
#    install/core/07-gtklock.sh
for script in \
    "$FM_FEDORA_PATH"/install/core/01-dnf-setup.sh \
    "$FM_FEDORA_PATH"/install/core/02-umbriel.sh; do
    info "-- $(basename "$script")"
    source "$script"
done

success "Core setup complete."