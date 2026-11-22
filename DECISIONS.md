# Architecture Decision Records (ADRs)

*Last updated: 2026-11-23*

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

---
## ADR-004: `fm upgrade` never upgrades a live session; the bar is session-owned

**Date:** 2026-11-01

**Context:** `fm upgrade` runs `install/core/01-dnf-setup.sh`, which did a full `sudo dnf upgrade --refresh` from inside the running Mango session. Replacing GTK/GLib/mangowm underneath a live bar and compositor kills them mid-redraw. Waybar is started by a bare `exec_once=waybar`, so a dead bar is never respawned and the session is left without a status bar until logout.

The obvious alternative — supervise the bar with a restart loop or systemd user unit — was rejected: it hides real crashes and adds a moving part for a failure that only occurs when the installer mutates live libraries.

**Decision:** Module 01 skips the full system upgrade whenever `WAYLAND_DISPLAY` or `DISPLAY` is set, and points the user at a TTY. `boot.sh` first installs are unaffected (no session yet). RPM Fusion is enabled *before* the upgrade so a cold install also gets those packages.

**Consequences:**
- ✅ `fm upgrade` only re-applies config and installs packages; it never swaps libraries under a running session
- ✅ A missing bar is now a crash symptom, not an installer side effect — logout/login is a valid recovery
- ✅ `fm upgrade` prints the skip and the TTY command, so it isn't silently doing less
- ⚠️ `fm upgrade` alone no longer brings system packages up to date; system updates are a separate, deliberate step
- ⚠️ A Waybar crash from any other cause still needs a logout. Accepted: the bar is part of the session, not a supervised daemon

---

## ADR-005: Panel switches are one helper; airplane state is derived, not stored

**Date:** 2026-11-01

**Context:** The Quick Settings panel needs Airplane and Do Not Disturb as real switches — state visible in the panel, mirrored on the bar, and a notification for every flip. DND already belongs to SwayNC and is readable from it. Airplane has no unprivileged switch on Linux: `/dev/rfkill` is root-only, so `rfkill block all` means either `sudo` (unusable from a panel click) or a `pkexec` password prompt for what is meant to be a one-click toggle.

