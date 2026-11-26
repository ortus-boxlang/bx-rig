#!/usr/bin/env bash
# `bxrig privacy` with every agent faked as a program on PATH (kiro-cli records its `settings` call) and a local AI state with one
# chat model: the report, telemetry off and back on in every file format, local-only on and off, and the plans that change
# nothing. Usage: privacy-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
export LOG="$tmp/log"; : > "$LOG"
H="$tmp/home"; mkdir -p "$H/.config/bxrig" "$H/.config/zed" "$H/.claude"
for c in claude codex pi kilo gemini opencode copilot cursor-agent amp crush goose qwen grok antigravity zeditor code; do stub "$c" 'exit 0'; done
stub kiro-cli 'echo "kiro-cli $*" >> "$LOG"'
echo '{ "active": "qwen3.5-4b", "models": { "qwen3.5-4b": { "kind": "chat" }, "nomic": { "kind": "embed" } }, "serve": { "listen": "127.0.0.1", "port": 8089 } }' > "$H/.config/bxrig/ai.json"
printf '{\n  // my settings\n  "theme": "One Dark"\n}\n' > "$H/.config/zed/settings.json"; cp "$H/.config/zed/settings.json" "$tmp/zed.orig"
echo '{"model":"opus","mcpServers":{"github":{"type":"http","url":"https://api.githubcopilot.com/mcp/"}}}' > "$H/.claude.json"
run() { env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u GEMINI_API_KEY -u NOVITA_API_KEY -u OPENCODE_API_KEY -u OPENROUTER_API_KEY -u GROQ_API_KEY -u MISTRAL_API_KEY -u DEEPSEEK_API_KEY -u XAI_API_KEY -u TOGETHER_API_KEY \
	HOME="$H" BXRIG_CONFIG_HOME="$H/.config" BXRIG_DATA_HOME="$tmp/data" BXRIG_SELF=/opt/bxrig LOG="$LOG" PATH="$tmp/bin:$PATH" GROQ_API_KEY=test-key "$@"; }
pv() { run "$binary" privacy "$@"; }

# ---- the report ----
pv --json > "$tmp/r.json"
jq -e '.data.server.ready and .data.server.models == ["qwen3.5-4b"] and (.data.agents | length) == 17 and .data.cloud_agents == 17' "$tmp/r.json" >/dev/null || fail "report: $(jq -c '.data | {server, n: (.agents|length), cloud_agents}' "$tmp/r.json")"
jq -e '[.data.keys[] | select(.name == "GROQ_API_KEY" and .where == "your environment")] | length == 1' "$tmp/r.json" >/dev/null || fail 'a key in the environment is listed by name'
! grep -q 'test-key' "$tmp/r.json" || fail 'a key value never appears'
jq -e '[.data.mcp[] | select(.server == "github" and .where == "web: api.githubcopilot.com" and .agent == "Claude Code")] | length == 1' "$tmp/r.json" >/dev/null || fail "Claude Code's MCP server: $(jq -c .data.mcp "$tmp/r.json")"
jq -e '[.data.agents[] | select(.id == "claude-code") | .local] == ["no"] and [.data.agents[] | select(.id == "pi-agent") | .local] == ["possible"]' "$tmp/r.json" >/dev/null || fail 'local: no for Claude Code, possible for Pi'
jq -e '[.data.data[] | select(.path | endswith("/.claude"))] | length == 1' "$tmp/r.json" >/dev/null || fail 'the folder with Claude Code chats'
pv | grep -q '17 of your agents send prompts to the cloud' || fail 'report text'

# ---- telemetry off: a plan first ----
{ pv telemetry off --json || true; } > "$tmp/plan.json"
jq -e '(.data.changes | length) == 9' "$tmp/plan.json" >/dev/null || fail "telemetry plan: $(jq -c '.data.changes | map(.agent)' "$tmp/plan.json")"
[[ ! -e "$H/.claude/settings.json" && ! -s "$LOG" ]] || fail 'the plan changed nothing'
[[ "$(code "$binary" privacy telemetry maybe)" == 2 ]] || fail 'off or on'
[[ "$(code "$binary" privacy telemetry off nobody --yes)" == 2 ]] || fail 'an unknown agent is a usage error'

