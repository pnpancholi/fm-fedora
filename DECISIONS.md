# Architecture Decision Records (ADRs)

*Last updated: 2026-09-20*

Each record follows: **Context → Decision → Consequences**

---

## ADR 001: Bash as Implementation Language

**Context:** Need a zero-dependency installer that runs on a minimal Fedora install (no Python, no Ansible).

**Decision:** Write all automation in POSIX-compatible Bash (targeting GNU Bash 4+).

**Consequences:**
- ✅ Runs everywhere Fedora runs, no extra packages
- ✅ Transparent, easy to audit and modify
- ❌ Limited data structures, error handling verbose
- ❌ No native YAML/TOML parsing (would need external tool)

---

## ADR 002: `boot.sh` Bootstrap Pattern

**Context:** Users should run a single command; the repo must self-install and self-update.

**Decision:** `boot.sh` handles:
1. Clone/update repo to `~/.local/share/fm-fedora`
2. Install `git` if missing (via `dnf`)
3. Start sudo keepalive background process
4. Exec `install.sh` from the cloned repo

**Consequences:**
- ✅ One-liner install works (`curl ... | bash`)
- ✅ Self-updating on re-run
- ✅ Sudo password prompted once
- ❌ Requires `curl` or `git` for initial fetch
- ❌ Background sudo keepalive adds complexity

---

## ADR 003: Modular Core Scripts with Numeric Prefixes

**Context:** Installation has ordered steps; new steps must be insertable.

**Decision:** Place modules in `install/core/` named `NN-name.sh` (zero-padded). `install.sh` runs them in lexical order via glob.

**Consequences:**
- ✅ Explicit ordering, easy to insert (e.g., `01a-` between `01-` and `02-`)
- ✅ Simple implementation: `for script in install/core/*.sh; do source "$script"; done`
- ✅ Each module can use helpers (`info`, `success`, etc.)
- ❌ No dependency graph — linear only
- ❌ Naming collisions if two people add `02-` simultaneously

---

## ADR 004: No External Config Format (Yet)

**Context:** Config files (YAML/TOML/ENV) add parsing deps and complexity.

**Decision:** Hardcode values in scripts for now. Document configurable values at top of each module.

**Consequences:**
- ✅ Zero deps, simple to read
- ✅ Easy to fork and edit values directly
- ❌ Users must edit scripts to customize (not ideal for sharing)
- ❌ No validation or schema
- 🔄 Revisit when >3 modules need shared config

---

## ADR 005: RPM Fusion via Direct RPM URLs

**Context:** Enable RPM Fusion without `dnf config-manager` (not always installed).

