#!/usr/bin/env bash
# `bxrig keys show|render`: pure output, no files written. Usage: keys-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
out="$("$binary" keys show)"
[[ "$out" == *"Super+C"* && "$out" == *"Super+Shift+Q"* ]] || fail 'show lists the shortcuts'
"$binary" keys show --json | jq -e '.command == "keys show" and .ok and (.data.shortcuts | length) > 100' >/dev/null || fail 'show --json envelope'
# one unbound row per Control Center page: no keys, not rendered, never a conflict
"$binary" keys show --json | jq -e '[.data.shortcuts[] | select(.id | startswith("tui-"))] | length == 20 and all(.keys == "")' >/dev/null || fail 'tui rows are unbound'
"$binary" keys render hyprland | grep -q 'tui databases' && fail 'an unbound row was rendered' || true
"$binary" keys conflicts --json | jq -e '(.data.within | length) == 0' >/dev/null || fail 'unbound rows are not conflicts'
"$binary" keys render xremap | grep -q 'Super-c: Ctrl-Shift-c' || fail 'xremap terminal rule'
"$binary" keys render hyprland | grep -q 'uwsm stop' || fail 'hyprland logout bind'
"$binary" keys render plasma | grep -q 'Log Out=Meta+Shift+Q' || fail 'plasma logout shortcut'
"$binary" keys render xremap --json | jq -e '.data.target == "xremap"' >/dev/null || fail 'render --json'
set +e; "$binary" keys render bogus >/dev/null 2>&1; c=$?; "$binary" keys >/dev/null 2>&1; d=$?; set -e
[[ "$c" == 2 && "$d" == 2 ]] || fail "bad usage exits 2 (got $c, $d)"
# Toggle top bar (Omarchy 4.5: Super+Shift+Space) runs `appearance bar toggle`, is listed, and clashes with nothing in either style
mkdir -p "$tmp/home"
for style in traditional mac; do
	env HOME="$tmp/home" "$binary" keys style "$style" --yes >/dev/null 2>&1 || fail "keys style $style"
	env HOME="$tmp/home" "$binary" keys show --json | jq -e '[.data.shortcuts[] | select(.id == "bar-toggle" and .keys == "Super+Shift+Space")] | length == 1' >/dev/null || fail "$style: the Toggle top bar row"
	env HOME="$tmp/home" "$binary" keys render hyprland | grep -Fq 'mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd([[sh -c '"'"'PATH="$HOME/.local/bin:$PATH"; bxrig appearance bar toggle'"'"']]))' || fail "$style: the Hyprland bind runs appearance bar toggle"
	env HOME="$tmp/home" "$binary" keys conflicts --json | jq -e '.data.ok == true and (.data.within | length) == 0' >/dev/null || fail "$style: keys conflicts is not clean"
done
echo "keys tests passed"
