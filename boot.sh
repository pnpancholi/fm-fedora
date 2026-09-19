#!/usr/bin/env bash
set -euo pipefail

c_reset="\033[0m"
c_brand="\033[38;2;220;20;60m"

REPO_URL="https://github.com/pnpancholi/fm-fedora.git"
REPO_BRANCH="main"
INSTALL_DIR="${FM_FEDORA_HOME:-$HOME/.local/share/fm-fedora}"

echo -e "${c_brand}fm-fedora${c_reset} — setting up your Fedora box"
echo

if [ "$(id -u)" -eq 0 ]; then
  echo "Please run this as your normal user, not root. It will ask for sudo when needed." >&2
  exit 1
fi

echo "This will ask for your sudo password once, then handle the rest."
sudo -v
( while true; do sudo -v; sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

if ! command -v git >/dev/null 2>&1; then
  echo "Installing git..."
  sudo dnf install -y -q git
fi

if [ -d "$INSTALL_DIR/.git" ]; then
  echo "Updating existing fm-fedora install..."
  git -C "$INSTALL_DIR" fetch --quiet origin "$REPO_BRANCH"
  git -C "$INSTALL_DIR" reset --hard --quiet "origin/$REPO_BRANCH"
else
  echo "Downloading fm-fedora..."
  git clone --quiet --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

exec bash "$INSTALL_DIR/install.sh" < /dev/tty
