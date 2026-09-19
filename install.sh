#!/usr/bin/env bash
set -euo pipefail

FM_FEDORA_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FM_FEDORA_PATH

source "$FM_FEDORA_PATH/lib/helpers.sh"

print_banner

info "Running core setup..."
for script in "$FM_FEDORA_PATH"/install/core/*.sh; do
  info "-- $(basename "$script")"
  source "$script"
done

success "Core setup complete."
