#!/usr/bin/env bash
set -euo pipefail

# Tool versions, installer URLs and the Java package live in box.json at the repository root (loaded below).
# BoxLang follows the latest stable release (owner decision 2026-11-09); BXRIG_BOXLANG_VERSION=x.y.z pins it.
# MatchBox comes from mvm: the stable release by default (`mvm install latest`), the snapshot build with --snapshot
# (BXRIG_MATCHBOX_CHANNEL=snapshot), or a branch built here with cargo (--matchbox-branch REF, see "MatchBox" below). Neither stable nor
# snapshot contains all the BxRig changes (the snapshot has bif-tui now, but not the class-file sharing fix), so they cannot compile bxrig
# well enough: the binary stage probes the MatchBox it would use (mb_can_compile_bxrig: bif-tui + class sharing).
# BXRIG_MVM_VERSION=x.y.z asks the MVM installer for a specific release.
# Free disk space in $HOME. A single stage needs MIN_FREE_GB; the whole install needs FULL_FREE_GB, checked up front so a machine that
# passes stage 1 cannot run out of space in stage 2. Derived from a real Arch run (2026-11-16): the image had 6 GB free and Rust alone
# took about 2.5 GB (4 GB left); packages about 1.3 GB (pacman reported 1334 MiB installed), the MatchBox branch build (cargo release
# target dir) about 3 GB, Java, mvm, BoxLang and the bxrig binary about 0.5 GB: about 7.3 GB, plus 0.7 GB headroom = 8 GB.
MIN_FREE_GB=5
FULL_FREE_GB=8
BOXLANG_LATEST_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang/version-latest.properties"

usage() {
	cat >&2 <<'USAGE'
Usage: install.sh [--yes] [--dry-run] [--snapshot | --matchbox-branch REF [--matchbox-repo OWNER/NAME]]
                                          install everything: packages, toolchains, the bxrig binary, the core apps
       install.sh check                   read-only report of what is installed
       install.sh packages|toolchains|binary|core --yes [--binary PATH --force]   re-run one stage
                                          (toolchains also takes --snapshot, --matchbox-branch REF and --matchbox-repo OWNER/NAME)
       MatchBox: stable by default; --snapshot = the mvm snapshot build; --matchbox-branch REF = built from that branch (default repo
       ortus-boxlang/matchbox). --matchbox-from-source is the same as --matchbox-branch bxrig.
       install.sh wizard                  the setup wizard (bxrig init); the full install ends with it at a terminal
USAGE
	exit 2
}
# Public words: no word = the whole install. Stage words re-run one stage. Internally the stages keep their old mode names.
mode=full; yes=0; dry=0; force=0; binary_arg=""; mb_branch_arg=""; mb_branch_set=0; mb_source=0; mb_snapshot=0; mb_repo_arg=""; mb_repo_set=0
# The MatchBox branch to install (default: the manifest's toolchain.matchbox.ref). Only [A-Za-z0-9._/@+-], no leading dash, no "..", no
# leading or trailing slash: it ends up in a git argument and in an API path, never in a shell string.
valid_ref() { [[ "$1" =~ ^[A-Za-z0-9._/@+-]+$ && "$1" != -* && "$1" != *..* && "$1" != /* && "$1" != */ ]]; }
valid_repo() { [[ "$1" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ && "$1" != -* && "$1" != *..* && "$1" != */-* ]]; }   # OWNER/NAME on GitHub
case "${1:-}" in
	check) mode=--check; shift ;;
	packages) mode=--install; shift ;;
	toolchains) mode=--install-toolchains; shift ;;
	binary) mode=--install-binary; shift ;;
	core) mode=--core; shift ;;
	wizard) mode=--wizard; shift ;;
esac
case "$mode" in
	--check|--wizard) [[ $# -eq 0 ]] || usage ;;
	full|--install-toolchains)
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--yes) yes=1 ;;
				--dry-run) [[ "$mode" == full ]] || usage; dry=1 ;;
				--matchbox-branch) [[ $# -ge 2 ]] || usage; mb_branch_arg="$2"; mb_branch_set=1; shift ;;
				--matchbox-repo) [[ $# -ge 2 ]] || usage; mb_repo_arg="$2"; mb_repo_set=1; shift ;;
				--matchbox-from-source) mb_source=1 ;;
				--snapshot) mb_snapshot=1 ;;
				*) usage ;;
			esac
			shift
		done
		[[ "$mode" == full || $yes -eq 1 ]] || usage ;;
	--install|--core)
		[[ $# -eq 1 && "$1" == --yes ]] || usage; yes=1 ;;
	--install-binary)
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--yes) yes=1; shift ;;
				--force) force=1; shift ;;
				--binary) [[ $# -ge 2 ]] || usage; binary_arg="$2"; shift 2 ;;
				*) usage ;;
			esac
		done
		[[ $yes -eq 1 ]] || usage ;;
esac

# ---- which MatchBox: stable (the default), snapshot (--snapshot), or a branch built here (--matchbox-branch REF) ----
# Flags beat the environment (BXRIG_MATCHBOX_CHANNEL=snapshot, BXRIG_MATCHBOX_BRANCH, BXRIG_MATCHBOX_REPO). --matchbox-from-source is the
# old spelling of "the manifest's branch" and means --matchbox-branch bxrig when no branch is given.
bad_option() { echo "$1" >&2; exit 2; }
env_channel="${BXRIG_MATCHBOX_CHANNEL:-}"
[[ -z "$env_channel" || "$env_channel" == stable || "$env_channel" == snapshot ]] || bad_option "Invalid BXRIG_MATCHBOX_CHANNEL: '$env_channel' (stable or snapshot; a branch is --matchbox-branch REF)"
MB_BRANCH_REQ="${mb_branch_arg:-}"; (( mb_branch_set )) || MB_BRANCH_REQ="${BXRIG_MATCHBOX_BRANCH:-}"
MB_REPO_REQ="${mb_repo_arg:-}"; (( mb_repo_set )) || MB_REPO_REQ="${BXRIG_MATCHBOX_REPO:-}"
(( ! mb_snapshot || ( ! mb_branch_set && ! mb_source ) )) || bad_option "--snapshot and --matchbox-branch cannot be combined: pick one MatchBox"
if (( mb_snapshot )); then MB_CHANNEL=snapshot
elif (( mb_branch_set || mb_source )) || [[ -n "$MB_BRANCH_REQ" ]]; then MB_CHANNEL=branch
else MB_CHANNEL="${env_channel:-stable}"; fi
[[ "$env_channel" != snapshot || -z "${BXRIG_MATCHBOX_BRANCH:-}" || $mb_snapshot -eq 1 || $mb_branch_set -eq 1 || $mb_source -eq 1 ]] || bad_option "BXRIG_MATCHBOX_CHANNEL=snapshot and a MatchBox branch cannot be combined: pick one MatchBox"
if (( mb_branch_set )) || { [[ "$MB_CHANNEL" == branch ]] && [[ -n "$MB_BRANCH_REQ" ]]; }; then
	valid_ref "$MB_BRANCH_REQ" || bad_option "Invalid MatchBox branch: '$MB_BRANCH_REQ' (letters, digits and . _ / @ + - only; no leading dash, no ..)"
fi
if (( mb_repo_set )) && [[ "$MB_CHANNEL" != branch ]]; then bad_option "--matchbox-repo needs --matchbox-branch REF"; fi
if [[ "$MB_CHANNEL" == branch ]] && { (( mb_repo_set )) || [[ -n "$MB_REPO_REQ" ]]; }; then
	valid_repo "$MB_REPO_REQ" || bad_option "Invalid MatchBox repository: '$MB_REPO_REQ' (OWNER/NAME: letters, digits and . _ - only)"
fi
# ---- the distribution: arch (CachyOS, Arch), suse (Tumbleweed, Slowroll), debian (13) or ubuntu (26.04), each with its package manager ----
os_id() { ( . "${BXRIG_OS_RELEASE:-/etc/os-release}" 2>/dev/null; echo "${ID:-unknown}|${ID_LIKE:-}|${VERSION_ID:-}" ) || echo "unknown||"; }
os_family() {  # ID ID_LIKE -> arch|suse|debian|ubuntu|""
	local id="$1" like=" $2 "
	if [[ "$id" == cachyos || "$id" == arch || "$like" == *" arch "* ]]; then echo arch
	elif [[ "$id" == opensuse* || "$like" == *" suse "* || "$like" == *" opensuse "* ]]; then echo suse
	elif [[ "$id" == ubuntu ]]; then echo ubuntu
	elif [[ "$id" == debian ]]; then echo debian
	elif [[ "$like" == *" ubuntu "* ]]; then echo ubuntu
	elif [[ "$like" == *" debian "* ]]; then echo debian
	else echo ""; fi
}
IFS='|' read -r os_name os_like os_version <<<"$(os_id)"
os_fam="$(os_family "$os_name" "$os_like")"
case "$os_fam" in
	arch) pm=pacman ;; suse) pm=zypper ;; debian|ubuntu) pm=apt-get ;;
	*) pm=pacman ;;   # an unknown system: `check` reports it unsupported, the stages refuse it (preflight_common)
