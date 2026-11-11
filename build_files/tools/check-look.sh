#!/usr/bin/env bash
# Static checks of the Pixel Guild look (docs/specs/0001-pixel-guild-look.md, "Acceptance"). Nothing can be rendered
# where this runs, so these checks read the files; the first real run of the desktop is on a machine with sway and eww.
#
#   check-look.sh            run every check whose tool is present; a check whose tool is missing prints
#                            "SKIPPED (<tool> not found)" and does not fail the run (what `just check` does)
#   check-look.sh --strict   a missing tool is a failure too: every check must run (the acceptance mode)
#
# Stops at the first real failure. Tools: python3 and git (most checks), grass (the Sass compiler eww embeds:
# cargo install grass --locked), fc-scan, dnf with network access (the font packages), shellcheck. Tools can be named
# by path: GRASS=/path/to/grass SHELLCHECK=/path/to/shellcheck. BASE_REF is what the bindings, the eww windows and
# commands, and the changed scripts are compared with; by default the merge base of HEAD and origin/main (or main).
set -euo pipefail

strict=0
case "${1:-}" in
    --strict) strict=1 ;;
    "") ;;
    *) echo "usage: check-look.sh [--strict]" >&2; exit 2 ;;
esac

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../.." && pwd)
eww="$root/build_files/system_files/etc/skel/.config/eww"
GRASS=${GRASS:-grass}
SHELLCHECK=${SHELLCHECK:-shellcheck}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

skipped=0
step() { printf '\n[%s] %s\n' "$1" "$2"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
# skip <what is missing>: a failure under --strict, a SKIPPED line otherwise
skip() {
    if ((strict)); then fail "$1 (--strict: every check must run)"; fi
    printf '  SKIPPED (%s)\n' "$1"
    skipped=$((skipped + 1))
}
# needs <tool>...: true when every tool is present, else skips the step
needs() {
    local t
    for t in "$@"; do have "$t" || { skip "$t not found"; return 1; }; done
}
check() { python3 -I "$here/check-look.py" --root "$root" --base "$BASE_REF" "$@" || fail "check '$1'"; }

BASE_REF=${BASE_REF:-}
if [[ -z $BASE_REF ]] && have git; then
    for ref in origin/main main; do
        if git -C "$root" rev-parse --verify --quiet "$ref^{commit}" >/dev/null; then
            BASE_REF=$(git -C "$root" merge-base HEAD "$ref") && break
        fi
    done
fi
if have git && [[ -n $BASE_REF ]]; then
    git -C "$root" rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null || fail "no commit $BASE_REF (set BASE_REF)"
    echo "comparing with $BASE_REF"
elif have git; then
    fail "neither origin/main nor main exists: set BASE_REF"
fi

step 1 "eww.scss compiles with grass"
if needs "$GRASS"; then
    "$GRASS" --load-path "$eww" "$eww/eww.scss" >"$tmp/eww.css" || fail "grass could not compile eww.scss"
    [[ -s $tmp/eww.css ]] || fail "grass produced nothing"
    echo "  ok: $(wc -l <"$tmp/eww.css") lines of CSS"
fi

step 2 "no colour literal in eww.scss and eww.yuck, GTK 3 CSS only"
needs python3 && check colours

step 3 "_tokens.scss holds the table's values"
needs python3 && check tokens

step 4 "eww.yuck: balanced, widgets defined and used, windows kept, icons present"
needs python3 git && check yuck

step 5 "icons: well-formed, on their grid, token colours"
needs python3 && check svg

step 6 "sway: bindings unchanged, no blur, square corners, no layer effects, shadow radius"
needs python3 git && check sway

step 7 "no old palette value under etc/skel/.config"
needs python3 && check palette

step 8 "the wallpaper script gives the committed PNG, 3840x2160"
if needs python3 cmp; then
    png="$root/build_files/system_files/usr/share/backgrounds/ink/ink-pixel-dusk.png"
    python3 -I "$here/pixel-wallpaper.py" "$tmp/run1.png" || fail "pixel-wallpaper.py failed"
    python3 -I "$here/pixel-wallpaper.py" "$tmp/run2.png" || fail "pixel-wallpaper.py failed"
    cmp -s "$tmp/run1.png" "$tmp/run2.png" || fail "two runs of pixel-wallpaper.py differ"
    cmp -s "$tmp/run1.png" "$png" || fail "pixel-wallpaper.py does not give the committed ink-pixel-dusk.png"
    echo "  ok: two runs give the committed bytes"
    check png-size "$png" 3840 2160
fi

step 9 "fonts: TrueType or OpenType only, fontconfig and Pango read them, the packages exist in Fedora"
fontdir="$root/build_files/system_files/usr/share/fonts"
# The desktop's text renderer (Pango) loads TrueType and OpenType only: fontconfig lists a web font file (.woff2) but
# nothing ever draws it. So a shipped font is .ttf or .otf; beside them, only licence texts.
fontfiles=()
while IFS= read -r -d '' f; do
    case $f in
        *.ttf | *.otf) fontfiles+=("$f") ;;
        *.txt) ;;
        *) fail "${f#"$root"/}: not a TrueType or OpenType font (the desktop's text renderer, Pango, loads only .ttf and .otf)" ;;
    esac