# ---- telemetry off ----
pv telemetry off --yes >/dev/null
jq -e '.env.DISABLE_TELEMETRY == "1" and .env.DISABLE_ERROR_REPORTING == "1"' "$H/.claude/settings.json" >/dev/null || fail 'Claude Code env'
grep -q '^\[analytics\]' "$H/.codex/config.toml" && grep -q '^enabled = false' "$H/.codex/config.toml" || fail 'Codex analytics'
jq -e '.privacy.usageStatisticsEnabled == false' "$H/.gemini/settings.json" "$H/.qwen/settings.json" >/dev/null || fail 'Gemini CLI and Qwen Code usage statistics'
jq -e '.enableInstallTelemetry == false' "$H/.pi/agent/settings.json" >/dev/null || fail 'Pi install telemetry'
grep -q '^GOOSE_TELEMETRY_ENABLED: false' "$H/.config/goose/config.yaml" || fail 'Goose'
grep -q 'kiro-cli settings telemetry.enabled false' "$LOG" || fail 'Kiro by its own command'
grep -q '// my settings' "$H/.config/zed/settings.json" && grep -q '"telemetry": {"diagnostics":false,"metrics":false}' "$H/.config/zed/settings.json" || fail 'Zed keeps its comments'
jq -e '."telemetry.telemetryLevel" == "off"' "$H/.config/Code/User/settings.json" >/dev/null || fail 'VS Code'
pv --json | jq -e '[.data.telemetry[] | select(.can and .state == "on") | .id] == ["kiro-cli"]' >/dev/null || fail "telemetry state: $(pv --json | jq -c '[.data.telemetry[] | "\(.id)=\(.state)"]')"
pv --json | jq -e '[.data.telemetry[] | select(.id == "amp") | .can] == [false]' >/dev/null || fail 'Amp has no switch'

# ---- telemetry on: back ----
pv telemetry on claude-code zed --yes >/dev/null
jq -e '(.env | has("DISABLE_TELEMETRY") | not)' "$H/.claude/settings.json" >/dev/null || fail 'Claude Code back on'
cmp -s "$H/.config/zed/settings.json" "$tmp/zed.orig" || fail 'Zed file back as it was'
jq -e '.privacy.usageStatisticsEnabled == false' "$H/.gemini/settings.json" >/dev/null || fail 'only the named agents'
[[ -f "$H/.claude/settings.json.bxrig-backup" ]] || fail 'the old file is kept'

# ---- local-only ----
{ pv local-only --json || true; } | jq -e '[.data.changes[].agent] == ["opencode-cli","pi-agent","copilot-cli","crush","goose"]' >/dev/null || fail "local plan: $({ pv local-only --json || true; } | jq -c '.data')"
pv local-only --yes >/dev/null
jq -e '.providers.bxrig.baseUrl == "http://127.0.0.1:8089/v1" and .providers.bxrig.models == [{"id":"qwen3.5-4b"}]' "$H/.pi/agent/models.json" >/dev/null || fail 'Pi local provider'
jq -e '.model == "bxrig/qwen3.5-4b"' "$H/.config/opencode/opencode.json" >/dev/null || fail 'OpenCode default model'
jq -e '.providers[0].name == "bxrig"' "$H/.copilot/providers.json" >/dev/null || fail 'Copilot provider'
jq -e '.requires_auth == false' "$H/.config/goose/custom_providers/bxrig.json" >/dev/null || fail 'Goose custom provider'
grep -q 'provider add bxrig' "$H/.config/crush/crushrc" || fail 'Crush provider'
pv --json | jq -e '[.data.agents[] | select(.local == "on") | .id] == ["opencode-cli","pi-agent","copilot-cli","crush","goose"] and .data.cloud_agents == 12' >/dev/null || fail 'local in use'
pv local-only --off --yes >/dev/null
pv --json | jq -e '[.data.agents[] | select(.local == "on")] | length == 0' >/dev/null || fail 'local-only off'
[[ ! -e "$H/.config/goose/custom_providers/bxrig.json" ]] || fail "Goose's provider file is gone"
jq -e '.providers | has("bxrig") | not' "$H/.pi/agent/models.json" >/dev/null || fail 'Pi provider gone'

# ---- local-only needs the local server on 127.0.0.1 with a chat model ----
echo '{ "models": {}, "serve": { "listen": "127.0.0.1", "port": 8089 } }' > "$H/.config/bxrig/ai.json"
[[ "$(code "$binary" privacy local-only --yes)" == 4 ]] || fail 'no chat model is a precondition'
echo '{ "active": "a", "models": { "a": { "kind": "chat" } }, "serve": { "listen": "0.0.0.0", "port": 8089 } }' > "$H/.config/bxrig/ai.json"
[[ "$(code "$binary" privacy local-only --yes)" == 4 ]] || fail 'a server on the network is a precondition'
echo 'privacy-test: ok'
