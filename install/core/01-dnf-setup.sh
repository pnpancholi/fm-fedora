if ! grep -q "max_parallel_downloads" /etc/dnf/dnf.conf 2>/dev/null; then
  info "Tuning dnf for faster downloads..."
  sudo tee -a /etc/dnf/dnf.conf > /dev/null <<'EOF'
max_parallel_downloads=10
fastestmirror=True
EOF
fi

info "Refreshing and upgrading system packages (this can take a while)..."
sudo dnf upgrade -y --refresh

if ! dnf repolist | grep -q rpmfusion-free; then
  info "Enabling RPM Fusion (free + nonfree)..."
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
fi
