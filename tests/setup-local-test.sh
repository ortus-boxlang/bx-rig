#!/usr/bin/env bash
# Tests scripts/setup-local.sh, scripts/get-matchbox.sh and scripts/dev-build.sh (and scripts/lib/matchbox-ref.sh) with fake git, cargo, curl and mvm
# binaries first on PATH: no network, no real clone, no real build, no real mvm. The fake MatchBox they produce answers --version and the
# capability probes (the terminal UI canvas and a bytecode compile of cross-referencing classes): FAKE_TUI=1 (default) plays a build
# with bif-tui, FAKE_TUI=0 one without it; FAKE_SHARE=1 (default) plays a build with the class-file sharing fix, FAKE_SHARE=0 one without.
# Each case runs a copy of the scripts in its own scratch tree.
# Usage: bash tests/setup-local-test.sh   (needs no binary)
set -euo pipefail
src="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
# system tools only: the host's ~/.local/bin, ~/.mvm/bin, etc. must not leak into the fakes
base_path=/usr/local/bin:/usr/bin:/bin
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
has() { grep -qF -- "$2" "$1" 2>/dev/null || fail "$3: '$2' not found in $1: $(cat "$1" 2>/dev/null | head -n 20)"; }
lacks() { if grep -qF -- "$2" "$1" 2>/dev/null; then fail "$3: '$2' must not be in $1"; fi; }
command -v jq >/dev/null || fail "jq is required"

manifest_repo=https://github.com/ortus-boxlang/matchbox
manifest_version="$(jq -r .toolchain.matchbox.version "$src/box.json")"
sha=0123456789abcdef0123456789abcdef01234567

# ---- the fakes: they log every call to $FAKE_LOG and create what the scripts expect ----
mkdir -p "$tmp/bin" "$tmp/mvmbin"
cat > "$tmp/mb-template" <<'FAKE'
#!/usr/bin/env bash
case "${1:-}" in
	--version|-v) echo "matchbox version ${FAKE_MB_VERSION:-${MB_VERSION:-0.14.0}}"; echo "commit: feedbee" ;;
	*--build*) if [[ "${FAKE_SHARE:-1}" == 1 ]]; then echo "Error: Compiler Error: Circular class reference: A -> B -> A" >&2; exit 1; else echo "thread 'main' has overflowed its stack" >&2; exit 134; fi ;;
	*probe.bxs) if [[ "${FAKE_TUI:-1}" == 1 ]]; then echo bxrig-tui-ok; else echo "Error: Native class 'tui.TUI' not found. Ensure it is registered." >&2; exit 1; fi ;;
esac
FAKE
cat > "$tmp/bin/git" <<'FAKE'
#!/usr/bin/env bash
echo "git $*" >> "$FAKE_LOG"
[[ "$1" == -C ]] && shift 2
case "$1" in
	clone|init) dest="${*: -1}"; mkdir -p "$dest/.git" ;;
	rev-parse) case "$*" in *--short*) echo "${FAKE_COMMIT:-abc1234}" ;; *--abbrev-ref*) echo "${FAKE_BRANCH:-bxrig}" ;; esac ;;
	ls-remote) printf '%s\trefs/heads/bxrig\n' "$sha" ;;
