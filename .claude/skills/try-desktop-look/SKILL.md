---
name: try-desktop-look
description: Try a branch's desktop configuration (sway, eww, mako, fuzzel, swaylock, terminal colours, fonts, wallpaper) on this machine without rebuilding the image - first in a headless session, then on the owner's live session with a backup and a way back - retake the README screenshots from it, then push the branch and open the pull request. Use it on the HOST, outside the devbox, when a branch changes anything under build_files/system_files/etc/skel/.config or the look of the desktop, when asked to "apply the look", "try the branch on my desktop", "redo the README screenshots" or "finish the PR" for such a branch.
---

# Try a desktop look, retake the screenshots, open the pull request

The desktop configuration of this image lives in `build_files/system_files/etc/skel/.config/`. A change to it cannot be rendered in a container: it needs eww, swayfx and grim, which exist only on a machine running the image. This skill is the host-side half of such a change. The other half (writing the change and checking it statically) is done elsewhere and ends with a branch that passes `build_files/tools/check-look.sh`.

**This machine is the owner's workstation.** The live session is where they work. So the order is fixed: headless first, live second, and the live step never happens without the owner saying yes in this conversation and without a backup that one command restores.

## 0. Where you are

Run on the host, not in the devbox, from a checkout or worktree of the branch.

```
command -v eww swaymsg sway grim gh cwebp || true   # eww, sway and grim are required; gh and cwebp have fallbacks below
git status --short && git branch --show-current
bash build_files/tools/check-look.sh                # if the branch has it: it must pass before anything else
```

If `eww` or `sway` is missing, you are in the devbox or on another machine: stop and say so.

Read the branch's specification under `docs/specs/` and the report of whoever implemented it, if the owner gives it: it lists the points only a real run can confirm. Walk through that list during the headless step.

## 1. A headless session (nothing here touches the live desktop)

The goal is a second, invisible sway with its own home and its own runtime directory, so that its eww daemon, its locks and its sockets are not the live ones. (`scripts/ewwguard` restarts eww when it sees two daemons on one runtime directory; a separate `XDG_RUNTIME_DIR` is what keeps the live bar safe.)

```
T=$(mktemp -d /tmp/ink-try.XXXXXX); mkdir -p "$T/home/.config" "$T/run" "$T/shots"; chmod 700 "$T/run"
cp -a build_files/system_files/etc/skel/.config/. "$T/home/.config/"
```

Things the running image does not have yet, and how the headless home gets them:

- **Fonts** the branch adds: copy the font files the branch ships (look under `build_files/system_files/usr/share/fonts/`) into `$T/home/.local/share/fonts/`. For a family the branch installs as a package (see `build_files/build.sh`) and that `fc-list` does not show on this machine, take the files from the `dist/fonts/` folder of the design system's repository if you have it, into the same folder. Then `HOME=$T/home fc-cache -f`. If a family cannot be found, say which: the screenshots would show a fallback font and must not be committed.
- **Wallpaper** and other files the branch adds under `usr/share`: the sway configuration names their installed path, which does not exist yet. Add `$T/home/.config/ink/sway.d/90-try.conf` with an `output * bg <path in the checkout> fill` line (that directory is included last by the configuration).

Start it. The previous screenshots of the README were taken this way, but the exact invocation was not recorded, and swayfx needs a GL renderer for its effects; start from this and adapt:

```
env -i HOME="$T/home" XDG_RUNTIME_DIR="$T/run" PATH="$PATH" LANG="${LANG:-C.UTF-8}" \
    XDG_CONFIG_HOME="$T/home/.config" XDG_CACHE_HOME="$T/home/.cache" \
    WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
    dbus-run-session sway -c "$T/home/.config/sway/config" >"$T/sway.log" 2>&1 &
```

Then, with `SWAYSOCK` set to the socket that appears in `$T/run` and the same `HOME` and `XDG_RUNTIME_DIR` on every command:

