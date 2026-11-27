#!/usr/bin/env bash
# The command registry (docs/reference/cli.json) as Main.bx uses it: every command rejects a flag it does not list with exit 2 and a usage line,
# takes the global flags, and `secrets run` hands its flags on. Usage: command-spec-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
run() { env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" "$@"; }
mkdir -p "$tmp/home"
cmds="$(python3 -c "import json;print(' '.join(c['name'] for g in json.load(open('$root/docs/reference/cli.json'))['groups'] for c in g['commands']))")"
[[ -n "$cmds" ]] || fail "no commands read from cli.json"
n=0
for c in $cmds; do
	rc=0; out="$(run "$binary" "$c" --zz-bogus-flag 2>&1)" || rc=$?
	[[ $rc == 2 ]] || fail "$c --zz-bogus-flag exited $rc, want 2: $out"
	grep -q "Unknown option: --zz-bogus-flag" <<<"$out" || fail "$c: no 'Unknown option' message: $out"
	grep -q "^Usage:" <<<"$out" || fail "$c: no usage line: $out"
	n=$((n+1))
done
# global flags are never rejected as unknown
for g in --json --quiet; do out="$(run "$binary" version $g 2>&1 || true)"; ! grep -q "Unknown option" <<<"$out" || fail "version $g was rejected"; done
# a command's own flag passes the check (pkg --source is listed)
out="$(run "$binary" pkg search --source=repo 2>&1 || true)"; ! grep -q "Unknown option" <<<"$out" || fail "pkg --source was rejected: $out"
# secrets run is not checked: flags after the program name belong to it
out="$(run "$binary" secrets run -- echo --whatever 2>&1 || true)"; ! grep -q "Unknown option" <<<"$out" || fail "secrets run was checked: $out"
echo "command-spec-test: ok ($n commands)"