esac
exit 0
FAKE
sed -i "s/\$sha/$sha/" "$tmp/bin/git"
cat > "$tmp/bin/cargo" <<'FAKE'
#!/usr/bin/env bash
echo "cargo $* (in $PWD)" >> "$FAKE_LOG"
profile=debug; [[ " $* " == *" --release "* ]] && profile=release
mkdir -p "target/$profile"
cp "$FAKE_MB_TEMPLATE" "target/$profile/matchbox"; chmod +x "target/$profile/matchbox"
FAKE
# mvm: "use X" puts a MatchBox in $HOME/.mvm/bin, like the real one
cat > "$tmp/mvmbin/mvm" <<'FAKE'
#!/usr/bin/env bash
echo "mvm $*" >> "$FAKE_LOG"
case "$1" in use) mkdir -p "$HOME/.mvm/bin"; cp "$FAKE_MB_TEMPLATE" "$HOME/.mvm/bin/matchbox"; chmod +x "$HOME/.mvm/bin/matchbox" ;; esac
exit 0
FAKE
cat > "$tmp/bin/curl" <<'FAKE'
#!/usr/bin/env bash
echo "curl $*" >> "$FAKE_LOG"
out=""; url=""
while (( $# )); do case "$1" in -o) out="$2"; shift 2 ;; -*) shift ;; *) url="$1"; shift ;; esac; done
case "$url" in
	*matchbox-linux-x86_64.sha256) sha256sum "$FAKE_PUBLISHED" | sed 's/ .*/  matchbox-linux-x86_64/' > "$out" ;;
	*matchbox-linux-x86_64) cp "$FAKE_PUBLISHED" "$out" ;;
	*) [[ "$out" == /dev/null ]] || echo ok > "$out" ;;
esac
FAKE
chmod +x "$tmp/bin/"* "$tmp/mvmbin/"*

n=0
# fresh: a scratch repo with the scripts under test (root = $w/repo, so .cache is $w/repo/.cache); a clean HOME without mvm
fresh() {
	n=$((n+1)); w="$tmp/case$n"; r="$w/repo"; log="$w/log"
	mkdir -p "$r/scripts/lib" "$r/bootstrap" "$r/tests"
	cp "$src/box.json" "$r/"; cp "$src/scripts/setup-local.sh" "$src/scripts/get-matchbox.sh" "$src/scripts/dev-build.sh" "$r/scripts/"
	cp "$src/scripts/lib/matchbox-ref.sh" "$r/scripts/lib/"
	rm -rf "${tmp:?}/home"; mkdir -p "$tmp/home"
	: > "$log"
}
# run SCRIPT ARGS...: output in $w/out, exit code in $rc; env: BXRIG_MATCHBOX_* are cleared unless the case sets them.
# mvm is only on the PATH when the case sets with_mvm=1.
with_mvm=0
run() {
	local s="$1" p="$tmp/bin"; shift
	(( ! with_mvm )) || p="$p:$tmp/mvmbin"
	set +e
	env -u BXRIG_MATCHBOX_BRANCH -u BXRIG_MATCHBOX_REPO -u MVM_HOME "${extra_env[@]}" PATH="$p:$base_path" FAKE_LOG="$log" MB_VERSION="$manifest_version" FAKE_MB_TEMPLATE="$tmp/mb-template" \
		bash "$r/scripts/$s" "$@" </dev/null > "$w/out" 2>&1
	rc=$?
	set -e
}
extra_env=(HOME="$tmp/home")
mbdir() { echo "$r/.cache/matchbox-src/$1"; }
# the dev.env of the case as variables
devenv() { ( . "$r/.cache/dev.env"; printf '%s|%s|%s|%s\n' "$MATCHBOX" "$MATCHBOX_REPO" "$MATCHBOX_REF" "$MATCHBOX_COMMIT" ); }

