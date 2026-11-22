#!/usr/bin/env bash
# `bxrig launcher` with a fake vicinae (version, ping, server, theme set, deeplink). Usage: launcher-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
export LOG="$tmp/log" UP="$tmp/up"; : > "$LOG"
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" XDG_DATA_HOME="$tmp/data" BXRIG_SELF=/opt/bxrig/bxrig PATH="$tmp/bin:$PATH" LOG="$LOG" UP="$UP" "$@"; }
mkdir -p "$tmp/bin"
themes="$tmp/data/vicinae/themes" scripts="$tmp/data/vicinae/scripts/bxrig"

# no vicinae yet
run "$binary" launcher --json | jq -e '.ok and .data.vicinae.installed == false and .data.scripts.count == 0' >/dev/null || fail 'status without vicinae'
[[ "$(code "$binary" launcher setup --yes)" == 4 ]] || fail 'setup without vicinae exits 4'
[[ "$(code "$binary" launcher files x)" == 4 ]] || fail 'files without vicinae exits 4'

stub vicinae 'echo "vicinae $*" >> "$LOG"
case "$1" in version) echo "v0.18.2" ;; ping) [[ -f "$UP" ]] ;; server) touch "$UP" ;; esac'
run "$binary" launcher --json | jq -e '.data.vicinae.installed and .data.vicinae.version == "v0.18.2" and .data.vicinae.running == false and .data.theme.written == false' >/dev/null || fail 'status with vicinae'
# setup: a plan first
[[ "$(code "$binary" launcher setup)" == 2 ]] && [[ ! -d "$scripts" ]] || fail 'setup without --yes is a plan'
run "$binary" launcher setup --dry-run --json | jq -e '(.data.steps | length) == 4' >/dev/null || fail 'the plan has four steps'
run "$binary" launcher setup --yes --json | jq -e '.ok' >/dev/null || fail 'setup'
grep -q '^vicinae server' "$LOG" && grep -q '^vicinae theme set bxrig' "$LOG" || fail "the server started and the theme selected: $(cat "$LOG")"
[[ -f "$themes/bxrig.toml" ]] && grep -q '^name = "BxRig"' "$themes/bxrig.toml" || fail 'the theme file'
[[ "$(ls "$scripts" | wc -l)" == 11 ]] && [[ -x "$scripts/agenda.sh" ]] || fail 'the script commands, executable'
grep -q '^BXRIG="/opt/bxrig/bxrig"' "$scripts/agenda.sh" || fail 'the scripts run this BxRig'
jq -e '.provider == "vicinae" and .menu_provider == "vicinae"' "$tmp/cfg/bxrig/runner.json" >/dev/null || fail 'vicinae is the launcher and the menu'
run "$binary" launcher setup --dry-run --json | jq -e '(.data.steps | length) == 2' >/dev/null || fail 'a second setup only rewrites the theme and the scripts'
# a theme switch rewrites the Vicinae theme and selects it again
: > "$LOG"; run "$binary" theme set bxrig-light >/dev/null
grep -q '^variant = "light"' "$themes/bxrig.toml" && grep -q '^vicinae theme set bxrig' "$LOG" || fail "theme set follows: $(cat "$LOG")"
# scripts: a command BxRig no longer offers is removed, yours elsewhere stay
touch "$scripts/old.sh"; mkdir -p "$tmp/data/vicinae/scripts/mine"; touch "$tmp/data/vicinae/scripts/mine/x.sh"
run "$binary" launcher scripts --yes >/dev/null; [[ ! -f "$scripts/old.sh" && -f "$tmp/data/vicinae/scripts/mine/x.sh" ]] || fail 'scripts rewrite'
[[ "$(code "$binary" launcher scripts remove)" == 2 ]] || fail 'scripts remove is a plan first'
run "$binary" launcher scripts remove --yes >/dev/null; [[ ! -d "$scripts" && -f "$tmp/data/vicinae/scripts/mine/x.sh" ]] || fail 'scripts remove deletes only BxRig'"'"'s'
# file search
run "$binary" launcher files my invoice >/dev/null; grep -q 'vicinae deeplink vicinae://launch/files/search?fallbackText=my%20invoice' "$LOG" || fail "files: $(tail -1 "$LOG")"
run "$binary" launcher files >/dev/null; tail -1 "$LOG" | grep -qx 'vicinae deeplink vicinae://launch/files/search' || fail 'files without a query'
[[ "$(code "$binary" launcher bogus)" == 2 ]] || fail 'an unknown subcommand is a usage error'
echo "launcher-test passed"
