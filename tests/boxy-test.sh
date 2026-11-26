#!/usr/bin/env bash
# `bxrig boxy`: the look (name, colour, outfits by date), the state, the images, hold-to-talk with a fake Voxtype, and speech through a fake
# OpenAI-compatible server (a fake curl) and a fake player. Nothing real is recorded or sent. Usage: boxy-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
export LOG="$tmp/log"; : > "$LOG"
H="$tmp/home"; mkdir -p "$H" "$tmp/bin"
stub voxtype 'echo "voxtype $*" >> "$LOG"
case "$1 $2" in
"record start") for a in "$@"; do f="$a"; done; echo "$f" > "$HOME/.outfile" ;;
"record stop") [[ "${BOXY_SILENT:-}" == 1 ]] || printf "what time is it" > "$(cat "$HOME/.outfile")" ;;
esac'
stub notify-send 'echo "notify $*" >> "$LOG"'
stub pw-play 'echo "play $*" >> "$LOG"'
stub curl 'out=""; body=""; cfg=""; args=("$@"); for ((i=0;i<${#args[@]};i++)); do case "${args[i]}" in -o) out="${args[i+1]}" ;; -d) body="${args[i+1]}" ;; -K) cfg="${args[i+1]}" ;; esac; done
echo "curl body=$body auth=$( [[ -n "$cfg" ]] && cat "$cfg" || true )" >> "$LOG"; [[ -n "$out" ]] && printf RIFFfake > "$out"; true'
run() { env HOME="$H" LOG="$LOG" BXRIG_SELF=bxrig PATH="$tmp/bin:$PATH" "$@"; }
bx() { run "$binary" boxy "$@"; }

# ---- the look: defaults, then changes ----
bx --json | jq -e '.data.name == "Boxy" and .data.state == "idle" and .data.voice.enabled == false and (.data.sprite | length) >= 1' >/dev/null || fail "status: $(bx --json)"
bx look --name=Pixel --color='#FF8800' --outfit=sunglasses --json | jq -e '.data.name == "Pixel" and .data.accent == "#ff8800" and .data.outfit == "sunglasses"' >/dev/null || fail "look set: $(bx look --json)"
[[ "$(code "$binary" boxy look --outfit=zzz)" == 2 && "$(code "$binary" boxy look --color=red)" == 2 && "$(code "$binary" boxy look --birthday=13-40)" == 2 && "$(code "$binary" boxy look --name='bad;name')" == 2 ]] || fail 'bad look values are usage errors'
# the season and the holidays, by date
bx look --outfit=auto >/dev/null
[[ "$(BXRIG_TODAY=2026-07-10 bx --json | jq -r .data.outfit)" == sunglasses ]] || fail 'summer is sunglasses'
[[ "$(BXRIG_TODAY=2026-01-10 bx --json | jq -r .data.outfit)" == beanie ]] || fail 'winter is the beanie'
[[ "$(BXRIG_TODAY=2026-12-24 bx --json | jq -r .data.outfit)" == beanie ]] || fail 'holidays are off until chosen'
bx look --holidays=christmas,halloween --birthday=03-09 >/dev/null
[[ "$(BXRIG_TODAY=2026-12-24 bx --json | jq -r .data.outfit)" == santa ]] || fail 'christmas outfit once chosen'
[[ "$(BXRIG_TODAY=2026-10-31 bx --json | jq -r .data.outfit)" == pumpkin ]] || fail 'halloween outfit'
[[ "$(BXRIG_TODAY=2026-03-09 bx --json | jq -r .data.outfit)" == party ]] || fail 'birthday outfit'
bx look --outfit=none >/dev/null
[[ "$(BXRIG_TODAY=2026-12-24 bx --json | jq -r .data.outfit)" == "" ]] || fail 'none means no outfit'
bx look --outfit=auto --holidays=none --birthday= >/dev/null

