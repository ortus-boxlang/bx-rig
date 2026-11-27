#!/usr/bin/env bash
# `bxrig help` and `bxrig help COMMAND`: the list, one command, JSON, unknown. Usage: help-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
root="$(cd "$(dirname "$binary")/.." && pwd)"
out="$("$binary" help)"
for g in "START HERE" "INSTALL AND REMOVE" "DESKTOP SETUP" "LOOK AND FEEL" "SYSTEM AND SECURITY" "DEVELOP" "EVERYDAY TOOLS"; do grep -q "^  $g\$" <<<"$out" || fail "the list has no group: $g"; done
grep -q '^    appearance ' <<<"$out" && grep -q '^    time ' <<<"$out" && grep -q '^    security ' <<<"$out" || fail 'new commands are listed'
# bare `bxrig` shows the same list
[[ "$("$binary")" == "$out" ]] || fail 'no command shows the help'
# every command of Main.bx is in the list (the generator checks it too)
for r in $(grep -oE 'case "[a-z0-9-]+":' "$root/src/Main.bx" | sed 's/case "//; s/"://' | sort -u); do grep -q "^    $r " <<<"$out" || fail "the help does not list: $r"; done
one="$("$binary" help time)"
grep -q '^bxrig time ' <<<"$one" && grep -q '^    bxrig time zone' <<<"$one" && grep -q 'bxrig time sync --yes' <<<"$one" || fail "help time: $one"
grep -q 'Changes the system: needs --yes' <<<"$one" || fail 'help says when --yes is needed'
! grep -q 'Changes the system' <<<"$("$binary" help appearance)" || fail 'appearance acts at once, so it does not claim to need --yes'
"$binary" help time --json | jq -e '.ok and .data.command.name == "time" and (.data.command.examples | length > 0)' >/dev/null || fail 'help --json'
"$binary" help --json | jq -e '(.data.groups | length == 7) and ([.data.groups[].commands[]] | length >= 80)' >/dev/null || fail 'help list --json'
set +e; "$binary" help nonsense >/dev/null 2>&1; c=$?; set -e; [[ $c == 2 ]] || fail "unknown command exits 2 (got $c)"
# every command line in the list is one short line (the brief)
awk '/^    [a-z]/ { if (length($0) > 90) bad = bad $1 " " } END { exit bad != "" }' <<<"$out" || fail 'a list line is too long'
# a command with many forms prints one per line, never one long wrapped line
[[ "$("$binary" ai | head -1)" == 'Usage:' ]] || fail 'bxrig ai prints its forms one per line'
[[ "$("$binary" ai | wc -l)" -gt 10 ]] || fail 'bxrig ai lists many forms'
# --version and --help work at the top and on every command
[[ "$("$binary" --version)" == bxrig\ * ]] || fail '--version prints "bxrig VERSION"'
[[ "$("$binary" -v)" == "$("$binary" --version)" ]] || fail '-v is --version'
"$binary" --version --json | jq -e '.data.version != "" and .exit == 0' >/dev/null || fail '--version --json'
"$binary" --help | grep -q 'bxrig COMMAND --help' || fail '--help lists the commands'
[[ "$("$binary" -h)" == "$("$binary" --help)" ]] || fail '-h is --help'
for name in $(jq -r '.groups[].commands[].name' "$root/docs/reference/cli.json"); do
	out="$("$binary" "$name" --help 2>&1)" || fail "$name --help exits 0"
	grep -q "^bxrig $name " <<<"$out" || fail "$name --help shows the command's page"
	[[ "$("$binary" "$name" -h 2>&1)" == "$out" ]] || fail "$name -h is $name --help"
done
set +e; "$binary" nonsense --help >/dev/null 2>&1; c=$?; set -e; [[ $c == 2 ]] || fail "an unknown command with --help exits 2 (got $c)"
# the docs page and the embedded data are current
bash "$root/bootstrap/gen-docs.sh" --check >/dev/null || fail 'docs/reference/commands.md or CommandFlagData.bx is stale'
echo "help-test: ok"
