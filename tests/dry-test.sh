#!/usr/bin/env bash
# Ratchet: patterns that must not come back, each with the highest count allowed today. Lower a maximum whenever a refactor removes copies;
# Targets (new homes included in the counts): say 2 (Cli, Out), fail 2, tryExec 0, has 1 (Proc), merge 1 (Text), validName 1, home/env/self 1 each (Env), Usage 0, test fail() 0.
# never raise one. See docs/architecture/CODE-REVIEW.md section 8 and docs/guides/contributing.md. Usage: dry-test.sh [ignored]
root="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
count() { # pattern, path, max   (counts matching lines, fixed string)
	local n; n="$(grep -rF --include='*.bx' --include='*.sh' -- "$1" "$root/$2" 2>/dev/null | wc -l)"
	if (( n > $3 )); then echo "FAIL: '$1' in $2 is $n, allowed $3"; fails=$((fails+1)); elif (( n < $3 )); then echo "note: '$1' in $2 is $n, lower the maximum from $3"; fi
}
count 'function say('              src/bxrig 2
count 'function fail('             src/bxrig 2
count 'function tryExec('          src/bxrig 0
count 'function has('              src/bxrig 1
count 'function merge('            src/bxrig 1
count 'function validName('        src/bxrig 0
count 'function dataHome('         src/bxrig 2
count 'function home()'            src/bxrig 4
count 'function env('              src/bxrig 1
count 'function self()'            src/bxrig 1
count '"Usage: bxrig'              src/Main.bx 4
count '"Usage: bxrig'              src/bxrig 14
count 'fail() { echo "FAIL'        tests 4
count 'function check( label, ok )' tests 2
count 'jsonDeserialize( fileRead(' src/bxrig 24
# external tools have one home each (src/bxrig/util): pacman, the AUR helper, systemctl and curl are only ever spelled there
for pat in '"pacman", "-' '"yay", "-' '"curl", "-' '"systemctl", "[-a-z]'; do
	n="$(grep -rnE "\[ *\"(sudo\", )?$pat" "$root/src" --include='*.bx' | grep -v '/util/' | grep -vE '^\S+:[0-9]+:\s*//' | wc -l)"
	(( n == 0 )) || { echo "FAIL: $n argv lists start a command ($pat) outside src/bxrig/util (use Pacman, Aur, Systemd or Http)"; fails=$((fails+1)); }
done
# one home each: the desktop (util/Desktop), first-party URLs (util/Urls), the version (generated util/Version)
for pat in 'XDG_CURRENT_DESKTOP' 'HYPRLAND_INSTANCE_SIGNATURE'; do
	n="$(grep -rn "getSystemSetting( \"$pat\"" "$root/src" --include='*.bx' | grep -v '/util/Desktop.bx' | wc -l)"
	(( n == 0 )) || { echo "FAIL: $n reads of $pat outside src/bxrig/util/Desktop.bx"; fails=$((fails+1)); }