# ---- images and state ----
bx export --dir="$tmp/img" --json | jq -e '(.data.files | length) == 4' >/dev/null || fail "export: $(bx export --dir="$tmp/img")"
ls "$tmp/img"/boxy-*.svg | wc -l | grep -q 7 || fail 'seven SVGs: one each and the working swirl in four'
grep -q '<svg' "$tmp/img/boxy-listening.svg" || fail 'svg content'
bx state --json | jq -e '.data.state == "idle" and (.data.image | length) > 0 and (.data.frames | length) == 1' >/dev/null || fail 'state'

# ---- speech: off until set up, never sends before it is on ----
bx voice --json | jq -e '.data.enabled == false and .data.configured == false' >/dev/null || fail 'voice off'
[[ "$(code "$binary" boxy voice on)" == 4 ]] || fail 'voice on before set up is a precondition'
[[ "$(code "$binary" boxy say hello)" == 4 ]] || fail 'say before set up is a precondition'
[[ "$(code "$binary" boxy voice set --url=ftp://x)" == 2 ]] || fail 'url must be http(s)'
bx voice set --url=https://api.example.com/v1/audio/speech --model=tts-1 --voice=alloy --key=TTS_KEY --json | jq -e '.data.configured and .data.where == "api.example.com" and .data.enabled == false' >/dev/null || fail 'voice set'
bx voice on | grep -q 'sent to api.example.com' || fail 'voice on says where words go'
grep -q curl "$LOG" && fail 'nothing was sent yet'
TTS_KEY=sekret bx say 'Hello *there*' | grep -q Spoken || fail 'say'
grep -q 'curl body={"input":"Hello there","model":"tts-1","response_format":"wav","voice":"alloy"}\|curl body=.*"input":"Hello there"' "$LOG" || fail "request body: $(cat "$LOG")"
grep -q 'Authorization: Bearer sekret' "$LOG" || fail 'the key goes in a header file, not argv'
grep -q 'sekret' <(grep '^curl' "$LOG" | sed 's/auth=.*//') && fail 'the key never appears in the command line'
grep -q '^play ' "$LOG" || fail 'the audio is played'
bx voice off >/dev/null; bx voice --json | jq -e '.data.enabled == false and .data.configured' >/dev/null || fail 'voice off keeps the settings'

