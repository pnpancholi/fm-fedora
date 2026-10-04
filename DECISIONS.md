# Architecture Decision Records (ADRs)

*Last updated: 2026-09-27*

Each record follows: **Context → Decision → Consequences**

---

## ADR-001: Compositor — Sway over Hyprland

**Date:** 2026-09-27

**Context:** Hyprland required a COPR repository (`solopasha/hyprland`) for Fedora, adding external dependency and potential instability. Hyprland's config syntax is proprietary and not portable.

**Decision:** Switch to Sway (i3-compatible Wayland compositor) available in official Fedora repositories. Sway uses i3-compatible config syntax, has universal GPU support (Intel/AMD/NVIDIA) via wlroots, and requires no external repos.

**Consequences:**
- ✅ No COPR dependency — all packages from Fedora official repos
- ✅ Universal GPU support with auto-detection (Intel/AMD/NVIDIA)
- ✅ i3-compatible config syntax — portable, well-documented
- ✅ Stable, mature codebase with long-term support
- ⚠️ No dynamic tiling (dwindle/master) — manual layout only
- ⚠️ No built-in animations/blur — requires external tools if desired
- ⚠️ Separate tools needed: swaybg, swayidle, swaylock-effects, swayimg, slurp, grim
- 📦 Modules updated: `02-hyprland.sh` → `02-sway.sh`, `config/hypr/` → `config/sway/`
- 🔧 Waybar module updated: `hyprland/workspaces` → `sway/workspaces`

---

## ADR-002: Control Center — SwayNC

**Date:** 2026-10-04

**Context:** Need quick toggles for DND, Wi-Fi, Bluetooth, power, and battery mode on SwayFX.

**Decision:** Use SwayNotificationCenter (official Fedora package) with a Tokyo Night CSS theme, plus power-profiles-daemon for battery modes.

**Consequences:**
- ✅ Official Fedora repos, no COPR
- ✅ GTK layer-shell panel built for Sway/wlroots
- ✅ DND, Wi-Fi, Bluetooth, power menu, volume/backlight in one panel
- ⚠️ Becomes the system notification daemon (popups enabled; DND governs them)