done < <(find "$fontdir" -type f -print0 2>/dev/null)
((${#fontfiles[@]} > 0)) || fail "no font file shipped under usr/share/fonts"
echo "  ok: ${#fontfiles[@]} font file(s), all TrueType or OpenType"
families=()
if needs fc-scan; then
    for f in "${fontfiles[@]}"; do
        fam=$(fc-scan --format '%{family}' "$f" 2>/dev/null) || fail "fc-scan cannot read ${f#"$root"/}"
        [[ -n $fam ]] || fail "fc-scan reports no family for ${f#"$root"/}"
        families+=("${fam%%,*}")
        echo "  ok: ${f#"$root"/}: $(fc-scan --format 'family=%{family} style=%{style} weight=%{weight}' "$f")"
    done
fi
if ((${#families[@]} > 0)) && needs pango-list; then
    # Pango with a fontconfig that knows only the shipped fonts: each family must be listed with a face of its own (a
    # face marked * is synthesised by Pango)
    iso="$tmp/fontconfig"
    mkdir -p "$iso/fonts" "$iso/home" "$iso/cache"
    cp "${fontfiles[@]}" "$iso/fonts/"
    printf '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">\n<fontconfig><dir>%s</dir><cachedir>%s</cachedir></fontconfig>\n' \
        "$iso/fonts" "$iso/cache" >"$iso/fonts.conf"
    env -u XDG_CONFIG_HOME -u XDG_CACHE_HOME -u XDG_DATA_HOME HOME="$iso/home" FONTCONFIG_FILE="$iso/fonts.conf" \
        pango-list >"$iso/pango.txt" 2>/dev/null || fail "pango-list failed"
    mapfile -t uniq < <(printf '%s\n' "${families[@]}" | sort -u)
    for fam in "${uniq[@]}"; do
        faces=$(awk -v fam="$fam" '
            index($0, fam " ") == 1 || $0 == fam { on = 1; next }
            on && /^[^ \t]/ { on = 0 }
            on && $1 !~ /^\*/ { sub(/^[ \t]+/, ""); print }' "$iso/pango.txt")
        [[ -n $faces ]] || fail "pango-list does not list '$fam' with a face of its own: the desktop would never draw it"
        echo "  ok: pango-list lists $fam: $(tr '\n' ';' <<<"$faces" | sed 's/;$//')"
    done
fi
if needs dnf; then
    # the package lines of the dnf5 install list ("    name-fonts \")
    mapfile -t pkgs < <(grep -E '^[[:space:]]+[a-z0-9-]+-fonts[[:space:]]*\\?$' "$root/build_files/build.sh" | awk '{print $1}' | sort -u)
    ((${#pkgs[@]} > 0)) || fail "no *-fonts package in build.sh"
    # a package every Fedora repository has: without it, the repositories cannot be read (no network)
    if [[ $(dnf repoquery --quiet --qf '%{name}\n' bash 2>/dev/null | sort -u) != bash ]]; then
        skip "the Fedora repositories cannot be read (no network?)"
    else
        for p in "${pkgs[@]}"; do
            found=$(dnf repoquery --quiet --qf '%{name}\n' "$p" 2>/dev/null | sort -u)
            [[ $found == "$p" ]] || fail "package $p not found in the enabled Fedora repositories"
            echo "  ok: package $p exists"
        done
    fi
fi

step 10 "shellcheck on the shell scripts added or changed since $BASE_REF"
if needs "$SHELLCHECK" git; then
    scripts=()
    while IFS= read -r f; do
        [[ -f $root/$f ]] || continue
        if [[ $f == *.sh ]] || head -n1 "$root/$f" | grep -qE '^#!.*\b(ba)?sh\b'; then scripts+=("$root/$f"); fi
    done < <({ git -C "$root" diff --name-only --diff-filter=AMR "$BASE_REF" -- build_files
              git -C "$root" ls-files --others --exclude-standard -- build_files; } | sort -u)
    if ((${#scripts[@]} == 0)); then
        echo "  ok: no shell script changed"
    else
        "$SHELLCHECK" "${scripts[@]}" || fail "shellcheck"
        for s in "${scripts[@]}"; do echo "  ok: ${s#"$root"/}"; done
    fi
fi

step 11 "colours copied into sway, mako, fuzzel, swaylock, alacritty and zellij are opaque token values"
needs python3 && check copied

step 12 "every key of swaylock, mako, fuzzel and the sway look section is a known one"
needs python3 && check keys

step 13 "the commands of eww.yuck's :on... attributes are the same as $BASE_REF's"
needs python3 git && check commands

step 14 "every name an eww.yuck expression reads is defined, every expression has a plausible shape"
needs python3 && check variables

if ((skipped)); then
    printf '\nall checks that could run passed; %d skipped (run with --strict to require every tool)\n' "$skipped"
else
    printf '\nall checks passed\n'
fi
