#!/usr/bin/env bash
# `bxrig ai shell` with fake hyprctl, dbus-send, yakuake and terminals. Usage: ai-shell-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg/bxrig" "$tmp/rt"
export LOG="$tmp/log"; : > "$LOG"
# fakes: hyprctl (clients come from $tmp/clients.json), dbus-send (yakuake "running" when $tmp/yak exists), terminals, agent
cat > "$tmp/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
echo "hyprctl $*" >> "$LOG"
[[ "$1 $2" == "clients -j" ]] && { cat "$CLIENTS" 2>/dev/null || echo '[]'; exit 0; }
[[ "$1 $2" == "monitors -j" ]] && { echo '[{"name":"DP-1","x":0,"y":0,"width":2560,"height":1600,"scale":1.0,"focused":true,"reserved":[0,36,0,0]}]'; exit 0; }
[[ "$2" == exec ]] && echo '[{"class":"com.bxrig.ai","workspace":{"name":"special:ai"}}]' > "$CLIENTS"
[[ -n "${FAIL_LEGACY:-}" && "$2" == togglespecialworkspace ]] && exit 1
exit 0
SH
cat > "$tmp/bin/dbus-send" <<'SH'
#!/usr/bin/env bash
echo "dbus-send $*" >> "$LOG"
if [[ "$*" == *NameHasOwner* ]]; then [[ -e "$YAK" ]] && echo "   boolean true" || echo "   boolean false"; fi
exit 0
SH
printf '#!/usr/bin/env bash\necho "yakuake started" >> "$LOG"; touch "$YAK"\n' > "$tmp/bin/yakuake"
for t in ghostty kitty; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n' "$t" > "$tmp/bin/$t"; done
printf '#!/usr/bin/env bash\necho agent\n' > "$tmp/bin/claude"
chmod +x "$tmp/bin"/*
export CLIENTS="$tmp/clients.json" YAK="$tmp/yak"
run() { env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u GEMINI_API_KEY HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_DATA_HOME="$tmp/data" BXRIG_SELF=bxrig XDG_RUNTIME_DIR="$tmp/rt" XDG_CURRENT_DESKTOP="${DESK:-}" HYPRLAND_INSTANCE_SIGNATURE= LOG="$LOG" CLIENTS="$CLIENTS" YAK="$YAK" FAIL_LEGACY="${FAIL_LEGACY:-}" PATH="$tmp/bin:$PATH" "$@"; }
wait_log() { for _ in $(seq 1 30); do grep -q "$1" "$LOG" && return 0; sleep 0.2; done; return 1; }
printf '{"default":"claude-code"}\n' > "$tmp/cfg/bxrig/ai.json"
printf '{"backend":"file"}\n' > "$tmp/cfg/bxrig/secrets.json"

# no desktop, no backend: exit 4
[[ "$(code "$binary" ai shell)" == 4 ]] || fail 'no backend exits 4'
[[ "$(code "$binary" ai shell bogus --backend=hyprland)" == 2 ]] || fail 'an unknown action exits 2'

# ---- Hyprland ----
printf 'com.mitchellh.ghostty.desktop\n' > "$tmp/cfg/xdg-terminals.list"
echo '[]' > "$CLIENTS"
run "$binary" ai shell --backend=hyprland --dry-run --json | jq -e '.data.action == "opened" and .data.steps[0] == ["hyprctl","dispatch","exec","[float; workspace special:ai; size 1536 720; move 512 40] '"'"'ghostty'"'"' '"'"'--class=com.bxrig.ai'"'"' '"'"'-e'"'"' '"'"'bxrig'"'"' '"'"'secrets'"'"' '"'"'run'"'"' '"'"'ANTHROPIC_API_KEY'"'"' '"'"'--'"'"' '"'"'claude'"'"'"]' >/dev/null || fail "dry-run opens centered, with the class and the agent: $(run "$binary" ai shell --backend=hyprland --dry-run --json)"
[[ ! -s "$LOG" || "$(grep -vc '^hyprctl \(clients\|monitors\)' "$LOG")" == 0 ]] || fail 'dry-run started something'
: > "$LOG"
run "$binary" ai shell --backend=hyprland | grep -q 'AI shell opened (Claude Code)' || fail 'first call opens the shell'
wait_log "hyprctl dispatch exec \[float; workspace special:ai; size 1536 720; move 512 40\] 'ghostty' '--class=com.bxrig.ai'" || fail "terminal start: $(cat "$LOG")"
grep -q 'hyprctl dispatch resizewindowpixel exact 1536 720,class:com.bxrig.ai' "$LOG" || fail 'sized as a centered drop-down (60% x 45%)'
grep -q 'hyprctl dispatch movewindowpixel exact 512 40,class:com.bxrig.ai' "$LOG" || fail 'centered, hanging from below the bar'
# the window exists: the next call toggles the special workspace
echo '[{"class":"com.bxrig.ai","workspace":{"name":"special:ai"}}]' > "$CLIENTS"; : > "$LOG"
run "$binary" ai shell --backend=hyprland | grep -q 'AI shell toggled' || fail 'second call toggles'
grep -q 'hyprctl dispatch togglespecialworkspace ai' "$LOG" || fail "toggle dispatch: $(cat "$LOG")"
! grep -q '^ghostty' "$LOG" || fail 'a second terminal was started'
# Lua-mode fallback when the legacy dispatcher fails
: > "$LOG"; FAIL_LEGACY=1 run "$binary" ai shell --backend=hyprland >/dev/null || fail 'the Lua form is tried when the legacy one fails'
grep -q 'hl.dsp.workspace.toggle_special("ai")' "$LOG" || fail 'Lua dispatcher fallback'
run "$binary" ai shell status --backend=hyprland --json | jq -e '.data.running == true' >/dev/null || fail 'status'
# no default agent: a plain shell
rm "$tmp/cfg/bxrig/ai.json"; echo '[]' > "$CLIENTS"
SHELL=/bin/zsh run "$binary" ai shell --backend=hyprland --dry-run --json | jq -e '.data.runs == "your shell" and (.data.steps[0][3] | contains("/bin/zsh"))' >/dev/null || fail 'without a default agent it opens a shell'
# only konsole-like (no class support): kitty works, none exits 4
printf 'kitty.desktop\n' > "$tmp/cfg/xdg-terminals.list"
run "$binary" ai shell --backend=hyprland --dry-run --json | jq -e '(.data.steps[0][3] | contains("'"'"'kitty'"'"' '"'"'--class'"'"' '"'"'com.bxrig.ai'"'"'"))' >/dev/null || fail 'kitty takes --class'
rm "$tmp/bin/ghostty" "$tmp/bin/kitty"; [[ "$(code "$binary" ai shell --backend=hyprland --dry-run)" == 4 ]] || fail 'no terminal that can set a class exits 4'
printf '#!/usr/bin/env bash\necho "ghostty $*" >> "$LOG"\n' > "$tmp/bin/ghostty"; chmod +x "$tmp/bin/ghostty"

# ---- Yakuake (Plasma) ----
printf '{"default":"claude-code"}\n' > "$tmp/cfg/bxrig/ai.json"; rm -f "$YAK" "$tmp/rt/bxrig-ai-shell"; : > "$LOG"
DESK=KDE run "$binary" ai shell --dry-run --json | jq -e '.data.backend == "yakuake"' >/dev/null || fail 'KDE picks yakuake'
DESK=KDE run "$binary" ai shell | grep -q 'AI shell opened (Claude Code)' || fail "yakuake first call: $(DESK=KDE run "$binary" ai shell 2>&1; cat "$LOG")"
grep -q '^yakuake started$' "$LOG" || fail 'yakuake was started'
! grep -q "org.kde.yakuake.addSession" "$LOG" || fail 'a freshly started Yakuake reuses its first tab'
rc="$(find "$tmp" -name yakuakerc | head -1)"
[[ -n "$rc" ]] || fail 'yakuakerc was written'
grep -q '^Width=60$' "$rc" && grep -q '^Height=45$' "$rc" && grep -q '^Position=50$' "$rc" && grep -q '^KeepOpen=true$' "$rc" || fail "the drop-down is centered and stays open: $(cat "$rc")"
grep -q "org.kde.yakuake.runCommand string:'bxrig' 'secrets' 'run' 'ANTHROPIC_API_KEY' '--' 'claude'" "$LOG" || fail "the agent command ran in the tab: $(grep runCommand "$LOG")"
grep -q '/yakuake/window org.kde.yakuake.toggleWindowState' "$LOG" || fail 'the window was shown'
[[ -f "$tmp/rt/bxrig-ai-shell" ]] || fail 'the tab is remembered'
: > "$LOG"; DESK=KDE run "$binary" ai shell | grep -q 'AI shell toggled' || fail 'second call toggles'
! grep -q 'addSession\|yakuake started' "$LOG" || fail 'a second call added another tab'
# a size you chose is kept
printf '[Window]\nWidth=80\n' > "$rc"; rm -f "$YAK" "$tmp/rt/bxrig-ai-shell"; DESK=KDE run "$binary" ai shell >/dev/null
grep -q '^Width=80$' "$rc" && grep -q '^Height=45$' "$rc" || fail "an existing Width is kept, the missing keys are added: $(cat "$rc")"
# Yakuake already running but no tab of ours: a new tab is added
touch "$YAK"; rm -f "$tmp/rt/bxrig-ai-shell"; : > "$LOG"; DESK=KDE run "$binary" ai shell >/dev/null
grep -q 'org.kde.yakuake.addSession' "$LOG" || fail 'a running Yakuake gets a new tab'
grep -q 'toggleWindowState' "$LOG" || fail 'toggle'
rm -f "$YAK"; rm "$tmp/bin/yakuake"; [[ "$(DESK=KDE code "$binary" ai shell)" == 4 ]] || fail 'Yakuake missing exits 4'
echo "ai-shell-test: ok"
