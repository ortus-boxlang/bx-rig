#!/usr/bin/env bash
# `bxrig ai agents` with fakes: bx-module (installs a fake bx-agents into BOXLANG_HOME), bxAgents (records what it is given and where; `new`
# makes a project), systemctl (records, answers is-active from a file), curl (ForgeBox) and xdg-open. Usage: ai-agents-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
export LOG="$tmp/log"; : > "$LOG"
H="$tmp/home"; BL="$H/.boxlang"; mkdir -p "$H/.config/bxrig" "$tmp/state"
cat > "$H/.config/bxrig/ai.json" <<'JSON'
{ "active": "tiny-a", "models": { "tiny-a": { "kind": "chat" } }, "serve": { "listen": "127.0.0.1", "port": 8089 } }
JSON
stub bx-module 'echo "bx-module $*" >> "$LOG"
[[ "$1" == install ]] || exit 0
d="$BOXLANG_HOME/modules/bx-agents"; mkdir -p "$d"; : > "$d/ModuleConfig.bx"
v="${2#bx-agents@}"; [[ "$v" == snapshot ]] && v=1.0.0-snapshot; printf "{\"version\":\"%s\"}" "$v" > "$d/box.json"'
stub bxAgents 'echo "bxAgents $* (in $PWD)" >> "$LOG"
if [[ "$1" == new ]]; then mkdir -p "$2"; printf "name: %s\nmodel: openai-compatible/x\n" "$2" > "$2/Agent.yml"; echo "Created $2"; fi
exit 0'
stub boxlang-miniserver 'exit 0'
stub systemctl 'echo "systemctl $*" >> "$LOG"
unit=""; for a in "$@"; do case "$a" in *.service) unit="$a";; esac; done
case "$*" in
  *is-active*) if [[ -e "$STATE/$unit" ]]; then echo active; else echo inactive; exit 3; fi ;;
  *enable*) touch "$STATE/$unit" ;;
  *disable*) rm -f "$STATE/$unit" ;;
esac
exit 0'
stub curl 'echo "curl $*" >> "$LOG"
case "$*" in
  *forgebox.test/api/v1/entry/bx-agents*) if [[ -e "$STATE/stable" ]]; then printf "{\"data\":{\"versions\":[{\"version\":\"1.1.0-snapshot\"},{\"version\":\"1.0.0\"}]}}"; else printf "{\"data\":{\"versions\":[{\"version\":\"1.0.0-snapshot\"}]}}"; fi ;;
  *) exit 7 ;;
esac'
stub xdg-open 'echo "xdg-open $*" >> "$LOG"'
run() { env HOME="$H" BXRIG_SELF="$binary" BOXLANG_HOME="$BL" STATE="$tmp/state" PATH="$tmp/bin:$PATH" BXRIG_BXAGENTS="$tmp/bin/bxAgents" BXRIG_MINISERVER="$tmp/bin/boxlang-miniserver" \
	BXRIG_BOXLANG_JARS="$tmp/jars" BXRIG_FORGEBOX_API="http://forgebox.test/api/v1" BXAGENTS_USER_CONFIG="$H/.bxagents/Agent.yml" "$binary" "$@"; }
yml="$H/.bxagents/Agent.yml"

# nothing yet
out="$(run ai agents)"; [[ "$out" == *"bx-agents is not installed"* && "$out" == *"No agents in $H/Agents"* ]] || fail "an empty machine: $out"
run ai agents --json | jq -e '.data.installed == false and .data.root == "'"$H/Agents"'" and (.data.agents | length) == 0' >/dev/null || fail 'the empty list as JSON'
[[ "$(code ai agents new Boxy)" == 4 ]] || fail 'new before bx-agents is installed'

# install: the plan, then the snapshot, the jar cache cleared, the profile written
out="$(run ai agents install || true)"; [[ "$out" == *"bx-module install bx-agents@snapshot"* && "$out" == *"Add --yes"* ]] || fail "the install plan: $out"
! grep -q bx-module "$LOG" || fail 'the plan ran bx-module'
mkdir -p "$tmp/jars"; : > "$tmp/jars/old.jar"
out="$(run ai agents install --yes)"; [[ "$out" == *"bx-agents 1.0.0-snapshot installed"* && "$out" == *"profile bxrig (tiny-a at http://127.0.0.1:8089/v1)"* ]] || fail "install: $out"
grep -q 'bx-module install bx-agents@snapshot' "$LOG" || fail 'install ran bx-module with the snapshot'
[[ ! -e "$tmp/jars" ]] || fail 'the jar cache was cleared'
grep -q '^  bxrig:$' "$yml" && grep -q 'baseURL: "http://127.0.0.1:8089/v1"' "$yml" && grep -q 'model: tiny-a' "$yml" || fail 'the bxrig profile was written'

# --stable: refused while ForgeBox has no stable release, then the newest stable one
[[ "$(code ai agents install --stable --yes)" == 4 ]] || fail '--stable without a stable release'
touch "$tmp/state/stable"; run ai agents update --stable --yes >/dev/null
grep -q 'bx-module install bx-agents@1.0.0' "$LOG" || fail '--stable installs the newest stable version'

