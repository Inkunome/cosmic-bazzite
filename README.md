# Ink desktop on Bazzite

A [Universal Blue](https://universal-blue.org/) image: [Bazzite](https://bazzite.gg/) (GNOME) with a second desktop, **swayfx + eww**, in light purple and pink, with a thorny branch of flowers under the bar. The Sway session is chosen from the GDM login screen; GNOME stays as a fallback.

![Desktop: tabbed windows, bar with a thorny branch, lilac wallpaper](docs/img/desktop.webp)

Everything lives in `build_files/`. The image is built by GitHub Actions and signed with cosign.

## What you get

| Piece | What it does |
| --- | --- |
| **swayfx** | Compositor: blur, shadows, rounded corners. Windows open as **tabs** by default |
| **eww bar** (landscape screens) | Workspaces, clock, keyboard layout, system chip, volume, notifications, tray, quick-settings menu |
| **eww dock** (portrait screens) | Pinned apps and minimised windows, centred at the bottom. No bar on portrait screens |
| **Launcher** (`Ctrl+Space`) | Pinned apps, type to search, `Enter` to start. Right-click an app to pin or unpin it |
| **Dashboard** (`Alt+Space`) | Time, CPU/RAM/disk, media player, toggles, calendar, notifications. A wide layout and a long one for portrait screens |
| **Expose** (`Super+Tab`) | Every workspace and window as a thumbnail, click one to jump to it |
| **Keyboard** | qwerty (default), azerty and bépo, switched live and shown in the bar |
| **Screenshots** | Area, window, screen or output; copy, save or annotate; optional 5 s delay |
| **Minimise to the dock** | `Alt+Esc` sends a window away, `Alt+Tab` brings the next one back |

### Launcher and expose

![App launcher with pinned applications](docs/img/launcher.webp)
![Expose view: workspaces and window thumbnails](docs/img/expose.webp)

### Dashboard and menus

![Dashboard](docs/img/dashboard.webp)
![Quick settings: Wi-Fi, Bluetooth, brightness, apps and power](docs/img/quick-settings.webp)
![Shortcut sheet, shown when hovering the keyboard layout](docs/img/shortcuts.webp)

### Portrait screens

The bar is replaced by a dock and the dashboard becomes a single column. Each screen is judged on its own shape, and the layout follows when you plug, unplug or rotate a screen.

| Dock | Dashboard |
| :---: | :---: |
| ![Portrait screen with the dock](docs/img/portrait.webp) | ![Portrait dashboard](docs/img/portrait-dashboard.webp) |

## Install

Switch an existing Fedora Atomic / Universal Blue machine to this image:

```bash
sudo bootc switch ghcr.io/inkunome/cosmic-bazzite
systemctl reboot
```

At the GDM login screen, pick the **Sway** session. To go back: `sudo bootc rollback`.

The image is named after the repository (`cosmic-bazzite`). Rename the repository on GitHub if you want a different image name; the workflow follows it.

New users get the desktop configuration automatically. For an existing home directory, copy it in once with:

```bash
ink-sync        # backs up ~/.config/{sway,eww,mako,fuzzel,swaylock}, then installs the defaults
```

Then reload Sway with `Super+Shift+C`.

Verify the signature with the key in this repository:

```bash
cosign verify --key cosign.pub ghcr.io/inkunome/cosmic-bazzite
```

## Shortcuts

`Super` is the Windows key. Letters and number keys are bound by **key position**, so they stay in the same place in qwerty, azerty and bépo. Hover the keyboard layout in the bar for the full sheet.

| Keys | Action |
| --- | --- |
| `Super+Shift+Return` | terminal |
| `Super+T` | zellij in a terminal |
| `Super+Ctrl+Space` | spellbook: zellij session `code` |
| `Ctrl+Space`, `Super+D` | app launcher |
| `Alt+Space` | dashboard |
| `Super+Tab` | expose |
| `Super+C` | clipboard history |
| `Super+←↑↓→` / `Super+Shift+←↑↓→` | focus / move a window |
| `Super+Return`, `Super+F` | fullscreen |
| `Super+Shift+F` | floating |
| `Super+W`, `Super+E` | tabs, split |
| `Super+A`, `Super+Shift+A` | focus parent, child container |
| `Super+Shift+Q` | close |
| `Alt+Esc`, `Alt+Tab` | minimise to the dock, next minimised window |
| `Super+1…9`, `Super+Shift+1…9` | go to a workspace, send the window there |
| `Super+PgUp/PgDn`, `Super+Ctrl+←/→` | previous / next workspace |
| `Super+Alt+←/→` | move the workspace to another screen |
| `Super+S` | screenshot: area, then annotate |
| `Super+Shift+S` | screenshot menu (mode, action, delay) |
| `Super+Ctrl+S`, `Super+Alt+S` | screenshot: all screens, window |
| `Super+Space` | next keyboard layout (qwerty, azerty, bépo) |
| `Super+Ctrl+1/2/3` | set bépo / azerty / qwerty |
| `Super+L` | lock the screen |
| `Super+Shift+E` | power menu |
| `Super+Shift+C` | reload Sway |

In the launcher, dashboard and expose, `Esc` closes the panel.

## Software kit

Installed in `build_files/build.sh`. COPRs: `swayfx/swayfx`, `varlad/eww`, `varlad/zellij`, `leloubil/wl-clip-persist`; they are left disabled after the build.

| Role | Packages |
| --- | --- |
| Compositor and session | `swayfx`, `swaybg`, `swayidle`, `swaylock`, `kanshi`, `wlr-randr`, `wdisplays`, `xdg-desktop-portal-wlr`, `xdg-desktop-portal-gtk` |
| Bar, dock, panels | `eww` |
| Launcher and menus | `fuzzel`, `wlogout` |
| Notifications and clipboard | `mako`, `cliphist`, `wl-clipboard`, `wl-clip-persist` |
| Screenshots | `grim`, `slurp`, `swappy` |
| System | `brightnessctl`, `playerctl`, `pavucontrol`, `wlsunset`, `udiskie`, `network-manager-applet`, `nm-connection-editor`, `blueman`, `mate-polkit`, `system-config-printer` |
| Apps and tools | `alacritty`, `zellij`, `thunar`, `fira-code-fonts`, `jq`, `socat`, `nix` |

Already in the Bazzite base and used by the desktop: NetworkManager, Bluetooth, PipeWire / WirePlumber, `tuned-ppd` (power profiles), GNOME Settings, gvfs, udisks2.

## Where things are

| Path in the image | Content |
| --- | --- |
| `/etc/skel/.config/sway/config` | Sway config: look, keys, autostart, keyboard layouts |
| `/etc/skel/.config/eww/` | `eww.yuck` (widgets), `eww.scss` (style), `scripts/`, `icons/` |
| `/etc/skel/.config/{mako,fuzzel,swaylock}/` | Notifications, launcher styling, lock screen |
| `/usr/bin/ink-layout` | Keyboard layout switcher (`next`, `set <name>`, `watch`) |
| `/usr/bin/ink-screenshot` | Screenshot tool (`area`, `window`, `screen`, `output` × `copy`, `save`, `edit`) |
| `/usr/bin/ink-scratch` | Minimise to the scratchpad, cycle, list |
| `/usr/bin/ink-sync` | Copy the default configuration into your home |
| `/usr/share/backgrounds/ink/` | Wallpapers: `lilac-dusk` (default), `forest-night`, `ink-feathers`, `loam-moss` |

### Make it yours

- **Wallpaper**: change the `output * bg …` line in `~/.config/sway/config`.
- **Pinned apps**: the launcher keeps them in `~/.config/ink/pinned` (one desktop-file id per line); right-click an app to pin or unpin it.
- **Colours**: the palette is at the top of `eww.scss` and in the `set $…` lines of the Sway config.
- **Keyboard layouts**: `input type:keyboard` in the Sway config; keep `NAMES` in `/usr/bin/ink-layout` in the same order.
- **Monitors**: `wdisplays` for a quick layout; add a `~/.config/kanshi/config` and start `kanshi` if you want profiles.

## Build and test

```bash
just build          # podman build of the image, tagged cosmic-bazzite:latest
just build-qcow2    # disk image to try it in a VM (needs bootc-image-builder)
just run-vm-qcow2
just check          # lint the Justfile
```

GitHub Actions (`.github/workflows/build.yml`) builds the image on every pull request and publishes and signs it when something lands on `main`, and every day at 10:05 UTC to follow Bazzite. Add your cosign private key as the `SIGNING_SECRET` repository secret; the public key is `cosign.pub`. ISO builds (`build-disk.yml`) run on demand.

## Notes

- Built for eww 0.6: monitors are addressed by index, and `Ctrl+Space` is a global shortcut, so applications do not get it (editor autocompletion, input methods).
- The panels that open on hover sit at a fixed distance from the right edge of the bar; adjust the `:x` of each window in `eww.yuck` if one is off on your screen.
- The lock screen is plain `swaylock` (colours only); `swaylock-effects` is not packaged for Fedora 45.
- Expose keeps the last thumbnail of windows it cannot capture, so a window on another workspace may show an older picture.