- `swaymsg -t get_outputs`: one headless output; set its size (`swaymsg output HEADLESS-1 resolution 1920x1080`). For the portrait pictures, `swaymsg create_output` gives a second one; set it to `1080x1920`.
- Read `$T/sway.log` and `eww logs`. **A configuration error is the first finding**: a sway line it rejects, a yuck parse error, a GTK CSS warning. `sway -C -c <config>` validates the sway file alone.
- The autostart lines of the configuration open the bar and the strip through `scripts/screens`. If nothing shows, run `~/.config/eww/scripts/screens apply` in that environment and read the error.
- Open a few windows (`alacritty`, a second one, a file manager) so the tabbed layout, the focused frame and the title buttons show.

When you find the invocation that works, **write it into this file** in place of the sketch above, so the next run does not search again.

### What to look at

Compare with the specification, piece by piece: bar chips, the branch under the bar, focused and unfocused windows, the bottom strip, the launcher (Ctrl+Space), the dashboard (Alt+Space), the quick settings and the other flyouts (they open on hover: `~/.config/eww/scripts/popopen <window> <var> <monitor>` opens one without a pointer; read the script for its arguments), expose (Super+Tab), the layout picker (Super+G), a notification (`notify-send "Screenshot" "Copied to clipboard"`), the screenshot menu (fuzzel), the portrait screen (workspaces, dock, clock; no bar).

**The lock screen is checked here, before anything goes live.** A swaylock configuration with a key swaylock does not know makes it exit, and a lock that does not start is a security problem, not a cosmetic one. In the headless session run `swaylock -f` (it locks only that session), confirm with `pgrep -x swaylock` that it is running and with a screenshot that it draws the new colours, then end it by the pid you started (`kill <pid>`), never with `pkill swaylock`, which would also hit the lock of the live session. If swaylock refuses to start, stop: the branch is not fit for the live step until that is fixed.

