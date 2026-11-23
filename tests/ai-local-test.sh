#!/usr/bin/env bash
# `bxrig ai` local AI with fakes: curl (the Hugging Face downloads and the llama.cpp server's API), llama (version, bench, update) and
# systemctl, and a small catalog (BXRIG_AI_CATALOG) whose checksums match the fake files. Usage: ai-local-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/home/.local/bin" "$tmp/srv"
export LOG="$tmp/log"; : > "$LOG"
SRV="$tmp/srv"
# the fake model files are their own ids; the catalog holds their real SHA-256
for id in tiny-a tiny-b emb-a; do printf 'gguf %s\n' "$id" > "$tmp/$id.ref"; done
sum() { sha256sum "$tmp/$1.ref" | cut -d' ' -f1; }
cat > "$tmp/catalog.json" <<JSON
{ "schema": 1, "tested_with": { "engine": "llama.cpp", "build": "b12627" }, "models": [
 { "id": "tiny-a", "label": "Tiny A", "family": "t", "params": "0.3B", "kind": "chat", "tier": "tiny", "repo": "org/tiny-a-GGUF", "file": "tiny-a.gguf", "sha256": "$(sum tiny-a)", "size_mb": 300, "mem_mb": 600, "license": "Apache-2.0", "tools": true, "vision": false, "verified": true, "score": { "total": 18, "of": 20 }, "reference": { "reply_s": 0.8, "tps": 60 } },
 { "id": "tiny-b", "label": "Tiny B", "family": "t", "params": "1B", "kind": "chat", "tier": "tiny", "repo": "org/tiny-b-GGUF", "file": "tiny-b.gguf", "sha256": "$(sum tiny-b)", "size_mb": 700, "mem_mb": 1200, "license": "MIT", "tools": true, "vision": false, "verified": true, "score": { "total": 20, "of": 20 }, "reference": { "reply_s": 2.5, "tps": 25 } },
 { "id": "bad-sum", "label": "Bad Sum", "family": "t", "params": "1B", "kind": "chat", "tier": "tiny", "repo": "org/bad", "file": "bad.gguf", "sha256": "$(printf '0%.0s' {1..64})", "size_mb": 10, "mem_mb": 10, "license": "MIT", "tools": false, "vision": false, "verified": false, "score": { "total": 1, "of": 20 }, "reference": { "reply_s": 9, "tps": 1 } },
 { "id": "emb-a", "label": "Emb A", "family": "e", "params": "0.3B", "kind": "embeddings", "default": true, "tier": "tiny", "repo": "org/emb-GGUF", "file": "emb-a.gguf", "sha256": "$(sum emb-a)", "size_mb": 300, "mem_mb": 400, "license": "Gemma", "verified": true }
] }
JSON
# curl: downloads write the fake file; the server answers on 127.0.0.1:8089 while $SRV/up exists
stub curl 'echo "curl $*" >> "$LOG"
out=""; method=GET; body=""; url=""
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift ;; -X) method="$2"; shift ;; -d) body="$2"; shift ;; -w|-H|--max-time|--retry|-C) shift ;; -*) ;; *) url="$1" ;; esac; shift; done
if [[ "$url" == https://huggingface.co/* ]]; then
  f="${url##*/}"; id="${f%.gguf}"; [[ -f "$REFS/$id.ref" ]] || id="$f"
  if [[ -f "$REFS/$id.ref" ]]; then cp "$REFS/$id.ref" "$out"; else printf "junk" > "$out"; fi; exit 0
fi
[[ -e "$SRV/up" ]] || { echo "curl: (7) Failed to connect" >&2; exit 7; }
echo "$method ${url#http://127.0.0.1:8089} $body" >> "$SRV/requests"
case "$url" in
  */health) printf "{\"status\":\"ok\"}\n200" ;;
  */v1/models) printf "{\"data\":[{\"id\":\"tiny-a\",\"status\":{\"value\":\"loaded\"}},{\"id\":\"emb-a\",\"status\":{\"value\":\"unloaded\"}}]}\n200" ;;
  */v1/chat/completions) printf "{\"choices\":[{\"message\":{\"content\":\"I am a tiny model.\"}}],\"timings\":{\"predicted_per_second\":42.5}}\n200" ;;
  */v1/embeddings) printf "{\"data\":[{\"embedding\":[0.1,0.2,0.3]}]}\n200" ;;
  */models/unload) printf "{\"success\":true}\n200" ;;
  *) printf "{}\n404" ;;
