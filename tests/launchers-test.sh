#!/usr/bin/env bash
# `bxrig launchers on|off|status`: one .desktop per Control Center page, opt-in, never over your edits. Fake terminal and a fake id. Usage: launchers-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg"
stub_id
for t in ghostty kitty; do printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/$t"; chmod +x "$tmp/bin/$t"; done
run() { env HOME="$tmp/home" XDG_DATA_HOME="$tmp/data" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" BXRIG_SELF=/opt/bxrig/bxrig PATH="$tmp/bin:$PATH" "$@"; }
apps="$tmp/data/applications"; icon="$tmp/data/icons/hicolor/256x256/apps/bxrig.png"

# nothing exists until you ask
run "$binary" launchers status --json | jq -e '.data.enabled == false and .data.present == 0 and .data.total == 32' >/dev/null || fail 'status before'
[[ "$(code "$binary" launchers on)" == 2 ]] || fail 'on without --yes is a plan (exit 2)'
[[ "$(code "$binary" launchers on --dry-run)" == 0 ]] || fail 'dry run exits 0'
[[ ! -e "$apps" && ! -e "$icon" ]] || fail 'a plan or dry run wrote files'
[[ "$(code "$binary" launchers)" == 0 ]] || fail 'bare launchers is status'
[[ "$(code "$binary" launchers nope)" == 2 ]] || fail 'unknown subcommand exits 2'
[[ "$(MOCK_UID=0 code "$binary" launchers on --yes)" == 4 ]] || fail 'root exits 4'

# on: the first terminal in xdg-terminals.list, one entry per page, the icon
printf 'com.mitchellh.ghostty.desktop\n' > "$tmp/cfg/xdg-terminals.list"
run "$binary" launchers on --dry-run | grep -q "write $apps/bxrig-tui-databases.desktop" || fail 'plan names the files'
[[ "$(code "$binary" launchers on --yes)" == 0 ]] || fail 'on --yes exits 0'
[[ "$(ls "$apps"/bxrig-tui-*.desktop | wc -l)" == 28 ]] || fail 'one entry per page'
f="$apps/bxrig-tui-databases.desktop"
grep -qx 'Name=BxRig Databases' "$f" || fail "name: $(cat "$f")"
grep -qx 'Icon=bxrig' "$f" || fail 'icon name'
grep -qx 'Categories=X-BxRig-Develop;' "$f" || fail 'categories'
dirf="$tmp/data/desktop-directories/bxrig.directory"; menuf="$tmp/cfg/menus/applications-merged/bxrig.menu"
grep -qx 'Name=BxRig' "$dirf" || fail 'the submenu folder'
grep -q '<Category>X-BxRig</Category>' "$menuf" || fail 'the menu merge'
run "$binary" launchers status --json | jq -e '.data.submenu == true' >/dev/null || fail 'status submenu'
# the wizard, the runner menu and the Control Center are at the top; pages sit at the top or in a folder with its own icon
dd="$tmp/data/desktop-directories"
grep -qx 'Exec=ghostty -e /opt/bxrig/bxrig init' "$apps/bxrig-wizard.desktop" || fail "wizard exec: $(grep '^Exec' "$apps/bxrig-wizard.desktop")"
grep -qx 'Exec=/opt/bxrig/bxrig menu' "$apps/bxrig-runner.desktop" || fail "runner exec: $(grep '^Exec' "$apps/bxrig-runner.desktop")"
grep -qx 'Exec=ghostty -e /opt/bxrig/bxrig tui' "$apps/bxrig-controlcenter.desktop" || fail 'control center exec'
for e in wizard runner controlcenter; do grep -qx 'Categories=X-BxRig;' "$apps/bxrig-$e.desktop" || fail "$e is not at the top"; done
grep -qx 'Categories=X-BxRig;' "$apps/bxrig-tui-apps.desktop" || fail 'apps at the top'
grep -qx 'Categories=X-BxRig;' "$apps/bxrig-tui-dashboard.desktop" || fail 'dashboard at the top'
for pg in boxlang java maven gradle versions databases mail ports; do grep -qx 'Categories=X-BxRig-Develop;' "$apps/bxrig-tui-$pg.desktop" || fail "$pg is not in Develop"; done
for pg in machines storage secrets logs packages shortcuts; do grep -qx 'Categories=X-BxRig-System;' "$apps/bxrig-tui-$pg.desktop" || fail "$pg is not in System"; done
grep -qx 'Categories=X-BxRig-Look;' "$apps/bxrig-tui-themes.desktop" || fail 'themes are not in Look'
[[ "$(ls "$dd"/*.directory | wc -l)" == 4 ]] || fail 'one .directory per folder'
[[ "$(grep -h '^Icon=' "$dd"/*.directory | sort -u | wc -l)" == 4 ]] || fail 'every folder has its own icon'
grep -qx 'Icon=applications-development' "$dd/bxrig-develop.directory" || fail 'Develop icon'
grep -q '<Directory>bxrig-system.directory</Directory>' "$menuf" || fail 'the System folder is in the menu merge'
grep -q '<Category>X-BxRig-Look</Category>' "$menuf" || fail 'the Look folder is in the menu merge'
grep -qx 'Exec=ghostty -e /opt/bxrig/bxrig tui databases' "$f" || fail "exec: $(grep '^Exec' "$f")"
! grep -q StartupWMClass "$f" || fail 'no StartupWMClass is written'
[[ "$(stat -c %a "$f")" == 644 ]] || fail 'mode 644'
cmp "$icon" "$root/assets/icons/256.png" || fail 'the icon is the embedded one'
for sz in 16 24 32 48 64 128 256; do cmp "$tmp/data/icons/hicolor/${sz}x${sz}/apps/bxrig.png" "$root/assets/icons/$sz.png" || fail "icon size $sz"; done
cmp "$tmp/data/icons/hicolor/scalable/apps/bxrig.svg" "$root/assets/icons/bxrig.svg" || fail 'scalable icon'
run "$binary" launchers status --json | jq -e '.data.icons == 8 and .data.icon == true' >/dev/null || fail 'status counts the icon files'
run "$binary" launchers status --json | jq -e '.data.enabled and .data.present == 32 and .data.icon and .data.terminal == "ghostty"' >/dev/null || fail 'status after'
run "$binary" launchers status | grep -q '32 of 32 launchers' || fail 'status text'

# again: nothing to do
[[ "$(code "$binary" launchers on --yes)" == 0 ]] || fail 'on twice is fine'

# an entry you edited is kept (on and off), and a changed icon is kept
echo '# mine' >> "$f"
run "$binary" launchers on --yes | grep -q 'Kept 1 you edited' || fail 'on keeps an edited entry'
grep -q '# mine' "$f" || fail 'on overwrote an edited entry'
echo mine > "$icon"
run "$binary" launchers off --dry-run | grep -q "keep   $f" || fail 'off plan keeps the edited entry'
[[ "$(code "$binary" launchers off)" == 2 ]] || fail 'off without --yes exits 2'
[[ "$(code "$binary" launchers off --yes)" == 0 ]] || fail 'off --yes exits 0'
[[ "$(ls "$apps"/bxrig-tui-*.desktop | wc -l)" == 1 && -f "$f" ]] || fail 'off removed only the unedited entries'
grep -qx mine "$icon" || fail 'off removed an icon you changed'
[[ ! -e "$tmp/data/icons/hicolor/16x16/apps/bxrig.png" && ! -e "$tmp/data/icons/hicolor/scalable/apps/bxrig.svg" ]] || fail 'off left the icons that are still BxRig icons'
[[ -f "$dirf" && -f "$menuf" ]] || fail 'the submenu stays while a kept entry needs it'
rm "$f"

# the icon goes while it is still BxRig's; `remove launchers` is the same as `launchers off`
rm "$icon"
[[ "$(code "$binary" launchers on --yes)" == 0 ]] || fail 'on again'
cmp "$icon" "$root/assets/icons/256.png" || fail 'the icon is written again when it is missing'
[[ "$(code "$binary" remove launchers)" == 2 ]] || fail 'remove launchers without --yes is a plan'
[[ "$(ls "$apps"/bxrig-tui-*.desktop | wc -l)" == 28 ]] || fail 'the plan removed files'
[[ "$(code "$binary" remove launchers --yes)" == 0 ]] || fail 'remove launchers --yes'
[[ -z "$(ls "$apps"/bxrig-tui-*.desktop 2>/dev/null)" && ! -e "$icon" ]] || fail 'remove launchers left files behind'
run "$binary" launchers off --yes | grep -q 'No launchers' || fail 'off with nothing there says so'
run "$binary" launchers status --json | jq -e '.data.enabled == false' >/dev/null || fail 'status after off'

# another terminal: kitty takes its command without -e
printf 'kitty.desktop\n' > "$tmp/cfg/xdg-terminals.list"
[[ "$(code "$binary" launchers on --yes)" == 0 ]] || fail 'on with kitty'
grep -qx 'Exec=kitty /opt/bxrig/bxrig tui logs' "$apps/bxrig-tui-logs.desktop" || fail "kitty exec: $(grep '^Exec' "$apps/bxrig-tui-logs.desktop")"
# the terminal changed: the entries are BxRig's still (journal), so they update
printf 'com.mitchellh.ghostty.desktop\n' > "$tmp/cfg/xdg-terminals.list"
[[ "$(code "$binary" launchers off --yes)" == 0 ]] || fail 'off after the terminal changed'
[[ -z "$(ls "$apps"/bxrig-tui-*.desktop 2>/dev/null)" ]] || fail 'off left entries after the terminal changed'
[[ ! -e "$dirf" && ! -e "$menuf" ]] || fail 'off left the submenu files'

# no terminal at all: exit 4
rm "$tmp/bin/ghostty" "$tmp/bin/kitty"; rm -f "$tmp/cfg/xdg-terminals.list"
mkdir -p "$tmp/nobin"; for c in sh cat id base64 rm sed grep; do ln -sf "$(command -v "$c")" "$tmp/nobin/$c"; done
set +e; env HOME="$tmp/home" XDG_DATA_HOME="$tmp/data" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" PATH="$tmp/nobin" "$binary" launchers on --yes >/dev/null 2>&1; rc=$?; set -e
[[ "$rc" == 4 ]] || fail "no terminal exits 4 (got $rc)"
echo "launchers-test: ok"