# ---- --matchbox stable and snapshot: mvm installs and activates the MatchBox, then the capability probe decides ----
for kind in stable snapshot; do
	what=latest; [[ $kind == stable ]] || what=snapshot
	fresh; with_mvm=1; run setup-local.sh --matchbox "$kind" --no-build
	[[ $rc == 0 ]] || fail "$kind: exit $rc: $(cat "$w/out")"
	has "$log" "mvm install $what" "$kind: mvm install"; has "$log" "mvm use $what" "$kind: mvm use"
	lacks "$log" "git clone" "$kind: no clone"; lacks "$log" "cargo" "$kind: no cargo"
	[[ "$(devenv)" == "$tmp/home/.mvm/bin/matchbox|mvm ($kind)|$what|feedbee" ]] || fail "$kind dev.env: $(devenv)"
	has "$w/out" "MatchBox in use: repo mvm ($kind), ref $what, commit feedbee, path $tmp/home/.mvm/bin/matchbox" "$kind: summary"
	# a MatchBox without the terminal UI cannot compile bxrig: stop, say so, record nothing, switch to nothing
	fresh; with_mvm=1; extra_env=(HOME="$tmp/home" FAKE_TUI=0); run setup-local.sh --matchbox "$kind" --no-build; extra_env=(HOME="$tmp/home")
	[[ $rc == 1 ]] || fail "$kind without the terminal UI: exit $rc: $(cat "$w/out")"
	has "$w/out" "cannot compile BxRig" "$kind: the capability message"; has "$w/out" "--matchbox branch --matchbox-branch bxrig" "$kind: names the way out"
	[[ ! -e "$r/.cache/dev.env" ]] || fail "$kind: a MatchBox that cannot compile bxrig was recorded"
	lacks "$log" "cargo" "$kind: never switches to a branch build by itself"
	# a snapshot-like MatchBox with bif-tui but without class sharing must be refused too (the real trap: it starts compiling and eats 50 GB)
	fresh; with_mvm=1; extra_env=(HOME="$tmp/home" FAKE_SHARE=0); run setup-local.sh --matchbox "$kind" --no-build; extra_env=(HOME="$tmp/home")
	[[ $rc == 1 ]] || fail "$kind without class sharing: exit $rc: $(cat "$w/out")"
	has "$w/out" "cannot compile BxRig efficiently" "$kind: the class-sharing message"; has "$w/out" "e7812e6" "$kind: names the fix"
	[[ ! -e "$r/.cache/dev.env" ]] || fail "$kind: a MatchBox that cannot compile bxrig was recorded"
done
fresh; with_mvm=0; run setup-local.sh --matchbox stable --no-build
[[ $rc == 4 ]] || fail "no mvm: exit $rc"; has "$w/out" "mvm is not installed" "no mvm: the install hint"

