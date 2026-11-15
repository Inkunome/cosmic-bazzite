#!/usr/bin/env bash
# Test of the sound panel's default-device path (eww/scripts/audio and its button in eww.yuck), against a fake audio
# server: stub pactl, wpctl and eww placed first in PATH, a sink whose name and description are hostile (a quote, a
# separator and a command that would create a marker file). Nothing touches a real audio server.
#
#   test-audio.sh [SCRIPT [YUCK]]   SCRIPT defaults to the repository's eww/scripts/audio, YUCK to its eww.yuck
#
# Prints one line per assertion and exits 1 when any fails. Needs bash, jq, sed, grep (run by check-look.sh).
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../.." && pwd)
eww="$root/build_files/system_files/etc/skel/.config/eww"
script=$(realpath "${1:-$eww/scripts/audio}")
yuck=$(realpath "${2:-$eww/eww.yuck}")

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.config/eww/scripts"
ln -s "$script" "$tmp/home/.config/eww/scripts/audio"
marker="$tmp/marker"

failed=0
ok() { printf '  ok: %s\n' "$*"; }
bad() { printf '  FAIL: %s\n' "$*"; failed=$((failed + 1)); }

# the fake server: sink 47 is hostile, sink 52 is plain, source 60 is a microphone, source 61 a sink's monitor; the
# sources also carry indexes that must never become an id (spelled 47.0, past 32 bits, the invalid index, negative)
# and the largest valid one, 4294967294
hostile_name="evil'; touch $marker; echo '"
hostile_desc="Speaker\$(touch $marker)'; touch $marker #"
json_str() { jq -Rn --arg s "$1" '$s'; }
cat >"$tmp/sinks.json" <<EOF
[{"index": 47, "name": $(json_str "$hostile_name"), "description": $(json_str "$hostile_desc"), "properties": {}},
 {"index": 52, "name": "alsa_output.plain", "description": "Plain speakers", "properties": {}}]
EOF
cat >"$tmp/sources.json" <<EOF
[{"index": 60, "name": "alsa_input.mic", "description": "Microphone", "properties": {}},
 {"index": 61, "name": "alsa_output.plain.monitor", "description": "Monitor of Plain speakers", "properties": {}},
 {"index": 47.0, "name": "alsa_input.float", "description": "Float index", "properties": {}},
 {"index": 4294967296, "name": "alsa_input.overflow", "description": "Overflowing index", "properties": {}},
 {"index": 4294967295, "name": "alsa_input.invalid", "description": "Invalid index", "properties": {}},
 {"index": -1, "name": "alsa_input.negative", "description": "Negative index", "properties": {}},
 {"index": 4294967294, "name": "alsa_input.last", "description": "Last index", "properties": {}}]
EOF

# every pactl call is logged as its arguments separated by spaces; set-default calls also go to set.log
cat >"$tmp/bin/pactl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$FAKE/pactl.log"
args=("$@")
[[ ${args[0]:-} == -- ]] && args=("${args[@]:1}")
case "${args[*]}" in
    "-f json list sinks") cat "$FAKE/sinks.json" ;;
    "-f json list sources") cat "$FAKE/sources.json" ;;
    get-default-sink) echo alsa_output.plain ;;
    get-default-source) echo alsa_input.mic ;;
    set-default-sink* | set-default-source*) printf '%s\n' "$*" >>"$FAKE/set.log" ;;
    *) echo "fake pactl: unexpected call: $*" >&2; exit 1 ;;
esac
EOF
cat >"$tmp/bin/wpctl" <<'EOF'
#!/bin/bash
[[ ${1:-} == get-volume ]] && echo "Volume: 0.50"
exit 0
EOF
cat >"$tmp/bin/eww" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$FAKE/eww.log"
EOF
chmod +x "$tmp/bin/pactl" "$tmp/bin/wpctl" "$tmp/bin/eww"

export FAKE="$tmp" HOME="$tmp/home" PATH="$tmp/bin:$PATH"

reset_logs() { rm -f "$tmp/pactl.log" "$tmp/set.log" "$tmp/eww.log" "$marker"; }
lines() { [[ -f $1 ]] && wc -l <"$1" || echo 0; }

echo "audio devices"
reset_logs
if out=$("$script" devices 2>/dev/null) && jq -e . >/dev/null 2>&1 <<<"$out"; then
    if jq -e '[.sinks[], .sources[]] | length > 0 and all(.id | type == "number")' >/dev/null <<<"$out"; then
        ok "every device has a numeric id"
    else
        bad "a device has no numeric id: $out"
    fi
    if jq -e '[.sinks[].id] == [47, 52] and [.sources[].id] == [60, 4294967294]' >/dev/null <<<"$out"; then
        ok "the ids are the server's indexes (47, 52; 60, 4294967294; the monitor and the four bad indexes left out)"
    else
        bad "the ids are not the server's indexes: $out"
    fi
    if jq -e '[.sinks[], .sources[]] | all(keys == ["default", "desc", "id"])' >/dev/null <<<"$out"; then
        ok "every device has exactly id, desc and default (no name)"
    else
        bad "a device has other fields than id, desc and default: $out"
    fi
    if jq -e '[.sinks[], .sources[]] | map(.default) == [false, true, true, false]' >/dev/null <<<"$out"; then
        ok "the defaults are the server's (sink 52, source 60)"
    else
        bad "the defaults are not the server's: $out"
    fi