esac'
cat > "$tmp/home/.local/bin/llama" <<'SH'
#!/usr/bin/env bash
echo "llama $*" >> "$LOG"
case "$1" in
  version) echo "version: 12627 (abc)"; echo "built with cc"; echo "build 12627" ;;
  bench) echo "loading..."; echo '[{"n_threads":1,"n_ubatch":512,"flash_attn":false,"n_prompt":256,"n_gen":0,"avg_ts":100},{"n_threads":1,"n_ubatch":512,"flash_attn":false,"n_prompt":0,"n_gen":32,"avg_ts":10},{"n_threads":2,"n_ubatch":256,"flash_attn":true,"n_prompt":256,"n_gen":0,"avg_ts":200},{"n_threads":2,"n_ubatch":256,"flash_attn":true,"n_prompt":0,"n_gen":32,"avg_ts":20}]' ;;
  update) echo "llama.cpp is up to date" ;;
esac
SH
chmod +x "$tmp/home/.local/bin/llama"
stub systemctl 'echo "systemctl $*" >> "$LOG"
case "$*" in *is-active*) [[ -e "$SRV/up" ]] && echo active || echo inactive ;; *enable*|*restart*) : > "$SRV/up" ;; *disable*) rm -f "$SRV/up" ;; esac; exit 0'
stub nproc 'echo 2'
run() { env HOME="$tmp/home" BXRIG_AI_CATALOG="$tmp/catalog.json" REFS="$tmp" SRV="$SRV" LOG="$LOG" BXRIG_SELF="$binary" PATH="$tmp/bin:$PATH" "$@"; }
plan() { run "$@" || true; }   # a plan exits 2; its output is what is checked
cfg="$tmp/home/.config/bxrig"; models="$tmp/home/.local/share/bxrig/models"

# ---- hardware and picks ----
run "$binary" ai hardware --json | jq -e '.data.budget_mb > 0 and (.data.class | IN("tiny","medium","high")) and (.data.backends | index("cpu")) != null' >/dev/null || fail "hardware: $(run "$binary" ai hardware --json)"
run "$binary" ai models recommend --json | jq -e '[.data.picks[].id] | index("tiny-b") != null and (index("bad-sum") == null)' >/dev/null || fail "recommend: $(run "$binary" ai models recommend --json)"
run "$binary" ai models recommend --json | jq -e '.data.embedding == "emb-a" and ([.data.picks[] | select(.default)] | length) == 1' >/dev/null || fail 'recommend: one default and the embedding model'
run "$binary" ai models recommend --all | grep -q 'not tested by BxRig' || fail 'recommend --all marks untested models'

# ---- engine ----
run "$binary" ai engine --json | jq -e '.data.installed and .data.source == "official" and .data.version == "b12627"' >/dev/null || fail "engine status: $(run "$binary" ai engine --json)"
[[ "$(code "$binary" ai engine install)" == 2 ]] || fail 'engine install without --yes is a plan (exit 2)'
plan "$binary" ai engine install | grep -q 'https://llama.app/install.sh' || fail 'the plan names the official installer'
[[ "$(code "$binary" ai engine install --source=nope)" == 2 ]] || fail 'a bad --source exits 2'
run "$binary" ai engine update --yes | grep -q 'up to date' || fail 'engine update runs llama update'

