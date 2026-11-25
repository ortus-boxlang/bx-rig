#!/usr/bin/env bash
# Catalog commands against the embedded catalog. Usage: catalog-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
code() { set +e; "$@" >/dev/null 2>&1; local rc=$?; set -e; echo "$rc"; }
# The Arch view of the catalog: what each app is (apps.json) with how Arch installs it (install/arch.json) merged in, as bxrig loads it.
cat="$tmp/catalog-arch.json"
jq -s '.[1].apps as $i | .[0] | .apps |= map(. + ($i[.id] // {}))' "$root/catalog/apps.json" "$root/catalog/install/arch.json" > "$cat"
# The source of truth and the embedded copy agree.
[[ "$("$binary" catalog version --json | jq -r .data.apps)" == "$(jq '.apps|length' "$cat")" ]] || fail 'app count differs'
[[ "$("$binary" catalog list --json | jq '.data|length')" == "$(jq '.apps|length' "$cat")" ]] || fail 'list count'
[[ "$("$binary" catalog list --tier=default --json | jq '.data|length')" == "$(jq '[.apps[]|select(.tier=="default")]|length' "$cat")" ]] || fail 'tier filter'
[[ "$("$binary" catalog list --group=infra --category=Containers --json | jq '.data|length')" == "$(jq '[.apps[]|select(.group=="infra" and .category=="Containers")]|length' "$cat")" ]] || fail 'group+category filter'
[[ "$("$binary" catalog groups --json | jq '.data|length')" == "$(jq '.groups|length' "$cat")" ]] || fail 'groups'
"$binary" catalog show podman | grep -Fq 'Podman' || fail 'show'
[[ "$("$binary" catalog show podman --json | jq -r .data.id)" == podman ]] || fail 'show --json'
[[ "$(code "$binary" catalog show nope)" == 3 ]] || fail 'unknown id exits 3'
[[ "$(code "$binary" catalog show)" == 2 ]] || fail 'show needs an id'
[[ "$(code "$binary" catalog bogus)" == 2 ]] || fail 'unknown verb exits 2'
[[ "$(code "$binary" catalog check)" == 0 ]] || fail 'catalog check must pass'
[[ "$("$binary" catalog check --json | jq '.data.errors|length')" == 0 ]] || fail 'check errors'
# Presentation metadata is complete for every app.
[[ "$(jq '[.apps[]|select((.description//"")=="")]|length' "$cat")" == 0 ]] || fail 'app without description'
[[ "$(jq '[.groups[].id] as $g | [.apps[]|select(.group as $x|$g|index($x)|not)]|length' "$cat")" == 0 ]] || fail 'app in unknown group'
# Profiles and shells (schema 3 additions).
[[ "$(jq '.profiles|length' "$cat")" -ge 12 ]] || fail 'profiles missing'
[[ "$(jq '[.profiles[].id] as $p | [.apps[]|select(.profiles)|.profiles|keys[]|select(. as $k|$p|index($k)|not)]|length' "$cat")" == 0 ]] || fail 'app in unknown profile'
[[ "$(jq '[.apps[]|select(.shells)|.shells[]|select(.!="hyprland" and .!="plasma")]|length' "$cat")" == 0 ]] || fail 'unknown shell'
[[ "$("$binary" catalog show git --json | jq -r '.data.profiles.core')" == default ]] || fail 'git is a default core app'
[[ "$("$binary" catalog show hyprsunset --json | jq -r '.data.shells[0]')" == hyprland ]] || fail 'hyprsunset targets hyprland'
# Negative cases for the check itself (needs a MatchBox to run the script).
mb="${MATCHBOX:-$(command -v matchbox || true)}"
if [[ -n "$mb" ]]; then
	(cd "$root/src" && "$mb" ../tests/catalog_check.bxs) | tail -n 1 | grep -Fq 'negative tests passed' || fail 'catalog check negative tests'
fi
# Owner's 2026-11-09 corrections
for id in amp-desktop elsewhen learn-omarchy; do [[ "$(jq --arg i "$id" '[.apps[]|select(.id==$i)]|length' "$cat")" == 0 ]] || fail "$id must not be in the catalog"; done
for id in datagrip opencode-desktop; do [[ "$(jq -r --arg i "$id" '.apps[]|select(.id==$i)|.tier' "$cat")" == optional ]] || fail "$id is an optional app"; done
[[ "$(jq -r '.apps[]|select(.id=="pi-agent")|"\(.source) \(.tier) \(.targets[0])"' "$cat")" == 'aur optional pi-bin' ]] || fail 'pi-agent is the optional AUR package pi-bin'
[[ "$(jq -r '.apps[]|select(.id=="codex-cli")|"\(.source) \(.tier) \(.targets[0])"' "$cat")" == 'pacman optional openai-codex' ]] || fail 'codex-cli is the optional package openai-codex'
for id in gemini-cli hermes-agent; do [[ "$(jq -r --arg i "$id" '.apps[]|select(.id==$i)|.tier' "$cat")" == optional ]] || fail "$id is an optional app"; done
[[ "$(jq -r '.apps[]|select(.id=="disktree")|.tier' "$cat")" == default ]] || fail 'disktree is default'
[[ "$(jq '[.apps[]|select(.source=="unresolved")]|length' "$cat")" == 0 ]] || fail 'no app is left unresolved'
[[ "$(jq '[.apps[]|select(.source=="pkgbuild" and (.pkgbuild.ref|test("^[0-9a-f]{40}$")|not))]|length' "$cat")" == 0 ]] || fail 'every pkgbuild ref is a full commit'
for id in zoom-web omapresent task-manager; do [[ "$(jq --arg i "$id" '[.apps[]|select(.id==$i)]|length' "$cat")" == 0 ]] || fail "$id was removed as an overlap"; done
# PR 12: every major coding agent installs on Arch, and by its vendor's script on Debian and openSUSE.
for id in pi-agent copilot-cli cursor-agent amp crush goose kiro-cli qwen-code grok-build; do
	[[ "$("$binary" catalog show "$id" --distro=arch --json | jq -r '.data.category')" == 'Coding agents' ]] || fail "$id is a coding agent on Arch"
done
for d in debian suse; do
	for id in pi-agent copilot-cli cursor-agent amp goose kiro-cli qwen-code grok-build; do
		[[ "$("$binary" catalog show "$id" --distro=$d --json | jq -r '.data.source')" == script ]] || fail "$id installs by its script on $d"
	done
done
# Debian's `pi` package computes digits of pi: Pi the agent comes from pi.dev's installer.
[[ "$("$binary" catalog show pi-agent --distro=debian --json | jq -r '.data.script.url')" == 'https://pi.dev/install.sh' ]] || fail 'pi-agent on Debian is pi.dev/install.sh'
echo 'catalog tests passed'
