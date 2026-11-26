#!/usr/bin/env bash
# `bxrig mcp` with fake agents: claude and codex record their `mcp add|remove` and answer `mcp get` from a file; the other agents are
# programs on PATH whose config files BxRig writes. boxlang is a fake MCP server that prints what it was started with, a log line
# and the notification reply the real one sends today, so the test sees what reaches the agent. Usage: mcp-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
export LOG="$tmp/log"; : > "$LOG"
H="$tmp/home"; mkdir -p "$H/.config/zed" "$H/.config/goose" "$tmp/state"
for c in pi kilo gemini opencode copilot cursor-agent amp crush goose kiro-cli qwen grok antigravity zeditor code; do stub "$c" 'exit 0'; done
for c in claude codex; do stub "$c" 'echo "'"$c"' $*" >> "$LOG"
f="$STATE/'"$c"'"
case "$2" in
	add) shift 2; echo "$*" > "$f" ;;
	remove) rm -f "$f" ;;
	get) [[ -f "$f" ]] || exit 1; cat "$f" ;;
esac'; done
# the fake server: what it was given, then one MCP answer per request line, plus the noise the real one adds today
stub boxlang 'echo "boxlang $* write=$BXRIG_MCP_WRITE self=$BXRIG_SELF (in $PWD)" >> "$LOG"
echo "[INFO ] [MCP] Starting STDIO transport for server: bxrig"
while IFS= read -r line; do
	case "$line" in
		*notifications/initialized*) echo "{\"error\":{\"code\":-32601,\"message\":\"Method not found: notifications/initialized\"},\"jsonrpc\":\"2.0\"}" ;;
		*) echo "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}" ;;
	esac
done
echo "[INFO ] [MCP] STDIO transport stopped"'
BL="$H/.boxlang"; mkdir -p "$BL/modules/bx-agents"; : > "$BL/modules/bx-agents/ModuleConfig.bx"; echo '{"version":"1.0.0"}' > "$BL/modules/bx-agents/box.json"
printf '{\n  // my settings\n  "theme": "One Dark"\n}\n' > "$H/.config/zed/settings.json"; cp "$H/.config/zed/settings.json" "$tmp/zed.orig"
printf 'extensions:\n  developer:\n    enabled: true\n' > "$H/.config/goose/config.yaml"; cp "$H/.config/goose/config.yaml" "$tmp/goose.orig"
run() { env HOME="$H" BXRIG_CONFIG_HOME="$H/.config/bxrig" BXRIG_DATA_HOME="$tmp/data" BXRIG_SELF=/opt/bxrig BXRIG_BOXLANG="$tmp/bin/boxlang" STATE="$tmp/state" LOG="$LOG" PATH="$tmp/bin:$PATH" "$@"; }
mcp() { run "$binary" mcp "$@"; }

# ---- the tools ----
mcp tools --json | jq -e '.data.read_only == 17 and .data.changing == 19 and (.data.tools | length) == 36' >/dev/null || fail "tools: $(mcp tools --json)"
mcp tools | grep -q '^  theme_set' || fail 'tools text lists theme_set'

# ---- status ----
mcp --json | jq -e '.data.server_ready and (.data.agents | length) == 17 and ([.data.agents[] | select(.installed)] | length) == 17 and ([.data.agents[] | select(.linked != "")] | length) == 0' >/dev/null || fail "status: $(mcp --json)"

# ---- link: a plan first ----
{ mcp link --json || true; } | tee "$tmp/plan.json" | jq -e '.data.write == false and (.data.agents | length) == 17' >/dev/null || fail "plan: $(jq -c ".data|{write,n:(.agents|length)}" "$tmp/plan.json")"
[[ ! -e "$H/.pi" ]] && ! grep -q ' mcp \(add\|remove\)' "$LOG" || fail 'the plan changed nothing'
[[ "$(code "$binary" mcp link nobody --yes)" == 2 ]] || fail 'an unknown agent is a usage error'

# ---- link two by name, read-only ----
mcp link pi-agent claude-code --yes >/dev/null
jq -e '.mcpServers.bxrig.command == "/opt/bxrig" and .mcpServers.bxrig.args == ["mcp","serve"]' "$H/.pi/agent/mcp.json" >/dev/null || fail 'pi: read-only entry'
grep -q 'claude mcp add --transport stdio --scope user bxrig -- /opt/bxrig mcp serve$' "$LOG" || fail "claude add: $(cat "$LOG")"
mcp --json | jq -e '[.data.agents[] | select(.linked != "") | "\(.id)=\(.linked)"] == ["claude-code=read-only","pi-agent=read-only"]' >/dev/null || fail "linked: $(mcp --json)"
[[ ! -e "$H/.qwen" ]] || fail 'only the named agents'