esac
command -v "$pm" >/dev/null 2>&1 || {
	if [[ "$pm" == pacman ]]; then echo "BxRig requires Arch Linux/CachyOS (pacman), openSUSE Tumbleweed or Slowroll (zypper), Ubuntu 26.04 or Debian 13 (apt)" >&2
	else echo "BxRig needs $pm on $os_name, and it was not found" >&2; fi
	exit 1
}
# The prerequisites in this distribution's names (the Java package from box.json, named for Arch, is translated in load_manifest).
base_packages() {
	case "$os_fam" in
		suse) echo "git curl unzip rustup gcc make jq" ;;
		debian|ubuntu) echo "git curl unzip rustup build-essential jq" ;;
		*) echo "git curl unzip rustup base-devel jq" ;;
	esac
}
java_package() {  # MAJOR ARCH_PACKAGE
	case "$os_fam" in
		suse) echo "java-$1-openjdk-devel" ;;
		debian|ubuntu) echo "openjdk-$1-jdk" ;;
		*) echo "$2" ;;
	esac
}
pm_has() {  # PACKAGE: installed?
	case "$os_fam" in
		suse) rpm -q --whatprovides "$1" >/dev/null 2>&1 ;;
		debian|ubuntu) [[ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null)" == ii* ]] ;;
		*) pacman -Qq "$1" >/dev/null 2>&1 ;;
	esac
}
pm_install_line() {  # the command a plan shows
	case "$os_fam" in
		suse) echo "sudo zypper install $*" ;;
		debian|ubuntu) echo "sudo apt-get update && sudo apt-get install $*" ;;
		*) echo "sudo pacman -Syu --needed $*" ;;
	esac
}
pm_install() {  # PACKAGE...: installs them (pacman also upgrades the system, as it always did)
	case "$os_fam" in
		suse) sudo zypper "${zy_flags[@]}" install "$@" ;;
		debian|ubuntu) sudo apt-get update && sudo apt-get install "${apt_flags[@]}" "$@" ;;
		*) sudo pacman -Syu "${pm_flags[@]}" --needed "$@" ;;
	esac
}
read -r -a packages <<<"$(base_packages)"   # the Java package is added from box.json
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || true)"

# ---- box.json: the single place that names tool versions (needs jq, so --install installs jq first) ----
MANIFEST="${BXRIG_MANIFEST:-$root/box.json}"
manifest_error=""
# A MatchBox built from a branch (or given as BXRIG_MATCHBOX_FILE) lives here, with build.info; mvm manages the others.
MATCHBOX_HOME="${BXRIG_HOME:-$HOME/.local/share/bxrig}/matchbox"
load_manifest() {
	manifest_error=""
	command -v jq >/dev/null 2>&1 || { manifest_error="jq is required to read box.json"; return 1; }
	[[ -f "$MANIFEST" ]] || { manifest_error="box.json not found at $MANIFEST (run this script from a BxRig checkout)"; return 1; }
	jq -e . "$MANIFEST" >/dev/null 2>&1 || { manifest_error="box.json is not valid JSON: $MANIFEST"; return 1; }
	local key
	for key in .toolchain.java.version .toolchain.java.package .toolchain.boxlang.version .toolchain.bvm.installer \
						 .toolchain.mvm.installer .toolchain.rust.channel; do
		jq -e "$key" "$MANIFEST" >/dev/null 2>&1 || { manifest_error="box.json is missing ${key#.}"; return 1; }
	done
	JAVA_MAJOR="$(jq -r .toolchain.java.version "$MANIFEST")"
	JAVA_PKG="$(jq -r .toolchain.java.package "$MANIFEST")"
	# The MatchBox repository and branch for --matchbox-branch (and its alias --matchbox-from-source): box.json toolchain.matchbox
	MATCHBOX_REPO="$(jq -r '.toolchain.matchbox.repo // empty' "$MANIFEST")"; MATCHBOX_REPO="${MATCHBOX_REPO:-https://github.com/ortus-boxlang/matchbox}"
	MATCHBOX_REF="$(jq -r '.toolchain.matchbox.ref // empty' "$MANIFEST")"; MATCHBOX_REF="${MATCHBOX_REF:-bxrig}"
	MB_BRANCH="${MB_BRANCH_REQ:-$MATCHBOX_REF}"
	MB_REPO_URL="$MATCHBOX_REPO"; [[ -z "$MB_REPO_REQ" ]] || MB_REPO_URL="https://github.com/$MB_REPO_REQ"
	BVM_URL="$(jq -r .toolchain.bvm.installer "$MANIFEST")"
	MVM_URL="$(jq -r .toolchain.mvm.installer "$MANIFEST")"
	RUST_CHANNEL="$(jq -r .toolchain.rust.channel "$MANIFEST")"
	BOXLANG_VERSION="${BXRIG_BOXLANG_VERSION:-$(jq -r .toolchain.boxlang.version "$MANIFEST")}"
	JAVA_PKG="$(java_package "$JAVA_MAJOR" "$JAVA_PKG")"
	read -r -a packages <<<"$JAVA_PKG $(base_packages)"
}
if load_manifest; then manifest_ok=1; else manifest_ok=0; fi
need_manifest() {  # for modes that cannot work without it
	(( manifest_ok )) && return 0
	echo "$manifest_error" >&2
	[[ "$manifest_error" == jq* ]] && echo "Run install.sh packages --yes first: it installs jq, then reads box.json." >&2
	exit 1
}

