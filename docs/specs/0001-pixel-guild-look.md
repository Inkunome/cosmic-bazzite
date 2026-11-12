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
| `widget-alpha` | `0.70` | the opacity of the widgets' backgrounds (below) |
| `block-alpha` | `0.35` | the opacity of a block inside a translucent panel, pill or dock (below) |

Rules that hold everywhere:

- **Every corner is square**: no `border-radius` other than 0, in eww, sway (`corner_radius 0`), mako, fuzzel.
- **The widgets' backgrounds are translucent, nothing is blurred** (the owner's choice of 2026-11-12, replacing "nothing is translucent"): one value, `$widget-alpha` in `_tokens.scss` (0.70 since the owner's second choice the same day; 0.85 first), applied through one helper of `eww.scss`, `widget()`, which derives the translucent colour from the token. Translucent: the `surface` of every floating panel, of the bar's chips (pills, workspace chips, the strip's chips) and of the dock, and the `bg` blocks inside panels (tiles, buttons, the search field, the calendar, notification and media blocks, expose's thumbnails and headers, key caps, the layout cards, the power-profile buttons). A block inside a translucent surface uses a second value, `$block-alpha` (0.35, helper `block()`), so it reads as a slightly denser area of the same glass (about 0.80 stacked on a 0.70 panel) instead of an opaque slab; on a block, `fg` reads 8.35:1 and `muted` 3.76:1 over pure white, 15.50 and 6.98 over the plain `bg`; the screenshot menu's background (fuzzel) carries the same alpha as its alpha byte. Opaque: frames, the hard shadows, text, icons, accent and status fills (the focused workspace, the privacy chip, selected and pressed states), meters, the lock screen and mako's notifications. A border that only reserves room inside a translucent fill takes the token at alpha 0 so the fill does not double under it. No `rgba()` is written in `eww.scss`; `blur disable` in sway, no `layer_effects` blur. Contrast at 0.70 on a panel (`surface`) over pure white: `fg` 5.47:1, `muted` 2.46:1, `accent` 2.58:1; over the plain `bg`: 15.13, 6.81, 7.13. On the `bg` blocks over white: 6.06, 2.73, 2.86.
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
- Pixelify Sans from Fedora if packaged (verify the same way); otherwise the font file is shipped under `build_files/system_files/usr/share/fonts/ink-pixelify-sans/` with its OFL licence text, taken from the `dist/fonts/` folder of the design system's repository. Check with `fc-scan` that fontconfig reads it and reports the family "Pixelify Sans", and which weights it holds: use a weight the file really has, never a synthesised bold. The file ships as TrueType, `PixelifySans-SemiBold.ttf` (the design system's `.woff2` decompressed with `woff2_decompress`, a lossless change of container): GTK's text renderer, Pango, loads TrueType and OpenType only, so a `.woff2` is listed by fontconfig but never drawn. Check with `pango-list` that the family is listed.
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
| `.dock`, `.wsdock`, `.bigclock` | `surface` fill, 3 px `line` border. `.wsdock` is a segmented strip: each workspace a square cell filling the dock's inner height, cells touching each other and the frame, the focused cell filled with `accent` (number `on-accent`), urgent with `bad`, hover `accent-tint`. `.bigclock-time` Pixelify Sans 40 px `fg`. `.dock-icon.mini` 2 px `muted` border, Pixelify initial. |
| `.pop` | `surface` fill, 3 px `fg` border, hard shadow (4 px, `line`) drawn inside the layer surface: give the panel a right and bottom margin of 6 px so the shadow has room. The fur texture goes: remove every `:style "background-image: … fur.svg"` from `eww.yuck` and delete `fur.svg`. |
| `.pop-title` | Pixelify Sans 18 px, `accent`. |
| `.dim` | `muted`. |
| `.tile` | `bg` fill, 2 px `bg` border; `.on` `accent-tint` fill, 2 px `accent` border. The state word under the label stays. |
| `.app` | `bg` fill; hover `accent-tint`. |
| `.pbtn` | `bg` fill; the shut-down button's label and icon in `bad`; `.confirm` 2 px `bad` border. |
| `.pop-btn` | 2 px `muted` border, IBM Plex Mono 12 px; `.muted` text in `bad`. |
| Sound panel (`slider-row`) | The device's name is a plain label (IBM Plex Mono 12 px, `fg`; muted: `bad` and the word "(muted)"); the percentage stays at the right of that line. Before each slider, a square mute toggle (24 px icon in a 2 px `muted` frame, tooltip "mute" / "unmute"): `vol-high` / `mic` when live, `vol-muted` / `mic-muted` (in `bad`) when muted, drawn in the selected state (`accent-tint` fill, `accent` frame); the slider takes the rest of the line. The owner's choice of 2026-11-12. |
| `scale` | Trough `line`, 6 px; highlight `accent`; the slider a 12×16 `fg` square. |
| `progressbar` | Square; trough `line`; progress `px-body`. |
| `calendar` | Square, IBM Plex Mono; the selected day `on-accent` on `accent`; other months' days `muted`. |
| `.search` | `bg` fill, 2 px `fg` border, IBM Plex Mono 15 px. |
| `.app-tile` | `bg` fill, 2 px `bg` border; `.selected` `accent-tint` fill, 2 px `accent` border. |
| `.result` | Transparent; `.selected` `accent` fill with `on-accent` text. The file starts with a rule that gives every widget the `fg` colour, so the labels inside a selected row need their own rule. |
| Expose | Cards square; `.focused` 3 px `accent` border; `.picked` 3 px `warn` border; workspace headers as `bg` chips, the target state in `accent`. |
| `.wp-btn` | No background at rest (fully transparent, no border, no shadow, as in the old design: the owner's choice of 2026-11-12), `accent` glyph (6.43:1 on the focused title bar's `accent-tint`), IBM Plex Mono bold; on hover an `accent` fill with the glyph in `on-accent`. |
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