# ---- speech on this machine: bx-audio, English and Spanish ----
stub bx-audio 'echo "bx-audio accent=${BX_AUDIO_ACCENT:-} $*" >> "$LOG"
if [[ "$1" == voices ]]; then echo "dora  es_ES  Apache-2.0"; exit 0; fi
for a in "$@"; do case "$a" in --out=*) printf RIFFfake > "${a#--out=}" ;; esac; done'
: > "$LOG"
[[ "$(code "$binary" boxy voice local --lang=fr --yes)" == 2 && "$(code "$binary" boxy voice local --accent=klingon --yes)" == 2 && "$(code "$binary" boxy voice local --voice=dora --yes)" == 2 && "$(code "$binary" boxy voice local --speed=9 --yes)" == 2 && "$(code "$binary" boxy voice local --hear=fr --yes)" == 2 ]] || fail 'bad local options are usage errors'
[[ "$(code "$binary" boxy voice local)" == 2 ]] || fail 'local voice shows a plan before --yes'
grep -q 'bx-audio' "$LOG" && fail 'the plan runs nothing'
bx voice local --dry-run --lang=auto --accent=castilian --hear=auto | grep -q 'Castilian' || fail 'dry run says the accent'
[[ -f "$H/.config/bxrig/boxy.json" ]] && jq -e '.voice.engine == "bx-audio"' "$H/.config/bxrig/boxy.json" >/dev/null && fail 'dry run writes nothing'
bx voice local --yes --json | jq -e '.data.engine == "bx-audio" and .data.lang == "auto" and .data.accent == "latam" and .data.voices.es == "dora" and .data.voices.en == "joe"' >/dev/null || fail 'local on, defaults: Latin American, dora and joe'
grep -q 'speak Hello, I am Pixel --voice=joe' "$LOG" && grep -q 'speak Hola, soy Pixel --voice=dora' "$LOG" || fail "both voices are fetched first: $(cat "$LOG")"
bx voice --json | jq -e '.data.enabled and .data.engine == "bx-audio" and .data.configured and .data.where == "this machine"' >/dev/null || fail 'voice status says local'
bx voice | grep -q 'Nothing leaves this machine' || fail 'status says nothing leaves'
bx --json | jq -e '.data.voice.engine == "bx-audio" and .data.voice.where == "this machine"' >/dev/null || fail 'boxy status says local'
: > "$LOG"; bx say "Hola, ¿cómo estás? Gracias por todo." >/dev/null || fail 'say in Spanish'
grep -q 'accent=latam speak --file=.* --voice=dora ' "$LOG" || fail "Spanish text uses dora, Latin American: $(cat "$LOG")"
grep -q '^play ' "$LOG" || fail 'the audio is played'
: > "$LOG"; bx say "The weather is nice and it is for you." >/dev/null; grep -q -- '--voice=joe ' "$LOG" || fail "English text uses joe: $(cat "$LOG")"
: > "$LOG"; bx say "La casa es grande" >/dev/null; grep -q -- '--voice=dora ' "$LOG" || fail "small Spanish words are enough: $(cat "$LOG")"
bx voice local --yes --lang=es --voice=alex --accent=castilian --speed=1.1 --hear=es >/dev/null || fail 'local with options'
: > "$LOG"; bx say "hello there" >/dev/null; grep -q 'accent=castilian speak --file=.* --voice=alex --out=.* --speed=1.1' "$LOG" || fail "a fixed language ignores the text's: $(cat "$LOG")"
grep -q 'language="es"' "$H/.config/voxtype/config.toml" || fail "Voxtype listens for Spanish: $(cat "$H/.config/voxtype/config.toml")"
bx voice test --lang=es --json | jq -e '.data.spoke and .data.voice == "alex"' >/dev/null || fail 'voice test'
bx voice list --lang=es | grep -q dora || fail 'voice list'
[[ "$(code "$binary" boxy voice local --yes --lang=auto --voice=dora)" == 2 ]] || fail '--voice with lang auto is a usage error'
bx voice set --url=https://api.example.com/v1/audio/speech --model=tts-1 --voice=alloy >/dev/null; bx voice --json | jq -e '.data.engine == "http"' >/dev/null || fail 'voice set goes back to a server'
mv "$tmp/bin/bx-audio" "$tmp/bin/bx-audio.off"; [[ "$(code "$binary" boxy voice local --yes --lang=en)" == 4 ]] || fail 'no bx-audio is a precondition'
mv "$tmp/bin/bx-audio.off" "$tmp/bin/bx-audio"

# ---- hold to talk ----
: > "$LOG"
bx listen start | grep -q 'is listening' || fail 'listen start'
grep -q 'voxtype record start --output-file' "$LOG" || fail "voxtype start: $(cat "$LOG")"
[[ "$(bx state --json | jq -r .data.state)" == listening ]] || fail 'state is listening'
bx listen stop >/dev/null || true
grep -q 'voxtype record stop' "$LOG" || fail 'voxtype stop'
grep -q 'notify .*what time is it\|could not ask' "$LOG" || fail "the heard words reach a notice: $(cat "$LOG")"
[[ "$(bx state --json | jq -r .data.state)" == idle ]] || fail 'back to idle'
: > "$LOG"; bx listen start >/dev/null; BOXY_SILENT=1 bx listen stop | grep -q 'Nothing was heard' || fail 'silence'
[[ "$(code "$binary" boxy listen sideways)" == 2 ]] || fail 'listen usage'
rm "$tmp/bin/voxtype"; [[ "$(code "$binary" boxy listen start)" == 4 ]] || fail 'no voxtype is a precondition'
echo "boxy-test ok"