# ---- Read-only inspection (used by --check and --plan; never changes the system) ----
BIN_DIR="${BXRIG_BIN_DIR:-$HOME/.local/bin}"
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
MVM_HOME="${MVM_HOME:-$HOME/.mvm}"
probe_path="$BVM_HOME/bin:$BVM_HOME/current/bin:$MVM_HOME/bin:$HOME/.cargo/bin:$BIN_DIR:$PATH"
probe_path="$MATCHBOX_HOME/bin:$probe_path"   # a MatchBox built here wins over the one mvm manages

tool_path() { PATH="$probe_path" command -v "$1" 2>/dev/null; }
first_version() { grep -m1 -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' || true; }
tool_version() {  # NAME [ARG]: first x.y[.z] printed by the tool, empty if unknown
	local bin; bin="$(tool_path "$1")" || return 0
	PATH="$probe_path" "$bin" "${2:---version}" 2>&1 | first_version || true
}
is_interactive() { [[ "${BXRIG_INTERACTIVE:-0}" == 1 || ( -t 0 && -t 1 ) ]]; }
# Refuse early, with a reason, when the machine cannot be provisioned. Needs inspect() to have run.
preflight_common() {  # [NEED_GB]: free space needed, default one stage
	local need_gb="${1:-$MIN_FREE_GB}"
	[[ "$os_ok" == 1 ]] || { echo "Unsupported OS: $os_name ${os_version} (BxRig supports CachyOS, Arch Linux, openSUSE Tumbleweed and Slowroll, Ubuntu 26.04 LTS and Debian 13)" >&2; exit 1; }
	[[ "$cpu" == x86_64 ]] || { echo "Unsupported CPU: $cpu (x86_64 only)" >&2; exit 1; }
	(( free_gb >= need_gb )) || { echo "Not enough free disk space: ${free_gb} GB free in $HOME, need at least $need_gb GB" >&2; exit 1; }
}
step_run() { local what="$1"; shift; "$@" || { echo "Failed: $what" >&2; exit 1; }; }
# Like step_run, but tries up to three times (0s, 10s, 30s apart): GitHub answers 403 to anonymous API calls
# when a shared address is rate limited, and that is usually brief. The command's own output is shown (and kept to pick the hint):
# the rate-limit hint only for real 403/429 output; anything else is most often a proxy or a TLS-inspecting firewall.
step_retry() {
	local what="$1" wait log last=""; shift
	log="$(mktemp)"
	for wait in ${BXRIG_RETRY_WAITS:-0 10 30}; do
		(( wait )) && { echo "Retrying in ${wait}s: $what" >&2; sleep "$wait"; }
		set +e; "$@" 2>&1 | tee "$log"; local rc="${PIPESTATUS[0]}"; set -e
		(( rc )) || { rm -f "$log"; return 0; }
		last="$(cat "$log")"
	done
	rm -f "$log"
	echo "Failed after 3 attempts: $what" >&2
	if grep -qiE '(^|[^0-9])(403|429)([^0-9]|$)|rate.?limit' <<<"$last"; then
		echo "GitHub reports a rate limit (HTTP 403/429): wait a while and rerun." >&2
	else
		echo "Could not reach GitHub. Behind a corporate proxy or a TLS-inspecting firewall? mvm may not trust its certificate. You can use the branch build instead: install.sh toolchains --yes --matchbox-branch bxrig" >&2
	fi
	exit 1
}
# ---- MatchBox ----
# stable (default): `mvm install latest` + `mvm use latest`. --snapshot: `mvm install snapshot` + `mvm use snapshot` (mvm skips an unchanged
# build). --matchbox-branch REF: a shallow clone of the branch built here with `cargo build --release --features bif-tui` and installed under
# $MATCHBOX_HOME/bin (build.info records repo, branch, commit); that directory is first on the installer's PATH, so the branch build is the one
# the binary stage uses and it never replaces the `matchbox` that mvm manages. BXRIG_MATCHBOX_FILE=PATH installs a local build there instead.
mb_marker() { sed -n "s/^$1=//p" "$MATCHBOX_HOME/build.info" 2>/dev/null | head -n 1 || true; }   # repo, branch, commit, source of the installed build
mb_local_build() { [[ -x "$MATCHBOX_HOME/bin/matchbox" ]]; }
# Can MatchBox $1 compile BxRig? BxRig draws its terminal UI with the canvas classes that only a build with the bif-tui feature registers
# (`createObject( "rust", "tui.TUI" )`). The probe runs a three line script that creates one and draws a frame; a MatchBox without the
# feature stops with "Native class 'tui.TUI' not found" and exits 1. Stable and snapshot builds do not have it yet (the bxrig branch is ahead of develop).
mb_builds_bxrig() {
	local mb="$1" dir out rc=0
	dir="$(mktemp -d)" || return 1
	printf '%s\n' 'tui = createObject( "rust", "tui.TUI" );' 'tui.begin_frame();' 'tui.render_to_string( 2, 1 );' 'println( "bxrig-tui-ok" );' > "$dir/probe.bxs"
	if command -v timeout >/dev/null 2>&1; then out="$(cd "$dir" && timeout 60 "$mb" probe.bxs </dev/null 2>/dev/null)" || rc=1
	else out="$(cd "$dir" && "$mb" probe.bxs </dev/null 2>/dev/null)" || rc=1; fi
	rm -rf "$dir"
	(( rc == 0 )) && [[ "$out" == *bxrig-tui-ok* ]]
}
# The other half of the capability check: does MatchBox compile each class file once? The bxrig branch's "Compile and store each class
# once" fix (commit e7812e6) is not on develop, so mvm's snapshot has bif-tui but still explodes on BxRig's ~200 classes:
# minutes, >50 GB and a 1.2 GB binary instead of ~20 MB. Two cross-referencing class files make a fixed compiler report
# "Circular class reference" quickly; the unfixed one recurses until it overflows the stack. Copy of scripts/lib/matchbox-ref.sh:
# this script ships alone in the install bundle and cannot source that file.
mb_shares_class_files() {
	local mb="$1" dir out rc=0
	[[ "$mb" == /* ]] || mb="$(cd "$(dirname "$mb")" && pwd)/$(basename "$mb")"
	dir="$(mktemp -d)" || return 1
	mkdir -p "$dir/probe" || { rm -rf "$dir"; return 1; }
	printf '%s\n' 'class A {' '  function makeB() { return new probe.B(); }' '}' > "$dir/probe/A.bx"
	printf '%s\n' 'class B {' '  function makeA() { return new probe.A(); }' '}' > "$dir/probe/B.bx"
	printf '%s\n' 'a = new probe.A();' 'println( "ok" );' > "$dir/main.bxs"
	if command -v timeout >/dev/null 2>&1; then
		out="$(cd "$dir" && ulimit -c 0 && ulimit -v 2097152 && timeout 20 "$mb" --build --output probe.bxb main.bxs </dev/null 2>&1)" || rc=1
	else
		out="$(cd "$dir" && ulimit -c 0 && ulimit -v 2097152 && "$mb" --build --output probe.bxb main.bxs </dev/null 2>&1)" || rc=1
	fi
	rm -rf "$dir"
	(( rc != 0 )) && [[ "$out" == *"Circular class reference"* ]]
}
mb_can_compile_bxrig() { mb_builds_bxrig "$1" && mb_shares_class_files "$1"; }
mb_cannot_compile_message() {  # the active MatchBox version
	echo "This MatchBox (${1:-unknown version}) cannot compile BxRig: it needs bif-tui and the class-file sharing fix (MatchBox commit e7812e6, on the bxrig branch)." >&2
	echo "  Use the branch build: install.sh toolchains --yes --matchbox-branch $MATCHBOX_REF, then run this again (or pass --binary PATH with a bxrig you built)." >&2
}
# The commit REF points at in REPO, 40 characters, empty when it cannot be read (no network, a commit id instead of a branch or tag).
mb_remote_head() {
	[[ "${BXRIG_SKIP_NETWORK:-0}" != 1 ]] && command -v git >/dev/null 2>&1 || return 0
	GIT_TERMINAL_PROMPT=0 git ls-remote "$MB_REPO_URL" "refs/heads/$MB_BRANCH" "refs/tags/$MB_BRANCH" 2>/dev/null | awk '{print $1; exit}' | grep -E '^[0-9a-f]{40}$' || true
}
# Whether the toolchains stage has to (re)install MatchBox. Stable: only when none is installed (re-running does not move it; use mvm update).
# Snapshot: always asked of mvm, which skips an unchanged build. Branch: no build here, another repo or branch, or the branch head moved.
mb_need() {
	if [[ -n "${BXRIG_MATCHBOX_FILE:-}" ]]; then mb_local_build && cmp -s "$BXRIG_MATCHBOX_FILE" "$MATCHBOX_HOME/bin/matchbox" && return 1; return 0; fi
	case "$MB_CHANNEL" in
		stable) tool_path matchbox >/dev/null && return 1; return 0 ;;
		snapshot) return 0 ;;
		branch)
			mb_local_build || return 0
			[[ "$(mb_marker repo)" == "$MB_REPO_URL" && "$(mb_marker branch)" == "$MB_BRANCH" ]] || return 0
			local head; head="$(mb_remote_head)"
			[[ -n "$head" && "$head" == "$(mb_marker commit)" ]] || return 0
			return 1 ;;
	esac
}
# Clone BRANCH shallow and build it into DEST (a file); the full commit goes to MB_BUILT_COMMIT.
MB_BUILT_COMMIT=""
matchbox_build_source() {
	local dest="$1" work="$2"
	command -v git >/dev/null 2>&1 || { echo "git is required to build MatchBox from source" >&2; exit 1; }
	PATH="$probe_path" command -v cargo >/dev/null 2>&1 || { echo "cargo is required to build MatchBox from source (run install.sh packages --yes first: it sets up Rust)" >&2; exit 1; }
	echo "Building MatchBox from source: branch $MB_BRANCH of $MB_REPO_URL (cargo build --release --features bif-tui)"
	step_run "clone $MB_REPO_URL branch $MB_BRANCH" env GIT_TERMINAL_PROMPT=0 git clone --quiet --depth 1 --branch "$MB_BRANCH" "$MB_REPO_URL" "$work/mbsrc"
	MB_BUILT_COMMIT="$(git -C "$work/mbsrc" rev-parse HEAD)"
	( cd "$work/mbsrc" && PATH="$probe_path" cargo build --release --features bif-tui ) || { echo "The MatchBox build failed; nothing was installed" >&2; exit 1; }
	[[ -x "$work/mbsrc/target/release/matchbox" ]] || { echo "The MatchBox build produced no executable; nothing was installed" >&2; exit 1; }
	cp "$work/mbsrc/target/release/matchbox" "$dest"
}
# A MatchBox of our own (built from a branch, or BXRIG_MATCHBOX_FILE), run once before it replaces anything, installed atomically.
install_matchbox_local() {
	local tmp source commit="" file_src="${BXRIG_MATCHBOX_FILE:-}"
	tmp="$(mktemp -d)"
	if [[ -n "$file_src" ]]; then
		[[ -f "$file_src" && -x "$file_src" && ! -L "$file_src" ]] || { echo "BXRIG_MATCHBOX_FILE must be an executable regular file: $file_src" >&2; rm -rf "$tmp"; exit 1; }
		cp "$file_src" "$tmp/matchbox"; source=file
	else
		matchbox_build_source "$tmp/matchbox" "$tmp"; source=branch; commit="$MB_BUILT_COMMIT"
	fi
	chmod 755 "$tmp/matchbox"
	"$tmp/matchbox" --version >/dev/null 2>&1 || { echo "The MatchBox build does not run; nothing was installed" >&2; rm -rf "$tmp"; exit 1; }
	mkdir -p "$MATCHBOX_HOME/bin"
	mv -f "$tmp/matchbox" "$MATCHBOX_HOME/bin/.matchbox.new" && mv -f "$MATCHBOX_HOME/bin/.matchbox.new" "$MATCHBOX_HOME/bin/matchbox"
	printf 'repo=%s\nbranch=%s\ncommit=%s\nsource=%s\n' "$MB_REPO_URL" "$MB_BRANCH" "$commit" "$source" > "$MATCHBOX_HOME/build.info"
	rm -rf "$tmp"
}
# mvm installs stable or snapshot; the local build of an earlier branch install must not shadow it.
install_matchbox_mvm() {
	local what="$1"
	step_retry "mvm install $what" mvm install "$what"; step_run "mvm use $what" mvm use "$what"
	if mb_local_build; then
		rm -f "$MATCHBOX_HOME/bin/matchbox" "$MATCHBOX_HOME/build.info"
		echo "Removed the MatchBox built from a branch earlier ($MATCHBOX_HOME): the $what MatchBox from mvm is the one in use now."
	fi
	tool_path matchbox >/dev/null || { echo "mvm installed MatchBox ($what) but no matchbox was found on the PATH ($MVM_HOME/bin)" >&2; exit 1; }
}
# BoxLang's active version, read from BVM's `current` symlink. Running `boxlang --version` starts the whole
# runtime, which rewrites its logs under ~/.boxlang on every call, so routine probes avoid it. Falls back to
# running boxlang only when BVM is not managing it. Install steps still run the real binary to verify.
bl_version() {
	local t
	if [[ -L "$BVM_HOME/current" ]] && t="$(basename "$(readlink "$BVM_HOME/current")")" && [[ "$t" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		printf '%s\n' "$t"
	else
		tool_version boxlang
	fi
}
# What "want" means for BoxLang: the pinned version, or the newest stable (empty when it cannot be looked up).
boxlang_want() {
	if [[ "$BOXLANG_VERSION" != latest ]]; then printf '%s\n' "$BOXLANG_VERSION"; return 0; fi
	command -v curl >/dev/null 2>&1 || return 0
	curl -fsS -m 8 "$BOXLANG_LATEST_URL" 2>/dev/null | sed -n 's/^version=\([0-9][0-9.]*\).*/\1/p' | head -n 1 || true
}

inspect() {
	missing_pkgs=()
	for pkg in "${packages[@]}"; do pm_has "$pkg" || missing_pkgs+=("$pkg"); done
	case "$os_fam" in
		arch) os_ok=1 ;;
		suse) [[ "$os_name" == *tumbleweed* || "$os_name" == *slowroll* ]] && os_ok=1 || os_ok=0 ;;
		debian) [[ "$os_version" == 13 ]] && os_ok=1 || os_ok=0 ;;
		ubuntu) [[ "$os_version" == 26.04 ]] && os_ok=1 || os_ok=0 ;;
		*) os_ok=0 ;;
	esac
	cpu="$(uname -m)"
	if [[ "$(id -u)" == 0 ]]; then is_root=1; else is_root=0; fi
	have_sudo=0; command -v sudo >/dev/null 2>&1 && have_sudo=1
	free_gb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2{printf "%d", $4/1048576}')"; free_gb="${free_gb:-0}"
	if [[ "${BXRIG_SKIP_NETWORK:-0}" == 1 ]]; then net="skipped"
	elif curl -fsSI -m 6 -o /dev/null https://downloads.ortussolutions.com/ >/dev/null 2>&1; then net="ok"; else net="unreachable"; fi
	java_ver=""; if jb="$(tool_path java)"; then java_ver="$(PATH="$probe_path" "$jb" -version 2>&1 | grep -m1 -oE 'version "[0-9][0-9.]*' | grep -oE '[0-9][0-9.]*' || true)"; fi
  java_major="${java_ver%%.*}"
  # yay (the AUR helper) is for Arch and CachyOS only: elsewhere it is never needed
  have_yay=0; tool_path yay >/dev/null && have_yay=1; [[ "$os_fam" == arch ]] || have_yay=1
  mvm_ver="$(tool_version mvm)"; have_mvm=0; tool_path mvm >/dev/null && have_mvm=1
  mb_ver="$(tool_version matchbox)"; mb_cc=no
  if mb_path="$(tool_path matchbox)" && mb_can_compile_bxrig "$mb_path"; then mb_cc=yes; fi
  have_bvm=0; tool_path bvm >/dev/null && have_bvm=1; bvm_ver="$(tool_version bvm)"
  bl_ver="$(bl_version)"; bl_want="$(boxlang_want)"
  rust_ver="$(tool_version rustc)"; have_rustup=0; tool_path rustup >/dev/null && have_rustup=1
  have_bxrig=0; tool_path bxrig >/dev/null && have_bxrig=1; bx_ver="$(tool_version bxrig version)"
  case ":$PATH:" in *":$BIN_DIR:"*) bin_on_path=1 ;; *) bin_on_path=0 ;; esac
}

