#!/usr/bin/env bash
# The Noctalia starter files through `config apply`: valid TOML and JSON, safe re-runs, drift. Usage: noctalia-config-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
export BXRIG_WALLPAPER_DIR="$root/assets/wallpapers" BXRIG_BASE_URL=http://127.0.0.1:9   # the theme wallpapers come from the checkout, never the network
mkdir -p "$tmp/home" "$tmp/power"   # no battery: the starter leaves the battery widget out
run() { env HOME="$tmp/home" BXRIG_POWER_DIR="$tmp/power" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" "$@"; }
run "$binary" config list | grep -q '^noctalia: missing' || fail 'config list shows noctalia as missing'
[[ "$(code "$binary" config apply noctalia)" == 2 ]] || fail 'apply without --yes exits 2'
[[ ! -e "$tmp/cfg/noctalia" ]] || fail 'apply without --yes wrote a file'
[[ "$(code "$binary" config apply noctalia --yes)" == 0 ]] || fail 'apply noctalia'
[[ "$(code "$binary" config apply noctalia-palette --yes)" == 0 ]] || fail 'apply noctalia-palette'
python3 - "$tmp/cfg/noctalia/config.toml" "$tmp/home" <<'PY' || fail 'config.toml is not valid TOML or lacks the expected keys'
import sys, tomllib
c = tomllib.load(open(sys.argv[1], 'rb'))
assert c['theme']['custom_palette'] == 'BxRig' and c['theme']['source'] == 'custom'
assert c['bar']['order'] == ['main'] and c['bar']['main']['position'] == 'top'
m = c['bar']['main']
# Standard: logo, workspaces, active window | clock, media | ... quick settings, control center (the grid button is in the dock)
assert m['start'] == ['bxrig-menu', 'workspaces', 'active_window'] and m['center'] == ['bxrig-clock', 'media']
assert m['end'][-2:] == ['bxrig-quick', 'control-center'] and 'battery' not in m['end'] and 'launcher' not in m['start']
assert c['widget']['bxrig-clock']['type'] == 'bxrig/clock:bar' and c['plugin_settings']['bxrig/clock']['format'] == '%b %-d - %H:%M'
assert c['widget']['bxrig-menu']['type'] == 'custom_button' and 'setsid bxrig menu' in c['widget']['bxrig-menu']['actions']['left']
assert c['widget']['bxrig-menu']['custom_image'].endswith('/plates/bxrig-menu.svg')
assert m['capsule'] is False and 'capsule_border' not in m
assert c['dock']['enabled'] is True and c['dock']['launcher_position'] == 'start' and c['dock']['launcher_custom_image'].endswith('/plates/bxrig-grid.svg')
assert c['shell']['setup_wizard_enabled'] is False and c['shell']['launcher']['app_grid'] is True
assert 'bxrig-agents' in m['end'] and 'bxrig-quick' in m['end'] and 'caffeine' not in m['end']
assert m['end'].index('bxrig-dev') == m['end'].index('bxrig-system') + 1 and c['widget']['bxrig-dev']['type'] == 'bxrig/dev:bar'
assert m['end'].index('bxrig-vpn') == m['end'].index('bxrig-dev') + 1 and m['end'].index('bxrig-vpn') < m['end'].index('tray') and c['widget']['bxrig-vpn']['type'] == 'bxrig/vpn:bar'
assert c['plugins']['enabled'] == ['bxrig/clock', 'bxrig/agents', 'bxrig/system', 'bxrig/quick', 'bxrig/dev', 'bxrig/power', 'bxrig/vpn', 'bxrig/launcher']
assert c['widget']['bxrig-system']['type'] == 'bxrig/system:bar' and m['end'].index('screenshot') + 1 == m['end'].index('bxrig-system') and m['end'].index('bxrig-system') < m['end'].index('tray')
assert c['notification']['group_by_app'] is True and c['notification']['border_color'] == 'primary'
assert c['wallpaper']['directory'] == sys.argv[2] + '/Pictures/BxRig'
assert c['wallpaper']['default']['path'].endswith('/bxrig.jpg')
PY
jq -e '.version == 2 and (.dark | has("primary","surface","hover")) and (.light | has("primary")) and (.dark.terminal.normal | length) == 8' "$tmp/cfg/noctalia/palettes/BxRig.json" >/dev/null || fail 'palette is not valid or lacks keys'
run "$binary" config list | grep -q '^noctalia: clean' || fail 'config list shows noctalia clean'
echo '# mine' >> "$tmp/cfg/noctalia/config.toml"
[[ "$(code "$binary" config apply noctalia --yes)" == 8 ]] || fail 'drift exits 8 without --force'
[[ "$(code "$binary" config apply noctalia --yes --force)" == 0 ]] || fail '--force overwrites'
echo "noctalia config tests passed"