**Decision:** One helper, `bin/fm-toggle`, with three modes — flip, `state` (prints `true`/`false` for SwayNC's `update-command`), and `bar` (one JSON line for Waybar). DND is `swaync-client -dn`/`-df`; airplane is `nmcli radio all on|off` plus `bluetoothctl power on|off`, both allowed by polkit for the active session with no prompt. Airplane state is *derived* — on means every radio we can switch is already off — rather than stored in a file of our own.

Two upstream behaviours shaped this and are worth not rediscovering: SwayNC's `buttons-grid` runs `update-command` every time the panel opens (so no polling loop), and it exports `SWAYNC_TOGGLE_STATE` to `command` after flipping the button (so the helper applies the requested state instead of flipping again).

**Consequences:**
- ✅ No password prompt, no stored state file that can drift from the system
- ✅ Panel, bar and any future keybind all read the same helper — one source of truth
- ✅ Failures are visible: a `critical` notification plus `journalctl -t fm-toggle`
- ⚠️ Derived state: turning Wi-Fi and Bluetooth off by hand also reads as "airplane on". Honest — all radios *are* off — but it can look like the switch acted on its own
- ⚠️ Switching airplane off turns every radio on; it does not restore the previous mix. GNOME remembers, we do not
- ⚠️ The "Do Not Disturb on" confirmation needs the `SWAYNC_BYPASS_DND` hint, or DND suppresses its own toast

---

## ADR-006: Compositor — mango to Umbriel

**Date:** 2026-11-08

**Context:** mango's animation and workspace model were the reason it replaced SwayFX (ADR-003), but its development path is independent of the shell work this setup is moving toward. Umbriel comes from the same project family as Noctalia (`noctalia-dev`), pairs with it as a first-class shell, and is built on the same stack mango already used: wlroots 0.20 + a SceneFX fork (`umbrielfx`). Its config is live-reloaded TOML with an offline validator, it has per-output workspaces, and its IPC is `umbriel msg …`.

Options rejected:
- **Stay on mango** — works today, but no first-class Noctalia pairing and a tag model that the shell has to translate.
- **niri** — scrolling is only one Umbriel layout; niri's scrollable model was already rejected in ADR-003.
- **Hyprland** — retired from Fedora after F42 (ADR-003).
- **SwayFX** — motion ceiling documented in ADR-003.

**Decision:** Replace mango with **Umbriel**, installed from Terra as `umbriel-nightly` plus `xdg-desktop-portal-umbriel-nightly`. The module is parked alongside the still-installed `mangowm`, and `~/.config/mango/` is left untouched, so a revert is a one-line change in `install.sh`.

**Consequences:**
- ✅ Same graphics stack (wlroots 0.20 + SceneFX fork), so GPU risk stays low
- ✅ TOML config at `~/.config/umbriel/config.toml`, live reload, `umbriel config validate` replaces `mango -c … -p`
- ✅ First-class path to adopting Noctalia surface by surface (bar, dock, notifications, OSD, lock, wallpaper, clipboard) — each has its own config switch
- ⚠️ Umbriel has **no upstream releases or tags** (`VERSION` 0.1.0); every Fedora build is a nightly git snapshot. Terra stays `enabled=0` outside the module, so the compositor only moves when the installer runs, but there is no `MANGO_VERSION`-style pin to hold
- ⚠️ Workspace semantics change: `Mod+Shift+N` moves the focused window **and follows it**, where mango's `tag` kept focus on the current tag
- ⚠️ `Mod+0` is bound to the overview because Umbriel has no 10th workspace; `Mod+O` is kept as a synonym
- ⚠️ Waybar/SwayNC/Vicinae/gtklock/swaybg are deliberately unchanged in this pass; they are the next layers to replace with Noctalia
- 📦 Modules updated: `02-mango.sh` → `02-umbriel.sh`, `config/mango/` → `config/umbriel/`
- 🔧 `bin/fm-power` logout now calls `umbriel msg session-quit skip-confirmation`
- 🗑️ `xdg-desktop-portal-wlr` is no longer installed; Umbriel's own portal backend handles ScreenCast/Screenshot

---
## ADR-007: Obsidian comes from the kmf COPR, not Terra, Flatpak or an AppImage

**Date:** 2026-11-22

**Context:** Obsidian ships no official Fedora RPM — the supported Linux formats are AppImage, Snap, Flatpak and DEB. The project wants Obsidian installed by the normal module path, updating through `dnf`, with a launcher entry and an `obsidian://` handler.

Terra looked like the answer: PR #15067 added `obsidian` on 2026-08-09, building the official `obsidianmd/obsidian-releases` tarball unmodified, with an `update.rhai` bump script. It was **removed the same day** — #15149, backported to el10/f43/f44/f45 — over Obsidian's terms prohibiting redistribution. So there is no Terra RPM to install, and none to pin to.

Options rejected:
- **Flatpak (`md.obsidian.Obsidian`)** — the only channel marked "verified by the Obsidian team", but it adds a second package channel to a project that otherwise installs only RPMs, and it needs a filesystem override before a vault outside the XDG paths is visible.
- **AppImage** — the official upstream build, but updates are a manual re-download, and it ships no `.desktop` or icon, so the launcher entry would have to be written and maintained by this project.

**Decision:** Install `obsidian` from the **kmf/Obsidian COPR** via `enable_copr_try`, as category "c. Notes" in `install/core/05-software-installation.sh`, leaving the COPR enabled so updates arrive through a normal `dnf upgrade`.

**Consequences:**
- ✅ Fedora's own build infrastructure; the RPM is signed by Copr's key, so `gpgcheck` stays on with no `--nogpgcheck` anywhere
- ✅ Updates are CI-driven — the repo auto-bumps on each upstream release (1.15.1 landed 2026-11-12) and follows Fedora branching, so the f45 chroot tracks the release
- ✅ Same pattern the project already trusts: module 04 installs Vicinae and Ghostty from COPRs
- ✅ The RPM ships `/usr/bin/obsidian`, a `.desktop` with `MimeType=x-scheme-handler/obsidian;` and a 512px icon — no config or desktop entry for us to write
- ⚠️ Single maintainer. If the COPR goes stale the package stops updating but keeps working, and nothing in the installer would notice — `enable_copr_try` only reports a missing chroot, not a frozen one
- ⚠️ The same redistribution claim that removed the Terra package could remove this one. Fallback if that happens: Flatpak, which Obsidian's own team verifies
- ⚠️ `dnf copr` needs `dnf-plugins-core`; already required by module 04, so this adds no new dependency
- 📦 `install/core/05-software-installation.sh` gains category "c. Notes" plus an Obsidian block in `verify_software_installation`, gated on `FM_OBSIDIAN_ATTEMPTED`

---

## ADR-008: Blip comes from the vendor's own installer, not Flatpak, Snap or an RPM

**Date:** 2026-11-23

**Context:** Blip (blip.net) has no Fedora RPM — nothing in Fedora, RPM Fusion, Terra or any COPR. The vendor's Linux page offers exactly four routes: Flathub (`net.blip.Blip`, verified by blip.net), Snap Store, an AUR package, a Nix flake, and an "Other" tab whose install command is `curl -fsSL https://static.blip.net/linux/install.sh | bash`.

Options rejected:
- **Flatpak** — the verified channel and what the project would pick if an RPM existed, but it is the first non-RPM package source in an otherwise RPM-only installer (ADR-007 rejected Flatpak for Obsidian on exactly this ground), and a Flatpaked Blip needs a filesystem override before a vault outside the XDG paths is visible.
- **Snap** — needs `snapd` plus the classic `/snap` symlink on Fedora, a heavyweight addition for one app.
- **Hand-rolled tarball logic in the module** — re-implements what the vendor's script already does (download, SHA-256 check, staging, rollback) and would have to be maintained against upstream layout changes.

**Decision:** Install Blip as category "d. File sharing" in `install/core/05-software-installation.sh` by running the vendor's script directly, unprivileged, on every install and every `fm upgrade`.

**Consequences:**
- ✅ The official path for distros without a store package: unpacks to `~/.local/opt/blip`, symlinks `~/.local/bin/blip`, writes `net.blip.Blip.desktop` and icons itself — nothing for the installer to author
- ✅ Idempotent and self-verifying: re-run upgrades to the latest release, a SHA-256 from `latest.json` is checked before extraction, and it refuses to overwrite an install or `.desktop` it does not own — so `fm upgrade` keeps Blip current with no repo of ours
- ✅ No sudo, no new repo, no new package channel: the module stays RPM-only for everything else
- ⚠️ `curl | bash` from a third-party origin: mitigated by HTTPS, the script's own checksum/staging/rollback logic, and its refusal to replace unmanaged installs — but trust rests on `static.blip.net` being intact
- ⚠️ Updates arrive through `fm upgrade` (network required), not `dnf upgrade`; a stale Blip is invisible to any package query — `rpm -q` finds nothing, so the verify pass keys off the marker file and `.desktop` instead
- ⚠️ Uninstall is the script's own `--uninstall` flag; `fm uninstall` is still unimplemented, so Blip is not on its removal list yet
- 📦 `install/core/05-software-installation.sh` gains category "d. File sharing" plus a Blip block in `verify_software_installation`, gated on `FM_BLIP_ATTEMPTED`
