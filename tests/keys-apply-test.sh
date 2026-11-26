#!/usr/bin/env bash
# `bxrig keys check|apply` and the shortcut files in `config`, with fake kreadconfig6/kwriteconfig6. Usage: keys-apply-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg" "$tmp/state" "$tmp/kg"
cat > "$tmp/bin/kreadconfig6" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == --version ]] && exit 0
[[ -f "$KG/${@: -1}" ]] && cat "$KG/${@: -1}" || true
MOCK
cat > "$tmp/bin/kwriteconfig6" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == --version ]] && exit 0
printf '%s' "${@: -1}" > "$KG/${@: -2:1}"
MOCK
stub_id
chmod +x "$tmp/bin/"*
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" KG="$tmp/kg" PATH="$tmp/bin:$PATH" "$@"; }

[[ "$(code "$binary" keys check)" == 1 ]] || fail 'check before apply exits 1'
[[ "$(code "$binary" keys apply)" == 2 ]] || fail 'apply without --yes exits 2'
[[ ! -e "$tmp/cfg/xremap/config.yml" ]] || fail 'apply without --yes wrote a file'
[[ "$(MOCK_UID=0 code "$binary" keys apply --yes)" == 4 ]] || fail 'root exits 4'
[[ "$(code "$binary" keys apply --yes --dry-run)" == 0 ]] || fail 'dry run exits 0'
[[ ! -e "$tmp/cfg/xremap/config.yml" && ! -s "$tmp/kg/Log Out" ]] || fail 'dry run changed something'
[[ "$(code "$binary" keys apply --yes)" == 0 ]] || fail 'apply --yes exits 0'
grep -q 'Super-c: Ctrl-Shift-c' "$tmp/cfg/xremap/config.yml" || fail 'xremap file written'
grep -q 'uwsm stop' "$tmp/cfg/hypr/bxrig.lua" || fail 'hypr file written'
[[ "$(cat "$tmp/kg/Log Out")" == "Meta+Shift+Q,Ctrl+Alt+Del,Log Out" ]] || fail 'plasma shortcut set'
[[ "$(code "$binary" keys check)" == 0 ]] || fail 'check after apply exits 0'
f="$(find "$tmp/cfg" -name keystyle.json | head -1)"; [[ -n "$f" ]] && jq -e '.style == "traditional"' "$f" >/dev/null || fail 'apply saves the style in effect (no keystyle.json before), so the xremap unit it writes does not turn the next run into Mac'
run "$binary" keys apply --yes >/dev/null; [[ "$(code "$binary" keys check)" == 0 ]] || fail 'a second apply keeps everything clean'
run "$binary" keys check --json | jq -e '.ok and (.data.items | length) == 5' >/dev/null || fail 'check --json'
run "$binary" config list | grep -q '^xremap: clean' || fail 'config list shows xremap'
[[ "$(code "$binary" keys apply --yes)" == 0 ]] || fail 're-run exits 0'
# hyprland.lua: the load line is added once, the rest of the file is kept byte for byte, and a backup is made
mkdir -p "$tmp/cfg/hypr"; printf -- '-- mine\n\thl.config({ x = 1 })' > "$tmp/cfg/hypr/hyprland.lua"
[[ "$(code "$binary" keys check)" == 1 ]] || fail 'hyprland.lua without the load line exits 1'
[[ "$(code "$binary" keys apply)" == 2 ]] || fail 'apply without --yes is a plan (exit 2) while the line is missing'
[[ "$(cat "$tmp/cfg/hypr/hyprland.lua")" == $'-- mine\n\thl.config({ x = 1 })' ]] || fail 'the plan changed hyprland.lua'
run "$binary" keys apply --yes --dry-run >/dev/null; [[ "$(grep -c 'require("bxrig")' "$tmp/cfg/hypr/hyprland.lua")" == 0 ]] || fail 'dry run changed hyprland.lua'
run "$binary" keys apply --yes >/dev/null || fail 'apply adds the line'
[[ "$(grep -c '^require("bxrig")$' "$tmp/cfg/hypr/hyprland.lua")" == 1 ]] || fail 'the load line is there once'
head -c 31 "$tmp/cfg/hypr/hyprland.lua" | grep -q $'^-- mine\n\thl.config({ x = 1 })' || fail 'the file kept your text and tab'
grep -q 'delete these two lines' "$tmp/cfg/hypr/hyprland.lua" || fail 'a comment says where the line came from'
find "$tmp" -path '*backups/hyprland.lua/*' -name '*.bak' | grep -q . || fail 'a backup of hyprland.lua was made'
[[ "$(code "$binary" keys check)" == 0 ]] || fail 'load line present exits 0'
run "$binary" keys apply --yes >/dev/null; [[ "$(grep -c 'require("bxrig")' "$tmp/cfg/hypr/hyprland.lua")" == 1 ]] || fail 'a second apply does not add it again'
printf -- '-- require("bxrig")\n' > "$tmp/cfg/hypr/hyprland.lua"
[[ "$(code "$binary" keys check)" == 1 ]] || fail 'a commented line does not count'
run "$binary" keys apply --yes >/dev/null; [[ "$(grep -c '^require("bxrig")$' "$tmp/cfg/hypr/hyprland.lua")" == 1 ]] || fail 'a commented line is not the load line'
# drift
echo '# mine' >> "$tmp/cfg/xremap/config.yml"
[[ "$(code "$binary" keys check)" == 1 ]] || fail 'drifted file exits 1'
[[ "$(code "$binary" keys apply --yes)" == 8 ]] || fail 'apply on drift exits 8 without --force'
grep -q '# mine' "$tmp/cfg/xremap/config.yml" || fail 'drift was overwritten without --force'
[[ "$(code "$binary" keys apply --yes --force)" == 0 ]] || fail '--force overwrites'
! grep -q '# mine' "$tmp/cfg/xremap/config.yml" || fail 'force did not overwrite'
echo "keys apply tests passed"
