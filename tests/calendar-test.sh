#!/usr/bin/env bash
# `bxrig calendar` and `bxrig remind` with a fake vdirsyncer, notify-send and systemctl. Usage: calendar-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
export LOG="$tmp/log"; : > "$LOG"
# vdirsyncer: logs its config and arguments; sync copies the fixture into the local folder of every pair
stub vdirsyncer 'echo "vdirsyncer $* config=$VDIRSYNCER_CONFIG" >> "$LOG"
[[ "$1" == sync ]] && for d in "$BXRIG_DATA_HOME"/calendars/*/; do cp "'"$root"'/tests/fixtures/calendar/work.ics" "$d"; done
exit "${VDIR_EXIT:-0}"'
stub notify-send 'echo "notify-send $*" >> "$LOG"'
stub systemctl 'echo "systemctl $*" >> "$LOG"'
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_DATA_HOME="$tmp/data" BXRIG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
cfg="$tmp/cfg/bxrig/vdirsyncer/config"

run "$binary" calendar --json | jq -e '.ok and (.data.calendars | length) == 0' >/dev/null || fail 'no calendars'
run "$binary" calendar | grep -q 'No calendars yet' || fail 'the empty list says how to add one'
[[ "$(code "$binary" calendar add ical Bad_Name https://x/a.ics)" == 2 ]] || fail 'a bad name is a usage error'
[[ "$(code "$binary" calendar add ical hol ftp://x/a.ics)" == 2 ]] || fail 'an address that is not http is a usage error'
run "$binary" calendar add ical holidays webcal://example.org/h.ics --json | jq -e '.data.kind == "ical"' >/dev/null || fail 'add ical'
[[ "$(code "$binary" calendar add ical holidays https://example.org/h.ics)" != 0 ]] || fail 'a taken name'
grep -q 'url = "https://example.org/h.ics"' "$cfg" || fail 'webcal is fetched as https'
[[ "$(stat -c %a "$cfg")" == 600 ]] || fail 'the config is private'
# google needs its client
[[ "$(code "$binary" calendar add google work)" == 2 ]] || fail 'google without a client is a usage error'
[[ "$(code "$binary" calendar add google work --client-id=x --client-secret-file="$tmp/none")" == 4 ]] || fail 'a missing secret file exits 4'
echo 's3cret' > "$tmp/secret"
run "$binary" calendar add google work --client-id=abc.apps --client-secret-file="$tmp/secret" | grep -q 'opens Google' || fail 'add google says the first sync signs in'
grep -q 'client_secret = "s3cret"' "$cfg" && grep -q 'type = "google_calendar"' "$cfg" || fail 'the google storage'
# sync runs vdirsyncer on BxRig's own config
run "$binary" calendar sync --json | jq -e '.ok and (.data.synced | sort) == ["holidays","work"]' >/dev/null || fail 'sync'
grep -q "vdirsyncer discover config=$cfg" "$LOG" && grep -q "vdirsyncer sync config=$cfg" "$LOG" || fail "vdirsyncer with VDIRSYNCER_CONFIG: $(cat "$LOG")"
run "$binary" calendar sync holidays >/dev/null; grep -q 'vdirsyncer sync holidays' "$LOG" || fail 'sync one calendar'
[[ "$(code "$binary" calendar sync nope)" == 4 ]] || fail 'sync an unknown calendar exits 4'
[[ "$(VDIR_EXIT=1 code "$binary" calendar sync)" == 6 ]] || fail 'a vdirsyncer failure exits 6'
run "$binary" calendar --json | jq -e '[.data.calendars[].events] == [1,1]' >/dev/null || fail 'the event files are counted'
# agenda reads the synced files
run "$binary" calendar agenda --days=60 --json | jq -e '.data.today != null and (.data.events | type) == "array"' >/dev/null || fail 'agenda json'
# remove: a plan first, then the local copy goes
[[ "$(code "$binary" calendar remove work)" == 2 ]] || fail 'remove without --yes is a plan'
run "$binary" calendar remove work --yes >/dev/null; [[ ! -d "$tmp/data/calendars/work" ]] && ! grep -q 'pair work' "$cfg" || fail 'remove'
[[ "$(code "$binary" calendar remove nope --yes)" == 4 ]] || fail 'remove an unknown calendar exits 4'

# reminders
run "$binary" remind --json | jq -e '.data.reminders == []' >/dev/null || fail 'no reminders'
[[ "$(code "$binary" remind "Call Ana")" == 2 ]] || fail 'a reminder needs a time'
[[ "$(code "$binary" remind "Call Ana" --in=soon)" == 2 ]] || fail 'not a time'
run "$binary" remind "Call Ana" --in=30m --json | jq -e '.data.id == 1 and .data.text == "Call Ana"' >/dev/null || fail 'add with --in'
run "$binary" remind "Renew" --at="2026-01-01 09:00" --json | jq -e '.data.at == "2026-01-01T09:00"' >/dev/null || fail 'add with --at (in the past, so due now)'
run "$binary" remind list --json | jq -e '(.data.reminders | map(.id)) == [2,1] and .data.reminders[0].due' >/dev/null || fail 'list: soonest first, the past one due'
run "$binary" remind due --json | jq -e '.data.shown == [2]' >/dev/null || fail 'due shows the one whose time came'
grep -q 'notify-send --app-name=bxrig --urgency=critical --icon=alarm-symbolic Reminder Renew' "$LOG" || fail "the notice: $(cat "$LOG")"
run "$binary" remind due --json | jq -e '.data.shown == []' >/dev/null || fail 'a reminder pops up once'
run "$binary" remind done 2 >/dev/null; run "$binary" remind list --json | jq -e '(.data.reminders | map(.id)) == [1]' >/dev/null || fail 'done'
run "$binary" remind remove 1 >/dev/null; run "$binary" remind list --json | jq -e '.data.reminders == []' >/dev/null || fail 'remove'
[[ "$(code "$binary" remind done 9)" == 4 ]] || fail 'an unknown reminder exits 4'
run "$binary" remind "Send the invoice" --at="tomorrow 09:00" --json | jq -e --arg d "$(date -d tomorrow +%F)" '.data.at == ($d + "T09:00")' >/dev/null || fail 'tomorrow HH:MM is tomorrow, even when 09:00 has not passed today'
[[ "$(code "$binary" remind "x" --at="tomorrow 25:00")" == 2 ]] || fail 'tomorrow with a bad time exits 2'
run "$binary" remind "Pay rent" --in=3h >/dev/null
{ run "$binary" remind clear --json || true; } | jq -e '.exit == 2 and (.data.count >= 2) and .data.done_only == false' >/dev/null || fail 'clear without --yes is a plan with a count'
[[ "$(code "$binary" remind clear)" == 2 ]] || fail 'clear without --yes exits 2'
run "$binary" remind list --json | jq -e '(.data.reminders | length) == 2' >/dev/null || fail 'the plan changed nothing (two still to come)'
inv="$(run "$binary" remind list --json | jq -r '.data.reminders[] | select(.text == "Send the invoice") | .id')"
run "$binary" remind done "$inv" >/dev/null
run "$binary" remind clear --done --yes --json | jq -e '.data.cleared == 2' >/dev/null || fail 'clear --done forgets only the finished (the one from before and this one)'
run "$binary" remind list --json | jq -e '(.data.reminders | length) == 1' >/dev/null || fail 'one left after clear --done'
run "$binary" remind clear --yes --json | jq -e '.data.cleared == 1' >/dev/null || fail 'clear forgets the rest'
run "$binary" remind list --json | jq -e '.data.reminders == []' >/dev/null || fail 'nothing left'

# with the scheduler installed, calendars and reminders get their tasks
mkdir -p "$tmp/cfg/systemd/user"; : > "$tmp/cfg/systemd/user/bxrig-scheduler.service"
run "$binary" calendar add ical team https://example.org/t.ics >/dev/null
run "$binary" remind "Stand up" --in=1h >/dev/null
run "$binary" scheduler list --json | jq -e '[.data.tasks[].name] | (index("calendar-sync") != null) and (index("reminders") != null)' >/dev/null || fail "the scheduler tasks: $(run "$binary" scheduler list --json)"
run "$binary" remind "Again" --in=2h >/dev/null
run "$binary" scheduler list --json | jq -e '[.data.tasks[] | select(.name == "reminders")] | length == 1' >/dev/null || fail 'the task is not added twice'
echo "calendar-test passed"
