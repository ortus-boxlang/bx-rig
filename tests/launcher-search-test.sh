#!/usr/bin/env bash
# `bxrig launcher search|run`: ranking, answer cards, breadcrumbs, web rows last, frecency. Usage: launcher-search-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
export BXRIG_BASE_URL=http://127.0.0.1:9
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/state" "$tmp/apps"
stub_id
cat > "$tmp/apps/zebra-notes.desktop" <<'D'
[Desktop Entry]
Type=Application
Name=Zebra Notes
Exec=true
D
run() { env HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" BXRIG_APPS_DIRS="$tmp/apps" PATH="$tmp/bin:$PATH" "$@"; }
s() { run "$binary" launcher search "$@" --json 2>/dev/null; }
s '2*(3+4)' | jq -e '.data.results[0].kind == "answer" and .data.results[0].title == "14"' >/dev/null || fail 'calculator card first'
s '10/4' | jq -e '.data.results[0].title == "2.5"' >/dev/null || fail 'decimal answer'
s '1/0' | jq -e '[.data.results[] | select(.kind == "answer")] | length == 0' >/dev/null || fail 'division by zero is not an answer'
s 'hello world' | jq -e '[.data.results[] | select(.kind == "answer")] | length == 0' >/dev/null || fail 'no card for plain words'
s 42 | jq -e '[.data.results[] | select(.kind == "answer")] | length == 0' >/dev/null || fail 'a bare number is not an answer'
s capture | jq -e '[.data.results[] | select(.kind == "menu" and (.breadcrumb | startswith("Trigger")))] | length > 0' >/dev/null || fail 'menu rows carry a breadcrumb'
s nord | jq -e '.data.results[0].id == "theme:nord" and .data.results[0].breadcrumb == "Appearance › Theme"' >/dev/null || fail 'theme row first for its name'
s zebra | jq -e '.data.results[0].id == "app:zebra-notes.desktop"' >/dev/null || fail 'app row'
s zebra | jq -e '.data.results | map(.kind) | .[-4:] == ["web","web","web","web"]' >/dev/null || fail 'web rows are last'
s zebra --limit=3 | jq -e '(.data.results | length) <= 3' >/dev/null || fail 'limit'
s zqxjv | jq -e '[.data.results[] | select(.kind != "web")] | length == 0' >/dev/null || fail 'nonsense matches nothing but the web rows'
[[ -z "$(s '' | jq -r '.data.results[]?.id')" ]] || fail 'empty query before any use shows nothing'
[[ "$(run "$binary" launcher run app:nope >/dev/null 2>&1; echo $?)" == 4 ]] || fail 'unknown row exits 4'
run "$binary" launcher run app:zebra-notes.desktop --dry-run 2>/dev/null | grep -q 'Would run Zebra Notes' || fail 'dry run says what it would do'
[[ ! -e "$tmp/state/bxrig/launcher.json" ]] || fail 'dry run counted a use'
[[ "$(run "$binary" launcher run app:zebra-notes.desktop >/dev/null 2>&1; echo $?)" == 0 ]] || fail 'run exits 0'
jq -e '.["app:zebra-notes.desktop"].count == 1' "$tmp/state/bxrig/launcher.json" >/dev/null || fail 'use counted'
s '' | jq -e '.data.results[0].id == "app:zebra-notes.desktop"' >/dev/null || fail 'empty query lists what you ran'
echo "launcher search tests passed"