**The window shadow.** swayfx's shadow with a very small blur radius is the least certain part of the look: a radius of 0 is undefined in its shader, and the branch uses the smallest defined value. Look at the focused window's right and bottom edges. If the shadow is garbled, missing or soft, set `shadows disable` in the sway configuration (the specification's fallback) and commit that.

Keys can be sent with `swaymsg` commands rather than a keyboard: run what the binding runs (`~/.config/eww/scripts/dash toggle launcher`, and so on).

Fix what is wrong **on the branch** (small, one commit per fix, re-run `check-look.sh`), copy the changed files into `$T/home/.config` again, and reload (`swaymsg reload`). Anything larger than a small fix: stop and report it instead.

### The README screenshots

The README shows eight pictures in `docs/img/`: `desktop`, `launcher`, `expose`, `dashboard`, `quick-settings`, `shortcuts`, `portrait`, `portrait-dashboard` (all `.webp`). Retake all eight from the headless session, same names, same subjects (read the README's captions), at the sizes of the files they replace (check with `file` or `identify`).

```
grim -o HEADLESS-1 "$T/shots/desktop.png"
cwebp -quiet -q 90 "$T/shots/desktop.png" -o docs/img/desktop.webp     # or: magick <png> -quality 90 <webp>
```

Before committing, **look at every picture** (read the PNG): no fallback font, no missing icon, no personal content. The headless home is empty, so no file name, account or notification of the owner's can appear; keep it that way (do not point it at the real home). The clock and the date are fine. Commit them alone: `readme: refresh the screenshots (<what changed>)`.

Stop the headless session (`swaymsg exit`), check that no process still has `$T` as its home, and remove `$T`.

## 2. The live session (only with the owner's yes)

Ask first, in one sentence, saying what will change and how to go back. Then:

```
[ -e ~/.cache/ink-try-last-backup ] && { echo "a try is already applied: restore it first (below), or the first backup would be lost"; exit 1; }
B=~/.config/ink-try-backup-$(date +%Y%m%d-%H%M%S); mkdir -p "$B"
for d in sway eww mako fuzzel swaylock alacritty zellij; do
  if [ -e ~/.config/$d ]; then cp -a ~/.config/$d "$B/"; else : > "$B/$d.absent"; fi
done
[ -e ~/.config/ink/sway.d/90-try.conf ] && cp -a ~/.config/ink/sway.d/90-try.conf "$B/"
echo "$B" > ~/.cache/ink-try-last-backup
```

Write the way back **before** applying, and give it to the owner, because a broken configuration may leave them without a bar or a launcher (a terminal still opens with Super+Shift+Return):

```
B=$(cat ~/.cache/ink-try-last-backup); [ -d "$B" ] || { echo "no backup at '$B': nothing restored"; exit 1; }
for d in sway eww mako fuzzel swaylock alacritty zellij; do
  if [ -e "$B/$d" ]; then rm -rf ~/.config/$d && cp -a "$B/$d" ~/.config/$d      # what was there before
  elif [ -e "$B/$d.absent" ]; then rm -rf ~/.config/$d; fi                       # it did not exist before the try
done
rm -f ~/.config/ink/sway.d/90-try.conf; [ -e "$B/90-try.conf" ] && cp -a "$B/90-try.conf" ~/.config/ink/sway.d/
rm -rf ~/.local/share/fonts/ink-try; fc-cache -f
swaymsg reload; makoctl reload
rm -f ~/.cache/ink-try-last-backup      # the backup folder itself stays until the owner removes it
```

Apply: copy the branch's `sway`, `eww`, `mako`, `fuzzel`, `swaylock` directories over the live ones, keeping the owner's own files that the image does not ship (`~/.config/ink/` is theirs: never replace it; only add `sway.d/90-try.conf` for the wallpaper path, and remove it at the end of the try). Terminal colours (`alacritty`, `zellij`) only if the owner wants them tried: those directories often hold their own settings, so merge the colour section by hand instead of replacing the file. Fonts into `~/.local/share/fonts/ink-try/`, then `fc-cache -f`. Then `swaymsg reload` and `makoctl reload`.

Check at once: `swaymsg -t get_version` answers, `eww active-windows` lists a bar or a dock for every screen, `eww logs` shows no error. If the bar is missing after ten seconds, restore without waiting to be asked, then report.

The owner looks and decides: keep it until the image update brings it for real, or go back. Either way, say exactly what is now in their home that the image did not put there (the try's files), so nothing is forgotten when the real update arrives. `ink-sync` after the image update replaces all of it with the image's own copy.

## 3. Push and open the pull request

Only for a branch the owner asked to be published, never to `main`, never a force push.

```
git push -u origin "$(git branch --show-current)"
```

The pull request's text: if the branch's worktree has an untracked `PR_BODY.md`, use it (and delete it afterwards); otherwise write one from the specification: what changes, what does not, how it was checked (the static script; the headless session; the live try or not), what was **not** checked (the image build, a VM), and the new screenshots.

```
gh pr view --json number,isDraft,url 2>/dev/null     # a pull request may already be open for the branch
gh pr create --base main --title "<one line>" --body-file PR_BODY.md
```

If the pull request already exists, do not open another: the push above adds your commits to it. Tick what you checked in its list of things not checked yet (`gh pr edit --body-file`), add what you found, and leave it a draft until the owner has seen the headless result; `gh pr ready` is theirs to ask for.

Without `gh`: give the owner the compare link that `git push` printed and the text to paste.

Do not merge. The repository's rule is that the owner tries the built image in a VM (`just build`, `just run-vm-qcow2`) before merging to `main`, because `main` is what their machine installs at its next update.

## 4. Report

- What the headless run showed: errors found and fixed (with commits), points confirmed, points still open.
- The screenshots committed, and anything in them that differs from the design.
- The live session: applied or not, kept or restored, and what remains in the home.
- The pull request's link.
- The working headless invocation, now recorded in section 1.
