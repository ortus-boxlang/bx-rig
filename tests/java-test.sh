#!/usr/bin/env bash
# `bxrig java` with fake JDKs and a fake download. Usage: java-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
export HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" BXRIG_JAVA_DIR="$tmp/data/java" BXRIG_JAVA_SYSTEM_DIR="$tmp/jvm" BXRIG_SDKMAN_DIR="$tmp/sdkman" BXRIG_JENV_DIR="$tmp/jenv" BXRIG_JENV_REPO="$tmp/jenv-src" BXRIG_SDKMAN_INSTALLER="file://$tmp/no-such-installer"
mkdir -p "$HOME"
code() { set +e; "$@" >/dev/null 2>&1; echo $?; set -e; }
mkjdk() { # dir version vendor
	mkdir -p "$1/bin"; printf '#!/bin/sh\necho java\n' > "$1/bin/java"; chmod +x "$1/bin/java"
	printf 'IMPLEMENTOR="%s"\nJAVA_VERSION="%s"\n' "$3" "$2" > "$1/release"
}
# a fake jenv: a git repo with bin/jenv that keeps its versions and global in $JENV_ROOT
mkdir -p "$tmp/jenv-src/bin"
cat > "$tmp/jenv-src/bin/jenv" <<'JENV'
#!/usr/bin/env bash
v="$JENV_ROOT/versions"; mkdir -p "$v"
case "$1" in
	enable-plugin) echo "$2" >> "$JENV_ROOT/plugins.log" ;;
	add) n="$(sed -n 's/^JAVA_VERSION="\(.*\)"/\1/p' "$2/release")"; echo "$2" > "$v/$n" ;;
	versions) ls "$v" ;;
	global) if [[ -n "${2:-}" ]]; then echo "$2" > "$JENV_ROOT/global"; else cat "$JENV_ROOT/global" 2>/dev/null || echo system; fi ;;
	local) echo "$2" > .java-version ;;
	remove) rm -f "$v/$2" ;;
esac
JENV
chmod +x "$tmp/jenv-src/bin/jenv"
git -C "$tmp/jenv-src" init -q; git -C "$tmp/jenv-src" -c user.email=t@t -c user.name=t add -A; git -C "$tmp/jenv-src" -c user.email=t@t -c user.name=t commit -qm init

mkjdk "$tmp/jvm/java-17-openjdk" 17.0.13 Arch
mkjdk "$tmp/sdkman/candidates/java/21.0.5-tem" 21.0.5 "Eclipse Adoptium"
mkdir -p "$tmp/sdkman/candidates/java"; ln -s 21.0.5-tem "$tmp/sdkman/candidates/java/current"

"$binary" java list --json | jq -e '(.data.homes | length == 2) and (.data.homes[0].major == 21) and (.data.homes[0].source == "sdkman") and (.data.homes[1].id == "system-java-17-openjdk")' >/dev/null || fail 'list sees sdkman and system homes, newest first, skipping current'
"$binary" java list | grep -q 'sdkman-21.0.5-tem' || fail 'plain list'

# install: a fake download (a tarball with one top folder), plan first
mkdir -p "$tmp/dl/jdk-21.0.13+9"; mkjdk "$tmp/dl/jdk-21.0.13+9" 21.0.13 "Eclipse Adoptium"; echo 'SEMANTIC_VERSION="21.0.13+9"' >> "$tmp/dl/jdk-21.0.13+9/release"; (cd "$tmp/dl" && tar -czf "$tmp/jdk21.tar.gz" jdk-21.0.13+9)
export BXRIG_JAVA_DOWNLOAD_URL="file://$tmp/jdk21.tar.gz" BXRIG_ADOPTIUM_API="file://$tmp/api"
mkdir -p "$tmp/api/v3/info"; echo '{"available_releases":[8,11,17,21],"available_lts_releases":[8,11,17,21],"most_recent_feature_release":21}' > "$tmp/api/v3/info/available_releases"
[[ "$(code "$binary" java install 21)" == 2 ]] || fail 'install plan exits 2'
[[ ! -d "$tmp/data/java" ]] || fail 'plan changed nothing'
"$binary" java install 21 --dry-run --json | jq -e '.dry_run' >/dev/null || fail 'dry run'
[[ "$(code "$binary" java install 99 --yes)" == 4 ]] || fail 'unknown release exits 4'
"$binary" java install 21 --yes --json | jq -e '.data.id == "temurin-21.0.13_9"' >/dev/null || fail 'install'
[[ -x "$tmp/data/java/temurin-21.0.13_9/bin/java" ]] || fail 'unpacked'
"$binary" java install 21 --yes --json | jq -e '.data.already == true' >/dev/null || fail 'install twice is a no-op'
"$binary" java available --json | jq -e '(.data.releases | length == 4) and (.data.releases[3].lts == true)' >/dev/null || fail 'available'

