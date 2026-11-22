#!/usr/bin/env bash
# `bxrig accessibility` with a fake hyprctl and gsettings: off by default, zoom keys that only hint while off, zoom steps on Hyprland,
# reduce motion, contrast with --dry-run, status --json. Usage: accessibility-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg" "$tmp/state"; export LOG="$tmp/log"; : > "$LOG"
stub hyprctl 'echo "hyprctl $*" >> "$LOG"; exit 0'
stub gsettings 'echo "gsettings $*" >> "$LOG"; exit 0'
stub noctalia 'echo "noctalia $*" >> "$LOG"; exit 0'
run() { env BXRIG_SELF="$binary" HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" HYPRLAND_INSTANCE_SIGNATURE="${HYPR-x}" XDG_CURRENT_DESKTOP="${DESKTOP-Hyprland}" "$@"; }

# off by default
run "$binary" accessibility --json | jq -e '.ok and .data.zoom == "off" and .data.reduce_motion == "off" and .data.contrast == "off"' >/dev/null || fail 'all off by default'
run "$binary" accessibility | grep -q 'Zoom:          off' || fail 'status text'
# a zoom key while zoom is off: a hint, exit 0, nothing run
out="$(run "$binary" accessibility zoom in)"; [[ "$out" == *"Zoom is off"* ]] || fail "key while off: $out"
[[ ! -s "$LOG" ]] || fail "key while off ran something: $(cat "$LOG")"
# on, then the keys
[[ "$(code "$binary" accessibility zoom on)" == 0 ]] || fail 'zoom on'
run "$binary" accessibility zoom status --json | jq -e '.data.zoom == "on"' >/dev/null || fail 'zoom on is saved'
run "$binary" accessibility zoom in >/dev/null; run "$binary" accessibility zoom in >/dev/null
grep -q 'hyprctl eval hl.config({ cursor = { zoom_factor = 2.0 } })' "$LOG" || fail "two steps in: $(cat "$LOG")"
run "$binary" accessibility zoom toggle >/dev/null
tail -n 1 "$LOG" | grep -q 'zoom_factor = 1.0' || fail 'toggle goes back to 1'
run "$binary" accessibility zoom toggle >/dev/null
tail -n 1 "$LOG" | grep -q 'zoom_factor = 2.0' || fail 'toggle again returns to the last zoom'
run "$binary" accessibility zoom out --dry-run --json | jq -e '.dry_run and .data.zoom_level == 1.5 and (.data.commands[0] | contains("zoom_factor = 1.5"))' >/dev/null || fail 'zoom out dry run'
[[ "$(code "$binary" accessibility zoom sideways)" == 2 ]] || fail 'bad action exits 2'
[[ "$(code "$binary" accessibility zoom off)" == 0 ]] || fail 'zoom off'
tail -n 1 "$LOG" | grep -q 'zoom_factor = 1.0' || fail 'zoom off zooms out'
# no desktop: a key says it needs Hyprland or Plasma (exit 4) once zoom is on
run "$binary" accessibility zoom on >/dev/null
[[ "$(HYPR= DESKTOP= code "$binary" accessibility zoom in)" == 4 ]] || fail 'no desktop exits 4'
# reduce motion: the plan, then GTK through gsettings
run "$binary" accessibility reduce-motion on --dry-run --json | jq -e '.dry_run and (.data.commands | index("bxrig appearance animations off") != null)' >/dev/null || fail 'reduce motion dry run'
: > "$LOG"
[[ "$(code "$binary" accessibility reduce-motion on)" == 0 ]] || fail 'reduce motion on'
grep -q 'gsettings set org.gnome.desktop.interface enable-animations false' "$LOG" || fail "gsettings: $(cat "$LOG")"
grep -q 'noctalia msg config-set shell.animation.enabled false' "$LOG" || fail "noctalia animations: $(cat "$LOG")"
run "$binary" accessibility --json | jq -e '.data.reduce_motion == "on"' >/dev/null || fail 'reduce motion saved'
# contrast: the plan names the theme
run "$binary" accessibility contrast colorblind --dry-run --json | jq -e '.dry_run and .data.theme == "bxrig-colorblind" and .data.command == "bxrig theme set bxrig-colorblind"' >/dev/null || fail 'contrast dry run'
[[ "$(code "$binary" accessibility contrast purple)" == 2 ]] || fail 'unknown contrast exits 2'
echo "accessibility tests passed"
