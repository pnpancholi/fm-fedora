# Agent Instructions for fm-fedora

## Quick Reference
- **Primary command**: `bash boot.sh` (from clone: `bash install.sh`)
- **Lint**: `shellcheck install/**/*.sh lib/*.sh boot.sh install.sh`
- **Test**: `bats tests/` (when added)

## Project Structure
```
fm-fedora/
├── boot.sh                 # Bootstrap entry point
├── install.sh              # Main installer
├── lib/
│   ├── helpers.sh          # Logging + banner utilities
│   └── fm-core.sh          # Shared functions (enable_copr, write_config_*)
├── install/
│   └── core/
│       ├── 01-dnf-setup.sh # DNF tuning, RPM Fusion, system upgrade
│       ├── 02-swayfx.sh    # SwayFX compositor, config, wallpaper, NVIDIA detect
│       ├── 03-waybar.sh    # Waybar + config/style
│       ├── 04-ghostty.sh   # Ghostty terminal + config
│       └── 05-swaync.sh    # SwayNC control center
├── assets/
│   ├── fm-fedora-banner.png
│   └── default-wallpaper.jpg
├── bin/                    # CLI tools (fm, fm-create-sway-desktop)
├── config/
│   ├── sway/config         # SwayFX config
│   ├── waybar/             # Waybar config.jsonc + style.css
│   ├── ghostty/config      # Ghostty config
│   └── swaync/             # SwayNC config.json + style.css
├── AGENTS.md
├── PROJECT.md
├── DECISIONS.md
└── README.md
```

## Conventions
- **Module naming**: `install/core/NN-name.sh` (zero-padded numeric prefix)
- **Execution order**: Explicit list in `install.sh` — `01-dnf-setup.sh`, `02-swayfx.sh`, `03-waybar.sh`, `04-ghostty.sh`, `05-swaync.sh`
- **Logging**: Use `info`, `success`, `warn`, `error` from `lib/helpers.sh`
- **Privilege escalation**: No root execution; sudo only in modules, prompted once via `boot.sh` keepalive
- **Shell target**: Bash 4+ (prefer POSIX where practical)

## Coding Standards
- `set -euo pipefail` at top of every script
- No external dependencies beyond `bash`, `git`, `dnf`, `sudo`
- Each module is idempotent (safe to re-run)
- Hardcoded values at top of modules, documented inline

## Vision / Goal
A professional Linux workstation setup — secure, fast, and productive. Strong opinionated defaults, extensible modules. Not just for developers — for anyone who demands more from their system.

## Key Decisions (see DECISIONS.md)
- **Fedora** — Cutting-edge packages, Wayland-first, strong upstream, RPM Fusion
- **SwayFX** — Sway fork with effects (blur, shadows, animations), i3-compatible, COPR swayfx/swayfx, universal GPU
- **Ghostty** — GPU-accelerated terminal, COPR scottames/ghostty, modern defaults
- **Bash modules** — Zero deps, linear execution, easy to fork/extend

## Current State
- **Done**: `01-dnf-setup.sh`, `02-swayfx.sh`, `03-waybar.sh`, `04-ghostty.sh`, `05-swaync.sh`, bootstrap, installer, helpers, core lib
- **In Progress**: Documentation, agent context files
- **Planned**: `05-packages.sh` (CLI/dev tools), `06-vicinae.sh` (optional alternative terminal)

## Environment / Requirements
- Fedora Linux (current release)
- Bash 4+
- git
- sudo access

## Common Tasks
| Task | Command |
|------|---------|
| Run installer | `bash boot.sh` |
| Lint all scripts | `shellcheck install/**/*.sh lib/*.sh boot.sh install.sh` |
| Add new module | Create `install/core/NN-name.sh`, add to install.sh, use helpers for logging |

## Gotchas / Tribal Knowledge
- `boot.sh` clones to `~/.local/share/fm-fedora` by default (override via `FM_FEDORA_HOME`)
- RPM Fusion URLs use `$(rpm -E %fedora)` — version-agnostic
- SwayFX from COPR `swayfx/swayfx` (not vanilla Sway, not Hyprland)
- Ghostty from COPR `scottames/ghostty`
- Modules are sourced (not executed) — variables/functions leak between modules
- Wallpaper: `assets/default-wallpaper.jpg` copied to `~/Pictures/wallpapers/` by `02-swayfx.sh`