# the profile follows the active model, and keeps the person's own settings
printf 'chat:\n  shell: true\n' > "$tmp/mine"; cat "$yml" >> "$tmp/mine"; mv "$tmp/mine" "$yml"
sed -i 's/"active": "tiny-a"/"active": "tiny-b"/' "$H/.config/bxrig/ai.json"
run ai agents profile >/dev/null
grep -q 'model: tiny-b' "$yml" && head -1 "$yml" | grep -q '^chat:' || fail 'the profile again: the new model, the rest kept'
run ai agents profile --off >/dev/null; [[ "$(cat "$yml")" == $'chat:\n  shell: true' ]] || fail "profile --off: $(cat "$yml")"

# new: bxAgents new in the projects folder, with the flags as typed
run ai agents new Boxy --model=openai-compatible/tiny-a --no-wizard >/dev/null
grep -q "bxAgents new Boxy --model=openai-compatible/tiny-a --no-wizard (in $H/Agents)" "$LOG" || fail "new: $(grep bxAgents "$LOG")"
[[ "$(code ai agents new Boxy)" == 4 ]] || fail 'a second agent with the same name'
[[ "$(code ai agents new start)" == 2 ]] || fail 'a command word as a name'
run ai agents --json | jq -e '.data.agents[0].name == "Boxy" and .data.agents[0].port == 8790 and .data.agents[0].running == false' >/dev/null || fail 'Boxy is listed on port 8790'

# the rest goes to bxAgents with the project, exactly as typed
run ai agents Boxy routines list "--name=Morning news" >/dev/null
grep -q "bxAgents routines --projectRoot=$H/Agents/Boxy list --name=Morning news (in $H/Agents/Boxy)" "$LOG" || fail "pass-through: $(grep 'bxAgents routines' "$LOG")"
[[ "$(code ai agents Nobody chat)" == 2 ]] || fail 'an unknown agent'

# start, status, open, default, stop
run ai agents start Boxy >/dev/null
u="$H/.config/systemd/user/bxrig-agent-boxy.service"
grep -q "^ExecStartPre=$tmp/bin/bxAgents build --projectRoot=$H/Agents/Boxy --no-banner$" "$u" || fail 'the unit builds first'
grep -q "^ExecStart=/bin/sh -c \"cd .build && exec $tmp/bin/boxlang-miniserver --port 8790 --host 127.0.0.1\"$" "$u" || fail "the unit runs the miniserver: $(grep ExecStart= "$u")"
grep -q 'systemctl --user enable --now bxrig-agent-boxy.service' "$LOG" || fail 'start enables the unit'
run ai agents status Boxy | grep -q 'Boxy is running at http://127.0.0.1:8790/' || fail 'status while running'
run ai agents open Boxy >/dev/null; grep -q 'xdg-open http://127.0.0.1:8790/' "$LOG" || fail 'open'
run ai agents default Boxy >/dev/null; run ai agents | grep -q '^● Boxy .*running' || fail 'the default and running mark'
run ai agents stop Boxy >/dev/null; grep -q 'systemctl --user disable --now bxrig-agent-boxy.service' "$LOG" || fail 'stop'
[[ "$(code ai agents open Boxy)" == 4 ]] || fail 'open while stopped'

# add a project from elsewhere, refuse a second one with the same name, forget it
mkdir -p "$tmp/work/helper" "$tmp/work/other"; printf 'name: Helper\n' > "$tmp/work/helper/Agent.yml"; printf 'name: Boxy\n' > "$tmp/work/other/Agent.yml"
run ai agents add "$tmp/work/helper" | grep -q 'Added Helper .* on port 8791' || fail 'add'
[[ "$(code ai agents add "$tmp/work/other")" == 4 ]] || fail 'a second Boxy'
[[ "$(code ai agents add "$tmp")" == 4 ]] || fail 'a folder that is not a project'
{ run ai agents forget Helper || true; } | grep -q 'Add --yes' || fail 'forget shows its plan'
run ai agents forget Helper --yes >/dev/null; run ai agents --json | jq -e '[.data.agents[].name] == ["Boxy"]' >/dev/null || fail 'forget'
[[ -f "$tmp/work/helper/Agent.yml" ]] || fail 'forget keeps the project'

# the projects folder
run ai agents dir "$tmp/work" >/dev/null; run ai agents --json | jq -e '.data.root == "'"$tmp/work"'" and ([.data.agents[].name] | sort) == ["Boxy","Helper"]' >/dev/null || fail 'dir'
[[ "$(code ai agents dir relative/path)" == 2 ]] || fail 'dir wants a full path'

# update restarts the agents that run
run ai agents dir "$H/Agents" >/dev/null; run ai agents start Boxy >/dev/null; : > "$LOG"
run ai agents update --yes | grep -q 'Restarted Boxy' || fail 'update restarts'
grep -q 'systemctl --user restart bxrig-agent-boxy.service' "$LOG" || fail 'update restarts the running unit'

# the Control Center page
run tui ai-boxlang --json | jq -e '.data.items[0].name == "Boxy" and .data.items[0].state == "running"' >/dev/null || fail 'the BoxLang agents page'
echo "ai-agents-test: ok"
