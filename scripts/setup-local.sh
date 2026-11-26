#!/usr/bin/env bash
# Sets up a local BxRig development environment: picks a MatchBox, records it in .cache/dev.env
# (read by scripts/dev-build.sh and tests/run-all.sh), builds dist/bxrig and runs a smoke test.
#   scripts/setup-local.sh [--matchbox stable|snapshot|branch] [--matchbox-branch REF] [--matchbox-repo REPO] [--release] [--no-build]
#                          [--no-setup] [--no-wizard] [--defaults]
#     stable    the released MatchBox, installed with mvm (`mvm install latest`, `mvm use latest`)
#     snapshot  the snapshot MatchBox from mvm (`mvm install snapshot`, `mvm use snapshot`)
#     branch    a branch of a MatchBox repository, shallow clone in .cache/matchbox-src/<repo>-<ref> built with cargo
#               (default: ortus-boxlang/matchbox, branch bxrig; debug build, --release for an optimized one)
#   --matchbox-branch REF   the branch, tag or commit (full 40 character id); implies --matchbox branch
#   --matchbox-repo REPO    a fork: https://host/owner/name or owner/name on GitHub (default: box.json toolchain.matchbox.repo)
#   --release               build the branch MatchBox in release mode
#   BXRIG_MATCHBOX_BRANCH and BXRIG_MATCHBOX_REPO set the two options (the flags win).
# Without --matchbox it asks (1 stable, 2 snapshot, 3 branch); with no terminal it builds the branch bxrig and says so.
# BxRig is always built with the MatchBox chosen. It needs both the terminal UI (bif-tui) and the class-file sharing fix (MatchBox
# commit e7812e6, on the bxrig branch but not on develop/snapshots). The script probes both and stops with the reason before saving
# anything or building; it never switches to another MatchBox by itself.
# After a successful build it provisions this machine with the same stages as bootstrap/install.sh (packages, toolchains, the
# fresh dist/bxrig, core apps), then starts the setup wizard at a terminal. --defaults runs the wizard with its defaults when
# there is no terminal. --no-setup only builds; --no-wizard skips just the wizard.
# .cache/dev.env records the MatchBox path, repo, ref and commit. Switch: scripts/setup-local.sh --matchbox branch --matchbox-branch bxrig
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
. "$root/scripts/lib/matchbox-ref.sh"
envfile="$root/.cache/dev.env"
choice=""; build=1; release=0; setup=1; wizard=1; wizard_defaults=0
branch="${BXRIG_MATCHBOX_BRANCH:-}"; branch_set=0; [[ -z "$branch" ]] || branch_set=1
repo_in="${BXRIG_MATCHBOX_REPO:-}"; repo_set=0; [[ -z "$repo_in" ]] || repo_set=1
branch_from="BXRIG_MATCHBOX_BRANCH"; repo_from="BXRIG_MATCHBOX_REPO"
die() { echo "$1" >&2; exit "${2:-2}"; }
while (( $# )); do
	case "$1" in
		--matchbox) [[ $# -ge 2 ]] || die "--matchbox needs a value"; choice="$2"; shift 2 ;;
		--matchbox=*) choice="${1#*=}"; shift ;;
		--matchbox-branch) [[ $# -ge 2 ]] || die "--matchbox-branch needs a value"; branch="$2"; branch_set=1; branch_from="--matchbox-branch"; shift 2 ;;
		--matchbox-branch=*) branch="${1#*=}"; branch_set=1; branch_from="--matchbox-branch"; shift ;;
		--matchbox-repo) [[ $# -ge 2 ]] || die "--matchbox-repo needs a value"; repo_in="$2"; repo_set=1; repo_from="--matchbox-repo"; shift 2 ;;
		--matchbox-repo=*) repo_in="${1#*=}"; repo_set=1; repo_from="--matchbox-repo"; shift ;;
		--release) release=1; shift ;;
		--no-build) build=0; shift ;;
		--setup) setup=1; shift ;;
		--no-setup) setup=0; shift ;;
		--no-wizard) wizard=0; shift ;;
		--defaults) wizard_defaults=1; shift ;;
		-h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
		*) echo "unknown argument: $1" >&2; exit 2 ;;
	esac
done