# Ordered list of steps still needed, derived from inspect(). One line per step.
build_steps() {
  steps=()
  if (( ${#missing_pkgs[@]} )); then
    if [[ "$os_fam" == arch ]]; then steps+=("packages|sudo pacman -Syu --needed ${missing_pkgs[*]}|installs missing packages and also upgrades the system")
    else steps+=("packages|$(pm_install_line "${missing_pkgs[@]}")|installs missing packages"); fi
  fi
  if (( ! have_yay )); then
    steps+=("yay|sudo pacman -S --needed yay|AUR helper, found in the cachyos repository; only runs if yay is absent (part of the packages stage)")
  fi
  if (( ! have_mvm )); then
    steps+=("mvm|download and run $MVM_URL|external script, shown and run")
  fi
  if mb_need; then
    if [[ -n "${BXRIG_MATCHBOX_FILE:-}" ]]; then
      steps+=("matchbox|copy BXRIG_MATCHBOX_FILE=$BXRIG_MATCHBOX_FILE to $MATCHBOX_HOME/bin/matchbox|a MatchBox you built yourself")
    else
      case "$MB_CHANNEL" in
        stable) steps+=("matchbox|mvm install latest && mvm use latest|the stable MatchBox from mvm (not enough to compile BxRig; the prebuilt bxrig does not need it)") ;;
        snapshot) steps+=("matchbox|mvm install snapshot && mvm use snapshot|the snapshot MatchBox from mvm (mvm skips a build that has not changed; not enough to compile BxRig)") ;;
        branch) steps+=("matchbox|git clone --depth 1 --branch $MB_BRANCH $MB_REPO_URL, then cargo build --release --features bif-tui|MatchBox built from the $MB_BRANCH branch, installed under $MATCHBOX_HOME (it can compile BxRig)") ;;
      esac
    fi
  fi
  if (( ! have_bvm )); then
    steps+=("bvm|download and run $BVM_URL|external script, shown and run; it may add BVM to your shell startup files")
  fi
  if [[ -z "$bl_ver" ]]; then
    steps+=("boxlang|bvm install $BOXLANG_VERSION && bvm use $BOXLANG_VERSION|BoxLang runtime ($([[ $BOXLANG_VERSION == latest ]] && echo "latest stable${bl_want:+, $bl_want}" || echo "pinned"))")
  elif [[ -n "$bl_want" && "$bl_ver" != "$bl_want" ]]; then
    steps+=("boxlang|bvm install $BOXLANG_VERSION && bvm use $BOXLANG_VERSION|update BoxLang $bl_ver to $bl_want")
  fi
  if (( ! have_rustup )) || [[ -z "$rust_ver" ]]; then
    steps+=("rust|rustup default $RUST_CHANNEL|activates Rust and Cargo for your user (part of the packages stage)")
  fi
  if (( ! have_bxrig )); then
    steps+=("binary|install.sh binary --yes|builds src/Main.bx with MatchBox (or use --binary PATH), verifies it, installs to $BIN_DIR/bxrig, no sudo")
  fi
  if (( have_bxrig && ! bin_on_path )); then
    steps+=("path|add $BIN_DIR to PATH yourself|BxRig does not edit shell startup files; the commands are printed by the packages stage")
  fi
}

