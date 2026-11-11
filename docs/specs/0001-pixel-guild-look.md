# 0001: the Pixel Guild look

Status: **requested by the owner on 2026-11-11** ("implement this new design and make the PR"). Written the same day.

## Why

The desktop has its own palette (plum, lilac, pink; Fraunces and Fira Code; rounded, translucent, blurred). The owner's other products take their look from the Inkunome design system. This change redraws the sway + eww session in that system's **pixel register**, dark theme: same purples and pinks as a family, square corners, hard borders, pixel icons, Pixelify Sans and IBM Plex.

The design was drawn first, compared with this repository, corrected, and accepted by the owner. It is a private design canvas ("Ink Desktop Remix", four artboards). This document carries everything needed from it; the artboard sources are not part of the repository.

## Goal

After this change, a fresh home (or `ink-sync`) gives the same desktop as today, piece for piece and key for key, in the new look, plus one changed layout: the dashboard.

## Non-goals

- **No behaviour change.** No binding, script logic, window rule, flyout timing or screen logic changes. The diff of the `bindsym`, `bindcode` and `mode` lines of the sway configuration must be empty.
- **No light theme yet.** The design system has one, and the tokens file is written so that a second palette is a file swap, but switching sway, mako, the lock screen and the icons with it is a later change.
- **No stream mode, no theme switch, no game-guard tile.** They were considered and removed from the design.
- **No GTK or Qt application theme.** Thunar, Firefox and the settings windows keep their own look.
- **No mascot.** The design system's mascot sprite is a placeholder.

## The tokens

Source: the design system's `tokens.json` (repository `inkunome-design`, commit `7fe3a1f`), dark values. They live in one new file, `eww/_tokens.scss`, which is the only place in the eww configuration where a colour is written. The same values are written once more in the `set $…` lines of the sway configuration and in the mako, fuzzel, swaylock, alacritty and zellij files, each with a comment naming this file as the source.

| Token | Value | Replaces |
|---|---|---|
| `bg` | `#150F28` | `$loam` |
| `surface` | `#20173A` | `$surface` (was translucent) |
| `sunken` | `#0C0818` | (wallpaper only) |
| `fg` | `#F3ECFF` | `$spore` |
| `muted` | `#A99BC9` | `$dim` |
| `line` | `#4A3B7A` | `$moss` |
| `accent` | `#FF7AA8` | `$glow`, `$feather`, `$pink` where they mean focus, selection or a title |
| `on-accent` | `#150F28` | text on an accent fill |
| `accent-tint` | `#3A1630` | the "on" state of a tile |
| `px-body` | `#7B66C8` | meters, the bramble's stem |
| `px-highlight` | `#B8A9F0` | stars, secondary terminal colour |
| `gold` | `#F2B84B` | moon, bramble berries |
| `warn` | `#F2B84B`, tint `#33270C` | `$amber` where it warns |
| `bad` | `#FF8A80` | `$amanita` |
| `ok` | `#6FD6A0` | (terminal green only) |
| `info` | `#A9B8FF` | (terminal blue only) |

Rules that hold everywhere:

- **Every corner is square**: no `border-radius` other than 0, in eww, sway (`corner_radius 0`), mako, fuzzel.
- **Nothing is translucent, nothing is blurred**: no `rgba()`, no alpha in a colour, `blur disable` in sway, no `layer_effects` blur.
- **No gradient, no soft shadow.** A shadow is a hard offset: 4 px right and down, in `line`.
- **Borders**: 3 px for windows and panels (`fg` for a panel, `accent` for the focused window, `line` for the others), 2 px for controls (`muted` for a control at rest, `accent` when on or selected). `line` is decoration and never the only boundary of a control.
- **Status always carries a word** or an explicit label, never colour alone. The accent is never a status colour.
- **Text contrast**: `fg` and `muted` on `bg` and `surface`; `on-accent` on `accent`. No `muted` text on `line`.

## Type

| Use | Face |
|---|---|
| Panel titles, the big clocks, workspace numbers, an app's initial | Pixelify Sans |
| Labels, notification text, tiles, buttons | IBM Plex Sans |
| Data: the bar clock, percentages, key caps, window titles, hints, the launcher's search | IBM Plex Mono |

Pixelify Sans is for short text only. The image installs the three families:

