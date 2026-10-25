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
│       ├── 02-mango.sh     # mango compositor, config, wallpaper, NVIDIA detect
│       ├── 03-waybar.sh    # Waybar + config/style
│       ├── 04-ghostty.sh   # Ghostty terminal + config
│       └── 05-swaync.sh    # SwayNC control center
├── assets/
│   ├── fm-fedora-banner.png
│   └── nordic-wp.png
├── bin/                    # CLI tools (fm)
├── config/
│   ├── mango/config.conf   # mango compositor config
│   ├── mango/theme.conf    # mango color tokens
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
- **Execution order**: Explicit list in `install.sh` — `01-dnf-setup.sh`, `02-mango.sh`, `03-waybar.sh`, `04-ghostty.sh`, `05-swaync.sh`
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
- **mango (mangowm)** — dwl-derived, wlroots + scenefx, dynamic dwindle tiling, per-event bezier animations, discrete tags, universal GPU, Terra repo (pinned)
- **Ghostty** — GPU-accelerated terminal, COPR scottames/ghostty, modern defaults
- **Bash modules** — Zero deps, linear execution, easy to fork/extend

## Current State
- **Done**: `01-dnf-setup.sh`, `02-mango.sh`, `03-waybar.sh`, `04-ghostty.sh`, `05-swaync.sh`, bootstrap, installer, helpers, core lib
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
| Fake an MPRIS player to test the Now Playing tile | `./bin/fm-mock-player` (needs `python3-dbus python3-gobject`; dev aid, never installed) |

## Gotchas / Tribal Knowledge
- `boot.sh` clones to `~/.local/share/fm-fedora` by default (override via `FM_FEDORA_HOME`)
- RPM Fusion URLs use `$(rpm -E %fedora)` — version-agnostic
- mango from **Terra** (`repos.fyralabs.com`) — no Fedora package, no first-party COPR. The repo is installed with `enabled=0` and enabled per-command (`--enablerepo='terra*'`), so routine `dnf upgrade` never touches it
- `02-mango.sh` **aborts** if Terra does not declare `gpgcheck=1` — do not weaken that gate
- `MANGO_VERSION` is pinned deliberately; bump it only after checking the config still parses
- mango has **9 tags** (mask `1`–`9`). `SUPER+0` is `toggleoverview`, not workspace 10
- `swaymsg` does not exist here: idle DPMS uses `wlopm`, exit uses `quit`
- mango ships `/usr/share/wayland-sessions/mango.desktop` itself — no desktop-file hack needed
- Config is validated offline with `mango -c <file> -p`
- Lock screen uses Fedora's `swaylock` (the `pheeef/swaylock-effects` COPR is abandoned — no builds past Fedora 41); config at `~/.config/swaylock/config`
- Ghostty from COPR `scottames/ghostty`
- Nerd Font from COPR `che/nerd-fonts` (package: `nerd-fonts`)
- Modules are sourced (not executed) — variables/functions leak between modules
- Wallpaper: `assets/nordic-wp.png` copied to `~/Pictures/wallpapers/` by `02-mango.sh`