report_check() {
  echo "== system =="
  printf 'os: %s (%s)\n' "$os_name" "$([[ $os_ok == 1 ]] && echo supported || echo unsupported)"
  printf 'cpu: %s (%s)\n' "$cpu" "$([[ $cpu == x86_64 ]] && echo supported || echo unsupported)"
  printf 'user: %s\n' "$([[ $is_root == 1 ]] && echo 'root (run as a normal user)' || echo normal)"
  printf 'sudo: %s\n' "$([[ $have_sudo == 1 ]] && echo available || echo missing)"
  printf 'disk-free: %s GB (%s)\n' "$free_gb" "$([[ $free_gb -ge $FULL_FREE_GB ]] && echo "ok, the whole install needs $FULL_FREE_GB" || echo "need $FULL_FREE_GB for the whole install")"
  printf 'network: %s\n' "$net"
  echo "== packages =="
  for pkg in "${packages[@]}"; do
    if [[ " ${missing_pkgs[*]-} " == *" $pkg "* ]]; then printf 'missing: %s\n' "$pkg"; else printf 'installed: %s\n' "$pkg"; fi
  done
  printf '%s: yay\n' "$([[ $have_yay == 1 ]] && echo installed || echo missing)"
  echo "== tools =="
  printf 'java: %s (want %s)\n' "${java_ver:-missing}" "$JAVA_MAJOR"
  printf 'mvm: %s\n' "$([[ $have_mvm == 1 ]] && echo "${mvm_ver:-installed}" || echo missing)"
  if [[ -z "$mb_ver" ]]; then echo 'matchbox: missing'
  else printf 'matchbox: %s (compiles BxRig: %s)\n' "$mb_ver" "$mb_cc"; fi
  printf 'bvm: %s\n' "$([[ $have_bvm == 1 ]] && echo "${bvm_ver:-installed}" || echo missing)"
  if [[ "$BOXLANG_VERSION" != latest ]]; then bl_desc="$BOXLANG_VERSION (pinned)"
  elif [[ -n "$bl_want" ]]; then bl_desc="latest = $bl_want"
  else bl_desc="latest, version lookup unavailable"; fi
  printf 'boxlang: %s (want %s)\n' "${bl_ver:-missing}" "$bl_desc"
  printf 'rust: %s\n' "${rust_ver:-no default toolchain}"
  printf 'bxrig: %s\n' "$([[ $have_bxrig == 1 ]] && echo "${bx_ver:-installed}" || echo missing)"
  echo "== path =="
  printf 'bin-dir: %s (%s)\n' "$BIN_DIR" "$([[ $bin_on_path == 1 ]] && echo on-PATH || echo not-on-PATH)"
  if (( ${#steps[@]} )); then printf 'summary: %d step(s) needed, run install.sh --dry-run\n' "${#steps[@]}"; else echo "summary: ready"; fi
}

# One line about the MatchBox the plan would install.
report_matchbox() {
  case "$MB_CHANNEL" in
    stable) echo "MatchBox: stable, installed with mvm (not enough to compile BxRig; pass --matchbox-branch $MATCHBOX_REF to compile it here)" ;;
    snapshot) echo "MatchBox: snapshot, installed with mvm (has bif-tui but not the class-sharing fix; pass --matchbox-branch $MATCHBOX_REF to compile it here)" ;;
    branch) printf 'MatchBox: branch %s of %s, built here with cargo (cargo build --release --features bif-tui)\n' "$MB_BRANCH" "$MB_REPO_URL" ;;
  esac
}
report_plan() {
	echo "Read-only plan. Nothing below has been run."
	if (( ${#steps[@]} == 0 )); then echo "Nothing to do: everything is installed at the pinned versions."; return; fi
	local i=0 line name cmd why
	for line in "${steps[@]}"; do
		i=$((i+1)); IFS='|' read -r name cmd why <<<"$line"
		printf '%d. %s\n   run: %s\n   why: %s\n' "$i" "$name" "$cmd" "$why"
	done
	echo "Re-run one stage with: install.sh packages|toolchains|binary|core --yes"
}

if [[ "$mode" == --check || "$mode" == full ]] && (( ! manifest_ok )); then
	if [[ "$manifest_error" == jq* ]]; then
		if [[ "$mode" == --check ]]; then
			printf '== manifest ==\nbox.json: cannot be read (%s)\nsummary: 1 step(s) needed, run install.sh --dry-run\n' "$manifest_error"
		else
			printf 'Read-only plan. Nothing below has been run.\n1. jq\n   run: sudo pacman -S --needed jq\n   why: %s; the other steps depend on versions listed in box.json\nThen run install.sh again for the full list. (install.sh --install --yes installs jq first.)\n' "$manifest_error"
		fi
		exit 0
	fi
	echo "$manifest_error" >&2; exit 1
fi
if [[ "$mode" == --check ]]; then
	inspect; build_steps; report_check; exit 0
fi
if [[ "$mode" == full ]]; then
	# The whole install: show the plan, ask once (a terminal) or need --yes, then run every stage in order.
	# BXRIG_ALL_SCRIPT replaces the script the stages are delegated to (tests only).
	[[ "$(id -u)" != 0 ]] || { echo "Run as a regular user; sudo is used only for pacman steps" >&2; exit 1; }
	inspect; build_steps
	report_matchbox
	if (( free_gb >= FULL_FREE_GB )); then disk_ok=1; else disk_ok=0; fi
	printf 'Disk: need %s GB for the whole install, %s GB free in %s (%s)\n' "$FULL_FREE_GB" "$free_gb" "$HOME" "$([[ $disk_ok == 1 ]] && echo ok || echo "not enough")"
	report_plan
	if (( ! dry && ! disk_ok && ${#steps[@]} )); then
		echo "Not enough free disk space: ${free_gb} GB free in $HOME, need $FULL_FREE_GB GB for the whole install. Nothing was changed." >&2; exit 1
	fi
	echo "Last: bxrig profile-install core --yes installs the core apps with pacman (a re-run installs nothing that is already there)."
	if (( dry )); then echo "Dry run: nothing was changed."; exit 0; fi
	if (( ! yes )); then
		if is_interactive; then
			printf 'Proceed? [Y/n] '; read -r answer || answer=n
			case "${answer:-Y}" in [Yy]*|"") ;; *) echo "Cancelled. Nothing was changed." >&2; exit 2 ;; esac
		else
			echo "Not running unattended without --yes. Nothing was changed." >&2; exit 2
		fi
	fi
	all_self="${BXRIG_ALL_SCRIPT:-${BASH_SOURCE[0]}}"
	mb_args=()
	case "$MB_CHANNEL" in
		snapshot) mb_args+=(--snapshot) ;;
		branch) mb_args+=(--matchbox-branch "$MB_BRANCH"); [[ -z "$MB_REPO_REQ" ]] || mb_args+=(--matchbox-repo "$MB_REPO_REQ") ;;
	esac
	echo "== 1/4 packages, yay and Rust =="; bash "$all_self" packages --yes || exit $?
	echo "== 2/4 Java 21 check, mvm, MatchBox, bvm and BoxLang =="; bash "$all_self" toolchains --yes ${mb_args[@]+"${mb_args[@]}"} || exit $?
	echo "== 3/4 the bxrig binary =="; bash "$all_self" binary --yes || exit $?
	echo "== 4/4 the core apps =="; bash "$all_self" core --yes || exit $?
	if is_interactive; then
		echo "Tools installed."
		echo "== the setup wizard =="; bash "$all_self" wizard || exit $?
	else
		echo "Tools installed. Run \`bxrig init\` for the desktop and apps."
	fi
	exit 0
fi

if [[ "$mode" == --wizard ]]; then
	wiz_bin="$BIN_DIR/bxrig"
	[[ -x "$wiz_bin" ]] || { echo "bxrig is not installed at $wiz_bin (run install.sh binary --yes first)" >&2; exit 1; }
	exec "$wiz_bin" init
fi
if [[ "$mode" == --core ]]; then
	# The core profile through the installed binary (it names the apps, installs them with pacman, and re-runs safely).
	[[ "$(id -u)" != 0 ]] || { echo "Run as a regular user; sudo is used only for pacman steps" >&2; exit 1; }
	core_bin="$BIN_DIR/bxrig"
	[[ -x "$core_bin" ]] || { echo "bxrig is not installed at $core_bin (run install.sh binary --yes first)" >&2; exit 1; }
	exec "$core_bin" profile-install core --yes
fi

if [[ "$mode" == --install-toolchains ]]; then
	# Re-runnable: only the steps still needed are performed. Runs as the normal user.
	need_manifest
	command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
	[[ "$(id -u)" != 0 ]] || { echo "Toolchains must be installed as a regular user" >&2; exit 1; }
	inspect
	preflight_common
	[[ "$java_major" == "$JAVA_MAJOR" ]] || { echo "Java $JAVA_MAJOR is required (found: ${java_ver:-none})" >&2; exit 1; }
	export PATH="$probe_path"
	cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/bxrig/external"

	# Download an external installer, show what it is (url, saved copy, sha256), and run it as the normal user.
	# There is no confirmation gate: installing the toolchain is what the command is for (owner decision 2026-11-10).
	run_external() {  # NAME URL [VAR=VALUE ...]  (extra assignments are passed to the script)
		local name="$1" url="$2" file hash lines; shift 2
		mkdir -p "$cache_dir"; chmod 700 "$cache_dir"
		file="$(mktemp "$cache_dir/$name.XXXXXX.sh")"
		if ! curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$file"; then echo "Download failed: $url" >&2; rm -f "$file"; exit 1; fi
		[[ -s "$file" ]] || { echo "Empty download: $url" >&2; rm -f "$file"; exit 1; }
		chmod 600 "$file"
		hash="$(sha256sum "$file" | cut -d' ' -f1)"; lines="$(wc -l < "$file")"
		printf 'External script: %s\n  url:    %s\n  saved:  %s (%s lines)\n  sha256: %s\n' "$name" "$url" "$file" "$lines" "$hash"
		if ! env "$@" bash "$file"; then echo "$name installer failed (script kept at $file)" >&2; exit 1; fi
	}

	done_any=0
	if (( ! have_mvm )); then
		run_external mvm "$MVM_URL" ${BXRIG_MVM_VERSION:+MVM_VERSION="$BXRIG_MVM_VERSION"}; done_any=1
		tool_path mvm >/dev/null || { echo "MVM installation failed: mvm not found afterwards" >&2; exit 1; }
	fi
	if mb_need; then
		if [[ -n "${BXRIG_MATCHBOX_FILE:-}" || "$MB_CHANNEL" == branch ]]; then install_matchbox_local; else install_matchbox_mvm "$([[ $MB_CHANNEL == snapshot ]] && echo snapshot || echo latest)"; fi
		done_any=1
		mb_now="$(tool_version matchbox)"
		[[ -n "$mb_now" ]] || { echo "MatchBox is not active after install" >&2; exit 1; }
		mb_kind="$MB_CHANNEL"; [[ -z "${BXRIG_MATCHBOX_FILE:-}" ]] || mb_kind=file
		case "$mb_kind" in
			file) echo "MatchBox $mb_now (the local build $BXRIG_MATCHBOX_FILE) installed and verified: $MATCHBOX_HOME/bin/matchbox" ;;
			branch) echo "MatchBox $mb_now (branch $MB_BRANCH of $MB_REPO_URL) installed and verified: $MATCHBOX_HOME/bin/matchbox"
				echo "Note: BxRig's installer finds it by absolute path; add $MATCHBOX_HOME/bin to your PATH if you want it to be your matchbox." ;;
			*) echo "MatchBox $mb_now ($MB_CHANNEL) installed and verified." ;;
		esac
		if mb_path="$(tool_path matchbox)" && mb_can_compile_bxrig "$mb_path"; then echo "This MatchBox can compile BxRig."
		else echo "Note: this MatchBox cannot compile BxRig well enough (it needs bif-tui and the class-file sharing fix). That is fine for the prebuilt bxrig; to compile it here use --matchbox-branch $MATCHBOX_REF."; fi
	fi
	if (( ! have_bvm )); then
		run_external bvm "$BVM_URL"; done_any=1
		tool_path bvm >/dev/null || { echo "BVM installation failed: bvm not found afterwards" >&2; exit 1; }
		echo "Note: the BVM installer may add BVM to your shell startup files; open a new shell to pick that up."
	fi
	bl_now="$(bl_version)"; bl_target="$(boxlang_want)"
	if [[ -z "$bl_now" || ( -n "$bl_target" && "$bl_now" != "$bl_target" ) ]]; then
		step_run "bvm install $BOXLANG_VERSION" bvm install "$BOXLANG_VERSION"; step_run "bvm use $BOXLANG_VERSION" bvm use "$BOXLANG_VERSION"; done_any=1
		bl_real="$(tool_version boxlang)"   # the one place the runtime is started: proof that it works
		[[ -n "$bl_real" ]] || { echo "BoxLang does not run after install" >&2; exit 1; }
		[[ -z "$bl_target" || "$bl_real" == "$bl_target" ]] || { echo "BoxLang $bl_target not active after install (found: $bl_real)" >&2; exit 1; }
		echo "BoxLang $bl_real installed and verified."
	elif [[ -z "$bl_target" ]]; then
		echo "BoxLang $bl_now is installed; could not look up the latest version, so it was left as is."
	fi
	if (( ! done_any )); then echo "Nothing to do: MVM, MatchBox ${mb_now:-$(tool_version matchbox)}, BVM, BoxLang ${bl_now:-?} are already installed."; fi
	echo "Rust and the bxrig binary are handled by later steps."
	exit 0
