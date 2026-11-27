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
run "$binary" launcher run web:ddg bash docs --dry-run --json 2>/dev/null | jq -e '.data.action.url == "https://duckduckgo.com/?q=bash%20docs"' >/dev/null || fail 'web row is made from the words after the id'
run "$binary" launcher run answer:calc 2+3 --dry-run --json 2>/dev/null | jq -e '.data.action.text == "5"' >/dev/null || fail 'answer row is made from the words after the id'
# every row has a glyph and a theme colour role for its tile
s capture | jq -e '[.data.results[] | select((.glyph | length) == 0 or ((.tone // "") | IN("primary","secondary","tertiary","error") | not))] | length == 0' >/dev/null || fail 'every row has a glyph and a tone'
s capture | jq -e '[.data.results[] | select(.title == "Region" and .breadcrumb == "Trigger › Capture")][0].glyph == "crop"' >/dev/null || fail 'Region in Capture gets a crop glyph'
s nord | jq -e '.data.results[0].tone == "secondary" and .data.results[0].glyph == "palette"' >/dev/null || fail 'a theme row is a palette on the secondary tone'
s zebra | jq -e '[.data.results[] | select(.kind == "web")][0] | .glyph == "world-search" and .tone == "tertiary"' >/dev/null || fail 'web rows are tertiary'
# the menu panel's levels
m() { run "$binary" menu level "$@" --json 2>/dev/null; }
m | jq -e '.data.entries | length > 10 and (map(.title) | index("Appearance")) != null' >/dev/null || fail 'menu level lists the sections'
m | jq -e '[.data.entries[] | select(.title == "Trigger")][0] | .hasChildren == true and .path == "Trigger" and .glyph == "bolt" and .tone == "primary"' >/dev/null || fail 'a section is a folder with a glyph'
m | jq -e '[.data.entries[] | select(.title == "Remove")][0].tone == "error"' >/dev/null || fail 'Remove is tinted as an error'
m "Trigger > Capture" | jq -e '.data.crumbs == ["Trigger","Capture"] and (.data.entries | length > 3) and ([.data.entries[] | select(.title == "Screenshot menu")][0].glyph == "camera") and ([.data.entries[] | select(.title == "Region")][0].glyph == "crop")' >/dev/null || fail 'a level has its crumbs and glyphs'
m "Trigger > Capture" | jq -e '[.data.entries[] | select(.hasChildren | not)][0].id | length > 0' >/dev/null || fail 'a leaf has an id for launcher run'
[[ "$(run "$binary" menu level "No > Such" >/dev/null 2>&1; echo $?)" == 4 ]] || fail 'an unknown section exits 4'
echo "launcher search tests passed"
