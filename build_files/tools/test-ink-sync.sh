#!/usr/bin/env bash
# Tests of ink-sync's alacritty step: fixture files in temporary homes, each result compared with the expected text,
# parsed as TOML (python3's tomllib), and a second run that must change nothing. Run by `just check`.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../.." && pwd)
sync="$root/build_files/system_files/usr/bin/ink-sync"
skel="$root/build_files/system_files/etc/skel/.config"
colors=/usr/share/ink/alacritty/colors.toml
imp="import = [\"$colors\"]"

command -v python3 >/dev/null || { echo "FAIL: python3 not found (the step relies on it)" >&2; exit 1; }
python3 -c 'import tomllib' 2>/dev/null || { echo "FAIL: python3 has no tomllib (3.11+ needed)" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
n=0

# run <home>: ink-sync with the checkout's skel in that home; its output in <home>/out
run() { HOME="$1" INK_SKEL="$skel" bash "$sync" >"$1/out" 2>&1; }
cfg_of() { echo "$1/.config/alacritty/alacritty.toml"; }
parses() { python3 -I -c 'import sys, tomllib; tomllib.loads(open(sys.argv[1], encoding="utf-8").read())' "$1" 2>/dev/null; }
same() { cmp -s "$1" "$2"; }
backups() { find "$1/.config/alacritty" -maxdepth 1 -name 'alacritty.toml.bak-*' | wc -l; }
ok() { n=$((n + 1)); echo "  ok: $1"; }
bad() { n=$((n + 1)); fails=$((fails + 1)); echo "  FAIL: $1" >&2; }

# case <name> <fixture text or "-" for no file> <expected text> <expected word in the output> <backups expected>
case_() {
    local name=$1 fixture=$2 expected=$3 word=$4 nbak=$5
    local h="$tmp/$name" cfg
    mkdir -p "$h/.config/alacritty"
    cfg=$(cfg_of "$h")
    [[ $fixture == - ]] || printf '%s' "$fixture" >"$cfg"
    printf '%s' "$expected" >"$h/expected"
    run "$h" || { bad "$name: ink-sync exited with an error ($(tail -1 "$h/out"))"; return; }
    if ! same "$cfg" "$h/expected"; then bad "$name: unexpected result"; diff "$h/expected" "$cfg" >&2 || true; return; fi
    if [[ $fixture != - ]] && ! parses "$cfg"; then
        # a fixture that was not valid TOML must come back untouched; that is checked by the comparison above
        [[ $name == invalid ]] || { bad "$name: the result does not parse"; return; }
    elif ! parses "$cfg"; then bad "$name: the result does not parse"; return; fi
    grep -q -- "$word" "$h/out" || { bad "$name: the output does not say '$word'"; cat "$h/out" >&2; return; }
    [[ $(backups "$h") == "$nbak" ]] || { bad "$name: $(backups "$h") backups, expected $nbak"; return; }
    if [[ $nbak == 1 ]]; then
        same "$(find "$h/.config/alacritty" -maxdepth 1 -name 'alacritty.toml.bak-*')" <(printf '%s' "$fixture") ||
            { bad "$name: the backup is not the original file"; return; }
    fi
    # a second run changes nothing and keeps no further copy
    cp "$cfg" "$h/after1"
    run "$h" || { bad "$name: second run exited with an error"; return; }
    same "$cfg" "$h/after1" || { bad "$name: the second run changed the file"; return; }
    [[ $(backups "$h") == "$nbak" ]] || { bad "$name: the second run kept another copy"; return; }
    ok "$name"
}

echo "ink-sync, alacritty step"

case_ absent - "$(cat "$skel/alacritty/alacritty.toml")
" "installed" 0

plain='# mine
[window]
opacity = 0.9

[[keyboard.bindings]]
key = "N"
mods = "Control|Shift"
action = "SpawnNewInstance"
'
case_ plain "$plain" "$plain
[general]
$imp
" "now imports" 1

withgeneral='[general]
live_config_reload = true

[window]
opacity = 0.85
'
case_ general "$withgeneral" "[general]
$imp
live_config_reload = true

[window]
opacity = 0.85
" "now imports" 1

withimport='[general]
import = ["~/.config/alacritty/themes/mine.toml"]  # my theme

[font]
size = 11
'
case_ import "$withimport" "[general]
import = [\"$colors\", \"~/.config/alacritty/themes/mine.toml\"]  # my theme

[font]
size = 11
" "now imports" 1

oldimport='import = ["/home/someone/extra.toml"]

[window]
opacity = 0.95
'
case_ old-import "$oldimport" "import = [\"$colors\", \"/home/someone/extra.toml\"]

[window]
opacity = 0.95
" "now imports" 1

owncolours='[colors.primary]
background = "#000000"
'
case_ own-colours "$owncolours" "$owncolours
[general]
$imp
" "take precedence" 1

already="[general]
$imp

[window]
opacity = 0.9
"
case_ already "$already" "$already" "already imports" 0

emptylist='[general]
import = []
'
case_ empty-list "$emptylist" "[general]
import = [\"$colors\"]
" "now imports" 1

multiline='[general]
import = [
  "a.toml",
]
'
case_ multi-line "$multiline" "$multiline" "add to it" 0

invalid='[window
opacity = 0.9
'
case_ invalid "$invalid" "$invalid" "not valid TOML" 0

# a symbolic link: left as it is, the line to add printed
h="$tmp/link"; mkdir -p "$h/.config/alacritty" "$h/dotfiles"
printf '[window]\nopacity = 0.8\n' >"$h/dotfiles/alacritty.toml"
ln -s "$h/dotfiles/alacritty.toml" "$(cfg_of "$h")"
if run "$h" && [[ -L $(cfg_of "$h") ]] && [[ $(cat "$h/dotfiles/alacritty.toml") == $'[window]\nopacity = 0.8' ]] &&
    grep -q "symbolic link" "$h/out" && grep -qF "$imp" "$h/out" && [[ $(backups "$h") == 0 ]]; then
    ok "link"
else
    bad "link"; cat "$h/out" >&2
fi

echo
if ((fails)); then echo "$fails of $n tests failed" >&2; exit 1; fi
echo "all $n tests passed"
