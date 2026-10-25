# fm-fedora — Project Context

> **Inspired by:** [Omakub](https://github.com/basecamp/omakub) (Ubuntu) and [Omarchy](https://github.com/basecamp/omarchy) (Arch). Different direction, same spirit. MIT-licensed.

## Stack
- **OS:** Fedora Linux (current stable)
- **Compositor:** mango (mangowm — dwl/wlroots + scenefx, dynamic tiling, animated, via Terra repo)
- **Terminal:** Ghostty (GPU-accelerated, via COPR scottames/ghostty)
- **Bar:** Waybar (status bar, IPC with mango via `mango/*` modules, Fedora repos)
- **Language:** Bash 4+ modules, zero external deps

## Structure
```
boot.sh → install.sh → install/core/01-dnf-setup.sh, 02-mango.sh, 03-waybar.sh, 04-ghostty.sh, 05-swaync.sh...
lib/helpers.sh — logging + banner
lib/fm-core.sh — shared functions
```

## Current State
- `01-dnf-setup.sh`: DNF tuning, RPM Fusion, system upgrade
- `02-mango.sh`: mango compositor, config, wallpaper, NVIDIA auto-detect
- `03-waybar.sh`: Waybar + config/style
- `04-ghostty.sh`: Ghostty terminal + config
- `05-swaync.sh`: SwayNC control center (DND, Wi-Fi, Bluetooth, power, battery mode)
- **Planned:** `05-packages.sh` (CLI/dev tools), `06-vicinae.sh` (optional alt terminal)

## Philosophy
**Speed** • **Mesmerizing** • **Strong Opinionated Defaults, Extensible Boundaries**

## Key Decisions (see DECISIONS.md)
| Topic | Decision |
|-------|----------|
| Distro | Fedora — cutting-edge, Wayland-first, strong upstream |
| Compositor | mango — dynamic dwindle tiling, per-event animations, scenefx effects, wlroots (universal GPU) |
| Terminal | Ghostty — GPU-accelerated, COPR scottames/ghostty, modern defaults |
| Language | Bash — zero deps, transparent, forkable |

## Extension Points
- Add modules: `install/core/NN-name.sh`
- Config: `config/` (reserved for user overrides)
- CLI tools: `bin/` (reserved for future commands)

## Requirements
- Fedora Linux (current release)
- Bash 4+, git, sudo access

## Quick Start
```bash
curl -fsSL https://raw.githubusercontent.com/pnpancholi/fm-fedora/main/boot.sh | bash
```