#!/usr/bin/env bash
set -euo pipefail

c_reset=$'\033[0m'
c_brand=$'\033[38;2;167;139;250m'   # violet

REPO_URL="https://github.com/pnpancholi/fm-fedora.git"
REPO_BRANCH="main"
INSTALL_DIR="${FM_FEDORA_HOME:-$HOME/.local/share/fm-fedora}"

say() { printf '  %s\n' "$*"; }

printf '\n%s  fm-fedora%s — setting up your Fedora box\n\n' "$c_brand" "$c_reset"

if [ "$(id -u)" -eq 0 ]; then
    echo "Please run this as your normal user, not root. It will ask for sudo when needed." >&2
    exit 1
fi

say "Authenticating sudo (asked once)..."
sudo -v
( while true; do sudo -v; sleep 60; done ) &
FM_SUDO_KEEPALIVE_PID=$!
export FM_SUDO_KEEPALIVE_PID
trap 'kill "${FM_SUDO_KEEPALIVE_PID:-}" 2>/dev/null' EXIT

if ! command -v git >/dev/null 2>&1; then
    say "Installing git..."
    sudo dnf install -y -q git >/dev/null 2>&1
fi

if [ -d "$INSTALL_DIR/.git" ]; then
    say "Updating fm-fedora..."
    git -C "$INSTALL_DIR" fetch --quiet origin "$REPO_BRANCH"
    git -C "$INSTALL_DIR" reset --hard --quiet "origin/$REPO_BRANCH"
else
    say "Downloading fm-fedora..."
    git clone --quiet --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

exec bash "$INSTALL_DIR/install.sh" < /dev/tty
