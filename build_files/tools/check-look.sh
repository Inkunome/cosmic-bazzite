#!/usr/bin/env bash
# Static checks of the Pixel Guild look (docs/specs/0001-pixel-guild-look.md, "Acceptance"). Nothing can be rendered
# where this runs, so these checks read the files; the first real run of the desktop is on a machine with sway and eww.
# Stops at the first failure.
#
# Needs: python3, git, grass (the Sass compiler eww embeds: cargo install grass --locked), fc-scan, dnf (with network,
# to look up the font packages) and shellcheck. Tools can be named by path:
#   GRASS=/path/to/grass SHELLCHECK=/path/to/shellcheck BASE_REF=main build_files/tools/check-look.sh
# BASE_REF is the branch the bindings, the eww windows and the changed scripts are compared with (default: main).
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../.." && pwd)
eww="$root/build_files/system_files/etc/skel/.config/eww"
GRASS=${GRASS:-grass}
SHELLCHECK=${SHELLCHECK:-shellcheck}
BASE_REF=${BASE_REF:-main}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

step() { printf '\n[%s] %s\n' "$1" "$2"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "$1 not found ($2)"; }
check() { python3 -I "$here/check-look.py" --root "$root" --base "$BASE_REF" "$@" || fail "check '$1'"; }

need python3 "the checks are written in Python"
need git "the bindings are compared with $BASE_REF"
git -C "$root" rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null || fail "no ref $BASE_REF (set BASE_REF)"

step 1 "eww.scss compiles with grass"
need "$GRASS" "cargo install grass --locked --root <dir>, then GRASS=<dir>/bin/grass"
"$GRASS" --load-path "$eww" "$eww/eww.scss" >"$tmp/eww.css" || fail "grass could not compile eww.scss"
[[ -s $tmp/eww.css ]] || fail "grass produced nothing"
echo "  ok: $(wc -l <"$tmp/eww.css") lines of CSS"

step 2 "no colour literal in eww.scss and eww.yuck, GTK 3 CSS only"
check colours

step 3 "_tokens.scss holds the table's values"
check tokens

step 4 "eww.yuck: balanced, widgets defined and used, icons present"
check yuck

step 5 "icons: well-formed, on their grid, token colours"
check svg

step 6 "sway: bindings unchanged, no blur, square corners, no layer effects"
check sway

step 7 "no old palette value under etc/skel/.config"
check palette

step 8 "the wallpaper script gives the committed PNG, 3840x2160"
png="$root/build_files/system_files/usr/share/backgrounds/ink/ink-pixel-dusk.png"
python3 -I "$here/pixel-wallpaper.py" "$tmp/run1.png" || fail "pixel-wallpaper.py failed"
python3 -I "$here/pixel-wallpaper.py" "$tmp/run2.png" || fail "pixel-wallpaper.py failed"
cmp -s "$tmp/run1.png" "$tmp/run2.png" || fail "two runs of pixel-wallpaper.py differ"
cmp -s "$tmp/run1.png" "$png" || fail "pixel-wallpaper.py does not give the committed ink-pixel-dusk.png"
echo "  ok: two runs give the committed bytes"
check png-size "$png" 3840 2160

step 9 "fonts: fontconfig reads the shipped files, the packages exist in Fedora"
need fc-scan "fontconfig"
fonts=0
while IFS= read -r -d '' f; do
    fonts=$((fonts + 1))
    fam=$(fc-scan --format '%{family}' "$f" 2>/dev/null) || fail "fc-scan cannot read ${f#"$root"/}"
    [[ -n $fam ]] || fail "fc-scan reports no family for ${f#"$root"/}"
    echo "  ok: ${f#"$root"/}: $(fc-scan --format 'family=%{family} style=%{style} weight=%{weight}' "$f")"
done < <(find "$root/build_files/system_files/usr/share/fonts" -type f \( -name '*.woff2' -o -name '*.woff' -o -name '*.ttf' -o -name '*.otf' \) -print0 2>/dev/null)
((fonts > 0)) || fail "no font file shipped under usr/share/fonts"
need dnf "the font package names are looked up in Fedora's repositories"
# the package lines of the dnf5 install list ("    name-fonts \")
mapfile -t pkgs < <(grep -E '^[[:space:]]+[a-z0-9-]+-fonts[[:space:]]*\\?$' "$root/build_files/build.sh" | awk '{print $1}' | sort -u)
((${#pkgs[@]} > 0)) || fail "no *-fonts package in build.sh"
for p in "${pkgs[@]}"; do
    found=$(dnf repoquery --quiet --qf '%{name}\n' "$p" 2>/dev/null | sort -u)
    [[ $found == "$p" ]] || fail "package $p not found in the enabled Fedora repositories"
    echo "  ok: package $p exists"
done

step 10 "shellcheck on the shell scripts added or changed since $BASE_REF"
need "$SHELLCHECK" "dnf install ShellCheck, or SHELLCHECK=<path>"
scripts=()
while IFS= read -r f; do
    [[ -f $root/$f ]] || continue
    if [[ $f == *.sh ]] || head -n1 "$root/$f" | grep -qE '^#!.*\b(ba)?sh\b'; then scripts+=("$root/$f"); fi
done < <({ git -C "$root" diff --name-only --diff-filter=AMR "$BASE_REF" -- build_files Justfile
          git -C "$root" ls-files --others --exclude-standard -- build_files; } | sort -u)
if ((${#scripts[@]} == 0)); then
    echo "  ok: no shell script changed"
else
    "$SHELLCHECK" "${scripts[@]}" || fail "shellcheck"
    for s in "${scripts[@]}"; do echo "  ok: ${s#"$root"/}"; done
fi

printf '\nall checks passed\n'