- IBM Plex Sans and IBM Plex Mono from Fedora's packages if they exist under those names (verify with `dnf repoquery` in the devbox, which is Fedora; record the exact package names in `build.sh`).
- Pixelify Sans from Fedora if packaged (verify the same way); otherwise the font file is shipped under `build_files/system_files/usr/share/fonts/ink-pixelify-sans/` with its OFL licence text, taken from the `dist/fonts/` folder of the design system's repository. Check with `fc-scan` that fontconfig reads it and reports the family "Pixelify Sans", and which weights it holds: use a weight the file really has, never a synthesised bold.
- `fira-code-fonts` stays installed (the terminal and zellij are free to use it).

## eww

### `eww.scss`

Rewritten around `@import "tokens";`. The class names stay, so `eww.yuck` changes only where this document says. GTK 3 CSS only: no `gap`, no `clip-path`, no flexbox, no CSS variables. The stepped corners of the design's panels are a web technique and are dropped: panels are plain squares.

| Piece | Look |
|---|---|
| Bar | Still no frame: separate chips on the wallpaper. |
| `.pill` | `surface` fill, no border, square, padding `3px 10px`. |
| `.ws` | Pixelify Sans. At rest `muted` on `surface`; `.visible` `fg`; `.focused` `on-accent` on `accent`; `.urgent` `on-accent` on `bad`. The label is the workspace name alone (the `◉`/`○` marks go). |
| `.layout` | `accent` text, 2 px `accent` border, `surface` fill, IBM Plex Mono bold. The label is the layout name alone (the `⌨` glyph goes). |
| `.clock` | `fg`, IBM Plex Mono bold. |
| `.privacy` | `warn` tint fill, `warn` text. Each visible icon is followed by a word: "mic", "camera", "screen shared". The tooltips stay. |
| `.caf.on` | `accent-tint` fill. |
| `.vine` | The bramble (below), 12 px high, repeated along x. |
| `.strip-win` | `surface` fill, 2 px `muted` border. |
| Empty-strip hint | Same text as today, `muted`, on a `surface` chip. |
| `.strip-dock`, `.strip-player` | `surface` fill. The player's three glyph buttons become the pixel icons `prev`, `play` / `pause`, `next`. |
| `.dock`, `.wsdock`, `.bigclock` | `surface` fill, 3 px `line` border. `.bigclock-time` Pixelify Sans 40 px `fg`. `.dock-icon.mini` 2 px `muted` border, Pixelify initial. |
| `.pop` | `surface` fill, 3 px `fg` border, hard shadow (4 px, `line`) drawn inside the layer surface: give the panel a right and bottom margin of 6 px so the shadow has room. The fur texture goes: remove every `:style "background-image: … fur.svg"` from `eww.yuck` and delete `fur.svg`. |
| `.pop-title` | Pixelify Sans 18 px, `accent`. |
| `.dim` | `muted`. |
| `.tile` | `bg` fill, 2 px `bg` border; `.on` `accent-tint` fill, 2 px `accent` border. The state word under the label stays. |
| `.app` | `bg` fill; hover `accent-tint`. |
| `.pbtn` | `bg` fill; the shut-down button's label and icon in `bad`; `.confirm` 2 px `bad` border. |
| `.pop-btn` | 2 px `muted` border, IBM Plex Mono 12 px; `.muted` text in `bad`. |
| `scale` | Trough `line`, 6 px; highlight `accent`; the slider a 12×16 `fg` square. |
| `progressbar` | Square; trough `line`; progress `px-body`. |
| `calendar` | Square, IBM Plex Mono; the selected day `on-accent` on `accent`; other months' days `muted`. |
| `.search` | `bg` fill, 2 px `fg` border, IBM Plex Mono 15 px. |
| `.app-tile` | `bg` fill, 2 px `bg` border; `.selected` `accent-tint` fill, 2 px `accent` border. |
| `.result` | Transparent; `.selected` `accent` fill with `on-accent` text. The file starts with a rule that gives every widget the `fg` colour, so the labels inside a selected row need their own rule. |
| Expose | Cards square; `.focused` 3 px `accent` border; `.picked` 3 px `warn` border; workspace headers as `bg` chips, the target state in `accent`. |
| `.wp-btn` | `bg` fill, `accent` glyph, IBM Plex Mono bold. |
| `.lcard` | `bg` fill, 2 px `muted` border; hover `accent` border. |
| `.keycap` | 2 px `muted` border, IBM Plex Mono. |
| Battery flyout | Bars as `progressbar`; the three profile buttons as `.pop-btn`, the current one `on-accent` on `accent`. |
| Focus | A 2 px `fg` outline on any focused control. |