# global needs jenv; setup plans first, then installs jenv, the shell files, 21 and the extras
[[ "$(code "$binary" java global 21 --yes)" != 0 ]] || fail 'global without jenv fails'
[[ "$(code "$binary" java setup)" == 2 ]] || fail 'setup plan exits 2'
[[ ! -d "$tmp/jenv" ]] || fail 'setup plan changed nothing'
"$binary" java setup --dry-run --json --versions=25,17 | jq -e '.dry_run and (.data.majors == [21,25,17])' >/dev/null || fail 'setup dry run lists majors'
mkdir -p "$tmp/cfg/bxrig"; echo old > "$tmp/cfg/bxrig/java.sh"; echo old > "$tmp/cfg/bxrig/java.fish"
"$binary" java setup --yes --json > "$tmp/setup.json" || fail 'setup'
[[ -x "$tmp/jenv/bin/jenv" ]] || fail 'jenv installed'
for p in export maven gradle; do grep -qx "$p" "$tmp/jenv/plugins.log" || fail "plugin $p enabled"; done
grep -q 'JENV_ROOT="'"$tmp"'/jenv"' "$tmp/cfg/bxrig/jenv.sh" || fail 'jenv.sh'
grep -q 'jenv init -' "$tmp/cfg/bxrig/jenv.sh" || fail 'jenv.sh init'
grep -q 'set -gx JENV_ROOT' "$tmp/cfg/bxrig/jenv.fish" || fail 'jenv.fish'
[[ ! -e "$tmp/cfg/bxrig/java.sh" && ! -e "$tmp/cfg/bxrig/java.fish" ]] || fail 'old java.sh and java.fish removed'
[[ "$(cat "$tmp/jenv/global")" == 21.0.13 ]] || fail "21 is global: $(cat "$tmp/jenv/global")"
"$binary" java status --json | jq -e '.data.jenv and (.data.global == "21.0.13")' >/dev/null || fail 'status'
"$binary" java list --json | jq -e '([.data.homes[] | select(.default)] | length == 1) and (.data.homes[] | select(.default) | .source == "bxrig")' >/dev/null || fail 'global marked'
"$binary" java setup --yes >/dev/null || fail 'setup twice'

# global and local through jenv
[[ "$(code "$binary" java global 17)" == 2 ]] || fail 'global plan exits 2'
"$binary" java global 17 --yes >/dev/null
[[ "$(cat "$tmp/jenv/global")" == 17.0.13 ]] || fail 'global 17'
"$binary" java default 21 --yes >/dev/null
[[ "$(cat "$tmp/jenv/global")" == 21.0.13 ]] || fail 'default is the old name of global'
(cd "$tmp" && "$binary" java local 17 --yes >/dev/null && [[ "$(cat .java-version)" == 17.0.13 ]]) || fail 'local'
[[ "$(code "$binary" java global 99 --yes)" == 4 ]] || fail 'unknown home exits 4'

# remove: only what BxRig installed; the default is cleared with it
[[ "$(code "$binary" java remove system-java-17-openjdk --yes)" == 4 ]] || fail 'system homes are not removed'
[[ "$(code "$binary" java remove temurin-21.0.13_9)" == 2 ]] || fail 'remove plan exits 2'
"$binary" java remove temurin-21.0.13_9 --yes >/dev/null
[[ ! -d "$tmp/data/java/temurin-21.0.13_9" ]] || fail 'removed'
[[ ! -e "$tmp/jenv/versions/21.0.13" ]] || fail 'forgotten in jenv'
[[ "$(code "$binary" java frobnicate)" == 2 ]] || fail 'bad usage exits 2'
echo "java tests passed"