fi

if [[ "$mode" == --install-binary ]]; then
	# Build (or accept) the bxrig binary, verify it BEFORE touching the installed copy, then replace atomically.
	[[ "$(id -u)" != 0 ]] || { echo "Run as a regular user; no sudo is needed" >&2; exit 1; }
	need_manifest
	work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
	# The theme wallpapers travel in this bundle (not in the binary): copied for bxrig to pick up (it checks each one's SHA-256).
	copy_wallpapers() {
		local src="$root/assets/wallpapers" dest="${XDG_DATA_HOME:-$HOME/.local/share}/bxrig/wallpapers"
		compgen -G "$src/*.jpg" >/dev/null || return 0
		mkdir -p "$dest" || return 1
		# only the missing or changed ones, so running the installer again leaves the folder untouched
		local f
		for f in "$src"/*.jpg; do cmp -s "$f" "$dest/${f##*/}" || cp -f "$f" "$dest/" || return 1; done
		echo "Theme wallpapers ready in $dest"
	}
	installed="$BIN_DIR/bxrig"
	check_binary() {  # PATH -> prints its version line; fails unless it identifies itself as BxRig
		local out; out="$("$1" version </dev/null 2>&1 | head -n 1)" || true
		[[ "$out" == BxRig\ * ]] || { echo "Not a working bxrig binary: $1 (version printed: ${out:-nothing})" >&2; return 1; }
		printf '%s\n' "$out"
	}
	if [[ -n "$binary_arg" ]]; then
		[[ -f "$binary_arg" && -x "$binary_arg" && ! -L "$binary_arg" ]] || { echo "--binary must be an executable regular file (not a symlink): $binary_arg" >&2; exit 1; }
		candidate="$binary_arg"
		new_version="$(check_binary "$candidate")" || exit 1
		if [[ -f "$installed" ]] && cmp -s "$candidate" "$installed" && (( ! force )); then echo "Nothing to do: $installed is identical ($new_version)."; copy_wallpapers; exit 0; fi
	else
		src="$root/src/Main.bx"
		[[ -n "$root" && -f "$src" ]] || { echo "Source not found ($src). Run this script from a BxRig checkout, or pass --binary PATH." >&2; exit 1; }
		# the version is generated from box.json into src/bxrig/util/Version.bx; bxrig prints it as "BxRig VERSION"
		want="$(sed -n 's/.*return "\([^"]*\)".*/BxRig \1/p' "$root/src/bxrig/util/Version.bx" 2>/dev/null | head -n 1 || true)"
    if (( ! force )) && [[ -x "$installed" && -n "$want" ]] && [[ "$(check_binary "$installed" 2>/dev/null || true)" == "$want" ]]; then
      echo "Nothing to do: $installed is already $want (use --force to rebuild)."; copy_wallpapers; exit 0
    fi
    mb_have="$(tool_version matchbox)"
    [[ -n "$mb_have" ]] || { echo "MatchBox is required to compile BxRig (found: none). Run install.sh toolchains --yes --matchbox-branch $MATCHBOX_REF first." >&2; exit 1; }
    mb_can_compile_bxrig "$(tool_path matchbox)" || { mb_cannot_compile_message "$mb_have"; exit 1; }
    cp -rL "$root/src" "$work/src"; chmod -R u+rwX,go+rX "$work/src"   # -L: src/resources links to the data folders
    echo "Building bxrig with MatchBox $mb_have (native compile; a few seconds with a capable MatchBox)"
    # the BoxLang modules bxrig embeds (box.json toolchain.modules); --module must come before the program
    mods=()
    if [[ -x "$root/scripts/get-modules.sh" && "${BXRIG_SKIP_NETWORK:-0}" != 1 ]]; then   # offline: built without them
      modlist="$(PATH="$probe_path" "$root/scripts/get-modules.sh" "$work/modules" 2>>"$work/build.log")" || { echo "Could not get the BoxLang modules bxrig embeds:" >&2; tail -n 5 "$work/build.log" >&2; exit 1; }
      while IFS= read -r m; do [[ -n "$m" ]] && mods+=( --module "$m" ); done <<<"$modlist"
    fi
    if ! ( cd "$work" && PATH="$probe_path" matchbox "${mods[@]}" --target native --output "$work/bxrig" src/Main.bx ) >> "$work/build.log" 2>&1; then
      echo "Build failed; the installed copy was not touched. Last lines of the build log:" >&2; tail -n 20 "$work/build.log" >&2; exit 1
    fi
    candidate="$work/bxrig"
    [[ -f "$candidate" && -x "$candidate" ]] || { echo "Build produced no executable; the installed copy was not touched" >&2; tail -n 20 "$work/build.log" >&2; exit 1; }
    new_version="$(check_binary "$candidate")" || { echo "The built binary failed its self-check; the installed copy was not touched" >&2; exit 1; }
  fi
  mkdir -p "$BIN_DIR"
  tmpdest="$(mktemp "$BIN_DIR/.bxrig.XXXXXX")"
  cp "$candidate" "$tmpdest"; chmod 755 "$tmpdest"; mv -f "$tmpdest" "$installed"
  final="$(check_binary "$installed")" || exit 1
  echo "Installed $installed ($final)"
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "Note: $BIN_DIR is not on your PATH (see the packages stage for the line to add)." ;; esac
  copy_wallpapers
  exit 0
fi

# ---- --install --yes: packages, yay (only if absent), Rust. Runs as the normal user; sudo only for pacman. ----
[[ "$(id -u)" != 0 ]] || { echo "Run as a regular user; sudo is used only for pacman steps" >&2; exit 1; }
# At a terminal pacman shows its own transaction prompt (a full upgrade deserves a second look);
# unattended there is nobody to answer it, and --yes already approved the plan.
pm_flags=(); is_interactive || pm_flags=(--noconfirm)
zy_flags=(); is_interactive || zy_flags=(--non-interactive)
apt_flags=(); is_interactive || apt_flags=(-y)
# box.json needs jq to be read, so jq comes first.
if (( ! manifest_ok )) && ! command -v jq >/dev/null 2>&1; then
  command -v sudo >/dev/null 2>&1 || { echo "sudo is required to install packages but was not found" >&2; exit 1; }
  echo "Installing jq first (needed to read box.json)"
  if [[ "$os_fam" == arch ]]; then sudo pacman -S "${pm_flags[@]}" --needed jq || { echo "Could not install jq; nothing else was changed" >&2; exit 1; }
  else pm_install jq || { echo "Could not install jq; nothing else was changed" >&2; exit 1; }; fi
  if load_manifest; then manifest_ok=1; else manifest_ok=0; fi
fi
need_manifest
inspect
preflight_common
if (( ${#missing_pkgs[@]} )) || { [[ "$os_fam" == arch ]] && ! tool_path yay >/dev/null; }; then
  (( have_sudo )) || { echo "sudo is required to install packages but was not found" >&2; exit 1; }
fi
changed=0
if (( ${#missing_pkgs[@]} )); then
  if [[ "$os_fam" == arch ]]; then echo "Installing missing packages (this also upgrades the system): ${missing_pkgs[*]}"; else echo "Installing missing packages: ${missing_pkgs[*]}"; fi
  pm_install "${missing_pkgs[@]}" || { echo "$pm failed; nothing else was changed" >&2; exit 1; }
  changed=1
else
  echo "packages: all installed"
fi
if [[ "$os_fam" != arch ]]; then
  :  # no AUR off Arch
elif ! tool_path yay >/dev/null; then
  echo "Installing yay (AUR helper) from your configured repositories"
  if ! sudo pacman -S "${pm_flags[@]}" --needed yay; then
    echo "yay is not available in your configured repositories. On CachyOS it is in the cachyos repo; otherwise install it from the AUR by hand." >&2
    exit 1
  fi
  changed=1
else
  echo "yay: already installed"
fi
if tool_path rustup >/dev/null && [[ -z "$(tool_version rustc)" ]]; then
  echo "Activating the stable Rust toolchain for your user"
  rustup default "$RUST_CHANNEL" || { echo "rustup could not install the stable toolchain" >&2; exit 1; }
  [[ -n "$(tool_version rustc)" ]] || { echo "Rust is still not available after rustup default $RUST_CHANNEL" >&2; exit 1; }
  changed=1
else
  echo "rust: ${rust_ver:-rustup not available}"
fi
if (( ! changed )); then echo "Nothing to do for packages, yay and Rust."; fi
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "Note: $BIN_DIR is not on your PATH. BxRig does not edit shell startup files. Add it yourself:"
     echo "  bash/zsh: export PATH=\"$BIN_DIR:\$PATH\""
     echo "  fish:     fish_add_path $BIN_DIR" ;;
esac
echo "Next: install.sh toolchains --yes (or run install.sh with no word to do every stage)"