need() { # tool...
	local missing=()
	for t in "$@"; do command -v "$t" >/dev/null || missing+=("$t"); done
	(( ${#missing[@]} == 0 )) || { echo "Missing tools: ${missing[*]}" >&2; exit 4; }
}
check_ref() { mb_valid_ref "$1" || { printf 'invalid MatchBox branch/ref (%s): %q\n  use letters, digits and . _ / @ + - only, no leading dash\n' "$2" "$1" >&2; exit 2; }; }
check_repo() { mb_valid_repo "$1" || { printf 'invalid MatchBox repo (%s): %q\n  use https://host/owner/name or owner/name\n' "$2" "$1" >&2; exit 2; }; }
(( ! branch_set )) || check_ref "$branch" "$branch_from"
(( ! repo_set )) || check_repo "$repo_in" "$repo_from"

# the default repo and branch for `--matchbox branch`: what box.json names
manifest_repo="$(jq -r '.toolchain.matchbox.repo // empty' "$root/box.json" 2>/dev/null || true)"
[[ -n "$manifest_repo" ]] || manifest_repo=https://github.com/ortus-boxlang/matchbox
manifest_ref="$(jq -r '.toolchain.matchbox.ref // empty' "$root/box.json" 2>/dev/null || true)"
[[ -n "$manifest_ref" ]] || manifest_ref=bxrig

case "$choice" in
	""|stable|snapshot|branch) ;;
	edge|source) die "--matchbox $choice was removed: use --matchbox branch (it builds the $manifest_ref branch of $manifest_repo; add --matchbox-branch REF or --matchbox-repo REPO for another). To use your own checkout, build it and run: MATCHBOX=/path/to/matchbox scripts/dev-build.sh" ;;
	*) die "unknown MatchBox choice: $choice (stable, snapshot or branch)" ;;
esac
if [[ "$choice" == stable || "$choice" == snapshot ]] && (( branch_set || repo_set )); then
	die "--matchbox $choice cannot be combined with --matchbox-branch or --matchbox-repo (a branch is built from source: --matchbox branch)"
fi
# a branch or repo given without --matchbox means the branch choice
if [[ -z "$choice" ]] && (( branch_set || repo_set )); then choice=branch; fi

if [[ -z "$choice" ]]; then
	if [[ -t 0 ]]; then
		echo "Which MatchBox should BxRig use?"
		echo "  1) stable    the released MatchBox from mvm (no bif-tui: cannot compile BxRig)"
		echo "  2) snapshot  the snapshot MatchBox from mvm (no class-sharing fix: compiles BxRig in minutes with >50 GB)"
		echo "  3) branch    build a branch of a MatchBox repository (default $manifest_ref of ortus-boxlang/matchbox; needs git and Rust)"
		while [[ -z "$choice" ]]; do
			read -rp "Choose 1, 2 or 3: " a || die "No answer; nothing was changed"
			case "$a" in 1|stable) choice=stable ;; 2|snapshot) choice=snapshot ;; 3|branch) choice=branch ;; esac
		done
		if [[ "$choice" == branch ]]; then
			if (( ! repo_set )); then
				while true; do
					read -rp "Repository (owner/name or https URL) [ortus-boxlang/matchbox]: " a || die "No answer; nothing was changed"
					[[ -n "$a" ]] || a="${manifest_repo#https://github.com/}"
					mb_valid_repo "$a" && break; echo "Not a valid repository: use https://host/owner/name or owner/name"
				done
				repo_in="$a"; repo_set=1
			fi
			if (( ! branch_set )); then
				while true; do
					read -rp "Branch, tag or full commit id [$manifest_ref]: " a || die "No answer; nothing was changed"
					[[ -n "$a" ]] || a="$manifest_ref"
					mb_valid_ref "$a" && break; echo "Not a valid ref: letters, digits and . _ / @ + - only, no leading dash"
				done
				branch="$a"; branch_set=1
			fi
		fi
	else
		choice=branch
		echo "No terminal to ask on: using the branch build (--matchbox branch, $manifest_ref of $manifest_repo). Pass --matchbox stable|snapshot|branch to choose."
	fi
fi

mkdir -p "$root/.cache"
s_repo=""; s_ref=""; s_commit=""
case "$choice" in
	stable|snapshot)
		need curl
		if ! command -v mvm >/dev/null; then
			installer="$(jq -r .toolchain.mvm.installer "$root/box.json" 2>/dev/null || true)"
			[[ -n "$installer" && "$installer" != null ]] || installer="https://raw.githubusercontent.com/ortus-boxlang/matchbox-quick-installer/main/install/install.sh"
			echo "mvm is not installed. Install it with:"
			echo "  curl -fsSL $installer | bash"
			echo "then open a new shell and run this script again."
			exit 4
		fi
		what=latest
		if [[ "$choice" == snapshot ]]; then what=snapshot; fi
		mvm install "$what"
		mvm use "$what"
		mb="${MVM_HOME:-$HOME/.mvm}/bin/matchbox"
		[[ -x "$mb" ]] || mb="$(command -v matchbox || true)"
		[[ -n "$mb" ]] || mb="$(find "${MVM_HOME:-$HOME/.mvm}" -type f -name matchbox -perm -u+x 2>/dev/null | head -n1)"
		[[ -n "$mb" ]] || { echo "mvm installed MatchBox but it is not on PATH; open a new shell and run this again" >&2; exit 4; }
		s_repo="mvm ($choice)"; s_ref="$what"
		s_commit="$("$mb" --version 2>&1 | sed -n 's/^commit: *//p' | head -n1 || true)"
		;;
	branch)
		need git cargo
		want_repo="$manifest_repo"; want_ref="$manifest_ref"
		(( ! repo_set )) || want_repo="$(mb_repo_url "$repo_in")"
		(( ! branch_set )) || want_ref="$branch"
		src="$root/.cache/matchbox-src/$(mb_repo_slug "$want_repo")-$(mb_ref_slug "$want_ref")"
		echo "Getting $want_repo $want_ref into $src"
		mb_git_checkout "$want_repo" "$want_ref" "$src" || { echo "Could not get $want_ref of $want_repo (is the repo and the branch, tag or full commit id right?)" >&2; exit 4; }
		s_repo="$want_repo"; s_ref="$want_ref"
		s_commit="$(git -C "$src" rev-parse --short HEAD)"
		if (( release )); then
			(cd "$src" && cargo build --release --features bif-tui)
			mb="$src/target/release/matchbox"
		else
			(cd "$src" && cargo build --features bif-tui)
			mb="$src/target/debug/matchbox"
		fi
		;;
