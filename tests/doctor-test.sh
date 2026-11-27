#!/usr/bin/env bash
# `bxrig doctor`: one status line per tool, exit 0 when all are there and 4 when one is missing, with fake tools. Usage: doctor-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home/.bvm"
# The PATH holds only the fakes and the two system programs doctor itself uses (sh, env and bash for the fakes, readlink), so a real git or jq on this machine never counts.
for t in sh env bash readlink; do ln -s "$(command -v "$t")" "$tmp/bin/$t"; done
stub git 'echo "git version 2.50.1"'
stub curl 'echo "curl 8.14.1 (x86_64-pc-linux-gnu)"'
stub unzip 'echo "UnZip 6.00 of 20 April 2009, by Debian."'
stub jq 'echo "jq-1.8.1"'
stub java 'echo "openjdk version \"${JAVA_VER:-21.0.8}\" 2026-07-21" >&2'
stub mvm 'echo "MVM version: 2.0.1"'
stub bvm 'echo "bvm 1.3.0"'
stub boxlang 'echo "must not be run" >&2; exit 9'
mkdir -p "$tmp/home/.bvm/1.19.0"; ln -s "$tmp/home/.bvm/1.19.0" "$tmp/home/.bvm/current"
stub matchbox 'if [[ "${1:-}" == --version ]]; then echo "matchbox version 0.14.0"; exit 0; fi
[[ "${MB_TUI:-yes}" == yes ]] && echo bxrig-tui-ok || { echo "Native class tui.TUI not found" >&2; exit 1; }'
stub rustc 'echo "rustc 1.100.0 (0ef1bc386 2026-11-09)"'
stub cargo 'echo "cargo 1.100.0 (abc 2026-11-09)"'
run() { env -i HOME="$tmp/home" PATH="$tmp/bin" BXRIG_DISTRO=arch "$@"; }

# everything present: one ok line per tool, exit 0
out="$(run "$binary" doctor)" || fail "doctor with every tool must exit 0: $out"
for l in 'ok   git 2.50.1' 'ok   curl 8.14.1' 'ok   unzip 6.00' 'ok   jq 1.8.1' 'ok   java 21.0.8' 'ok   mvm 2.0.1' 'ok   bvm 1.3.0' 'ok   boxlang 1.19.0' \
	'ok   matchbox 0.14.0 (compiles BxRig)' 'ok   rustc 1.100.0' 'ok   cargo 1.100.0'; do
	[[ "$out" == *"$l"* ]] || fail "doctor lacks the line '$l': $out"
done
[[ "$out" == *'Workstation prerequisites'* && "$out" == *'Native build prerequisites'* ]] || fail "doctor lacks its headers: $out"
[[ "$(grep -cE '^(ok  |miss) ' <<<"$out")" == 11 ]] || fail "doctor must print 11 status lines: $out"

# a missing tool is a line of its own with the command that installs it, and exit 4
rm "$tmp/bin/jq" "$tmp/bin/cargo"
out="$(run "$binary" doctor)" && fail 'doctor must exit 4 while a tool is missing' || rc=$?
[[ "${rc:-0}" == 4 ]] || fail "missing tool exit ${rc:-0}, not 4"
[[ "$out" == *'miss jq (install: sudo pacman -S jq)'* ]] || fail "doctor lacks the miss line for jq: $out"
[[ "$out" == *'miss cargo (install: sudo pacman -S rustup && rustup default stable)'* && "$out" == *'ok   git 2.50.1'* ]] || fail "doctor report: $out"
# the same through the alias and with --json
{ run "$binary" prerequisites || true; } | grep -q 'miss jq' || fail 'prerequisites is not doctor'
j="$(run "$binary" doctor --json || true)"
jq -e '.command == "doctor" and .exit == 4 and .ok == false and .data.ok == false and (.data.tools | length) == 11 and ((.data.tools[] | select(.id == "jq")) | .ok == false and .fix == "sudo pacman -S jq")' <<<"$j" >/dev/null || fail "doctor --json: $j"
jq -e '(.data.tools[] | select(.id == "matchbox")) | .ok == true and .compiles_bxrig == true and .version == "0.14.0"' <<<"$j" >/dev/null || fail "doctor --json matchbox: $j"

