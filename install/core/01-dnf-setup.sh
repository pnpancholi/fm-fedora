# PKG: (system packages: dnf config, rpmfusion-free-release, rpmfusion-nonfree-release)

STEP_LABEL="Preparing system packages"

ui_step
if ! grep -q "max_parallel_downloads" /etc/dnf/dnf.conf 2>/dev/null; then
  ui_exec sudo tee -a /etc/dnf/dnf.conf <<'EOF'
max_parallel_downloads=10
fastestmirror=True
EOF
fi

# RPM Fusion first: these are repo files only, safe to add in any session.
# Doing this before the upgrade means the upgrade also sees RPM Fusion packages.
ui_step
if ! dnf repolist | grep -q rpmfusion-free; then
  ui_exec sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
fi

# Full upgrade only outside a graphical session.
#
# `fm upgrade` runs this module from a terminal inside Umbriel. Upgrading there
# replaces GTK/GLib/umbriel underneath the running bar and compositor, which
# kills them mid-redraw — and the autostart entry for waybar never respawns the
# bar, so the session loses it until the next login.
#
# boot.sh is unaffected: a first install has no session, so the upgrade runs.
ui_step
if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
  warn "Graphical session detected — system upgrade skipped; run 'sudo dnf upgrade --refresh' from a TTY, then reboot"
else
  ui_exec sudo dnf upgrade -y --refresh
fi
