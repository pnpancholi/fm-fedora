# PKG: (system packages: dnf config, rpmfusion-free-release, rpmfusion-nonfree-release)

# Set to 1 whenever the full system upgrade is skipped, so `fm upgrade` can
# tell the user what it did not do. Reset every run.
FM_SYSTEM_UPGRADE_SKIPPED=0

if ! grep -q "max_parallel_downloads" /etc/dnf/dnf.conf 2>/dev/null; then
  info "Tuning dnf for faster downloads..."
  sudo tee -a /etc/dnf/dnf.conf > /dev/null <<'EOF'
max_parallel_downloads=10
fastestmirror=True
EOF
fi

# RPM Fusion first: these are repo files only, safe to add in any session.
# Doing this before the upgrade means the upgrade also sees RPM Fusion packages.
if ! dnf repolist | grep -q rpmfusion-free; then
  info "Enabling RPM Fusion (free + nonfree)..."
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
fi

# Full upgrade only outside a graphical session.
#
# `fm upgrade` runs this module from a terminal inside Mango. Upgrading there
# replaces GTK/GLib/mangowm underneath the running bar and compositor, which
# kills them mid-redraw — and `exec_once=waybar` in the mango config never
# respawns the bar, so the session loses it until the next login.
#
# boot.sh is unaffected: a first install has no session, so the upgrade runs.
if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
  FM_SYSTEM_UPGRADE_SKIPPED=1
  warn "Graphical session detected — skipping full system upgrade"
  warn "Replacing GTK/compositor libraries under a live session kills the bar"
  warn "Run 'sudo dnf upgrade --refresh' from a TTY, then reboot"
else
  info "Refreshing and upgrading system packages (this can take a while)..."
  sudo dnf upgrade -y --refresh
fi