# a wrong Java is missing, a MatchBox without the terminal UI is missing (it cannot compile BxRig)
ln -s "$(command -v jq)" "$tmp/bin/jq" 2>/dev/null || true
out="$(run env JAVA_VER=17.0.9 "$binary" doctor)" && fail 'Java 17 must exit 4' || true
[[ "$out" == *'miss java 17.0.9 (found 17.0.9, need 21 or newer; install: sudo pacman -S jdk21-openjdk)'* ]] || fail "doctor java: $out"
out="$(run env MB_TUI=no "$binary" doctor)" && fail 'a MatchBox without the terminal UI must exit 4' || true
[[ "$out" == *'miss matchbox 0.14.0 (cannot compile BxRig; install: install.sh toolchains --yes --matchbox-branch bxrig)'* ]] || fail "doctor matchbox without TUI: $out"

# --dev: advice on the developer setup, never an error
stub cargo 'echo "cargo 1.100.0 (abc 2026-11-09)"'
stub git '[[ "$1" == --version ]] && echo "git version 2.50.1" || exit 1'
out="$(run "$binary" doctor --dev)" || fail "doctor --dev with nothing set up must still exit 0: $out"
for l in 'Developer setup' 'warn git-identity' 'warn ssh-key (no SSH key; fix: bxrig ssh key --yes)' 'warn git-signing (commits not signed; fix: bxrig git signing on --yes)' 'warn containers' 'warn editor' 'warn scheduler (not installed; fix: bxrig scheduler install --yes)'; do
	[[ "$out" == *"$l"* ]] || fail "doctor --dev lacks '$l': $out"
done
stub git 'case "$*" in "--version") echo "git version 2.50.1";; *user.name) echo Ada;; *user.email) echo ada@example.com;; *commit.gpgsign) echo true;; *gpg.format) echo ssh;; *) exit 1;; esac'
stub ssh-add 'exit 0'
stub podman 'echo "podman version 5.6.0"'
mkdir -p "$tmp/home/.ssh"; : > "$tmp/home/.ssh/id_ed25519"
out="$(run env EDITOR=nvim "$binary" doctor --dev)" || fail "doctor --dev all set: $out"
for l in 'ok   git-identity (Ada <ada@example.com>)' 'ok   ssh-key (~/.ssh/id_ed25519)' 'ok   ssh-agent (has your key)' 'ok   git-signing (commits signed (ssh))' 'ok   containers 5.6.0 (podman)' 'ok   editor (EDITOR=nvim)'; do
	[[ "$out" == *"$l"* ]] || fail "doctor --dev lacks '$l': $out"
done
run "$binary" doctor --dev --json | jq -e '[.data.tools[] | select(.group == "dev")] | length == 7 and all(.advice)' >/dev/null || fail 'doctor --dev --json'
[[ "$(run "$binary" doctor --json | jq '[.data.tools[] | select(.group == "dev")] | length')" == 0 ]] || fail 'doctor without --dev has no dev rows'
rm -f "$tmp/bin"/{ssh-add,podman}

# nothing at all: every tool is listed as missing, not just the headers
rm -f "$tmp/bin"/{git,curl,unzip,jq,java,mvm,bvm,boxlang,matchbox,rustc,cargo}
out="$(run "$binary" doctor)" && fail 'an empty PATH must exit 4' || true
[[ "$(grep -c '^miss ' <<<"$out")" == 11 ]] || fail "an empty PATH must list 11 missing tools: $out"
[[ "$(run "$binary" doctor extra >/dev/null 2>&1; echo $?)" == 2 ]] || { rc="$(run "$binary" doctor extra >/dev/null 2>&1; echo $?)"; fail "doctor extra exits $rc, not 2"; }
echo "doctor tests passed"
