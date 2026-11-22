#!/usr/bin/env bash
# `bxrig boxlang` with fake bvm, mvm, bx-module, code and curl (a canned ForgeBox answer). Usage: boxlang-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/nobin"; export LOG="$tmp/log"; : > "$LOG"
logger() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n%s\n' "$1" "${2:-}" > "$tmp/bin/$1"; }
logger boxlang 'echo "BoxLang 1.19.0"'
logger bvm 'case "$1" in current) echo 1.19.0 ;; list) echo "1.19.0" ;; esac'
logger mvm 'case "$1" in list) echo "0.14.0" ;; esac'
logger matchbox 'echo "MatchBox 0.14.0"'
logger bx-module 'echo "done"'
logger code 'case "$1" in --list-extensions) echo ortus-solutions.vscode-boxlang ;; esac'
logger xdg-open
printf '#!/usr/bin/env bash\necho "curl $*" >> "$LOG"\necho '"'"'{"data":{"results":[{"slug":"bx-ai","title":"BoxLang AI","summary":"AI integration","latestVersion":{"version":"3.7.0"}},{"slug":"bx-sites","title":"Sites","summary":"Static sites","latestVersion":{"version":"1.0.0"}}]}}'"'"'\n' > "$tmp/bin/curl"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }

run "$binary" boxlang status --json | jq -e '.data.boxlang == "BoxLang 1.19.0" and .data.bvm == "1.19.0" and .data.mvm and .data.bx_module and .data.vscode_extension' >/dev/null || fail "status: $(run "$binary" boxlang status --json)"
# use: bvm and mvm, installing a missing version first
run "$binary" boxlang use 1.19.0 | grep -q 'bvm now uses 1.19.0' || fail 'use'
grep -q '^bvm use 1.19.0' "$LOG" && ! grep -q '^bvm install 1.19.0' "$LOG" || fail "an installed version is not reinstalled: $(cat "$LOG")"
: > "$LOG"; run "$binary" boxlang use snapshot >/dev/null; grep -q '^bvm install snapshot' "$LOG" && grep -q '^bvm use snapshot' "$LOG" || fail 'a missing version is installed first'
: > "$LOG"; run "$binary" boxlang matchbox use 0.15.0 >/dev/null; grep -q '^mvm install 0.15.0' "$LOG" && grep -q '^mvm use 0.15.0' "$LOG" || fail 'mvm'
[[ "$(code "$binary" boxlang use 'a;b')" == 4 ]] || fail 'a bad version exits 4'
# matchbox: the home, config, .env files and logs (HOME is $tmp/home; MatchBox creates the home on its first run)
unset MATCHBOX_HOME  # a developer's own MatchBox home must not leak into the test
mb="$tmp/home/.matchbox"; mkdir -p "$tmp/proj"
run_in() { local d="$1"; shift; (cd "$d" && env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" LOG="$LOG" PWD="$d" "$@"); }
# A MatchBox with a runtime home creates it when this very command starts, an older one does not: status must agree with the disk either way.
st="$(run_in "$tmp/proj" "$binary" boxlang matchbox status --json | jq -c .data)"
want_home=false; [[ -d "$mb" ]] && want_home=true
echo "$st" | jq -e --arg home "$mb" --argjson want "$want_home" '.home == $home and .home_exists == $want and .env_user_exists == false' >/dev/null || fail "matchbox status agrees with the disk: $st"
echo '{}' > "$tmp/proj/boxlang.json"; echo 'A=1' > "$tmp/proj/.env"; mkdir -p "$mb/config" "$mb/logs"; : > "$mb/logs/application.log"; : > "$mb/logs/runtime.log"
printf '// keep\n{\n\t"logging": {\n\t\t// level\n\t\t"rootLevel":"WARN", "maxLogDays": 90\n\t}\n}\n' > "$mb/config/boxlang.json"
run_in "$tmp/proj" "$binary" boxlang matchbox status --json | jq -e '.data.home_exists and .data.config_exists and .data.project_config_exists and .data.env_project_exists and (.data.env_user_exists | not) and (.data.logs | contains(["application.log","runtime.log"]))' >/dev/null || fail "matchbox status after a first run: $(run_in "$tmp/proj" "$binary" boxlang matchbox status --json | jq -c .data)"
# log-level: a plan first, then the one value changes and the comments stay
rc=0; run_in "$tmp/proj" "$binary" boxlang matchbox log-level debug >/dev/null || rc=$?; [[ "$rc" == 2 ]] || fail "log-level without --yes is a plan (got $rc)"
grep -q '"rootLevel":"WARN"' "$mb/config/boxlang.json" || fail 'a plan changes nothing'
run_in "$tmp/proj" "$binary" boxlang matchbox log-level debug --yes >/dev/null
grep -q '"rootLevel": "DEBUG", "maxLogDays": 90' "$mb/config/boxlang.json" && grep -q '^// keep$' "$mb/config/boxlang.json" && grep -q '// level' "$mb/config/boxlang.json" || fail "log-level edits one value: $(cat "$mb/config/boxlang.json")"
[[ "$(code "$binary" boxlang matchbox log-level loud --yes)" == 4 ]] || fail 'a bad level exits 4'
printf '{ "a": { "rootLevel": "WARN" }, "logging": { "rootLevel": "INFO" } }' > "$mb/config/boxlang.json"
[[ "$(code "$binary" boxlang matchbox log-level off --yes)" == 4 ]] && grep -q '"rootLevel": "INFO"' "$mb/config/boxlang.json" || fail 'an ambiguous config is left alone'
rm -f "$mb/config/boxlang.json"; run "$binary" boxlang matchbox log-level trace --yes >/dev/null; grep -q '"rootLevel": "TRACE"' "$mb/config/boxlang.json" || fail 'log-level writes a small config when there is none'
MBHOME="$tmp/elsewhere"; run env MATCHBOX_HOME="$MBHOME" "$binary" boxlang matchbox log-level warn --yes >/dev/null; [[ -f "$MBHOME/config/boxlang.json" ]] || fail 'MATCHBOX_HOME moves the home'
# env: names only, one line changed, mode 600, values never printed
run "$binary" boxlang matchbox env list | grep -q 'none yet' || fail 'env list with no file'
rc=0; run "$binary" boxlang matchbox env set API_KEY 'sup3r secret' >"$tmp/plan.txt" || rc=$?; [[ "$rc" == 2 ]] || fail "env set without --yes is a plan (got $rc)"
! grep -q 'sup3r' "$tmp/plan.txt" && [[ ! -e "$tmp/home/.matchbox.env" ]] || fail 'a plan shows no value and writes nothing'
out="$(run "$binary" boxlang matchbox env set API_KEY 'sup3r secret' --yes)"; [[ "$out" != *sup3r* ]] || fail 'env set never prints the value'
run "$binary" boxlang matchbox env set TOKEN abc --yes >/dev/null; run "$binary" boxlang matchbox env set HASH 'a#b' --yes >/dev/null
run "$binary" boxlang matchbox env set TOKEN xyz --yes >/dev/null
f="$tmp/home/.matchbox.env"
[[ "$(cat "$f")" == $'API_KEY="sup3r secret"\nTOKEN=xyz\nHASH="a#b"' ]] || fail "env set changes one line and keeps the rest: $(cat "$f")"
[[ "$(stat -c %a "$f")" == 600 ]] || fail "the env file is mode 600 (got $(stat -c %a "$f"))"
run "$binary" boxlang matchbox env list --json | jq -e '.data.keys == ["API_KEY","TOKEN","HASH"] and (tostring | contains("sup3r") | not)' >/dev/null || fail 'env list names the keys only'
run "$binary" boxlang matchbox env unset TOKEN --yes >/dev/null; [[ "$(cat "$f")" == $'API_KEY="sup3r secret"\nHASH="a#b"' ]] || fail "env unset removes one line: $(cat "$f")"
[[ "$(code "$binary" boxlang matchbox env unset NOPE --yes)" == 4 ]] || fail 'unsetting an unknown key exits 4'
[[ "$(code "$binary" boxlang matchbox env set 'bad key' x --yes)" == 4 ]] || fail 'a bad name exits 4'
[[ "$(code "$binary" boxlang matchbox env set K "it's \"x\"" --yes)" == 4 ]] || fail 'a value with both quote characters exits 4'
[[ "$(code "$binary" boxlang matchbox env set K $'a\nb' --yes)" == 4 ]] || fail 'a value with a line break exits 4'
[[ "$(code "$binary" boxlang matchbox nope)" == 2 ]] || fail 'an unknown matchbox action exits 2'
# logging: every command's exit is written to MatchBox's `bxrig` log (`[bxrig] boxlang exit 4`). MatchBox keeps WARN and above by default, so a
# precondition shows and a normal run does not until `logging.loggers.bxrig.level` is INFO. A MatchBox without a runtime home (an older build)
# ignores writeLog, so the checks run only when this binary's MatchBox made a home.
LH="$tmp/loghome"; mkdir -p "$LH"
run_home() { env HOME="$LH" BXRIG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
run_home "$binary" boxlang status >/dev/null
run_home "$binary" boxlang use 'a;b' >/dev/null 2>&1 || true
if [[ -d "$LH/.matchbox/modules" ]]; then
	blog="$LH/.matchbox/logs/bxrig.log"
	grep -q '\[WARN\] \[bxrig\] boxlang exit 4' "$blog" || fail "a precondition is a warning in the bxrig log: $(cat "$blog" 2>&1)"
	! grep -q 'boxlang exit 0' "$blog" || fail "a normal run is below the default level: $(cat "$blog")"
	printf '{ "logging": { "loggers": { "bxrig": { "level": "INFO" } } } }\n' > "$LH/.matchbox/config/boxlang.json"
	run_home "$binary" boxlang status >/dev/null
	grep -q '\[INFO\] \[bxrig\] boxlang exit 0' "$blog" || fail "logging.loggers.bxrig.level INFO logs every command: $(cat "$blog")"
else
	echo "note: this MatchBox has no runtime home; the bxrig log check is skipped"
fi
# modules: the live ForgeBox list, then bx-module
run "$binary" boxlang modules list | grep -q 'bx-ai  3.7.0  AI integration' || fail 'forgebox list'
grep -q 'entries/boxlang-modules?orderBy=popular&max=50&offset=0' "$LOG" || fail 'forgebox api url'
: > "$LOG"; run "$binary" boxlang modules search ai >/dev/null; grep -q 'searchTerm=ai' "$LOG" || fail 'search term'
: > "$LOG"; run "$binary" boxlang modules install bx-ai bx-sites >/dev/null; grep -q '^bx-module install bx-ai bx-sites' "$LOG" || fail 'bx-module install'
run "$binary" boxlang modules update >/dev/null; grep -q '^bx-module update --force' "$LOG" || fail 'update'
[[ "$(code "$binary" boxlang modules install)" == 4 ]] || fail 'install needs names'
[[ "$(code "$binary" boxlang modules install 'x;y')" == 4 ]] || fail 'bad module name exits 4'
# vscode
: > "$LOG"; run "$binary" boxlang vscode | grep -q 'ortus-solutions.vscode-boxlang' || fail 'vscode'
grep -q '^code --install-extension ortus-solutions.vscode-boxlang --force' "$LOG" && grep -q 'vscode-boxlang-developer-pack' "$LOG" || fail 'both extensions'
rc=0; env HOME="$tmp/home" PATH="$tmp/nobin" "$binary" boxlang vscode >/dev/null 2>&1 || rc=$?; [[ "$rc" == 4 ]] || fail "no code exits 4 (got $rc)"
# links and the welcome page
run "$binary" boxlang links --json | jq -e '(.data.links | map(.url) | index("https://try.boxlang.io") != null) and (.data.links | length) >= 10' >/dev/null || fail 'links'
run "$binary" boxlang welcome >/dev/null; f="$tmp/cfg/bxrig/welcome.html"
grep -q 'Try BoxLang' "$f" && grep -q 'matchbox.boxlang.io' "$f" && grep -q 'xdg-open' "$LOG" || fail 'welcome page'
[[ "$(code "$binary" boxlang nope)" == 2 ]] || fail 'usage exits 2'

# ---- check, update, home, modules as rows (the bx-module text is the real output, from tests/fixtures/boxlang) ----
fx="$root/tests/fixtures/boxlang"
mkdir -p "$tmp/lib"; : > "$tmp/lib/boxlang-1.18.2.jar"
logger bx-module "case \"\$1\" in list) cat '$fx/bx-module-list.txt' ;; outdated) cat '$fx/bx-module-outdated.txt' ;; *) echo done ;; esac"
printf '#!/usr/bin/env bash\necho "curl $*" >> "$LOG"\ncase "$*" in *version-latest*) printf "version=1.19.0+67\\nbuildDate=2026-11-03\\n" ;; *) exit 22 ;; esac\n' > "$tmp/bin/curl"
chmod +x "$tmp/bin"/*
j="$(run "$binary" boxlang check --json || true)"
jq -e '.exit == 10 and .data.boxlang.installed == "1.18.2" and .data.boxlang.latest == "1.19.0+67" and .data.boxlang.update and .data.outdated == 3 and (.data.modules | length) == 7' <<<"$j" >/dev/null || fail "check: $j"
jq -e '[.data.modules[] | select(.outdated) | .name] == ["bx-toml","bx-yaml","bx-image"] and (.data.modules[] | select(.name == "bx-toml") | .nested and .latest == "1.1.0+2")' <<<"$j" >/dev/null || fail "check rows: $j"
{ run "$binary" boxlang check || true; } | grep -q '1.18.2  ->  1.19.0+67' || fail 'check text'
: > "$tmp/lib/boxlang-1.19.0.jar"; rm "$tmp/lib/boxlang-1.18.2.jar"
{ run "$binary" boxlang check --json || true; } | jq -e '.data.boxlang.update == false' >/dev/null || fail 'the same version with a build number is current'
run "$binary" boxlang modules installed --json | jq -e '(.data.modules | length) == 7 and .data.modules[0].name == "bx-sites" and .data.modules[1].nested and .data.modules[6].version == "1.14.0+28"' >/dev/null || fail 'modules installed rows'
run "$binary" boxlang modules outdated --json | jq -e '[.data.modules[] | select(.outdated)] | length == 3' >/dev/null || fail 'modules outdated rows'
: > "$LOG"; [[ "$(code "$binary" boxlang modules remove bx-ftp)" == 2 ]] && ! grep -q '^bx-module remove' "$LOG" || fail 'remove is a plan without --yes'
run "$binary" boxlang modules remove bx-ftp --yes >/dev/null; grep -q '^bx-module remove --force bx-ftp' "$LOG" || fail "remove --yes: $(cat "$LOG")"
: > "$LOG"; run "$binary" boxlang modules update --dry-run >/dev/null; ! grep -q '^bx-module update' "$LOG" || fail 'update --dry-run ran bx-module'
# update: bvm when it is there, the quick installer when not
[[ "$(code "$binary" boxlang update)" == 2 ]] || fail 'update without --yes is a plan'
: > "$LOG"; run "$binary" boxlang update --yes >/dev/null; grep -q '^bvm install latest' "$LOG" && grep -q '^bvm use latest' "$LOG" || fail "update with bvm: $(cat "$LOG")"
# (only the fakes and the system folders on the PATH, so a real bvm in /usr/local/bin does not count)
lean() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:/usr/bin:/bin" LOG="$LOG" "$@"; }
rm "$tmp/bin/bvm"; logger install-boxlang; chmod +x "$tmp/bin/install-boxlang"
: > "$LOG"; lean "$binary" boxlang update --yes >/dev/null; grep -q '^install-boxlang latest --non-interactive' "$LOG" || fail "update with the quick installer: $(cat "$LOG")"
rm "$tmp/bin/install-boxlang"; rc=0; lean "$binary" boxlang update --yes >/dev/null 2>&1 || rc=$?; [[ "$rc" == 4 ]] || fail "update with neither exits 4, not $rc"
# home
mkdir -p "$tmp/home/.boxlang"
run "$binary" boxlang home --json | jq -e --arg h "$tmp/home/.boxlang" '.data.home == $h and .data.exists and .data.modules == ($h + "/modules")' >/dev/null || fail 'home'
{ run env BOXLANG_HOME="$tmp/bh" "$binary" boxlang home --json || true; } | jq -e --arg h "$tmp/bh" '.data.home == $h and (.data.exists | not)' >/dev/null || fail 'home from BOXLANG_HOME'
: > "$LOG"; run "$binary" boxlang home --open >/dev/null; grep -q "xdg-open $tmp/home/.boxlang" "$LOG" || fail 'home --open'
# run and repl hand the terminal to boxlang
: > "$LOG"; run "$binary" boxlang run hello.bxs a b >/dev/null; grep -q '^boxlang hello.bxs a b' "$LOG" || fail "run: $(cat "$LOG")"
: > "$LOG"; run "$binary" boxlang repl </dev/null >/dev/null; grep -q '^boxlang *$' "$LOG" || fail "repl: $(cat "$LOG")"
echo "boxlang-test ok"