# ---- pull: three at once, checksums ----
[[ "$(code "$binary" ai models pull tiny-a)" == 2 ]] || fail 'pull without --yes is a plan'
[[ ! -d "$models" ]] || [[ -z "$(ls -A "$models")" ]] || fail 'the plan downloaded something'
[[ "$(code "$binary" ai models pull nope --yes)" == 4 ]] || fail 'an unknown model exits 4'
run "$binary" ai models pull tiny-a tiny-b emb-a --yes > "$tmp/pull.out" || fail "pull: $(cat "$tmp/pull.out")"
for id in tiny-a tiny-b emb-a; do cmp -s "$models/$id.gguf" "$tmp/$id.ref" || fail "$id was not downloaded"; done
[[ "$(grep -c 'https://huggingface.co/org/' "$LOG")" == 3 ]] || fail 'one download per model'
grep -q -- '-C - -o' "$LOG" || fail 'downloads resume (-C -)'
ls "$models"/*.part >/dev/null 2>&1 && fail 'a .part file was left'
jq -e '.active == "tiny-a" and (.models | keys) == ["emb-a","tiny-a","tiny-b"] and .models["emb-a"].kind == "embeddings"' "$cfg/ai.json" >/dev/null || fail "state: $(cat "$cfg/ai.json")"
grep -q '^\[emb-a\]$' "$cfg/ai-models.ini" && grep -q '^embeddings = true$' "$cfg/ai-models.ini" || fail "preset: $(cat "$cfg/ai-models.ini")"
run "$binary" ai models pull tiny-a --yes | grep -q 'already here, checked' || fail 'a model already here is checked, not downloaded again'
set +e; run "$binary" ai models pull bad-sum --yes > "$tmp/bad.out" 2>&1; rc=$?; set -e
[[ "$rc" == 6 ]] && grep -q 'checksum mismatch' "$tmp/bad.out" || fail "a bad checksum fails (exit $rc): $(cat "$tmp/bad.out")"
[[ ! -e "$models/bad.gguf" && -e "$models/bad.gguf.part" ]] || fail 'a bad file is kept as .part, never as the model'
jq -e '.models | has("bad-sum") | not' "$cfg/ai.json" >/dev/null || fail 'a bad download is not recorded'

# ---- the server ----
run "$binary" ai serve status | grep -q 'not running' || fail 'serve status when stopped'
[[ "$(code "$binary" ai models test)" == 4 ]] || fail 'test with the server down exits 4'
run "$binary" ai serve start | grep -q 'starting' || fail 'serve start'
unit="$tmp/home/.config/systemd/user/bxrig-ai.service"
grep -q "^ExecStart=$tmp/home/.local/bin/llama serve --models-preset $cfg/ai-models.ini --models-max [23] --host 127.0.0.1 --port 8089 --no-webui$" "$unit" || fail "unit: $(cat "$unit")"
grep -q 'systemctl --user enable --now bxrig-ai.service' "$LOG" || fail 'the unit is enabled'
run "$binary" ai serve status --json | jq -e '.data.running and .data.base_url == "http://127.0.0.1:8089/v1" and .data.models["tiny-a"] == "loaded"' >/dev/null || fail "serve status: $(run "$binary" ai serve status --json)"

# ---- test, use, ask ----
run "$binary" ai models test > "$tmp/test.out" || fail "test: $(cat "$tmp/test.out")"
grep -q '✓ tiny-a: .* 42.5 tok/s' "$tmp/test.out" && grep -q '✓ emb-a' "$tmp/test.out" || fail "test output: $(cat "$tmp/test.out")"
grep -q 'POST /v1/embeddings {"model":"emb-a"' "$SRV/requests" || grep -q 'POST /v1/embeddings .*emb-a' "$SRV/requests" || fail 'the embedding model gets an embeddings request'
jq -e '.models["tiny-a"].measured.tps == 42.5 and .models["emb-a"].measured.dimensions == 3' "$cfg/ai.json" >/dev/null || fail "measured: $(jq .models "$cfg/ai.json")"
run "$binary" ai models use tiny-b | grep -q 'Active model: Tiny B' || fail 'use'
grep -q 'POST /models/unload .*tiny-a' "$SRV/requests" || fail 'use unloads the old model'
[[ "$(code "$binary" ai models use emb-a)" == 2 ]] || fail 'an embedding model cannot be the active model'
run "$binary" ai ask what are you --json | jq -e '.data.answer == "I am a tiny model." and .data.model == "tiny-b"' >/dev/null || fail 'ask'
grep -q '"content":"what are you"' "$SRV/requests" || fail "ask sends the question: $(tail -1 "$SRV/requests")"
run "$binary" ai models list | grep -q '● Tiny B' || fail 'list marks the active model'

# ---- tune ----
[[ "$(code "$binary" ai models tune tiny-a)" == 2 ]] || fail 'tune without --yes is a plan'
run "$binary" ai models tune tiny-a --yes | grep -q '2 threads, batch 256, flash attention on' || fail 'tune picks the fastest settings'
grep -q "llama bench -m $models/tiny-a.gguf" "$LOG" || fail 'tune runs llama bench'
awk '/^\[tiny-a\]/{f=1;next} /^\[/{f=0} f' "$cfg/ai-models.ini" | grep -q '^threads = 2$' || fail "tuned preset: $(cat "$cfg/ai-models.ini")"
grep -q '^flash-attn = on$' "$cfg/ai-models.ini" && grep -q '^ubatch-size = 256$' "$cfg/ai-models.ini" || fail 'tuned preset keys'
grep -q 'systemctl --user restart bxrig-ai.service' "$LOG" || fail 'a running server restarts after a change'

# ---- listen on the network: an API key ----
[[ "$(code "$binary" ai serve --listen=0.0.0.0)" == 2 ]] || fail 'listen without --yes is a plan'
[[ "$(code "$binary" ai serve --listen=10.0.0.5 --yes)" == 2 ]] || fail 'only 127.0.0.1 or 0.0.0.0'
run "$binary" ai serve --listen=0.0.0.0 --yes | grep -q 'API key (shown once' || fail 'a key is made'
[[ "$(stat -c %a "$cfg/ai-api-key")" == 600 ]] || fail 'the key file is private'
grep -q -- "--host 0.0.0.0 --port 8089 --no-webui --api-key-file $cfg/ai-api-key$" "$unit" || fail "network unit: $(grep ExecStart "$unit")"
: > "$LOG"; run "$binary" ai models test tiny-a >/dev/null
grep -q "Authorization: Bearer bxai-" "$LOG" || fail 'requests carry the key on the network'
key1="$(cat "$cfg/ai-api-key")"; run "$binary" ai serve --listen=0.0.0.0 --port=8090 --yes >/dev/null; [[ "$(cat "$cfg/ai-api-key")" == "$key1" ]] || fail 'the key is kept'
run "$binary" ai serve --listen=127.0.0.1 --port=8089 --yes >/dev/null

# ---- remove, status, stop ----
[[ "$(code "$binary" ai models remove tiny-b)" == 2 ]] || fail 'remove without --yes is a plan'
[[ -e "$models/tiny-b.gguf" ]] || fail 'the plan removed the file'
run "$binary" ai models remove tiny-b --yes | grep -q 'Removed tiny-b' || fail 'remove'
[[ ! -e "$models/tiny-b.gguf" ]] && jq -e '.active == "tiny-a"' "$cfg/ai.json" >/dev/null || fail 'removing the active model picks another chat model'
! grep -q '^\[tiny-b\]' "$cfg/ai-models.ini" || fail 'the preset forgets a removed model'
run "$binary" ai status --json | jq -e '.data.engine.installed and .data.server.running and .data.active == "tiny-a" and (.data.models | keys) == ["emb-a","tiny-a"]' >/dev/null || fail "status: $(run "$binary" ai status --json)"
run "$binary" tui ai --json | jq -e '[.data.items[].kind] | .[0:3] == ["hardware","engine","server"] and (index("model") != null)' >/dev/null || fail "the Control Center page: $(run "$binary" tui ai --json | head -c 400)"
run "$binary" ai serve stop | grep -q 'stopped' || fail 'serve stop'
grep -q 'systemctl --user disable --now bxrig-ai.service' "$LOG" || fail 'stop disables the unit'

# ---- setup: plan only (the full run is the commands above) ----
[[ "$(code "$binary" ai setup)" == 2 ]] || fail 'setup without --yes is a plan'
plan "$binary" ai setup --picks=all --tune --json | jq -e '(.data.models | index("emb-a")) != null and (.data.steps | map(select(test("tune"))) | length) == 1' >/dev/null || fail "setup plan: $(plan "$binary" ai setup --picks=all --json)"
[[ "$(code "$binary" ai models nope)" == 2 ]] || fail 'an unknown subcommand exits 2'
echo "ai-local-test: ok"