# ---- --matchbox branch: the default repo and branch, a clone of its own, cargo with bif-tui ----
fresh; run setup-local.sh --matchbox branch --no-build
[[ $rc == 0 ]] || fail "branch: exit $rc: $(cat "$w/out")"
d="$(mbdir ortus-boxlang-matchbox-bxrig)"
has "$log" "git clone --quiet --depth 1 --branch bxrig $manifest_repo $d" "the default is the bxrig branch of the manifest repo"
has "$log" "cargo build --features bif-tui (in $d)" "debug build"
lacks "$log" "--release" "debug by default"; lacks "$log" "mvm" "no mvm for a branch"
[[ ! -e "$w/matchbox" ]] || fail "../matchbox must not be touched"
[[ "$(cat "$r/.cache/dev.env")" == "# written by scripts/setup-local.sh (branch)
MATCHBOX=$d/target/debug/matchbox
MATCHBOX_REPO=$manifest_repo
MATCHBOX_REF=bxrig
MATCHBOX_COMMIT=abc1234" ]] || fail "branch dev.env: $(cat "$r/.cache/dev.env")"
fresh; run setup-local.sh --matchbox branch --release --no-build
has "$log" "cargo build --release --features bif-tui (in $(mbdir ortus-boxlang-matchbox-bxrig))" "--release"
has "$r/.cache/dev.env" "MATCHBOX=$(mbdir ortus-boxlang-matchbox-bxrig)/target/release/matchbox" "--release path in dev.env"
# a branch that cannot compile bxrig (a build without bif-tui) is refused the same way
fresh; extra_env=(HOME="$tmp/home" FAKE_TUI=0); run setup-local.sh --matchbox branch --no-build; extra_env=(HOME="$tmp/home")
[[ $rc == 1 ]] || fail "branch without the terminal UI: exit $rc"; has "$w/out" "cannot compile BxRig" "branch: the capability message"; [[ ! -e "$r/.cache/dev.env" ]] || fail "branch: recorded"
fresh; extra_env=(HOME="$tmp/home" FAKE_SHARE=0); run setup-local.sh --matchbox branch --no-build; extra_env=(HOME="$tmp/home")
[[ $rc == 1 ]] || fail "branch without class sharing: exit $rc"; has "$w/out" "cannot compile BxRig efficiently" "branch: the class-sharing message"; [[ ! -e "$r/.cache/dev.env" ]] || fail "branch: recorded"

# no terminal and no option: the branch build, said out loud
fresh; run setup-local.sh --no-build
[[ $rc == 0 ]] || fail "no option, no tty: exit $rc: $(cat "$w/out")"
has "$w/out" "No terminal to ask on: using the branch build (--matchbox branch, bxrig of $manifest_repo)" "the default is announced"
has "$log" "--branch bxrig $manifest_repo $(mbdir ortus-boxlang-matchbox-bxrig)" "no option, no tty builds bxrig"
lacks "$log" "mvm" "no option, no tty does not touch mvm"

# the removed choices say what to use now
for old in edge source; do
	fresh; run setup-local.sh --matchbox $old --no-build
	[[ $rc == 2 ]] || fail "--matchbox $old: exit $rc"; has "$w/out" "was removed: use --matchbox branch" "--matchbox $old"; [[ ! -s "$log" ]] || fail "--matchbox $old ran something"
done
fresh; run setup-local.sh --matchbox nonsense --no-build; [[ $rc == 2 ]] || fail "unknown choice: $rc"; has "$w/out" "stable, snapshot or branch" "unknown choice"
for kind in stable snapshot; do
	fresh; with_mvm=1; run setup-local.sh --matchbox $kind --matchbox-branch develop --no-build
	[[ $rc == 2 ]] || fail "$kind + branch: exit $rc"; [[ ! -s "$log" ]] || fail "$kind + branch ran something"
	fresh; with_mvm=1; run setup-local.sh --matchbox $kind --matchbox-repo someone/fork --no-build; [[ $rc == 2 ]] || fail "$kind + repo: exit $rc"
done
with_mvm=0

# ---- --matchbox-branch, --matchbox-repo, env vars (they imply the branch choice) ----
fresh; run setup-local.sh --matchbox-branch develop --no-build
[[ $rc == 0 ]] || fail "branch: exit $rc: $(cat "$w/out")"
d="$(mbdir ortus-boxlang-matchbox-develop)"
has "$log" "git clone --quiet --depth 1 --branch develop $manifest_repo $d" "shallow clone into the dedicated dir"
has "$log" "cargo build --features bif-tui (in $d)" "debug build of the dedicated clone"
has "$r/.cache/dev.env" "MATCHBOX_REF=develop" "ref recorded"
fresh; run setup-local.sh --matchbox-branch=develop --release --no-build
has "$log" "cargo build --release --features bif-tui (in $(mbdir ortus-boxlang-matchbox-develop))" "--release for a branch"
fresh; run setup-local.sh --matchbox branch --matchbox-branch feature/x+y@2 --no-build
has "$log" "--branch feature/x+y@2 $manifest_repo $(mbdir ortus-boxlang-matchbox-feature-x-y-2)" "slashes become dashes in the dir name"
fresh; run setup-local.sh --matchbox-repo someone/matchbox-fork --matchbox-branch topic --no-build
d="$(mbdir someone-matchbox-fork-topic)"
has "$log" "--branch topic https://github.com/someone/matchbox-fork $d" "owner/name is a GitHub repo"
has "$r/.cache/dev.env" "MATCHBOX_REPO=https://github.com/someone/matchbox-fork" "repo recorded"
fresh; run setup-local.sh --matchbox-repo=https://github.com/someone/matchbox-fork.git --matchbox-branch topic --no-build
has "$log" "--branch topic https://github.com/someone/matchbox-fork.git $(mbdir someone-matchbox-fork-topic)" "a full URL is kept, .git is not in the dir name"
fresh; run setup-local.sh --matchbox-repo https://git.example.org/team/mb --no-build
has "$log" "--branch bxrig https://git.example.org/team/mb $(mbdir git.example.org-team-mb-bxrig)" "repo alone: another host, manifest ref"
env_run() { set +e; env PATH="$tmp/bin:$base_path" FAKE_LOG="$log" MB_VERSION="$manifest_version" FAKE_MB_TEMPLATE="$tmp/mb-template" HOME="$tmp/home" "$@" bash "$r/scripts/setup-local.sh" --no-build </dev/null > "$w/out" 2>&1; rc=$?; set -e; }
fresh; env_run BXRIG_MATCHBOX_BRANCH=develop BXRIG_MATCHBOX_REPO=someone/fork
has "$log" "--branch develop https://github.com/someone/fork $(mbdir someone-fork-develop)" "env vars"
fresh; env_run BXRIG_MATCHBOX_BRANCH=develop
has "$log" "--branch develop $manifest_repo $(mbdir ortus-boxlang-matchbox-develop)" "env branch alone"
fresh
set +e; env PATH="$tmp/bin:$base_path" FAKE_LOG="$log" MB_VERSION="$manifest_version" FAKE_MB_TEMPLATE="$tmp/mb-template" HOME="$tmp/home" BXRIG_MATCHBOX_BRANCH=develop bash "$r/scripts/setup-local.sh" --matchbox-branch other --no-build </dev/null > "$w/out" 2>&1; rc=$?; set -e
has "$log" "--branch other " "flag wins over the env var"; lacks "$log" "--branch develop" "env var overridden"
# a second run refreshes the dedicated clone with a fetch, no second clone
fresh; run setup-local.sh --matchbox-branch develop --no-build; : > "$log"; run setup-local.sh --matchbox-branch develop --no-build
d="$(mbdir ortus-boxlang-matchbox-develop)"
lacks "$log" "git clone" "no second clone"
has "$log" "git -C $d remote set-url origin $manifest_repo" "origin refreshed"
has "$log" "git -C $d fetch --quiet --depth 1 origin develop" "refresh is a shallow fetch"
has "$log" "git -C $d checkout --quiet --force --detach FETCH_HEAD" "refresh checks out FETCH_HEAD"
# a full commit id is fetched by itself
fresh; run setup-local.sh --matchbox-branch "$sha" --no-build
d="$(mbdir ortus-boxlang-matchbox-$sha)"
has "$log" "git init --quiet $d" "commit: init"; has "$log" "git -C $d remote add origin $manifest_repo" "commit: remote"
has "$log" "git -C $d fetch --quiet --depth 1 origin $sha" "commit: fetch of that sha"; lacks "$log" "git clone" "commit: no clone"
has "$r/.cache/dev.env" "MATCHBOX_REF=$sha" "commit recorded as ref"
# a dedicated dir that is not a clone is refused, not reused
fresh; mkdir -p "$(mbdir ortus-boxlang-matchbox-develop)"; run setup-local.sh --matchbox-branch develop --no-build
[[ $rc == 4 ]] || fail "dir that is not a clone: exit $rc"; has "$w/out" "is not a git clone" "dir that is not a clone"

# ---- bad values are refused before anything runs ----
bad() { # FLAG VALUE
	fresh; run setup-local.sh "$1" "$2" --no-build
	[[ $rc == 2 ]] || fail "$1 '$2': exit $rc, expected 2: $(cat "$w/out")"
	has "$w/out" "invalid MatchBox" "$1 '$2' message"
	[[ ! -s "$log" ]] || fail "$1 '$2' ran something: $(cat "$log")"
	[[ ! -e "$r/.cache" ]] || fail "$1 '$2' wrote .cache"
}
for v in "a b" "a;b" 'a$(id)' '$(id)' "a\`id\`" "-x" "--upload-pack=x" "" "a|b" "a&b" "a>b" "a'b" 'a"b' "a*" "a..b" "a/" "$(printf 'a\nb')" "a:b" "a\\b"; do bad --matchbox-branch "$v"; done
for v in "a b" "x;y/z" 'o/$(id)' "-owner/name" "" "name" "http://github.com/a/b" "https://host/a b" "https://host/a;b" "../x/y" "a/b/c" "git@github.com:a/b" "file:///etc"; do bad --matchbox-repo "$v"; done
fresh; set +e; env PATH="$tmp/bin:$base_path" FAKE_LOG="$log" BXRIG_MATCHBOX_BRANCH='x;y' bash "$r/scripts/setup-local.sh" --no-build </dev/null > "$w/out" 2>&1; rc=$?; set -e
[[ $rc == 2 ]] || fail "bad env branch: exit $rc"; has "$w/out" "BXRIG_MATCHBOX_BRANCH" "the message names the env var"; [[ ! -s "$log" ]] || fail "bad env branch ran something"
fresh; run setup-local.sh --matchbox-branch; [[ $rc == 2 ]] || fail "--matchbox-branch without a value: $rc"
[[ ! -e "$tmp/pwned" ]] || fail "injection"

# ---- the interactive menu (a real terminal through a pty) ----
if command -v python3 >/dev/null; then
	pty() { # ANSWERS... ; runs setup-local.sh --no-build on a pty and feeds the answers
		env HOME="$tmp/home" PATH="$tmp/bin:$tmp/mvmbin:$base_path" FAKE_LOG="$log" MB_VERSION="$manifest_version" FAKE_MB_TEMPLATE="$tmp/mb-template" python3 -I - "$r/scripts/setup-local.sh" "$@" > "$w/out" 2>&1 <<'PY' || true
import os, pty, sys, time
script, answers = sys.argv[1], sys.argv[2:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash", script, "--no-build"])
out = b""
for a in answers:
    time.sleep(0.4)
    os.write(fd, (a + "\n").encode())
while True:
    try:
        d = os.read(fd, 4096)
    except OSError:
        break
    if not d:
        break
    out += d
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
PY
	}
	fresh; pty 1
	has "$w/out" "1) stable" "the menu lists stable"; has "$w/out" "2) snapshot" "the menu lists snapshot"; has "$w/out" "3) branch" "the menu lists branch"
	lacks "$w/out" "4)" "the menu has three choices"
	has "$log" "mvm install latest" "choice 1 installs the stable MatchBox"; has "$log" "mvm use latest" "choice 1 activates it"; lacks "$log" "snapshot" "choice 1 is not the snapshot"
	fresh; pty 2
	has "$log" "mvm install snapshot" "choice 2 installs the snapshot"; has "$log" "mvm use snapshot" "choice 2 activates it"
	fresh; pty 3 someone/fork 'x;y' feature/q
	has "$w/out" "Not a valid ref" "an invalid branch is asked again"
	has "$log" "--branch feature/q https://github.com/someone/fork $(mbdir someone-fork-feature-q)" "choice 3 asks for repo and branch"
	fresh; pty 3 "" ""
	has "$log" "--branch bxrig $manifest_repo $(mbdir ortus-boxlang-matchbox-bxrig)" "choice 3 defaults to ortus-boxlang/matchbox and bxrig"
	fresh; pty 9 7 1
	has "$w/out" "Choose 1, 2 or 3" "an unknown choice is asked again"; has "$log" "mvm install latest" "the menu goes on after a wrong answer"
	fresh; pty 1; lacks "$w/out" "No terminal to ask on" "a terminal gets the menu, not the default"
else
	echo "skip: interactive menu (no python3)"
fi

# get-matchbox.sh: default behaviour first
published() { printf '#!/usr/bin/env bash\necho "matchbox version %s"\n' "$1" > "$w/published"; chmod +x "$w/published"; }
fresh; published "$manifest_version"
extra_env=(HOME="$tmp/home" FAKE_PUBLISHED="$w/published"); run get-matchbox.sh "$w/out-mb"; extra_env=(HOME="$tmp/home")
[[ $rc == 0 ]] || fail "get-matchbox default: $rc: $(cat "$w/out")"
lacks "$log" "cargo" "the default path takes the published build"
has "$w/out-mb.info" "version=$manifest_version" "default .info"
lacks "$w/out-mb.info" "repo=" "the default .info has no repo line"
fresh; run get-matchbox.sh "$w/out-mb" --from-source
[[ $rc == 0 ]] || fail "get-matchbox --from-source: $rc: $(cat "$w/out")"
has "$log" "git clone --quiet --depth 1 --branch bxrig $manifest_repo" "--from-source clones the manifest branch"
has "$log" "cargo build --release --locked --features bif-tui" "--from-source keeps --locked"
# the check is not weakened: a published build with another version is refused, and so is a source build of it
fresh; published 0.99.0
extra_env=(HOME="$tmp/home" FAKE_PUBLISHED="$w/published" FAKE_MB_VERSION=0.99.0); run get-matchbox.sh "$w/out-mb"; extra_env=(HOME="$tmp/home")
[[ $rc != 0 ]] || fail "a wrong published version was accepted"; has "$w/out" "box.json wants $manifest_version" "published version mismatch is an error"
[[ ! -e "$w/out-mb" ]] || fail "a refused MatchBox was installed"
fresh; extra_env=(HOME="$tmp/home" FAKE_MB_VERSION=0.99.0); run get-matchbox.sh "$w/out-mb" --from-source; extra_env=(HOME="$tmp/home")
[[ $rc != 0 ]] || fail "a wrong source build was accepted by default"
# the same --ref/--repo as box.json is the default path
fresh; run get-matchbox.sh "$w/out-mb" --ref bxrig --repo ortus-boxlang/matchbox --from-source
has "$log" "cargo build --release --locked" "the manifest ref and repo keep the default path"

# --ref / --repo: built from source, a version difference is a warning
fresh; extra_env=(HOME="$tmp/home" FAKE_MB_VERSION=0.99.0); run get-matchbox.sh "$w/out-mb" --ref develop; extra_env=(HOME="$tmp/home")
[[ $rc == 0 ]] || fail "get-matchbox --ref: $rc: $(cat "$w/out")"
has "$log" "git clone --quiet --depth 1 --branch develop $manifest_repo" "--ref clones that ref"
has "$log" "cargo build --release --features bif-tui" "--ref builds in release mode"
lacks "$log" "--locked" "--ref does not insist on the lock file"
lacks "$log" "matchbox-linux-x86_64" "--ref never downloads the published build"
has "$w/out" "warning:" "--ref version mismatch warns"; has "$w/out" "$manifest_version" "--ref warning names box.json's version"
[[ -x "$w/out-mb" ]] || fail "--ref left no executable"
has "$w/out-mb.info" "ref=develop" ".info ref"; has "$w/out-mb.info" "repo=$manifest_repo" ".info repo"; has "$w/out-mb.info" "commit=abc1234" ".info commit"
fresh; run get-matchbox.sh "$w/out-mb" --repo=someone/fork --ref=topic
has "$log" "--branch topic https://github.com/someone/fork" "--repo shorthand and the = forms"
lacks "$w/out" "warning:" "no warning when the version matches"
fresh; run get-matchbox.sh "$w/out-mb" --repo someone/fork     # repo alone: the manifest branch of the fork
has "$log" "--branch bxrig https://github.com/someone/fork" "--repo alone keeps the manifest ref"
fresh; run get-matchbox.sh "$w/out-mb" --ref "$sha"
has "$log" "fetch --quiet --depth 1 origin $sha" "--ref with a full commit id fetches it"
for v in "a b" "a;b" 'a$(id)' "-x" ""; do
	fresh; run get-matchbox.sh "$w/out-mb" --ref "$v"
	[[ $rc == 2 ]] || fail "get-matchbox --ref '$v': $rc"; [[ ! -s "$log" ]] || fail "get-matchbox --ref '$v' ran something"
done
for v in "a b" "x;y/z" "-o/n" "" "name"; do
	fresh; run get-matchbox.sh "$w/out-mb" --repo "$v"
	[[ $rc == 2 ]] || fail "get-matchbox --repo '$v': $rc"; [[ ! -s "$log" ]] || fail "get-matchbox --repo '$v' ran something"
done


# dev-build.sh: builds with the MatchBox it is given, but only one that can compile bxrig
fresh
printf '#!/usr/bin/env bash\n' | tee "$r/bootstrap/gen-assets.sh" "$r/bootstrap/gen-version.sh" "$r/scripts/get-modules.sh" > /dev/null
chmod +x "$r/bootstrap/gen-assets.sh" "$r/bootstrap/gen-version.sh" "$r/scripts/get-modules.sh"
mkdir -p "$r/src"; : > "$r/src/Main.bx"
cat > "$w/mb" <<'MB'
#!/usr/bin/env bash
case "${1:-}" in
	--version) echo "matchbox version 0.99.0"; exit 0 ;;
	*--build*) [[ "${FAKE_SHARE:-1}" == 1 ]] && { echo "Error: Compiler Error: Circular class reference: A -> B -> A" >&2; exit 1; }; echo "thread 'main' has overflowed its stack" >&2; exit 134 ;;
	*probe.bxs) [[ "${FAKE_TUI:-1}" == 1 ]] && { echo bxrig-tui-ok; exit 0; }; echo "Native class 'tui.TUI' not found" >&2; exit 1 ;;