- The quick-settings pill keeps the paw, by the owner's choice of 2026-11-12: `paw.svg`, redrawn on the 12×12 grid, shown at 24 px.
- Icon sizes become whole multiples of 12 px: 12, 24 or 36. This applies to the Ink icons, with one exception for application icons: in the dock of a portrait screen every icon is 36 px, system theme included, and every button is 48 px (36 px + 6 px padding a side, the minimised window's initial included), so the dock is exactly 76 px tall (48 + 2 × 3 px margin + 2 × 8 px padding + 2 × 3 px border), as tall as the big clock and the workspace box beside it. Elsewhere, application icons from the system theme keep their sizes (20 px in the bottom strip).
- The labels of `.ws` and `.layout`, the privacy words and the player's icons, as said above.

## Icons

Every SVG under `eww/icons/` is redrawn; file names stay unless said otherwise, so the scripts that build icon names (`battery`, `launch`, `apps`) keep working.

- **Grid**: `viewBox="0 0 12 12"`, `shape-rendering="crispEdges"`, only rectangles or axis-aligned paths on whole coordinates.
- **Where the design system already has the icon** (bell, lock, search, home, user, key, shield, clock, package, and others), use its grid: `icons/icons.txt` in the design system's repository (`#` is a filled cell). Draw the rest on the same grid, in the same weight (2-cell strokes, solid shapes).
- **Colours are written in the file** (an eww image takes no stylesheet), from the tokens only:
  - `fg`: mic, terminal, browser, files, settings, bell, vol-high, vol-low, the layout icons, lock, suspend, logout, reboot, prev, play, pause, next, cpu, the battery's outline.
  - `accent`: launcher, dashboard, coffee-on, the dot of bell-dot, the paw.
  - `muted`: coffee (off), bell-off.
  - `bad`: vol-muted, mic-muted, power-poweroff, the fill of battery-0.
  - `warn`: privacy-mic, privacy-cam, privacy-screen, the fill of battery-20.
  - `px-body`: the fill of the other batteries; `gold`: the bolt of the charging ones, except on battery-20-charging, whose bolt is `fg` because its `warn` fill has the same value as `gold`.
  - power-suspend is a crescent moon.
- **The paw** (kept by the owner's choice of 2026-11-12, in place of the inkwell first drawn for the quick-settings pill): two inner toes, two outer toes and the pad, `M3 1h2v2h-2zM7 1h2v2h-2zM1 3h2v2h-2zM9 3h2v2h-2zM4 5h4v1h-4zM3 6h6v1h-6zM2 7h8v2h-8zM2 9h3v1h-3zM7 9h3v1h-3z` in `accent`.
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
  - play `M4 2h1v8h-1zM5 3h2v6h-2zM7 4h1v4h-1zM8 5h1v2h-1z`, prev, with a bar so it mirrors next (bar, then the left triangle) `M2 2h1v8h-1zM8 2h1v8h-1zM6 3h2v6h-2zM5 4h1v4h-1zM4 5h1v2h-1z`; next is its mirror `M3 2h1v8h-1zM4 3h2v6h-2zM6 4h1v4h-1zM7 5h1v2h-1zM9 2h1v8h-1z` (a plain mirror of the old prev was the play icon itself)

## Wallpaper

A new default, `/usr/share/backgrounds/ink/ink-pixel-dusk.png`, 3840×2160, drawn on a 384×216 grid and scaled by 10: a `bg` night sky, a few `px-highlight` and `gold` stars, a `gold` moon with two `bg` craters at the upper right, two bands of stepped hills along the bottom (`surface` behind, `sunken` in front). It is produced by a script kept in the repository, `build_files/tools/pixel-wallpaper.py` (Python standard library only, writes the PNG itself, same bytes on every run), and the PNG is committed. The four existing wallpapers stay installed; the sway configuration's comment says how to switch back.

## Sway

Only the palette and the look sections change.

- The `set $…` palette lines become the tokens.
- `font pango:IBM Plex Mono 10`.
- `default_border pixel 3`, `titlebar_border_thickness 1` with `titlebar_padding 10 5` unchanged (sway draws the title border inside the padding, so the title bar keeps its height and its text's place; a thin line separates unfocused tabs, the owner's choice of 2026-11-12), `corner_radius 0`.
- `blur disable`; the `blur_passes` and `blur_radius` lines go.
- `shadows enable`, `shadow_blur_radius 1`, `shadow_offset 4 4`, `shadow_color` `line` (opaque), `shadow_inactive_color` fully transparent: a hard shadow under the focused window only.
- `default_dim_inactive 0`; the `dim_inactive_colors` line goes.
- The four `layer_effects` lines go (no blur, no rounded corners, no shadows on panels: eww draws its own).
- Colours:

| | border | background | text | indicator | child border |
|---|---|---|---|---|---|
| `client.focused` | `accent-tint` | `accent-tint` | `fg` | `accent` | `accent` |
| `client.focused_inactive` | `line` | `bg` | `fg` | `line` | `line` |
| `client.unfocused` | `line` | `bg` | `muted` | `line` | `line` |
| `client.urgent` | `bad` | `bad` | `on-accent` | `bad` | `bad` |

- `output * bg` uses `bg` as the solid colour and the new wallpaper with `fill`.

In swayfx 0.6 the shadow radius is the blur sigma of the shader, which divides by it: `shadow_blur_radius 0` is undefined, so the configuration uses 1, the smallest defined value and the closest to a hard offset. How hard the result looks is checked on the host (see "What cannot be checked here"). If it reads as a soft glow, the fallback is `shadows disable`.

## The other files

- **mako**: IBM Plex Sans 10; `surface` background (opaque); `fg` text; `fg` border, 3 px, radius 0; progress colour `line`; high urgency border `bad`.
- **fuzzel** (screenshot menu, clipboard): IBM Plex Mono 13; background `surface` at `$widget-alpha` (alpha byte `b2`), text `fg`, match `accent`, selection `accent` with `on-accent` text and match, border `fg` 3 px, radius 0.
- **swaylock**: IBM Plex Mono; the ring and inside colours mapped from the table above (`bg` screen, `surface` inside, `line` ring, `accent` key highlight and verifying, `bad` backspace and wrong).
- **alacritty**: a `[colors]` section: background `sunken` (the owner's choice of 2026-11-12: `surface` read too light and too purple for a terminal), foreground `fg`, cursor `accent`; ANSI red `bad`, green `ok`, yellow `warn`, blue `info`, magenta `accent`, cyan `px-highlight`, black `bg`, white `fg` (bright black `muted`; the other bright colours the same as normal). No font change.
- **zellij** (`themes/ink.kdl`): the same mapping; the theme's name stays `ink`.
- **`README.md`**: the sentences that describe the look and the "Colours" line (the palette is now `_tokens.scss` and the `set $…` lines); a short "Look" paragraph naming the design system. The screenshots are retaken on the host (below), not here.
- **`ink-sync`**: unchanged. It does not copy the alacritty and zellij directories today; the README says how to take the new terminal colours by hand.

## What cannot be checked here, and who checks it

The devbox has no eww, no sway, no grim. Nothing in this change can be rendered where it is written. So:

- This piece is checked statically (next section).
- The first real run is on the host, with the repository's skill `.claude/skills/try-desktop-look` (written by the orchestrator, not part of this piece): a headless session first, the README screenshots from it, then the owner's live session with a backup and a way back, then the push and the pull request.
- The image build and `bootc container lint` run in the pull request's CI. The owner tries the image in a VM before merging.

## Acceptance (static, in the devbox)

A script `build_files/tools/check-look.sh` runs all of it and exits non-zero on the first failure. It is kept in the repository and wired into `just check`. A check whose tool is missing prints `SKIPPED (<tool> not found)` and does not fail the run, so `just check` works on a machine without the tools; with `--strict` a missing tool is a failure, and acceptance means `check-look.sh --strict` passes.

1. `eww.scss` compiles with `grass` (the Sass compiler eww embeds), installed into a scratch folder with `cargo install grass --locked --root <scratch>`; if that cannot be installed offline or online, say so and use another Sass compiler, naming it.
2. In `eww.scss` and `eww.yuck`: no colour literal (`#rgb`, `#rrggbb`, `rgb(`, `rgba(`, a CSS colour name used as a colour); in `eww.scss` no `border-radius` other than 0; no `gap:`, `clip-path`, `display:`, `var(`.
3. `_tokens.scss` holds exactly the table's values, `$widget-alpha` and `$block-alpha` included (numbers in (0, 1]).
4. `eww.yuck`: parentheses and strings balanced; every widget used is defined and every defined widget is used; every icon path it can produce exists (including the names built from data: the battery icons that `scripts/battery` can print, `launcher` and `dashboard`, the built-in dock ids, `lay-h|v|t|s`, `power-lock|suspend|logout|reboot|poweroff`); every icon file is referenced.
5. Every SVG is well-formed, on its grid, with whole coordinates and token colours only.
6. The sway configuration's `bindsym`, `bindcode` and `mode` lines are identical to `main`'s; it contains no `blur` setting other than `blur disable`, no `corner_radius` other than 0, no `layer_effects`, and a `shadow_blur_radius` of at least 1 (0 is undefined in swayfx).
7. No file under `etc/skel/.config` contains an old palette value (`1c1424`, `2a1d36`, `5b4570`, `f6eaf4`, `b9a3c4`, `c8a2f0`, `ff9ccf`, `ff8fc4`, `e0566f`, `ffd1e6`, `f0d4ff`, `ffc8e2`, any case).
8. The wallpaper script run twice gives the same bytes as the committed PNG, which is 3840×2160.
9. Every shipped font file is `.ttf` or `.otf`; `fc-scan` reads each one; `pango-list`, with fontconfig pointed at a copy holding only the shipped fonts, lists each family; the package names in `build.sh` exist in Fedora's repositories.
10. `shellcheck` passes on every script added or changed.
11. Every colour copied into the sway look section, mako, fuzzel, swaylock, alacritty and zellij is a token value and opaque (the exceptions: sway's fully transparent `shadow_inactive_color`, and fuzzel's background, whose alpha byte must be `$widget-alpha`).
12. Every key of the swaylock, mako and fuzzel files, and every option of the sway look section, is on an allow-list holding exactly the keys in use, each verified against the program's man page; a new key fails until it is verified and added on purpose.
13. The set of distinct commands in the `:on…` attributes of `eww.yuck` equals `main`'s.
14. Every variable an `eww.yuck` expression or `${…}` interpolation reads is defined (a `defvar`, `defpoll` or `deflisten`, a parameter in scope, a `for` variable, an `EWW_*` built-in), every function called is one of eww's, and every expression has a plausible shape (balanced, no two operands or operators in a row, each `?` with its `:`). Best effort, with a tokenizer of the script's own, not eww's parser.

## Test plan

There is no test suite in this repository. The checks above are the tests of this piece. Each one must be shown to fail on a deliberate mistake (a colour literal put back, an unbalanced parenthesis, a missing icon, a changed binding) and pass again once it is removed; the report says which were tried.

## Work split

One piece: the look. Then one fresh review of the diff (static, the same limits). Then the host-side run with the skill.
