```text
███████╗███╗   ███╗      ███████╗███████╗██████╗  ██████╗ ██████╗  █████╗ 
██╔════╝████╗ ████║      ██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗
█████╗  ██╔████╔██║█████╗█████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║
██╔══╝  ██║╚██╔╝██║╚════╝██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║
██║     ██║ ╚═╝ ██║      ██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║
╚═╝     ╚═╝     ╚═╝      ╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
```

**A fast, mesmerizing workstation setup with strong defaults and extensible boundaries.** A minimal, modular bash toolkit to automate a fresh Fedora installation.

> *Banner renders in crimson (`\033[38;2;220;20;60m`) when displayed via `print_banner()` in `lib/helpers.sh`*

## Philosophy

fm-fedora is built on three pillars:

**Speed —** Every default is tuned for performance. DNF parallel downloads, fastest mirror selection, minimal boot services, GPU-accelerated compositor (Hyprland), and a native Wayland terminal (Vicinae). No bloat, no waiting.

**Mesmerizing —** The experience should feel alive. Smooth animations, consistent theming, instant terminal spawn, responsive tiling. The desktop disappears; only your work remains.

**Strong Defaults, Extensible Boundaries —** Opinionated out of the box (Fedora + Hyprland + Vicinae + Waybar + modern CLI tools), but every layer is replaceable. Modules run in order, config lives in plain files, no framework lock-in. Fork one script or the whole thing.

## Quick Start

```bash
# One-liner (clones to ~/.local/share/fm-fedora and runs installer)
curl -fsSL https://raw.githubusercontent.com/pnpancholi/fm-fedora/main/boot.sh | bash

# Or manually
git clone https://github.com/pnpancholi/fm-fedora.git ~/.local/share/fm-fedora
bash ~/.local/share/fm-fedora/boot.sh
```

> Runs as your normal user. Asks for `sudo` once, then handles the rest.

## What It Does (So Far)

- ✅ Tunes DNF for faster parallel downloads (`max_parallel_downloads=10`, `fastestmirror`)
- ✅ Enables RPM Fusion (free + nonfree repositories)
- ✅ Fully upgrades system packages
- 🚧 Extensible — add your own modules in `install/core/`

## Architecture

```
boot.sh          →  Bootstrap: clones repo, installs git, keeps sudo alive
install.sh       →  Main entry: runs all scripts in install/core/ in order
install/core/    →  Numbered modules (01-dnf-setup.sh, 02-*, etc.)
lib/helpers.sh   →  Shared logging (info/success/warn/error) + banner
```

Each core module is sourced in lexical order. See `DECISIONS.md` for design rationale.

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
├── bin/                    # Reserved: future user-facing CLI tools
├── config/                 # Reserved: future config files (user overrides)
└── docs/                   # Documentation (architecture, adding modules, etc.)
```

## Requirements

- Fedora Linux (current release recommended)
- `bash` (GNU Bash 4+)
- `git`
- `sudo` access

## Extending

Add new modules as `install/core/NN-name.sh` (e.g., `02-packages.sh`, `03-flatpaks.sh`). They run automatically in order. See `docs/adding-modules.md` (coming soon) for conventions.

## License

MIT — see [LICENSE](LICENSE) (to be added).