esac
while (( $# )); do [[ "$1" == --output ]] && { echo built > "$2"; }; shift; done
MB
chmod +x "$w/mb"
extra_env=(HOME="$tmp/home" MATCHBOX="$w/mb"); run dev-build.sh; extra_env=(HOME="$tmp/home")
[[ $rc == 0 && -f "$r/dist/bxrig" ]] || fail "dev-build with a capable MatchBox (any version is fine): $rc: $(cat "$w/out")"
rm -f "$r/dist/bxrig"
extra_env=(HOME="$tmp/home" MATCHBOX="$w/mb" FAKE_TUI=0); run dev-build.sh; extra_env=(HOME="$tmp/home")
[[ $rc == 1 ]] || fail "dev-build with a MatchBox without the terminal UI: exit $rc"
has "$w/out" "cannot compile BxRig" "dev-build: the capability message"; has "$w/out" "0.99.0" "dev-build names the MatchBox version"; [[ ! -e "$r/dist/bxrig" ]] || fail "dev-build built with a MatchBox that cannot compile bxrig"
rm -f "$r/dist/bxrig"
extra_env=(HOME="$tmp/home" MATCHBOX="$w/mb" FAKE_SHARE=0); run dev-build.sh; extra_env=(HOME="$tmp/home")
[[ $rc == 1 ]] || fail "dev-build with a MatchBox without class sharing: exit $rc"
has "$w/out" "cannot compile BxRig efficiently" "dev-build: the class-sharing message"; [[ ! -e "$r/dist/bxrig" ]] || fail "dev-build built with a MatchBox that cannot compile bxrig"

# ---- the summary at the end: which MatchBox, how to switch, how to test the installer with it ----
fresh; run setup-local.sh --matchbox-branch develop --no-build
d="$(mbdir ortus-boxlang-matchbox-develop)"
has "$w/out" "MatchBox in use: repo $manifest_repo, ref develop, commit abc1234, path $d/target/debug/matchbox" "summary names repo, ref, commit and path"
has "$w/out" "--matchbox branch --matchbox-branch bxrig" "summary says how to switch"
has "$w/out" "BXRIG_MATCHBOX_FILE=$d/target/debug/matchbox bash bootstrap/install.sh toolchains --yes" "summary gives the installer command"
mb_path="$d/target/debug/matchbox"
[[ -f "$mb_path" && -x "$mb_path" && ! -L "$mb_path" ]] || fail "the built MatchBox must be an executable regular file (what install.sh requires of BXRIG_MATCHBOX_FILE)"
"$mb_path" --version >/dev/null || fail "the built MatchBox must run"
fresh; run setup-local.sh --matchbox-repo someone/fork --matchbox-branch topic --no-build
has "$w/out" "MatchBox in use: repo https://github.com/someone/fork, ref topic" "summary for a fork"

export FAKE_LOG=/dev/null

echo "setup-local tests passed"
