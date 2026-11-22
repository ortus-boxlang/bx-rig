#!/usr/bin/env bash
# `bxrig ai session` with a fake tmux. Usage: ai-session-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg/bxrig" "$tmp/tm" "$tmp/work"
export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/bin/tmux" <<'SH'
#!/usr/bin/env bash
echo "tmux $*" >> "$LOG"
case "$1" in
  new-session) while [[ $# -gt 0 ]]; do [[ "$1" == -s ]] && n="$2"; shift; done; : > "$TM/$n" ;;
  list-sessions) ls "$TM" 2>/dev/null | grep . || exit 1 ;;
  attach-session) echo "attached $3" ;;
  kill-session) rm -f "$TM/$3" ;;
esac
SH
printf '#!/usr/bin/env bash\necho claude\n' > "$tmp/bin/claude"
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\n[[ "$1" == is-active ]] && echo "${SVC:-inactive}"\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\necho "sudo $*" >> "$LOG"\nexec "$@"\n' > "$tmp/bin/sudo"
chmod +x "$tmp/bin"/*
run() { env -u ANTHROPIC_API_KEY HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_DATA_HOME="$tmp/data" BXRIG_SELF=bxrig TM="$tmp/tm" LOG="$LOG" SVC="${SVC:-}" NO_SERVER="${NO_SERVER:-}" PWD="$tmp/work" PATH="$tmp/bin:$PATH" "$@"; }
printf '{"default":"claude-code"}\n' > "$tmp/cfg/bxrig/ai.json"; printf '{"backend":"file"}\n' > "$tmp/cfg/bxrig/secrets.json"

# ---- sessions ----
run "$binary" ai session list | grep -q 'No agent sessions are running' || fail 'empty list'
run "$binary" ai session start --dry-run --json | jq -e ".data.session == \"bxrig-claude-code\" and .data.dir == \"$tmp/work\" and .data.command[0:6] == [\"tmux\",\"new-session\",\"-d\",\"-s\",\"bxrig-claude-code\",\"-c\"]" >/dev/null || fail "dry-run: $(run "$binary" ai session start --dry-run --json)"
[[ ! -s "$LOG" || "$(grep -vc 'list-sessions' "$LOG")" == 0 ]] || fail 'dry-run created a session'
run "$binary" ai session start | grep -q 'Started bxrig-claude-code' || fail 'start'
grep -q "tmux new-session -d -s bxrig-claude-code -c $tmp/work 'bxrig' 'secrets' 'run' 'ANTHROPIC_API_KEY' '--' 'claude'" "$LOG" || fail "tmux command: $(grep new-session "$LOG")"
run "$binary" ai session start | grep -q 'already running' || fail 'start is idempotent'
[[ "$(grep -c new-session "$LOG")" == 1 ]] || fail 'a second session was created'
run "$binary" ai session start claude-code --name=api --dir="$tmp" --json | jq -e '.data.session == "bxrig-claude-code-api" and .data.dir == "'"$tmp"'"' >/dev/null || fail 'named session in another folder'
run "$binary" ai session list --json | jq -e '.data.sessions == ["bxrig-claude-code","bxrig-claude-code-api"]' >/dev/null || fail 'list'
touch "$tmp/tm/other-session"; run "$binary" ai session list --json | jq -e '(.data.sessions | index("other-session")) == null' >/dev/null || fail "other tmux sessions are not listed"
run "$binary" ai session attach claude-code-api | grep -q 'attached bxrig-claude-code-api' || fail 'attach by short name'
[[ "$(code "$binary" ai session attach nope)" == 4 ]] || fail 'attach to a missing session exits 4'
[[ "$(code "$binary" ai session start --name='a b')" == 2 ]] || fail 'a bad name exits 2'
[[ "$(code "$binary" ai session start codex-cli)" == 4 ]] || fail 'an agent that is not installed exits 4'
[[ "$(code "$binary" ai session stop claude-code-api)" == 2 ]] || fail 'stop without --yes exits 2'
[[ -e "$tmp/tm/bxrig-claude-code-api" ]] || fail 'the plan ended the session'
run "$binary" ai session stop claude-code-api --yes | grep -q 'was ended' || fail 'stop --yes'
[[ ! -e "$tmp/tm/bxrig-claude-code-api" ]] || fail 'stop did not end it'
mkdir -p "$tmp/nobin"; ln -sf "$(command -v sh)" "$tmp/nobin/sh"; ln -sf "$tmp/bin/claude" "$tmp/nobin/claude"
set +e; env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/nobin" "$binary" ai session start >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail "no tmux exits 4 (got $rc)"

echo "ai-session-test: ok"