**Decision:** Install release RPMs directly using version-agnostic URLs:
```
https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

**Consequences:**
- ✅ Works on minimal Fedora (no `dnf-plugins-core` needed)
- ✅ Auto-detects Fedora version via `rpm -E %fedora`
- ✅ Idempotent (dnf handles already-installed)
- ❌ Hardcoded mirror URL (could use metalink)
- ❌ No GPG key verification beyond RPM signatures

---

## ADR 006: DNF Tuning Defaults

**Context:** Default DNF is slow (single download, no fastestmirror).

**Decision:** Append to `/etc/dnf/dnf.conf`:
```
max_parallel_downloads=10
fastestmirror=True
```

**Consequences:**
- ✅ Significant speedup on typical connections
- ✅ Safe defaults (mirrorlist still used, just reordered)
- ❌ `max_parallel_downloads=10` may saturate slow links
- 🔄 Consider making tunable via config later

---

## ADR 007: No Root Execution

**Context:** Running installer as root is dangerous and breaks `$HOME` paths.

**Decision:** Enforce non-root in `boot.sh`; use `sudo` for privileged operations only.

**Consequences:**
- ✅ Protects user's home directory
- ✅ Follows principle of least privilege
- ✅ Sudo keepalive avoids repeated prompts
- ❌ Slightly more complex (sudo in every module)

---

## ADR 008: Reserved `bin/` and `config/` Directories

**Context:** Empty directories exist in repo root.

**Decision:** Keep both, document as reserved for future use:
- `bin/` — Future user-facing CLI tools (e.g., `fm-fedora update`, `fm-fedora add-module`)
- `config/` — Future user config files (e.g., `config/user.conf` for package lists, toggles)

**Consequences:**
- ✅ Clear intent for contributors
- ✅ Avoids breaking changes later
- ❌ Empty dirs in repo (minor noise)
- 🔄 Remove if not used within 6 months

---

## ADR 009: MIT License

**Context:** Project should be freely usable, modifiable, distributable.

**Decision:** License under MIT.

**Consequences:**
- ✅ Maximum permissiveness
- ✅ Compatible with all use cases (personal, commercial, forked)
- ❌ No copyleft — derivatives can be closed source

---

## ADR 010: Why Fedora Linux

**Context:** Choosing a base distribution for the setup toolkit.

**Decision:** Target Fedora Linux (current stable release) as the sole supported distribution.

**Consequences:**
- ✅ Cutting-edge packages, latest kernel, Wayland-first
- ✅ Strong upstream contribution (kernel, GNOME, systemd, PipeWire)
- ✅ RPM Fusion provides proprietary/codec packages cleanly
- ✅ `dnf` is fast, reliable, has good CLI/UX
- ✅ Silverblue/ Kinoite variants for immutable desktop if desired
- ❌ Shorter support window (~13 months) vs LTS distros
- ❌ Frequent upgrades required (every 6 months)
- ❌ Less third-party vendor support (vs Ubuntu/Debian)
- ❌ SELinux complexity for newcomers

**Rationale:** Fedora balances "modern" with "stable enough," has excellent Wayland/Hyprland support, and aligns with upstream development. The toolkit name `fm-fedora` reflects this focus.

---

## ADR 011: Why Hyprland

**Context:** Selecting a Wayland compositor for the default desktop experience.

**Decision:** Use Hyprland as the primary/recommended compositor.

**Consequences:**
- ✅ Dynamic tiling with floating support — best of both worlds
- ✅ Excellent animation/smoothness (GPU-accelerated)
- ✅ Highly configurable via single `hyprland.conf`
- ✅ Active development, responsive upstream
- ✅ Native Wayland, no X11 dependency
- ✅ Built-in IPC for scripting/status bars (e.g., waybar)
- ❌ Steeper learning curve than GNOME/KDE
- ❌ Manual config for everything (keybinds, rules, env vars)
- ❌ No built-in panel/bar — requires waybar/eww/ags
- ❌ NVIDIA requires extra kernel params (`nvidia_drm.modeset=1`)
- ❌ Not in Fedora default repos (needs COPR: `solopasha/hyprland`)

**Rationale:** Hyprland offers a modern, performant, hackable Wayland experience that appeals to users who want control. The toolkit will include a `03-hyprland.sh` module for install + base config.

---

## ADR 012: Why Vicinae

**Context:** Need a terminal emulator that fits the Hyprland/Wayland stack.

**Decision:** Use Vicinae as the default/recommended terminal emulator.

**Consequences:**
- ✅ Native Wayland (no XWayland overhead)
- ✅ GPU-accelerated rendering (via Smithay/Wayland protocols)
- ✅ Minimal, fast, low latency
- ✅ Configurable via TOML (modern, readable)
- ✅ Supports ligatures, true color, images (kitty protocol)
- ✅ Daemon mode for instant window spawn
- ❌ Less mature than foot/alacritty/kitty
- ❌ Smaller community, fewer plugins/themes
- ❌ Not in Fedora repos (build from source or COPR)
- ❌ Configuration differs from common term emulators

**Rationale:** Vicinae aligns with the "modern Wayland-native" philosophy. It integrates well with Hyprland's IPC and aesthetics. The toolkit will include a `04-vicinae.sh` module for install + config.
