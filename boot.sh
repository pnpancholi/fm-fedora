#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/pnpancholi/fm-fedora.git"
REPO_BRANCH="main"
INSTALL_DIR="${FM_FEDORA_HOME:-$HOME/.local/share/fm-fedora}"

echo "==> fm-fedora bootstrap"

if [ "$(id -u)" -eq 0 ]; then
  echo "Please run this as your normal user, not root. It will ask for sudo when needed." >&2
  exit 1
fi

sudo -v
( while true; do sudo -v; sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

if ! command -v git >/dev/null 2>&1; then
  echo "==> Installing git..."
  sudo dnf install -y git
fi

if [ -d "$INSTALL_DIR/.git" ]; then
  echo "==> Existing install found, updating..."
  git -C "$INSTALL_DIR" fetch --quiet origin "$REPO_BRANCH"
  git -C "$INSTALL_DIR" reset --hard --quiet "origin/$REPO_BRANCH"
else
  echo "==> Cloning fm-fedora to $INSTALL_DIR..."
  git clone --quiet --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

exec bash "$INSTALL_DIR/install.sh" < /dev/tty