# ---- link every installed one with --write; one BxRig can not change is left out, unless it was named ----
mkdir -p "$H/.qwen"; printf '{ // a comment\n"x": 1 }\n' > "$H/.qwen/settings.json"
mcp link --write --yes --json > "$tmp/all.json"
jq -e '(.data.skipped | map(.agent)) == ["qwen-code"] and (.data.agents | length) == 16' "$tmp/all.json" >/dev/null || fail "all: $(cat "$tmp/all.json")"
[[ "$(code "$binary" mcp link qwen-code --yes)" == 4 ]] || fail 'a named agent that can not be changed is a precondition'
mcp --json | jq -e '[.data.agents[] | select(.linked == "write")] | length == 16' >/dev/null || fail "all write: $(mcp --json)"
jq -e '.mcpServers.bxrig.args == ["mcp","serve","--write"]' "$H/.pi/agent/mcp.json" >/dev/null || fail 'pi: write entry'
[[ -f "$H/.pi/agent/mcp.json.bxrig-backup" ]] || fail 'the old file is kept'
grep -q '// my settings' "$H/.config/zed/settings.json" || fail 'zed keeps its comments'
grep -q '"context_servers": { "bxrig"' "$H/.config/zed/settings.json" || fail 'zed: context_servers'
grep -q '^  developer:' "$H/.config/goose/config.yaml" && grep -q '^  bxrig:' "$H/.config/goose/config.yaml" || fail 'goose: both extensions'
grep -q '^\[mcp_servers.bxrig\]' "$H/.grok/config.toml" || fail 'grok: toml table'
grep -q -- '--args mcp --args serve --args --write' "$H/.config/crush/crushrc" || fail 'crush: crushrc line'
grep -q 'codex mcp add bxrig -- /opt/bxrig mcp serve --write' "$LOG" || fail 'codex add with --write'

# ---- unlink gives files back ----
mcp unlink --yes --json | jq -e '(.data.agents | length) == 16' >/dev/null || fail 'unlink every linked one'
grep -q '// a comment' "$H/.qwen/settings.json" || fail 'the file BxRig left out is untouched'

cmp -s "$H/.config/zed/settings.json" "$tmp/zed.orig" || fail "zed file back: $(cat "$H/.config/zed/settings.json")"
cmp -s "$H/.config/goose/config.yaml" "$tmp/goose.orig" || fail 'goose file back'
grep -q 'claude mcp remove bxrig --scope user' "$LOG" || fail 'claude remove'
mcp --json | jq -e '[.data.agents[] | select(.linked != "")] | length == 0' >/dev/null || fail "nothing linked: $(mcp --json)"

# ---- serve: only MCP messages reach the agent ----
out="$(printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize"}' '{"jsonrpc":"2.0","method":"notifications/initialized"}' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | run "$binary" mcp serve 2>/dev/null)"
[[ "$(printf '%s\n' "$out" | wc -l)" == 2 ]] && ! grep -q 'INFO\|Method not found' <<<"$out" || fail "serve output: $out"
grep -q "boxlang $tmp/data/mcp/serve.bxs write= self=/opt/bxrig (in $tmp/data/mcp)" "$LOG" || fail "serve start: $(grep boxlang "$LOG")"
for f in serve.bxs BxRig.bx changing.json; do [[ -s "$tmp/data/mcp/$f" ]] || fail "serve writes $f"; done
[[ "$(jq length "$tmp/data/mcp/changing.json")" == 19 ]] || fail 'changing.json'
printf '' | run "$binary" mcp serve --write >/dev/null 2>&1; grep -q 'write=1' "$LOG" || fail 'serve --write'
rm -rf "$BL/modules/bx-agents"
err="$(printf '' | run "$binary" mcp serve 2>&1 >/dev/null || true)"; outn="$(printf '' | run "$binary" mcp serve 2>/dev/null || true)"
[[ -z "$outn" ]] && grep -q 'bxrig ai agents install' <<<"$err" || fail "serve without bx-agents: out=$outn err=$err"
[[ "$(code "$binary" mcp serve)" == 4 ]] || fail "serve without bx-agents exits 4 (precondition)"
mcp --json | jq -e '.data.server_ready == false' >/dev/null || fail 'status says the server needs bx-agents'
echo 'mcp-test: ok'