done
n="$(grep -rn '0\.11\.0\|"version" *=' "$root/src" --include='*.bx' | grep -v '/util/Version.bx' | wc -l)"
(( n == 0 )) || { echo "FAIL: the version string is spelled outside util/Version.bx"; fails=$((fails+1)); }
# root-owned files go through util/SystemFile, unit text through util/SystemdUnit, settings JSON through util/JsonStore
n="$(grep -rn '"install", "-Dm' "$root/src" --include='*.bx' | grep -v '/util/' | wc -l)"
(( n == 0 )) || { echo "FAIL: $n spelled sudo install argv lists outside src/bxrig/util (use SystemFile.installArgv)"; fails=$((fails+1)); }
n="$(grep -rn '"\[Unit\]"' "$root/src" --include='*.bx' | wc -l)"
(( n == 0 )) || { echo "FAIL: $n hand-built [Unit] texts (allowed 0, use SystemdUnit.render)"; fails=$((fails+1)); }
# exit codes returned by name, not by number (return 2; 3; 4;), and the id and sudo fakes of the shell tests come from tests/lib/harness.sh
n="$(grep -rnE 'return [234];' "$root/src" --include='*.bx' | grep -v 'MailProvider\|/util/Exit.bx' | wc -l)"
(( n == 0 )) || { echo "FAIL: $n bare return 2, 3 or 4 (use new bxrig.util.Exit().usage(), .timeout(), .precondition())"; fails=$((fails+1)); }
n="$(grep -ln '/usr/bin/id' "$root"/tests/*-test.sh | wc -l)"
(( n <= 5 )) || { echo "FAIL: $n tests spell their own id fake (allowed 5 with their own variants; use stub_id from tests/lib/harness.sh)"; fails=$((fails+1)); }
# exit codes are named (src/bxrig/util/Exit.bx): no number as the code argument of say( ) / fail( ), and no CLIExit( N ) in Main.bx except 130 (Ctrl+C)
bare="$(grep -rhoE '(out)\.(say|fail)\( *[0-9]+ *,|(cli)\.(say|fail)\( *[^,()]+, *[0-9]+ *,' "$root/src/bxrig" | wc -l)"
(( bare == 0 )) || { echo "FAIL: $bare say/fail calls pass a bare number as the exit code (use a name from Exit.bx)"; fails=$((fails+1)); }
bare="$(grep -oE 'CLIExit\( *[0-9]+ *\)' "$root/src/Main.bx" | grep -vc '130' || true)"
(( bare == 0 )) || { echo "FAIL: $bare CLIExit( N ) calls in Main.bx pass a bare number (use xit.NAME())"; fails=$((fails+1)); }
# plans and dry runs are worded in util/Mutation (banner, footer, show; Out.plan)
n="$(grep -rn 'Nothing was changed\. Add --yes\|"Dry run" : "Plan"' "$root/src" --include='*.bx' | grep -v '/util/Mutation.bx' | wc -l)"
(( n == 0 )) || { echo "FAIL: $n hand-written plan or dry-run footers outside src/bxrig/util/Mutation.bx (use Out.plan, Mutation.banner and Mutation.footer)"; fails=$((fails+1)); }
# environment variable names are listed once (util/Env.names), page icon names once (ControlCenterPages)
n="$(grep -rn 'getSystemSetting(' "$root/src" --include='*.bx' | grep -v '/util/Env.bx' | wc -l)"
(( n == 0 )) || { echo "FAIL: $n getSystemSetting calls outside src/bxrig/util/Env.bx (use Env.named( id ), the ids are listed in Env.names())"; fails=$((fails+1)); }
n="$(grep -rn 'function icon() { return "' "$root/src" --include='*.bx' | wc -l)"
(( n == 0 )) || { echo "FAIL: $n page icon names spelled outside ControlCenterPages (use ControlCenterPages.icon( id ))"; fails=$((fails+1)); }
# the views draw through TuiKit directly (no one-line forwarders of mix, brand, shimmer, put, fillRect, gtext)
n="$(grep -rnP '^\tfunction (put|fillRect|gtext|shimmer|mix|brand)\(' "$root"/src/bxrig/*View.bx | wc -l)"
(( n == 0 )) || { echo "FAIL: $n view forwarders to TuiKit (call variables.kit directly)"; fails=$((fails+1)); }
# every test file is run by CI (a new test cannot be forgotten)
for t in "$root"/tests/*-test.sh "$root"/tests/*_test.bxs "$root"/tests/catalog_check.bxs; do
	[[ -f "$t" ]] || continue
	grep -q "$(basename "$t")" "$root/.github/workflows/ci.yml" || { echo "FAIL: $(basename "$t") is not listed in .github/workflows/ci.yml"; fails=$((fails+1)); }
done
# every tracked shell script is syntax-checked by CI job 1 (the `bash -n` list)
bashn="$(sed -n 's/^ *bash -n //p' "$root/.github/workflows/ci.yml" | head -n1)"
while IFS= read -r f; do
	[[ " $bashn " == *" $f "* ]] || { echo "FAIL: $f is not in the bash -n list of .github/workflows/ci.yml"; fails=$((fails+1)); }
done < <(git -C "$root" ls-files '*.sh' 2>/dev/null)
# the formatting CI job 1 checks (tabs, LF, final newline, no trailing spaces): run scripts/format.sh before you commit
bash "$root/scripts/format.sh" --check >/dev/null 2>&1 || { echo "FAIL: scripts/format.sh --check lists unformatted files (run scripts/format.sh)"; fails=$((fails+1)); }
(( fails == 0 )) || exit 1
echo "dry-test: ok"
