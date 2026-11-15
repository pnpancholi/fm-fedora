# Min/max buttons — notes

Date: 2026-11-15
Context: fm-fedora desktop env = Umbriel compositor + Noctalia shell (no GNOME Shell).

## Why apps have no min/max today

- GNOME extensions only run inside `gnome-shell`. Our session is Umbriel + Noctalia,
  so extensions cannot load and cannot touch any app's titlebar.
- What we see is **client-side decorations** (CSD): libadwaita/GTK apps draw their
  own headerbar and default to close-only.
- Files, Ptyxis and other GTK4/libadwaita apps never negotiate server-side
  decorations, so the compositor cannot add buttons to them.

## Mechanisms that actually work

| Layer | Mechanism | Covers |
| --- | --- | --- |
| Umbriel | `[appearance.title_bar]` (`mode`, `buttons`, colors) | clients that negotiate SSD: Qt, some Electron/Chromium, XWayland |
| GTK | `gtk-decoration-layout=:minimize,maximize,close` in `~/.config/gtk-3.0/settings.ini` and `gtk-4.0/settings.ini` | GTK3/GTK4 apps incl. libadwaita |
| Compositor | keybinds: `window-toggle-maximize`, `window-toggle-maximize-to-edges` | every window, any toolkit |

Umbriel title bar modes: `off` (default), `negotiated`, `on`, `forced`.
`forced` adds a bar even to apps that draw a headerbar → duplicate titlebars.
`on` / `negotiated` = one bar per app, no duplicates.

Relevant keys:

```toml
[appearance]
prefer_no_csd = true            # advertise SSD preference

[appearance.title_bar]
mode = "on"                     # off | negotiated | on | forced
height = 28
button_position = "right"
buttons = ["minimize", "maximize", "close"]
button_glyph = "always"

[appearance.title_bar]          # per-app override
# [[window_rule]] match.is_dialog = true → title_bar_buttons = ["close"]

[layout]
client_maximize = "column"      # or "edges"
```

## Minimize is not a tiling concept

Docs (Layout → Minimize): only floating windows minimize. Tiled, pinned,
fullscreen and scratchpad windows cannot, and neither the app nor Umbriel's title
bar offers a minimize button for them.

- `stacking` layout: every window floats → min + max for all windows.
- `dwindle` / `master` / `scrolling`: maximize only; minimize appears only on
  explicitly floated windows (`Mod+Shift+Space`).
- Tiling equivalents of "minimize": tab stacks (`column-toggle-tabbed`, hides a
  window behind a tab bar) or scratchpads (`window-toggle-scratchpad`).

## Maximize semantics

- `window-toggle-maximize` → fills the layout area: full column width when tiled,
  usable area when floating/stacking.
- `window-toggle-maximize-to-edges` → drops struts/gaps/borders (edges), keeps
  panel zones.
- `client_maximize = "edges"` makes the app's own maximize button (and titlebar
  double-click) behave like maximize-to-edges.
- Maximize works in every layout and every toolkit; it is the reliable path.

## "Min = take half of what it had"

No native action: extents accept absolute fractions
(`window-set-primary-extent <fraction>`) or signed deltas
(`window-modify-primary-extent <delta>`), never a multiplicative "halve current".

Options:
1. Bind a preset: `window-set-primary-extent 0.5`.
2. Bind `window-cycle-primary-extent-back` (presets `[0.333, 0.5, 0.667]`).
3. Helper `bin/fm-shrink`: read focused window extent from
   `umbriel windows --json`, halve it, call `window-set-primary-extent`.
   Closest thing to "shrink by half of whatever it was".

## Proposed plan (not implemented — needs build mode)

1. `config/umbriel/config.toml`: explicit `prefer_no_csd = true`, add
   `[appearance.title_bar]` (`mode = "on"`, height 28, buttons
   minimize/maximize/close, glyphs always) and Tokyo Night `[colors.title_bar]`.
2. Add `config/gtk-3.0/settings.ini` + `config/gtk-4.0/settings.ini`
   (`gtk-decoration-layout=:minimize,maximize,close`, dark theme), copied by
   `install/core/04-desktop-env.sh`.
3. Keybinds: `Mod+M` → `window-toggle-maximize`,
   `Mod+Shift+M` → `window-toggle-maximize-to-edges`.
4. Optional: `bin/fm-shrink` + `Mod+Minus` for the "halve current extent" behaviour.
5. Verify in VM: Nautilus/Ptyxis (GTK), Chromium, an Electron app, a Qt app;
   note any app that still draws its own frame.
