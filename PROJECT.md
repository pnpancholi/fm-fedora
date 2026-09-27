# fm-fedora — Project Context

> **Inspired by:** [Omakub](https://github.com/basecamp/omakub) (Ubuntu) and [Omarchy](https://github.com/basecamp/omarchy) (Arch). Different direction, same spirit. MIT-licensed.

## Stack
- **OS:** Fedora Linux (current stable)
- **Compositor:** Sway (Wayland, i3-compatible, official Fedora repos)
- **Terminal:** Vicinae (Wayland-native, GPU-accelerated, via COPR or source)
- **Bar:** Waybar (status bar, IPC with Sway)
- **Language:** Bash 4+ modules, zero external deps

## Structure
```
boot.sh → install.sh → install/core/01-dnf-setup.sh, 02-*, 03-hyprland.sh, 04-vicinae.sh...
lib/helpers.sh — logging + banner
```

## Current State
- `01-dnf-setup.sh`: DNF tuning, RPM Fusion, system upgrade
- **Planned:** `02-packages.sh`, `03-hyprland.sh`, `04-vicinae.sh`, `05-waybar.sh`, `06-cli-tools.sh`

## Philosophy
**Speed** • **Mesmerizing** • **Strong Opinionated Defaults, Extensible Boundaries**

## Key Decisions (see DECISIONS.md)
| Topic | Decision |
|-------|----------|
| Distro | Fedora — cutting-edge, Wayland-first, strong upstream |
| Compositor | Sway — i3-compatible, stable, Fedora repos, universal GPU |
| Terminal | Vicinae — native Wayland, TOML config, daemon mode |
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
