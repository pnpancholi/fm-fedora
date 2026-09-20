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
│   └── helpers.sh          # Logging + banner utilities
├── install/
│   └── core/
│       └── 01-dnf-setup.sh # DNF tuning, RPM Fusion, system upgrade
├── assets/
│   └── fm-fedora-banner.png
├── bin/                    # Reserved: future CLI tools
├── config/                 # Reserved: future config files
├── AGENTS.md
├── PROJECT.md
├── DECISIONS.md
└── README.md
```

## Conventions
- **Module naming**: `install/core/NN-name.sh` (zero-padded numeric prefix)
- **Execution order**: Lexical glob — `for script in install/core/*.sh; do source "$script"; done`
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
- **Hyprland** — Dynamic tiling Wayland compositor, GPU-accelerated, highly configurable
- **Vicinae** — Native Wayland terminal, GPU-rendered, TOML config, daemon mode
- **Bash modules** — Zero deps, linear execution, easy to fork/extend

## Current State
- **Done**: `01-dnf-setup.sh` (DNF tuning, RPM Fusion, system upgrade), bootstrap, installer, helpers
- **In Progress**: Documentation, agent context files
- **Planned**: `02-packages.sh`, `03-hyprland.sh`, `04-vicinae.sh`, `05-waybar.sh`, `06-cli-tools.sh`

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
| Add new module | Create `install/core/NN-name.sh`, use helpers for logging |

## Gotchas / Tribal Knowledge
- `boot.sh` clones to `~/.local/share/fm-fedora` by default (override via `FM_FEDORA_HOME`)
- RPM Fusion URLs use `$(rpm -E %fedora)` — version-agnostic
- Hyprland is not in Fedora repos — needs COPR: `solopasha/hyprland`
- Vicinae is not in Fedora repos — build from source or COPR
- Modules are sourced (not executed) — variables/functions leak between modules
