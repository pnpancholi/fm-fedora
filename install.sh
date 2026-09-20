#!/usr/bin/env bash
set -euo pipefail

FM_FEDORA_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FM_FEDORA_PATH

source "$FM_FEDORA_PATH/lib/helpers.sh"

print_banner

# Install fm CLI to PATH
mkdir -p "$HOME/.local/bin"
ln -sf "$FM_FEDORA_PATH/bin/fm" "$HOME/.local/bin/fm"

# Ensure ~/.local/bin in PATH
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc" ]] && ! grep -q '~/.local/bin' "$rc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    fi
done

info "fm CLI installed. Restart shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\""

# Modules disabled for now — enable when ready:
# for script in "$FM_FEDORA_PATH"/install/core/*.sh; do
#   info "-- $(basename "$script")"
#   source "$script"
# done

success "Core setup complete."