Every rule the current stylesheet has for a class must have a counterpart: read the whole current file and leave no class unstyled.

### `eww.yuck`: the dashboard's new layout

Both dashboards change layout. Everything else in the file keeps its structure.

**Wide dashboard** (`dashboard`, window `dashboard-wide`, 960 px wide instead of 800):

- No title, no uptime, no close button. It closes with Alt+Space, Escape, or the dashboard icon of the strip or the dock, as today. The `uptime` poll goes if nothing else reads it.
- Two equal columns, 24 px apart, 28 px padding.
- **Left**: the time (Pixelify Sans, 96 px); the date as `%A %d %B %Y` (IBM Plex Mono, `muted`); the calendar in a `bg` box with 16 px padding.
- **Right**, top to bottom, 24 px apart:
  - A row with "Notifications" (Pixelify Sans 20 px, `fg`) and a "Clear all" button (`.pop-btn`), which runs what the notification flyout's button runs. Under it the recent notifications, each a `bg` box: an 8×8 `accent` square, the summary in semibold, the body in `muted` 13 px. No time is shown: mako's history has none. When there is none: "nothing yet".
  - "System" (same title style), then three rows, each: a label (`CPU`, `Memory`, `Disk`, IBM Plex Mono, `muted`), a meter of **ten segments** (each 16×12 px, 3 px apart; a segment is on when the value reaches its tenth, rounded to the nearest; on is `px-body`, off is `line`), and the value as `NN%`. For the disk at 85% or more, the on segments are `warn` and the value reads `NN% · nearly full` in `warn`.
  - A `bg` box with one line: on the left the track (`artist — title`, or the title alone, or "nothing playing"), on the right "Alt+Space closes", both IBM Plex Mono 13 px `muted`.
- The five tiles (Wi-Fi, Bluetooth, do not disturb, night light, caffeine) are no longer on the dashboard; they stay in the quick settings.