else
    bad "audio devices did not print JSON"
    out='{"sinks":[],"sources":[]}'
fi

echo "the button's command, as eww runs it (/bin/sh -c) for the hostile sink"
# the command template of the default-device button, with ${kind} and ${d.FIELD} substituted the way eww does
template=$(grep -o ':onclick "~/.config/eww/scripts/audio default [^"]*"' "$yuck" | head -n1 | sed 's/^:onclick "//; s/"$//')
if [[ -z $template ]]; then
    bad "no default-device button in $yuck"
else
    cmd=$template
    # the literal placeholder ${kind} of the eww template is meant, not a shell expansion
    # shellcheck disable=SC2016
    cmd=${cmd//'${kind}'/sink}
    while [[ $cmd =~ \$\{d\.([a-z]+)\} ]]; do
        field=${BASH_REMATCH[1]}
        value=$(jq -r --arg f "$field" '.sinks[] | select(.desc | startswith("Speaker")) | .[$f]' <<<"$out")
        cmd=${cmd//"\${d.$field}"/"$value"}
    done
    # the literal text ${ is searched for in the substituted command, not expanded
    # shellcheck disable=SC2016
    if [[ $cmd == *'${'* ]]; then
        bad "the button substitutes something this test does not know: $template"
    else
        reset_logs
        /bin/sh -c "$cmd" >/dev/null 2>&1
        if [[ -e $marker ]]; then bad "the hostile name ran a command (marker file created)"; else ok "no marker file"; fi
        if [[ $(cat "$tmp/set.log" 2>/dev/null) == "-- set-default-sink 47" ]]; then
            ok "the default was set once, to sink 47"
        else
            bad "the default was not set once to sink 47 (set calls: $(tr '\n' '|' <"$tmp/set.log" 2>/dev/null))"
        fi
    fi
fi

echo "audio default refuses, with no change of default"
# refused <why> <kind> <id> [list]: non-zero exit, no set-default call, no marker; "early" also wants no pactl call at all
refused() {
    local why=$1 kind=$2 id=$3 when=${4:-early}
    reset_logs
    if "$script" default "$kind" "$id" >/dev/null 2>&1; then
        bad "$why: exit 0"
        return
    fi
    if [[ -e $marker ]]; then bad "$why: the marker file was created"; return; fi
    if (($(lines "$tmp/set.log") > 0)); then bad "$why: set-default was called ($(tr '\n' '|' <"$tmp/set.log"))"; return; fi
    if [[ $when == early ]] && (($(lines "$tmp/pactl.log") > 0)); then
        bad "$why: pactl ran before the argument was refused ($(tr '\n' '|' <"$tmp/pactl.log"))"
        return
    fi
    ok "$why"
}
refused "the hostile name itself" sink "$hostile_name"
refused "an empty id" sink ""
refused "digits followed by letters" sink "47abc"
refused "digits followed by a separator and a command" sink "47; touch $marker"
refused "digits followed by a space" sink "47 "
refused "digits followed by a newline" sink $'47\n'
refused "a negative number" sink "-47"
refused "a name that is an option" sink "--server=unix:$tmp/x"
refused "a kind that is neither sink nor source" speaker 47
refused "an id that is not in the list" sink 99 listed
refused "a source's id given for a sink" sink 60 listed
refused "a sink's id given for a source" source 47 listed
refused "the id of a sink's monitor given for a source" source 61 listed
refused "an id with a leading zero" sink 047 listed
refused "the float spelling 47.0" source 47.0
refused "47, for a source whose index is spelled 47.0" source 47 listed
refused "an index past 32 bits" source 4294967296 listed
refused "the invalid index 4294967295" source 4294967295 listed
refused "the negative index -1" source -1
reset_logs
if "$script" default sink 47 extra >/dev/null 2>&1 || (($(lines "$tmp/set.log") > 0)); then
    bad "an extra argument: accepted"
else
    ok "an extra argument"
fi

echo "audio default accepts a listed id"
for case in "sink 52" "source 60" "source 4294967294"; do
    read -r kind id <<<"$case"
    reset_logs
    if "$script" default "$kind" "$id" >/dev/null 2>&1; then
        if [[ $(cat "$tmp/set.log" 2>/dev/null) == "-- set-default-$kind $id" ]]; then
            ok "$kind $id set once"
        else
            bad "$kind $id: set calls were: $(tr '\n' '|' <"$tmp/set.log" 2>/dev/null)"
        fi
    else
        bad "$kind $id: refused"
    fi
done

if ((failed)); then
    printf '%d assertion(s) failed\n' "$failed"
    exit 1
fi
echo "all assertions passed"
