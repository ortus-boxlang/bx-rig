#!/usr/bin/env bash
# `bxrig boxlang servers` with fake ss, boxlang-miniserver, box and xdg-open. Usage: servers-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/code/shop" "$tmp/code/legacy/www" "$tmp/code/deep/a/b/c/d/app" "$tmp/code/node_modules/x" "$tmp/plain"
export LOG="$tmp/log" LISTEN="$tmp/listen"; : > "$LOG"; : > "$LISTEN"
logger() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n%s\n' "$1" "${2:-}" > "$tmp/bin/$1"; }
# ss prints a LISTEN line for every port in $LISTEN
logger ss 'while read -r p; do [[ -n "$p" ]] && echo "LISTEN 0 4096 127.0.0.1:$p 0.0.0.0:* users:((\"java\",pid=4242,fd=12))"; done < "$LISTEN"'
logger boxlang-miniserver 'echo "MiniServer started"; echo 8099 >> "$LISTEN"'
logger box
logger xdg-open
chmod +x "$tmp/bin"/*
printf '{ "port": 8099, "host": "127.0.0.1" }\n' > "$tmp/code/shop/miniserver.json"
printf '{ "name": "Legacy App", "web": { "http": { "port": 8500 }, "webroot": "www" } }\n' > "$tmp/code/legacy/server.json"
printf '{ "port": 9000 }\n' > "$tmp/code/deep/a/b/c/d/app/miniserver.json"
printf '{ "name": "dep" }\n' > "$tmp/code/node_modules/x/server.json"
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" LOG="$LOG" LISTEN="$LISTEN" "$@"; }
reg="$tmp/cfg/bxrig/servers.json"

run "$binary" boxlang servers --json | jq -e '.ok and (.data.servers | length) == 0' >/dev/null || fail 'an empty list'
run "$binary" boxlang servers | grep -q 'No apps registered' || fail 'the empty list says how to add one'
# scan: a plan first, the dependency folders and anything deeper than --depth skipped
[[ "$(code "$binary" boxlang servers scan "$tmp/code")" == 2 ]] && [[ ! -f "$reg" ]] || fail 'scan without --yes is a plan'
run "$binary" boxlang servers scan "$tmp/code" --dry-run --json | jq -e '(.data.found | map(.path | split("/") | last) | sort) == ["legacy","shop"]' >/dev/null || fail "scan finds shop and legacy only: $(run "$binary" boxlang servers scan "$tmp/code" --dry-run --json)"
run "$binary" boxlang servers scan "$tmp/code" --yes --json | jq -e '(.data.added | sort) == ["legacy-app","shop"]' >/dev/null || fail 'scan --yes registers them'
jq -e '(.servers | length) == 2 and (.servers | map(.kind) | sort) == ["commandbox","miniserver"]' "$reg" >/dev/null || fail 'the registry file'
run "$binary" boxlang servers scan "$tmp/code" | grep -q 'Every app below' || fail 'a second scan has nothing new'
run "$binary" boxlang servers scan "$tmp/code" --depth=6 --yes --json | jq -e '.data.added == ["app"]' >/dev/null || fail '--depth reaches deeper'
# add
[[ "$(code "$binary" boxlang servers add "$tmp/plain")" == 4 ]] || fail 'a folder with no app file exits 4'
[[ "$(code "$binary" boxlang servers add "$tmp/nope")" == 4 ]] || fail 'a missing folder exits 4'
run "$binary" boxlang servers add "$tmp/code/shop" --json | jq -e '.data.added == false and .data.name == "shop"' >/dev/null || fail 'adding a registered folder again'
mkdir -p "$tmp/other/shop"; printf '{ "port": 8111 }\n' > "$tmp/other/shop/miniserver.json"
run "$binary" boxlang servers add "$tmp/other/shop" --json | jq -e '.data.name == "shop-2"' >/dev/null || fail 'a taken name gets a number'
run "$binary" boxlang servers add "$tmp/other/shop" --name="My Shop" --json >/dev/null
run "$binary" boxlang servers remove shop-2 >/dev/null; [[ "$(jq '[.servers[] | select(.name == "shop-2")] | length' "$reg")" == 0 ]] || fail 'remove'
[[ "$(code "$binary" boxlang servers remove nope)" == 4 ]] || fail 'remove an unknown app exits 4'
# list: the port, the kind and the state come from the app's own file and the listening ports
run "$binary" boxlang servers --json | jq -e '(.data.servers[] | select(.name == "legacy-app") | .port == 8500 and .kind == "commandbox" and .state == "stopped" and (.webroot | endswith("/legacy/www")))' >/dev/null || fail 'list rows'
# start and stop a MiniServer: detached in its folder, the pid kept, TERM to stop
[[ "$(code "$binary" boxlang servers start shop --dry-run)" == 0 ]] && ! grep -q '^boxlang-miniserver' "$LOG" || fail 'start --dry-run starts nothing'
run "$binary" boxlang servers start shop >/dev/null; sleep 1
grep -q '^boxlang-miniserver miniserver.json' "$LOG" || fail "start: $(cat "$LOG")"
grep -q 'MiniServer started' "$tmp/state/bxrig/servers/shop.log" || fail 'the output goes to the log'
[[ -s "$tmp/state/bxrig/servers/shop.pid" ]] || fail 'the pid is kept'
run "$binary" boxlang servers status shop --json | jq -e '.data.state == "running" and .data.url == "http://127.0.0.1:8099/"' >/dev/null || fail 'running after start'
run "$binary" boxlang servers start shop | grep -q 'already running' || fail 'start twice'
run "$binary" boxlang servers log shop --json | jq -e '.data.lines | index("MiniServer started") != null' >/dev/null || fail 'log'
logger kill 'echo "kill $*" >> "$LOG"'; chmod +x "$tmp/bin/kill"
run "$binary" boxlang servers stop shop >/dev/null; grep -q '^kill -TERM ' "$LOG" || fail "stop: $(cat "$LOG")"
# CommandBox through box server
: > "$LOG"; run "$binary" boxlang servers start legacy-app >/dev/null; grep -q "^box server start directory=$tmp/code/legacy --noOpenBrowser" "$LOG" || fail "box server start: $(cat "$LOG")"
echo 8500 >> "$LISTEN"; : > "$LOG"; run "$binary" boxlang servers stop legacy-app >/dev/null; grep -q "^box server stop directory=$tmp/code/legacy" "$LOG" || fail 'box server stop'
# open and folder
: > "$LOG"; run "$binary" boxlang servers open legacy-app >/dev/null; sleep 0.3; grep -q '^xdg-open http://127.0.0.1:8500/' "$LOG" || fail "open: $(cat "$LOG")"
: > "$LOG"; run "$binary" boxlang servers folder shop >/dev/null; sleep 0.3; grep -q "^xdg-open $tmp/code/shop" "$LOG" || fail 'folder'
# a folder that went away
rm -rf "$tmp/code/deep"; run "$binary" boxlang servers --json | jq -e '(.data.servers[] | select(.name == "app") | .state) == "missing"' >/dev/null || fail 'a removed folder is missing'
[[ "$(code "$binary" boxlang servers start app)" == 4 ]] || fail 'starting a missing app exits 4'
[[ "$(code "$binary" boxlang servers frobnicate x)" == 2 ]] || fail 'usage exits 2'
echo "servers-test ok"
