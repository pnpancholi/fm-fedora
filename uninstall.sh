#!/usr/bin/env bash
set -euo pipefail

FM_FEDORA_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FM_FEDORA_PATH/lib/helpers.sh"

print_banner

warn "Uninstall not yet implemented."
info "This will eventually remove: COPRs, packages, configs, services"
info "Kept: DNF tuning, RPM Fusion"