esac

[[ -x "$mb" ]] || { echo "No MatchBox at $mb" >&2; exit 4; }
echo "MatchBox: $("$mb" --version 2>&1 | head -n1) ($mb)"
# BxRig is always built with this MatchBox: if it cannot compile it, stop here (nothing is recorded, nothing switches silently)
mb_require_bxrig_capable "$mb" || exit 1
printf '# written by scripts/setup-local.sh (%s)\nMATCHBOX=%q\nMATCHBOX_REPO=%q\nMATCHBOX_REF=%q\nMATCHBOX_COMMIT=%q\n' "$choice" "$mb" "$s_repo" "$s_ref" "$s_commit" > "$envfile"
echo "Saved in .cache/dev.env"

summary() {
	echo
	printf 'MatchBox in use: repo %s, ref %s, commit %s, path %s\n' "${s_repo:-unknown}" "${s_ref:-unknown}" "${s_commit:-unknown}" "$mb"
	echo "Switch:          scripts/setup-local.sh --matchbox stable|snapshot|branch   (for example: --matchbox branch --matchbox-branch bxrig)"
	printf 'Test the end-user installer with it:\n  BXRIG_MATCHBOX_FILE=%q bash bootstrap/install.sh toolchains --yes\n' "$mb"
}
# Provision this machine from the local checkout, with the exact binary and MatchBox just built. These are the same stages the
# web installer runs through bootstrap/install.sh; only the download/signature part is skipped (there is nothing to download).
setup_machine() {
	local inst="$root/bootstrap/install.sh" bin="$root/dist/bxrig" installed="${BXRIG_BIN_DIR:-$HOME/.local/bin}/bxrig"
	[[ -f "$inst" ]] || { echo "No installer at $inst" >&2; return 4; }
	[[ -x "$bin" ]] || { echo "No built binary at $bin" >&2; return 4; }
	stage() { # LABEL CMD...
		local label="$1"; shift
		echo
		echo "== $label =="
		"$@" || { printf 'Machine setup failed at %s. dist/bxrig is still ready; fix the problem and rerun this script.\n' "$label" >&2; return 1; }
	}
	stage "packages (bootstrap/install.sh packages)" bash "$inst" packages --yes || return $?
	# The branch, snapshot or stable MatchBox chosen above is installed the way the installer's summary suggests.
	stage "toolchains (with the MatchBox chosen above)" env BXRIG_MATCHBOX_FILE="$mb" bash "$inst" toolchains --yes || return $?
	stage "the bxrig binary from dist/bxrig" bash "$inst" binary --yes --force --binary "$bin" || return $?
	stage "the core apps" bash "$inst" core --yes || return $?
	if (( wizard )); then
		echo
		if (( wizard_defaults )); then
			stage "the setup wizard (defaults)" "$installed" init --defaults --yes || return $?
		elif [[ -t 0 && -t 1 ]]; then
			stage "the setup wizard" bash "$inst" wizard || return $?
		else
			echo "No terminal for the setup wizard. Run: bxrig init"
		fi
	fi
}

(( build )) || { summary; exit 0; }
echo
echo "Building dist/bxrig with $mb (usually about a second) ..."
MATCHBOX="$mb" "$root/scripts/dev-build.sh"
echo "Running smoke test ..."
"$root/dist/bxrig" version
if (cd "$root/src" && "$mb" ../tests/init_plan_test.bxs >/dev/null); then echo "smoke test passed"; else echo "Smoke test failed; this machine was not set up" >&2; exit 1; fi
if (( setup )); then
	setup_machine || exit $?
else
	echo
	echo "Machine setup skipped (--no-setup); dist/bxrig is ready."
fi
echo
echo "Ready. Next:"
echo "  scripts/dev-build.sh            rebuild dist/bxrig"
echo "  tests/run-all.sh                run every test"
echo "  tests/run-all.sh dist/bxrig X   run the tests whose name contains X"
summary