**Long dashboard** (`dashboard-long`, portrait screens): the same blocks in one scrolling column, in this order: time and date, notifications, system, calendar, the media line (without the key hint's column: the hint goes under the track).

The `ring` and `media-card` widgets go if nothing uses them any more. A new small widget draws the ten-segment meter.

### Other changes in `eww.yuck`

- The quick-settings pill shows `inkwell.svg` instead of `paw.svg` (delete `paw.svg`).
- Icon sizes become whole multiples of 12 px: 12, 24 or 36. This applies to the Ink icons, with one exception for application icons: in the dock of a portrait screen every icon is 36 px, system theme included, and every button is 48 px (36 px + 6 px padding a side, the minimised window's initial included), so the dock is exactly 76 px tall (48 + 2 × 3 px margin + 2 × 8 px padding + 2 × 3 px border), as tall as the big clock and the workspace box beside it. Elsewhere, application icons from the system theme keep their sizes (20 px in the bottom strip).
- The labels of `.ws` and `.layout`, the privacy words and the player's icons, as said above.

## Icons

Every SVG under `eww/icons/` is redrawn; file names stay unless said otherwise, so the scripts that build icon names (`battery`, `launch`, `apps`) keep working.

- **Grid**: `viewBox="0 0 12 12"`, `shape-rendering="crispEdges"`, only rectangles or axis-aligned paths on whole coordinates. `inkwell.svg` is the exception, on its own 11×8 grid.
- **Where the design system already has the icon** (bell, lock, search, home, user, key, shield, clock, package, and others), use its grid: `icons/icons.txt` in the design system's repository (`#` is a filled cell). Draw the rest on the same grid, in the same weight (2-cell strokes, solid shapes).
- **Colours are written in the file** (an eww image takes no stylesheet), from the tokens only:
  - `fg`: terminal, browser, files, settings, bell, vol-high, vol-low, the layout icons, lock, suspend, logout, reboot, prev, play, pause, next, cpu, the battery's outline.
  - `accent`: launcher, dashboard, coffee-on, the dot of bell-dot, the inkwell (with one `fg` shine cell).
  - `muted`: coffee (off), bell-off.
  - `bad`: vol-muted, power-poweroff, the fill of battery-0.
  - `warn`: privacy-mic, privacy-cam, privacy-screen, the fill of battery-20.
  - `px-body`: the fill of the other batteries; `gold`: the bolt of the charging ones.
- **The inkwell** (11×8): `M4 0h3v2h-3zM2 2h7v1h-7zM1 3h9v4h-9zM2 7h7v1h-7z` in `accent`, and `M3 4h1v1h-1z` in `fg`.
- **The bramble**, `vine-bottom.svg`, a 48×12 tile: `M0 3h12v3h-12zM12 6h12v3h-12zM24 3h12v3h-12zM36 0h12v3h-12zM9 6h3v3h-3zM33 6h3v3h-3z` in `px-body`; `M18 0h6v3h-6zM18 9h3v3h-3z` in `accent`; `M42 3h3v3h-3z` in `gold`.
- Icons already drawn for the design, to reuse as they are (12×12 paths):
  - terminal `M1 2h10v1h-10zM1 3h1v7h-1zM10 3h1v7h-1zM1 10h10v1h-10zM3 5h1v1h-1zM4 6h1v1h-1zM3 7h1v1h-1zM6 8h3v1h-3z`
  - browser `M1 2h10v2h-10zM1 4h1v6h-1zM10 4h1v6h-1zM1 10h10v1h-10zM3 6h6v1h-6zM3 8h4v1h-4z`
  - files `M1 3h4v1h-4zM1 4h10v6h-10z`
  - settings (even-odd) `M5 1h2v2h-2zM5 9h2v2h-2zM1 5h2v2h-2zM9 5h2v2h-2zM3 3h6v6h-6zM5 5h2v2h-2z`
  - dashboard `M1 1h4v4h-4zM7 1h4v4h-4zM1 7h4v4h-4zM7 7h4v4h-4z`
  - launcher (the design system's search icon)
  - vol-high `M2 5h2v2h-2zM4 4h1v4h-1zM5 3h1v6h-1zM8 4h1v4h-1zM10 3h1v6h-1z`
  - coffee `M2 4h7v5h-7zM9 5h2v1h-2zM10 6h1v2h-1zM9 8h2v1h-2zM1 10h9v1h-9zM4 1h1v2h-1zM6 1h1v2h-1z`
  - play `M4 2h1v8h-1zM5 3h2v6h-2zM7 4h1v4h-1zM8 5h1v2h-1z`, prev `M7 2h1v8h-1zM5 3h2v6h-2zM4 4h1v4h-1zM3 5h1v2h-1z`

## Wallpaper

A new default, `/usr/share/backgrounds/ink/ink-pixel-dusk.png`, 3840×2160, drawn on a 384×216 grid and scaled by 10: a `bg` night sky, a few `px-highlight` and `gold` stars, a `gold` moon with two `bg` craters at the upper right, two bands of stepped hills along the bottom (`surface` behind, `sunken` in front). It is produced by a script kept in the repository, `build_files/tools/pixel-wallpaper.py` (Python standard library only, writes the PNG itself, same bytes on every run), and the PNG is committed. The four existing wallpapers stay installed; the sway configuration's comment says how to switch back.

## Sway

Only the palette and the look sections change.

- The `set $…` palette lines become the tokens.
- `font pango:IBM Plex Mono 10`.
- `default_border pixel 3`, `titlebar_border_thickness 3`, `corner_radius 0`.
- `blur disable`; the `blur_passes` and `blur_radius` lines go.
- `shadows enable`, `shadow_blur_radius 1`, `shadow_offset 4 4`, `shadow_color` `line` (opaque), `shadow_inactive_color` fully transparent: a hard shadow under the focused window only.
- `default_dim_inactive 0`; the `dim_inactive_colors` line goes.
- The four `layer_effects` lines go (no blur, no rounded corners, no shadows on panels: eww draws its own).
- Colours:

| | border | background | text | indicator | child border |
|---|---|---|---|---|---|
| `client.focused` | `accent` | `accent` | `on-accent` | `accent` | `accent` |
| `client.focused_inactive` | `line` | `bg` | `fg` | `line` | `line` |
| `client.unfocused` | `line` | `bg` | `muted` | `line` | `line` |
| `client.urgent` | `bad` | `bad` | `on-accent` | `bad` | `bad` |

- `output * bg` uses `bg` as the solid colour and the new wallpaper with `fill`.

In swayfx 0.6 the shadow radius is the blur sigma of the shader, which divides by it: `shadow_blur_radius 0` is undefined, so the configuration uses 1, the smallest defined value and the closest to a hard offset. How hard the result looks is checked on the host (see "What cannot be checked here"). If it reads as a soft glow, the fallback is `shadows disable`.

## The other files

- **mako**: IBM Plex Sans 10; `surface` background (opaque); `fg` text; `fg` border, 3 px, radius 0; progress colour `line`; high urgency border `bad`.
- **fuzzel** (screenshot menu, clipboard): IBM Plex Mono 13; background `surface`, text `fg`, match `accent`, selection `accent` with `on-accent` text and match, border `fg` 3 px, radius 0.
- **swaylock**: IBM Plex Mono; the ring and inside colours mapped from the table above (`bg` screen, `surface` inside, `line` ring, `accent` key highlight and verifying, `bad` backspace and wrong).
- **alacritty**: a `[colors]` section: background `surface`, foreground `fg`, cursor `accent`; ANSI red `bad`, green `ok`, yellow `warn`, blue `info`, magenta `accent`, cyan `px-highlight`, black `bg`, white `fg` (bright black `muted`; the other bright colours the same as normal). No font change.
- **zellij** (`themes/ink.kdl`): the same mapping; the theme's name stays `ink`.
- **`README.md`**: the sentences that describe the look and the "Colours" line (the palette is now `_tokens.scss` and the `set $…` lines); a short "Look" paragraph naming the design system. The screenshots are retaken on the host (below), not here.
- **`ink-sync`**: unchanged. It does not copy the alacritty and zellij directories today; the README says how to take the new terminal colours by hand.

## What cannot be checked here, and who checks it

The devbox has no eww, no sway, no grim. Nothing in this change can be rendered where it is written. So:

- This piece is checked statically (next section).
- The first real run is on the host, with the repository's skill `.claude/skills/try-desktop-look` (written by the orchestrator, not part of this piece): a headless session first, the README screenshots from it, then the owner's live session with a backup and a way back, then the push and the pull request.
- The image build and `bootc container lint` run in the pull request's CI. The owner tries the image in a VM before merging.

## Acceptance (static, in the devbox)

A script `build_files/tools/check-look.sh` runs all of it and exits non-zero on the first failure. It is kept in the repository and wired into `just check`.

1. `eww.scss` compiles with `grass` (the Sass compiler eww embeds), installed into a scratch folder with `cargo install grass --locked --root <scratch>`; if that cannot be installed offline or online, say so and use another Sass compiler, naming it.
2. In `eww.scss` and `eww.yuck`: no colour literal (`#rgb`, `#rrggbb`, `rgb(`, `rgba(`, a CSS colour name used as a colour); in `eww.scss` no `border-radius` other than 0; no `gap:`, `clip-path`, `display:`, `var(`.
3. `_tokens.scss` holds exactly the table's values.
4. `eww.yuck`: parentheses and strings balanced; every widget used is defined and every defined widget is used; every icon path it can produce exists (including the names built from data: the battery icons that `scripts/battery` can print, `launcher` and `dashboard`, the built-in dock ids, `lay-h|v|t|s`, `power-lock|suspend|logout|reboot|poweroff`); every icon file is referenced.
5. Every SVG is well-formed, on its grid, with whole coordinates and token colours only.
6. The sway configuration's `bindsym`, `bindcode` and `mode` lines are identical to `main`'s; it contains no `blur` setting other than `blur disable`, no `corner_radius` other than 0, no `layer_effects`, and a `shadow_blur_radius` of at least 1 (0 is undefined in swayfx).
7. No file under `etc/skel/.config` contains an old palette value (`1c1424`, `2a1d36`, `5b4570`, `f6eaf4`, `b9a3c4`, `c8a2f0`, `ff9ccf`, `ff8fc4`, `e0566f`, `ffd1e6`, `f0d4ff`, `ffc8e2`, any case).
8. The wallpaper script run twice gives the same bytes as the committed PNG, which is 3840×2160.
9. `fc-scan` reads each shipped font file; the package names in `build.sh` exist in Fedora's repositories.
10. `shellcheck` passes on every script added or changed.

## Test plan

There is no test suite in this repository. The checks above are the tests of this piece. Each one must be shown to fail on a deliberate mistake (a colour literal put back, an unbalanced parenthesis, a missing icon, a changed binding) and pass again once it is removed; the report says which were tried.

## Work split

One piece: the look. Then one fresh review of the diff (static, the same limits). Then the host-side run with the skill.
