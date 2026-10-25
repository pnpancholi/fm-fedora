# Architecture Decision Records (ADRs)

*Last updated: 2026-10-25*

Each record follows: **Context → Decision → Consequences**

---

## ADR-001: Compositor — Sway over Hyprland

**Date:** 2026-09-27

**Status:** Superseded by ADR-003 (compositor moved to mango).

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

---

## ADR-003: Compositor — SwayFX to mango

**Date:** 2026-10-25

**Context:** The complaint driving this change was purely motion/polish, not layout or stability. SwayFX's entire animation surface is one global knob — `animation_duration_ms` — applying to window open/close only, with no curves, no per-event control, and no tag-transition animation. That ceiling is structural, not a tuning problem.

Requirements: discrete workspaces (a scrollable model was explicitly rejected), real per-event animation control, universal GPU support, and the project stays a curated tiling setup rather than a desktop environment.

Options rejected:
- **niri** — scroll replaces discrete workspaces.
- **Hyprland** — retired from Fedora after F42; a lockstep chain of seven `hypr*` packages must move together, its plugin ABI breaks each release, and it has no offline config validator.
- **Wayfire** — pre-1.0 with a weaker animation config surface.
- **Plasma / COSMIC** — full DEs; would discard the Waybar + SwayNC module work.
- **qtile / labwc / i3** — no Wayland-native animation engine.
- **awesome** — X11-only, last release 2019.

**Decision:** Replace SwayFX with **mango (mangowm)**, installed from the Terra repo, version-pinned, with scenefx effects and per-event bezier animations.

**Consequences:**
- ✅ Per-event animation control: durations and curves for move/open/close/tag/focus, `zoom`/`slide`/`fade` types, layer-surface animations, animated tag transitions
- ✅ Same graphics stack (wlroots + **scenefx**, the library SwayFX already used) — lowest GPU risk of any candidate
- ✅ Discrete tags with `dwindle` default; `scroller` exists but is not the model
- ✅ Native XWayland, `.conf` hot-reload, Waybar `mango/*` modules, SwayNC unchanged
- ✅ Offline config validation via `mango -c … -p` (replaces `sway -c … -C`)
- ⚠️ Terra is a third-party repo — no Fedora package and no first-party COPR. Mitigated by enabling it only for install (`enabled=0`), a hard `gpgcheck=1` gate, and a pinned `MANGO_VERSION`
- ⚠️ Pre-1.0 and largely single-maintainer — pinned deliberately; SwayFX stays revertable in git
- ⚠️ **9 tags**, not 10 workspaces. `SUPER+0` becomes `toggleoverview`, `SUPER+Shift+0` becomes `tag_special_tag`
- ⚠️ `swaymsg` has no equivalent: idle DPMS now uses `wlopm`, exit uses `quit`
- 📦 Modules updated: `02-swayfx.sh` → `02-mango.sh`, `config/sway/` → `config/mango/`
- 🔧 Waybar modules updated: `sway/workspaces`/`sway/window` → `mango/workspaces`/`mango/window` (+ `mango/layout`)
- 🗑️ `bin/fm-create-sway-desktop` removed — mango ships its own `/usr/share/wayland-sessions/mango.desktop`