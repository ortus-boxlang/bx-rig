#!/usr/bin/env bash
# `bxrig scheduler` with a fake systemctl and boxlang, and the update and backup commands moving onto it. Usage: scheduler-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home"; export LOG="$tmp/log"; : > "$LOG"
logger() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n%s\n' "$1" "${2:-}" > "$tmp/bin/$1"; }
logger systemctl 'case "$*" in *is-active*) echo active ;; esac'
logger boxlang
logger notify-send
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" BXRIG_DATA_HOME="$tmp/data" BXRIG_SELF="$binary" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
st="$tmp/state/bxrig/scheduler"

run "$binary" scheduler --json | jq -e '.ok and .data.service == "not installed" and (.data.tasks | length) == 0' >/dev/null || fail 'status before anything'
# add: WHEN is checked, a name is unique, the command comes after --
[[ "$(code "$binary" scheduler add x --when=sometimes -- true)" == 2 ]] || fail 'an unreadable WHEN exits 2'
[[ "$(code "$binary" scheduler add "Bad Name" --when=hourly -- true)" == 2 ]] || fail 'a bad name exits 2'
[[ "$(code "$binary" scheduler add x --when=hourly)" == 2 ]] || fail 'no command exits 2'
run "$binary" scheduler add hello --when="every 5 minutes" --group=demo -- sh -c 'echo hi there' >/dev/null || fail 'add'
run "$binary" scheduler add boom --when="daily 02:30" --group=demo --notify=failure -- sh -c 'echo broken >&2; exit 3' >/dev/null
run "$binary" scheduler add tidy --when="weekly sun 10:00" -- bxrig version >/dev/null
[[ "$(code "$binary" scheduler add hello --when=hourly -- true)" == 8 ]] || fail 'a taken name exits 8'
jq -e '(.tasks | length) == 3 and (.tasks[2].run == ["version"]) and (.tasks[0].command | length) == 3' "$tmp/cfg/bxrig/schedule.json" >/dev/null || fail "schedule.json: $(cat "$tmp/cfg/bxrig/schedule.json")"
jq -e '(.tasks | map(.call)) == [".every( 5, \"minutes\" )", ".everyDayAt( \"02:30\" )", ".onSundays( \"10:00\" )"]' "$st/tasks.json" >/dev/null || fail "tasks.json: $(cat "$st/tasks.json")"
grep -q 'scheduler.task( "boom", "demo" )' "$tmp/data/scheduler/Scheduler.bx" || fail 'the runner is written'
# run: recorded, classified, notified on failure
run "$binary" scheduler run hello --json | jq -e '.data.status == "ok" and .data.exit == 0 and (.data.output | test("hi there"))' >/dev/null || fail 'run hello'
[[ "$(code "$binary" scheduler run boom)" == 6 ]] || fail 'a failed run exits 6'
grep -q '^notify-send --app-name=bxrig boom failed' "$LOG" || fail "the failure is notified: $(cat "$LOG")"
run "$binary" scheduler run tidy --json | jq -e '.data.status == "ok"' >/dev/null || fail 'bxrig words run with this bxrig'
[[ "$(wc -l < "$st/history/hello.jsonl")" == 1 ]] || fail 'one line of history per run'
run "$binary" scheduler show boom --json | jq -e '.data.stats.runs == 1 and .data.stats.failures == 1 and .data.last_status == "failed" and (.data.runs[0].output | test("broken")) and .data.next_run != ""' >/dev/null || fail 'show'
run "$binary" scheduler --json | jq -e '.data.failing == 1' >/dev/null || fail 'status counts the failing task'
# pause and resume a group, disable one
run "$binary" scheduler pause demo >/dev/null; jq -e '[.tasks[] | select(.group == "demo") | .enabled] == [false, false]' "$tmp/cfg/bxrig/schedule.json" >/dev/null || fail 'pause'
jq -e '(.tasks | length) == 1' "$st/tasks.json" >/dev/null || fail 'a paused task leaves the runner'
run "$binary" scheduler resume demo >/dev/null; run "$binary" scheduler disable tidy >/dev/null
jq -e '[.tasks[] | .enabled] == [true, true, false]' "$tmp/cfg/bxrig/schedule.json" >/dev/null || fail 'resume and disable'
[[ "$(code "$binary" scheduler pause nothing)" == 4 ]] || fail 'an empty group exits 4'
run "$binary" scheduler remove tidy >/dev/null; [[ "$(jq '.tasks | length' "$tmp/cfg/bxrig/schedule.json")" == 2 ]] || fail 'remove'
[[ "$(code "$binary" scheduler remove tidy)" == 4 ]] || fail 'removing an unknown task exits 4'
# install: a plan, then the runner, the unit, the built-in tasks and the old timers off
mkdir -p "$tmp/cfg/systemd/user"; : > "$tmp/cfg/systemd/user/bxrig-update-check.timer"; : > "$tmp/cfg/systemd/user/bxrig-backup.timer"
mkdir -p "$tmp/cfg/bxrig"; echo '{"targets":{},"data":{"schedule":"hourly"}}' > "$tmp/cfg/bxrig/backup.json"
[[ "$(code "$binary" scheduler install)" == 2 ]] && [[ ! -f "$tmp/cfg/systemd/user/bxrig-scheduler.service" ]] || fail 'install is a plan without --yes'
: > "$LOG"; run "$binary" scheduler install --yes >/dev/null || fail "install: $(run "$binary" scheduler install --yes 2>&1)"
grep -q "ExecStart=$tmp/bin/boxlang schedule $tmp/data/scheduler/Scheduler.bx" "$tmp/cfg/systemd/user/bxrig-scheduler.service" || fail "the unit: $(cat "$tmp/cfg/systemd/user/bxrig-scheduler.service")"
grep -q 'systemctl --user disable --now bxrig-update-check.timer' "$LOG" && grep -q 'systemctl --user disable --now bxrig-backup.timer' "$LOG" && grep -q 'systemctl --user enable --now bxrig-scheduler.service' "$LOG" || fail "install: $(cat "$LOG")"
jq -e '[.tasks[].name] == ["hello","boom","update-check","backup-data","boxlang-check"] and (.tasks[3].when == "hourly")' "$tmp/cfg/bxrig/schedule.json" >/dev/null || fail "built-ins: $(jq -c '[.tasks[].name]' "$tmp/cfg/bxrig/schedule.json")"
run "$binary" scheduler --json | jq -e '.data.service == "active"' >/dev/null || fail 'service state'
# a change restarts the running scheduler
: > "$LOG"; run "$binary" scheduler disable hello >/dev/null; grep -q 'systemctl --user try-restart bxrig-scheduler.service' "$LOG" || fail 'a change restarts it'
# the update and backup commands use the scheduler now
: > "$LOG"; run "$binary" update notifications off --json | jq -e '.data.by == "scheduler"' >/dev/null || fail 'update notifications off'
jq -e '(.tasks[] | select(.name == "update-check") | .enabled) == false' "$tmp/cfg/bxrig/schedule.json" >/dev/null || fail 'the update-check task is paused'
! grep -q 'bxrig-update-check.timer' "$LOG" || fail 'no timer is touched any more'
run "$binary" update notifications on >/dev/null; jq -e '(.tasks[] | select(.name == "update-check") | .enabled)' "$tmp/cfg/bxrig/schedule.json" >/dev/null || fail 'update notifications on'
run "$binary" backup data schedule daily --yes --json | jq -e '.data.by == "scheduler"' >/dev/null || fail 'backup data schedule daily'
jq -e '(.tasks[] | select(.name == "backup-data") | .when) == "daily 02:30"' "$tmp/cfg/bxrig/schedule.json" >/dev/null || fail 'the backup task follows'
run "$binary" backup data schedule off --yes >/dev/null; jq -e '(.tasks[] | select(.name == "backup-data") | .enabled) == false' "$tmp/cfg/bxrig/schedule.json" >/dev/null || fail 'backup off pauses the task'
# uninstall keeps the tasks
run "$binary" scheduler uninstall --yes >/dev/null; [[ ! -f "$tmp/cfg/systemd/user/bxrig-scheduler.service" && -f "$tmp/cfg/bxrig/schedule.json" ]] || fail 'uninstall keeps schedule.json'
rm "$tmp/bin/boxlang"; [[ "$(code env PATH="$tmp/bin:/usr/bin:/bin" "$binary" scheduler install --yes)" == 4 ]] || fail 'install without boxlang exits 4'
[[ "$(code "$binary" scheduler frob)" == 2 ]] || fail 'usage exits 2'
echo "scheduler-test ok"
