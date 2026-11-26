#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Qq) [[ "$2" == git ]] ;;
  *) echo "unexpected pacman invocation" >&2; exit 9 ;;
esac
MOCK
cat > "$tmp/sudo" <<'MOCK'
#!/usr/bin/env bash
echo "unexpected sudo invocation" >&2
exit 9
MOCK
chmod +x "$tmp/pacman" "$tmp/sudo"
export PATH="$tmp:$PATH"
# The installer picks its package manager from os-release: these checks describe Arch (the runner itself may be Ubuntu).
printf 'ID=arch\n' > "$tmp/os-arch-release"; export BXRIG_OS_RELEASE="$tmp/os-arch-release"
bash "$root/bootstrap/install.sh" check | grep -F 'installed: git'
bash "$root/bootstrap/install.sh" check | grep -F 'missing: jdk21-openjdk'
if bash "$root/bootstrap/install.sh" packages >/dev/null 2>&1; then
	echo 'FAIL: unattended install without --yes' >&2; exit 1
fi
if bash "$root/bootstrap/install.sh" --unknown >/dev/null 2>&1; then
	echo 'FAIL: invalid bootstrap command accepted' >&2; exit 1
fi
if bash "$root/bootstrap/install.sh" toolchains >/dev/null 2>&1; then
	echo 'FAIL: toolchain installation without confirmation' >&2; exit 1
fi
echo 'bootstrap check tests passed'

# ---- B1/B2: read-only --check and --plan, with a fully isolated PATH and HOME ----
sys="$tmp/sys"; bin="$tmp/bin"; home="$tmp/home"
mkdir -p "$sys" "$bin" "$home/.local/bin"
for t in bash env grep awk df id uname head tr cat sort dirname mktemp sed cut mkdir chmod rm wc sha256sum basename ls cp mv find cmp tail stat readlink ln jq tee; do
	p="$(command -v "$t")" && ln -sf "$p" "$sys/$t"
done
# Fixture repository: a copy of the script next to a box.json with known pins. Tests run this copy.
repo="$tmp/repo"; mkdir -p "$repo/bootstrap" "$repo/src"
cp "$root/bootstrap/install.sh" "$repo/bootstrap/install.sh"; cp -rL "$root/src/." "$repo/src/"   # -L: src/resources links to the data folders
cat > "$repo/box.json" <<'JSON'
{ "name": "bxrig", "version": "0.11.0-dev",
  "toolchain": {
    "java": { "version": "21", "package": "jdk21-openjdk" },
    "boxlang": { "version": "latest" },
    "bvm": { "version": "latest", "installer": "https://install-bvm.boxlang.io" },
    "mvm": { "version": "latest", "installer": "https://raw.githubusercontent.com/ortus-boxlang/matchbox-quick-installer/main/install/install.sh" },
    "matchbox": { "version": "0.12.0" },
    "rust": { "channel": "stable" },
    "nvm": { "version": "v0.41.0", "installer": "https://raw.githubusercontent.com/nvm-sh/nvm/v0.41.0/install.sh", "node": "lts/*" } } }
JSON
REALJQ="$(command -v jq)"
mock() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$bin/$1"; chmod +x "$bin/$1"; }
reset_mocks() { rm -f "$bin"/*;
	mock pacman 'case "$1" in -Qq) [[ " ${MOCK_INSTALLED:-} " == *" $2 "* ]] ;; *) exit 9 ;; esac'
	mock sudo 'echo "sudo must not run in read-only modes" >&2; exit 9'
	mock id '[[ "$1" == -u ]] && echo "${MOCK_UID:-1000}" || /usr/bin/id "$@"'
}
run() { env -i HOME="$home" PATH="$bin:$sys" BXRIG_SKIP_NETWORK=1 BXRIG_OS_RELEASE="${OSREL:-$tmp/os-arch}" MOCK_INSTALLED="${MOCK_INSTALLED:-}" MOCK_UID="${MOCK_UID:-1000}" "$@"; }
printf 'ID=cachyos\nID_LIKE=arch\n' > "$tmp/os-arch"
printf 'ID=fedora\nID_LIKE="rhel centos"\n' > "$tmp/os-other"
need() { grep -Fq -- "$2" <<<"$1" || { echo "FAIL: expected '$2' in output:" >&2; echo "$1" >&2; exit 1; }; }
refuse() { if grep -Fq -- "$2" <<<"$1"; then echo "FAIL: unexpected '$2' in output:" >&2; echo "$1" >&2; exit 1; fi; }

# 1. Everything missing.
reset_mocks; MOCK_INSTALLED=""
out="$(run bash "$repo/bootstrap/install.sh" check)"
for s in 'os: cachyos (supported)' 'user: normal' 'sudo: available' 'network: skipped' 'missing: jdk21-openjdk' 'missing: base-devel' 'missing: yay' 'missing: jq' 'java: missing (want 21)' 'matchbox: missing' 'boxlang: missing (want latest, version lookup unavailable)' 'bxrig: missing' 'step(s) needed'; do need "$out" "$s"; done
plan="$(run bash "$repo/bootstrap/install.sh" --dry-run)"
for s in 'Nothing below has been run' '1. packages' 'sudo pacman -Syu --needed jdk21-openjdk git curl unzip rustup base-devel' 'upgrades the system' 'sudo pacman -S --needed yay' 'download and run https://install-bvm.boxlang.io' 'mvm install latest && mvm use latest' 'bvm install latest' 'rustup default stable' 'install.sh binary --yes' 'external script, shown and run'; do need "$plan" "$s"; done

# 2. Everything present at the pinned versions: nothing to do.
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock sudo 'exit 9'
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock mvm 'echo "MVM version: 2.0.1"'
mock matchbox 'echo "MatchBox 0.12.0"'
mock bvm 'echo "bvm 1.40.0"'
mock boxlang 'echo "Ortus BoxLang v1.19.0+67"'
mock rustc 'echo "rustc 1.90.0 (abc 2026-01-01)"'
mock rustup 'exit 0'
mock yay 'exit 0'
mock bxrig '[[ "$1" == version ]] && echo "BxRig 0.11.0-dev"'
cp "$bin/bxrig" "$home/.local/bin/bxrig"; rm "$bin/bxrig"
# nvm and Node.js present (a fake nvm.sh and node)
mkdir -p "$home/.nvm/bin"
printf '%s\n' 'nvm() { case "$1" in --version) echo 0.41.0 ;; esac; }' '[ -x "$NVM_DIR/bin/node" ] && export PATH="$NVM_DIR/bin:$PATH"' 'true' > "$home/.nvm/nvm.sh"
printf '#!/usr/bin/env bash\necho v22.11.0\n' > "$home/.nvm/bin/node"; chmod +x "$home/.nvm/bin/node"
out="$(run bash "$repo/bootstrap/install.sh" check)"
for s in 'installed: yay' 'java: 21.0.13' 'matchbox: 0.12.0' 'boxlang: 1.19.0' 'rust: 1.90.0' 'bxrig: 0.11.0' 'bin-dir: '; do need "$out" "$s"; done
need "$out" 'not-on-PATH'; need "$out" '1 step(s) needed'   # only the PATH step remains
plan="$(run bash "$repo/bootstrap/install.sh" --dry-run)"; need "$plan" 'add '; need "$plan" '/.local/bin to PATH'
out="$(env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXRIG_SKIP_NETWORK=1 BXRIG_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$repo/bootstrap/install.sh" check)"
need "$out" 'summary: ready'
plan="$(env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXRIG_SKIP_NETWORK=1 BXRIG_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$repo/bootstrap/install.sh" --dry-run)"
need "$plan" 'Nothing to do'

# 3. Wrong versions are planned for replacement, right ones are left alone.
mock boxlang 'echo "Ortus BoxLang v1.18.0+10"'; mock matchbox 'echo "MatchBox 0.11.0"'
mock curl 'printf "version=1.19.0+67\nbuildDate=x\n"'
plan="$(env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXRIG_SKIP_NETWORK=1 BXRIG_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$repo/bootstrap/install.sh" --dry-run)"
need "$plan" 'update BoxLang 1.18.0 to 1.19.0'; need "$plan" 'bvm install latest'; refuse "$plan" 'mvm install'; refuse "$plan" 'download and run'; refuse "$plan" 'sudo pacman'   # an installed MatchBox is left alone (any version)
plan="$(env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXRIG_SKIP_NETWORK=1 BXRIG_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$repo/bootstrap/install.sh" --dry-run --snapshot)"
need "$plan" 'mvm install snapshot && mvm use snapshot'; need "$plan" 'MatchBox: snapshot'

# 4. Root, unsupported OS, wrong arguments.
out="$(MOCK_UID=0 run bash "$repo/bootstrap/install.sh" check)"; need "$out" 'user: root (run as a normal user)'
out="$(OSREL="$tmp/os-other" run bash "$repo/bootstrap/install.sh" check)"; need "$out" 'os: fedora (unsupported)'
if run bash "$repo/bootstrap/install.sh" --dry-run extra >/dev/null 2>&1; then echo 'FAIL: --plan accepted an argument' >&2; exit 1; fi
if run bash "$repo/bootstrap/install.sh" check --yes >/dev/null 2>&1; then echo 'FAIL: --check accepted --yes' >&2; exit 1; fi
echo 'bootstrap check/plan tests passed'

# ---- B3: toolchain install, external installers run without a gate (all downloads are mocked) ----
MVM_FAKE='mkdir -p "$HOME/.mvm/bin"
cat > "$HOME/.mvm/bin/mvm" <<"M"
#!/usr/bin/env bash
case "$1" in
  install) echo "mvm $*" >> "$HOME/mvm.log" ;;
  use) echo "mvm $*" >> "$HOME/mvm.log"; v=0.13.2; [[ "$2" == snapshot ]] && v=0.14.1; printf "#!/usr/bin/env bash\necho \"MatchBox %s\"\n" "$v" > "$HOME/.mvm/bin/matchbox"; chmod +x "$HOME/.mvm/bin/matchbox" ;;
  --version) echo "MVM version: 2.0.1" ;;
esac
M
chmod +x "$HOME/.mvm/bin/mvm"
echo "MARK-MVM-RAN" >> "$HOME/ran.log"'
BVM_FAKE='mkdir -p "$HOME/.bvm/bin"
cat > "$HOME/.bvm/bin/bvm" <<"M"
#!/usr/bin/env bash
case "$1" in
  install) : ;;
  use) v="$2"; [[ "$v" == latest ]] && v="${MOCK_LATEST:-1.19.0}"; printf "#!/usr/bin/env bash\necho \"Ortus BoxLang v%s+1\"\n" "$v" > "$HOME/.bvm/bin/boxlang"; chmod +x "$HOME/.bvm/bin/boxlang" ;;
  --version) echo "bvm 1.40.0" ;;
esac
M
chmod +x "$HOME/.bvm/bin/bvm"
echo "MARK-BVM-RAN" >> "$HOME/ran.log"'
NVM_FAKE='mkdir -p "$HOME/.nvm"
cat > "$HOME/.nvm/nvm.sh" <<"M"
# fake nvm: a shell function plus node on the PATH once "nvm install" ran
nvm() {
  case "$1" in
    --version) echo "0.41.0" ;;
    install) mkdir -p "$NVM_DIR/bin"; printf "#!/usr/bin/env bash\necho v22.11.0\n" > "$NVM_DIR/bin/node"; chmod +x "$NVM_DIR/bin/node" ;;
    alias) : ;;
  esac
}
[ -x "$NVM_DIR/bin/node" ] && export PATH="$NVM_DIR/bin:$PATH"
true
M
echo "MARK-NVM-RAN" >> "$HOME/ran.log"'
export MVM_FAKE BVM_FAKE NVM_FAKE
fresh_home() { rm -rf "$home"; mkdir -p "$home/.local/bin"; : > "$tmp/curl.log"; }
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock sudo 'exit 9'
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
[[ -n "$out" ]] && echo "$url" >> "$CURL_LOG"
[[ "${MOCK_CURL_FAIL:-0}" == 1 ]] && exit 22
case "$url" in
  *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;;
  *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;; *nvm-sh/nvm*) printf "%s\n" "$NVM_FAKE" > "$out" ;;
  *version-latest.properties*) printf "version=%s+1\nbuildDate=x\n" "${MOCK_LATEST:-1.19.0}" ;;
  *) exit 22 ;;
esac'
trun() { env -i HOME="$home" MOCK_LATEST="${MOCK_LATEST:-1.19.0}" PATH="$bin:$sys" BXRIG_SKIP_NETWORK=1 BXRIG_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" CURL_LOG="$tmp/curl.log" MVM_FAKE="$MVM_FAKE" BVM_FAKE="$BVM_FAKE" NVM_FAKE="$NVM_FAKE" "$@"; }

# 1. Runs unattended; end state is at the pins; each script shows its url and sha256.
fresh_home
out="$(trun bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"
for x in 'External script: mvm' 'External script: bvm' 'sha256: ' 'MatchBox 0.13.2 (stable) installed and verified.' 'BoxLang 1.19.0 installed and verified.'; do need "$out" "$x"; done
need "$(cat "$home/mvm.log")" 'mvm install latest'; need "$(cat "$home/mvm.log")" 'mvm use latest'
chk="$(trun env PATH="$home/.local/bin:$bin:$sys" bash "$repo/bootstrap/install.sh" check)"; need "$chk" 'matchbox: 0.13.2'; need "$chk" 'boxlang: 1.19.0'
[[ "$(stat -c %a "$home/.cache/bxrig/external")" == 700 ]] || { echo 'FAIL: cache dir not private' >&2; exit 1; }

# 4. Second run: nothing to do, nothing downloaded.
: > "$tmp/curl.log"
out="$(trun bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"
need "$out" 'Nothing to do'; [[ ! -s "$tmp/curl.log" ]] || { echo 'FAIL: rerun downloaded something' >&2; exit 1; }

# 5. Partial state: MVM+MatchBox present, BVM missing -> only the BVM script is fetched.
rm -rf "$home/.bvm"; : > "$tmp/curl.log"
trun bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null >/dev/null 2>&1
[[ "$(wc -l < "$tmp/curl.log")" == 1 ]] && grep -q install-bvm "$tmp/curl.log" || { echo 'FAIL: partial recovery fetched the wrong scripts' >&2; cat "$tmp/curl.log" >&2; exit 1; }

# 6. Failures: download error, wrong Java, root, unknown flag.
fresh_home
if out="$(trun env MOCK_CURL_FAIL=1 bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: download failure ignored' >&2; exit 1; fi
need "$out" 'Download failed'
mock java 'echo "openjdk version \"17.0.9\" 2024-01-01" >&2'
if out="$(trun bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: wrong Java accepted' >&2; exit 1; fi; need "$out" 'Java 21 is required'
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
if out="$(trun env MOCK_UID=0 bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: root accepted' >&2; exit 1; fi; need "$out" 'regular user'
if trun bash "$repo/bootstrap/install.sh" toolchains --yes --bogus >/dev/null 2>&1; then echo 'FAIL: unknown flag accepted' >&2; exit 1; fi
echo 'bootstrap toolchain tests passed'

# ---- B4: --install installs missing packages, yay only if absent, and Rust; reruns change nothing ----
install_mocks() {
	reset_mocks; : > "$tmp/pacman.log"; : > "$tmp/state"
	mock pacman 'case "$1" in
  -Qq) grep -qx -- "$2" "$STATE" ;;
  -Syu) shift; echo "Syu $*" >> "$PLOG"; [[ "${MOCK_SYU_FAIL:-0}" == 1 ]] && exit 1; for p in "$@"; do [[ "$p" == --needed ]] || echo "$p" >> "$STATE"; done ;;
  -S) shift; echo "S $*" >> "$PLOG"; [[ " $* " == *" yay "* && "${MOCK_YAY_FAIL:-0}" == 1 ]] && exit 1
      [[ " $* " == *" yay "* ]] && { printf "#!/usr/bin/env bash\nexit 0\n" > "$BINDIR/yay"; chmod +x "$BINDIR/yay"; }
      [[ " $* " == *" jq "* ]] && { ln -sf "$REALJQ" "$SYSDIR/jq"; echo jq >> "$STATE"; }
      exit 0 ;;
  *) exit 9 ;;
esac'
	mock sudo '"$@"'
	mock rustup '[[ "${MOCK_RUSTUP_FAIL:-0}" == 1 ]] && exit 1; if [[ "$1 $2" == "default stable" ]]; then echo "rustup $*" >> "$PLOG"; printf "#!/usr/bin/env bash\necho \"rustc 1.90.0\"\n" > "$BINDIR/rustc"; chmod +x "$BINDIR/rustc"; fi'
	mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
}
irun() { env -i HOME="$home" PATH="$bin:$sys" BXRIG_SKIP_NETWORK=1 BXRIG_OS_RELEASE="$tmp/os-arch" STATE="$tmp/state" PLOG="$tmp/pacman.log" BINDIR="$bin" REALJQ="$REALJQ" SYSDIR="$sys" MOCK_UID="${MOCK_UID:-1000}" MOCK_YAY_FAIL="${MOCK_YAY_FAIL:-0}" MOCK_SYU_FAIL="${MOCK_SYU_FAIL:-0}" MOCK_RUSTUP_FAIL="${MOCK_RUSTUP_FAIL:-0}" "$@"; }

install_mocks; fresh_home
out="$(irun bash "$repo/bootstrap/install.sh" packages --yes 2>&1)"
log="$(cat "$tmp/pacman.log")"
need "$log" 'Syu --noconfirm --needed jdk21-openjdk git curl unzip rustup base-devel'; need "$log" 'S --noconfirm --needed yay'; need "$log" 'rustup default stable'
need "$out" 'does not edit shell startup files'; need "$out" 'Next: install.sh toolchains --yes'
before="$(wc -l < "$tmp/pacman.log")"
out="$(irun bash "$repo/bootstrap/install.sh" packages --yes 2>&1)"
need "$out" 'packages: all installed'; need "$out" 'yay: already installed'; need "$out" 'Nothing to do for packages, yay and Rust.'
[[ "$(wc -l < "$tmp/pacman.log")" == "$before" ]] || { echo 'FAIL: rerun changed the system again' >&2; cat "$tmp/pacman.log" >&2; exit 1; }

# Only the missing package is requested, and yay is skipped when present.
install_mocks; fresh_home; echo "git" >> "$tmp/state"; echo "curl" >> "$tmp/state"; mock yay 'exit 0'
irun bash "$repo/bootstrap/install.sh" packages --yes >/dev/null 2>&1
log="$(cat "$tmp/pacman.log")"; need "$log" 'Syu --noconfirm --needed jdk21-openjdk unzip rustup base-devel'; refuse "$log" 'S --noconfirm --needed yay'

# At a terminal pacman is left to ask itself: no --noconfirm.
install_mocks; fresh_home
irun env BXRIG_INTERACTIVE=1 bash "$repo/bootstrap/install.sh" packages --yes >/dev/null 2>&1
log="$(cat "$tmp/pacman.log")"; need "$log" 'Syu --needed jdk21-openjdk'; refuse "$log" '--noconfirm'

# Failure paths: yay unavailable, root.
install_mocks; fresh_home
if out="$(MOCK_YAY_FAIL=1 irun bash "$repo/bootstrap/install.sh" packages --yes 2>&1)"; then echo 'FAIL: missing yay ignored' >&2; exit 1; fi; need "$out" 'yay is not available'
install_mocks; fresh_home
if out="$(MOCK_UID=0 irun bash "$repo/bootstrap/install.sh" packages --yes 2>&1)"; then echo 'FAIL: --install ran as root' >&2; exit 1; fi; need "$out" 'regular user'
[[ ! -s "$tmp/pacman.log" ]] || { echo 'FAIL: root run touched the system' >&2; exit 1; }
echo 'bootstrap install tests passed'

# ---- B5: binary builds (or accepts) bxrig, verifies it first, installs atomically ----
SRCVER="BxRig $(sed -n 's/.*return "\([^"]*\)".*/\1/p' "$root/src/bxrig/util/Version.bx")"   # the version lives in Version.bx (from box.json)
fake_bin() { printf '#!/usr/bin/env bash\n[[ "$1" == version ]] && echo "%s" || echo "other"\n' "$1"; }
b_mocks() {
  reset_mocks; fresh_home
  mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
  mock matchbox 'if [[ "$1" == --version ]]; then echo "MatchBox ${MOCK_MB:-0.12.0}"; exit 0; fi
if [[ "$1" == *probe.bxs ]]; then [[ "${MOCK_TUI:-1}" == 1 ]] && echo bxrig-tui-ok || { echo "Native class tui.TUI not found" >&2; exit 1; }; exit 0; fi
if [[ "$1" == --build ]]; then [[ "${MOCK_SHARE:-1}" == 1 ]] && { echo "Error: Compiler Error: Circular class reference: A -> B -> A" >&2; exit 1; } || { echo "thread 'main' has overflowed its stack" >&2; exit 134; }; fi
[[ "${MOCK_BUILD_FAIL:-0}" == 1 ]] && { echo "boom: compile error" >&2; exit 1; }
echo "$*" >> "$BLOG"
out=bxrig; while [[ $# -gt 0 ]]; do [[ "$1" == --output ]] && { out="$2"; break; }; shift; done
cp "$FAKE" "$out"; chmod 755 "$out"'
  : > "$tmp/build.log"; fake_bin "$SRCVER" > "$tmp/fake_built"
}
brun() { env -i HOME="$home" PATH="$bin:$sys" BXRIG_SKIP_NETWORK=1 BXRIG_OS_RELEASE="$tmp/os-arch" BLOG="$tmp/build.log" FAKE="$tmp/fake_built" MOCK_UID="${MOCK_UID:-1000}" MOCK_MB="${MOCK_MB:-0.12.0}" MOCK_TUI="${MOCK_TUI:-1}" MOCK_SHARE="${MOCK_SHARE:-1}" MOCK_BUILD_FAIL="${MOCK_BUILD_FAIL:-0}" "$@"; }
dest="$home/.local/bin/bxrig"

# 1. Build from source and install.
b_mocks
out="$(brun bash "$repo/bootstrap/install.sh" binary --yes 2>&1)" || { echo "FAIL: binary --yes: $out" >&2; exit 1; }
need "$out" 'Building bxrig with MatchBox 0.12.0'; need "$out" "Installed $dest ($SRCVER)"
[[ -x "$dest" ]] && [[ "$("$dest" version)" == "$SRCVER" ]] || { echo 'FAIL: binary not installed or not working' >&2; exit 1; }
need "$(cat "$tmp/build.log")" '--target native --output'; need "$(cat "$tmp/build.log")" 'src/Main.bx'
# 2. Same version again: nothing built, nothing replaced. --force rebuilds.
: > "$tmp/build.log"; stamp="$(stat -c %Y-%i "$dest")"
out="$(brun bash "$repo/bootstrap/install.sh" binary --yes 2>&1)"; need "$out" 'Nothing to do'
[[ ! -s "$tmp/build.log" && "$(stat -c %Y-%i "$dest")" == "$stamp" ]] || { echo 'FAIL: rerun rebuilt or replaced the binary' >&2; exit 1; }
brun bash "$repo/bootstrap/install.sh" binary --yes --force >/dev/null 2>&1; [[ -s "$tmp/build.log" ]] || { echo 'FAIL: --force did not rebuild' >&2; exit 1; }
# 3. A failed build or a bad result never touches the installed copy.
fake_bin "BxRig 0.0.1-old" > "$dest"; chmod 755 "$dest"; old="$(cat "$dest")"
if out="$(MOCK_BUILD_FAIL=1 brun bash "$repo/bootstrap/install.sh" binary --yes --force 2>&1)"; then echo 'FAIL: build failure ignored' >&2; exit 1; fi
need "$out" 'installed copy was not touched'; need "$out" 'compile error'; [[ "$(cat "$dest")" == "$old" ]] || { echo 'FAIL: failed build changed the install' >&2; exit 1; }
fake_bin "oops not it" > "$tmp/fake_built"
if out="$(brun bash "$repo/bootstrap/install.sh" binary --yes --force 2>&1)"; then echo 'FAIL: bad binary accepted' >&2; exit 1; fi
need "$out" 'self-check'; [[ "$(cat "$dest")" == "$old" ]] || { echo 'FAIL: bad binary replaced the install' >&2; exit 1; }
fake_bin "$SRCVER" > "$tmp/fake_built"
# 4. Prerequisites: a MatchBox that cannot compile bxrig (stable, snapshot: no terminal UI), none at all, root. The version does not matter.
out="$(MOCK_MB=0.11.0 brun bash "$repo/bootstrap/install.sh" binary --yes --force 2>&1)" || { echo "FAIL: any MatchBox version that can compile bxrig must do: $out" >&2; exit 1; }
if out="$(MOCK_TUI=0 brun bash "$repo/bootstrap/install.sh" binary --yes --force 2>&1)"; then echo 'FAIL: a MatchBox without the terminal UI compiled bxrig' >&2; exit 1; fi
need "$out" 'This MatchBox (0.12.0) cannot compile BxRig'; need "$out" '--matchbox-branch bxrig'
# bif-tui is not enough: without class sharing the compiler eats tens of GB on BxRig's classes, so refuse it before building
if out="$(MOCK_SHARE=0 brun bash "$repo/bootstrap/install.sh" binary --yes --force 2>&1)"; then echo 'FAIL: a MatchBox without class sharing compiled bxrig' >&2; exit 1; fi
need "$out" 'class-file sharing fix'; need "$out" '--matchbox-branch bxrig'
[[ "$(cat "$dest")" != "" ]] || { echo 'FAIL: the installed copy is gone' >&2; exit 1; }
mv "$bin/matchbox" "$bin/matchbox.off"; if out="$(brun bash "$repo/bootstrap/install.sh" binary --yes --force 2>&1)"; then echo 'FAIL: no MatchBox accepted' >&2; exit 1; fi; need "$out" 'MatchBox is required to compile BxRig'; mv "$bin/matchbox.off" "$bin/matchbox"
if out="$(MOCK_UID=0 brun bash "$repo/bootstrap/install.sh" binary --yes 2>&1)"; then echo 'FAIL: root accepted' >&2; exit 1; fi; need "$out" 'regular user'
# 5. --binary: installs a given file after verifying it; rejects symlinks, non-executables and impostors.
b_mocks; good="$tmp/good"; fake_bin "BxRig 9.9.9" > "$good"; chmod 755 "$good"
out="$(brun bash "$repo/bootstrap/install.sh" binary --yes --binary "$good" 2>&1)"; need "$out" 'Installed'; [[ "$("$dest" version)" == "BxRig 9.9.9" ]] || { echo 'FAIL: --binary not installed' >&2; exit 1; }
need "$(brun bash "$repo/bootstrap/install.sh" binary --yes --binary "$good" 2>&1)" 'identical'
# The version check must not inherit interactive input (which makes bxrig print its banner first).
cat > "$tmp/interactive-bin" <<'BIN'
#!/usr/bin/env bash
if [[ -t 0 ]] || read -r line; then echo "banner"; fi
echo "BxRig 9.9.10"
BIN
chmod 755 "$tmp/interactive-bin"
out="$(brun bash "$repo/bootstrap/install.sh" binary --yes --binary "$tmp/interactive-bin" <<< 'interactive input' 2>&1)" || { echo "FAIL: binary version check inherited stdin: $out" >&2; exit 1; }
need "$out" "Installed $dest (BxRig 9.9.10)"
ln -sf "$good" "$tmp/link"; printf 'x' > "$tmp/plain"; fake_bin "BxRig" | sed 's/BxRig/Other/' > "$tmp/imp"; chmod 755 "$tmp/imp"
for bad in "$tmp/link" "$tmp/plain" "$tmp/imp" "$tmp/missing"; do
	if brun bash "$repo/bootstrap/install.sh" binary --yes --binary "$bad" >/dev/null 2>&1; then echo "FAIL: --binary accepted $bad" >&2; exit 1; fi
done
[[ "$("$dest" version </dev/null)" == "BxRig 9.9.10" ]] || { echo 'FAIL: rejected --binary changed the install' >&2; exit 1; }
# 6. Arguments.
if brun bash "$repo/bootstrap/install.sh" binary >/dev/null 2>&1; then echo 'FAIL: binary without --yes' >&2; exit 1; fi
if brun bash "$repo/bootstrap/install.sh" binary --yes --bogus >/dev/null 2>&1; then echo 'FAIL: unknown flag' >&2; exit 1; fi
if brun bash "$repo/bootstrap/install.sh" binary --yes --binary >/dev/null 2>&1; then echo 'FAIL: --binary without a path' >&2; exit 1; fi
echo 'bootstrap binary tests passed'

# ---- B6: failure paths. Every one must say why, and leave the system as it was ----
# Network unreachable is reported, not fatal, for the read-only report.
reset_mocks; mock curl 'exit 22'
out="$(env -i HOME="$home" PATH="$bin:$sys" BXRIG_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="" bash "$repo/bootstrap/install.sh" check 2>&1)"; need "$out" 'network: unreachable'

# Unsupported OS and too little disk stop every installing mode before anything runs.
install_mocks; fresh_home; mock curl 'exit 22'
for m in "packages --yes" "toolchains --yes"; do
	if out="$(OSREL="$tmp/os-other" env -i HOME="$home" PATH="$bin:$sys" BXRIG_SKIP_NETWORK=1 BXRIG_OS_RELEASE="$tmp/os-other" STATE="$tmp/state" PLOG="$tmp/pacman.log" BINDIR="$bin" bash "$repo/bootstrap/install.sh" $m 2>&1 </dev/null)"; then echo "FAIL: '$m' ran on an unsupported OS" >&2; exit 1; fi
	need "$out" 'Unsupported OS: fedora'
done
[[ ! -s "$tmp/pacman.log" ]] || { echo 'FAIL: unsupported OS touched the system' >&2; exit 1; }
mock df 'printf "Filesystem 1024-blocks Used Available Capacity Mounted\nx 100 50 1024 5%% /\n"'
if out="$(irun bash "$repo/bootstrap/install.sh" packages --yes 2>&1)"; then echo 'FAIL: low disk accepted' >&2; exit 1; fi; need "$out" 'Not enough free disk space'
[[ ! -s "$tmp/pacman.log" ]] || { echo 'FAIL: low disk touched the system' >&2; exit 1; }
# A single stage with 5 GB free still passes its own check (the 8 GB need is for the whole install only).
mock df 'printf "Filesystem 1024-blocks Used Available Capacity Mounted\nx 100 50 5242880 5%% /\n"'
install_mocks; fresh_home
out="$(irun bash "$repo/bootstrap/install.sh" packages --yes 2>&1)" || { echo "FAIL: a single stage with 5 GB free was refused: $out" >&2; exit 1; }
rm -f "$bin/df"

# sudo missing, pacman failing, rustup failing.
install_mocks; fresh_home; rm -f "$bin/sudo"
if out="$(irun bash "$repo/bootstrap/install.sh" packages --yes 2>&1)"; then echo 'FAIL: missing sudo ignored' >&2; exit 1; fi; need "$out" 'sudo is required'
install_mocks; fresh_home
if out="$(MOCK_SYU_FAIL=1 irun bash "$repo/bootstrap/install.sh" packages --yes 2>&1)"; then echo 'FAIL: pacman failure ignored' >&2; exit 1; fi
need "$out" 'pacman failed; nothing else was changed'; refuse "$(cat "$tmp/pacman.log")" 'S --noconfirm --needed yay'
install_mocks; fresh_home; echo jdk21-openjdk >> "$tmp/state"; for q in git curl unzip rustup base-devel jq; do echo $q >> "$tmp/state"; done; mock yay 'exit 0'
if out="$(MOCK_RUSTUP_FAIL=1 irun bash "$repo/bootstrap/install.sh" packages --yes 2>&1)"; then echo 'FAIL: rustup failure ignored' >&2; exit 1; fi; need "$out" 'rustup could not install'

# Interrupted toolchain install: the MVM installer dies midway; a later run resumes and finishes.
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock sudo 'exit 9'; mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
[[ -n "$out" ]] && echo "$url" >> "$CURL_LOG"
case "$url" in *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;; *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;; *nvm-sh/nvm*) printf "%s\n" "$NVM_FAKE" > "$out" ;; *version-latest.properties*) printf "version=%s+1\nbuildDate=x\n" "${MOCK_LATEST:-1.19.0}" ;; *) exit 22 ;; esac'
fresh_home
GOOD_MVM="$MVM_FAKE"
if out="$(MVM_FAKE='echo half-done; exit 1' trun bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: dying installer treated as success' >&2; exit 1; fi
need "$out" 'mvm installer failed (script kept at'
[[ ! -e "$home/.bvm" ]] || { echo 'FAIL: later steps ran after a failed one' >&2; exit 1; }
out="$(MVM_FAKE="$GOOD_MVM" trun bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"
need "$out" 'BoxLang 1.19.0 installed and verified.'
# A failing "bvm install" is named, not silent.
fresh_home; rm -rf "$home/.bvm"; : > "$tmp/curl.log"
BAD_BVM="${BVM_FAKE/install) : ;;/install) exit 1 ;;}"
if out="$(BVM_FAKE="$BAD_BVM" trun bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: bvm install failure ignored' >&2; exit 1; fi
need "$out" 'Failed: bvm install latest'
echo 'bootstrap failure-path tests passed'

# ---- Routine probes must not start the BoxLang runtime (it rewrites its own logs on every start) ----
reset_mocks; fresh_home; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock boxlang 'echo ran >> "$HOME/boxlang-ran"; echo "Ortus BoxLang v9.9.9+1"'
mkdir -p "$home/.bvm/versions/1.19.0"; ln -s "$home/.bvm/versions/1.19.0" "$home/.bvm/current"; ln -sf "$bin/boxlang" "$home/.bvm/bin-boxlang" 2>/dev/null || true
out="$(run bash "$repo/bootstrap/install.sh" check)"; need "$out" 'boxlang: 1.19.0 (want latest, version lookup unavailable)'
run bash "$repo/bootstrap/install.sh" --dry-run >/dev/null
[[ ! -e "$home/boxlang-ran" ]] || { echo 'FAIL: a read-only probe started the BoxLang runtime' >&2; exit 1; }
# Without BVM's symlink, it falls back to asking boxlang itself.
rm "$home/.bvm/current"; out="$(run bash "$repo/bootstrap/install.sh" check)"; need "$out" 'boxlang: 9.9.9'
echo 'bootstrap probe tests passed'

# ---- BoxLang follows the latest stable release; MatchBox stays pinned ----
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock sudo 'exit 9'; mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
[[ -n "$out" ]] && echo "$url" >> "$CURL_LOG"
case "$url" in *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;; *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;; *nvm-sh/nvm*) printf "%s\n" "$NVM_FAKE" > "$out" ;; *version-latest.properties*) printf "version=%s+1\nbuildDate=x\n" "${MOCK_LATEST:-1.19.0}" ;; *) exit 22 ;; esac'
fresh_home
out="$(trun bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; need "$out" 'BoxLang 1.19.0 installed and verified.'
chk="$(trun env PATH="$home/.local/bin:$bin:$sys" bash "$repo/bootstrap/install.sh" check)"; need "$chk" 'boxlang: 1.19.0 (want latest = 1.19.0)'
# Upstream ships a newer BoxLang: the next run updates it with `bvm`, downloads no installer script.
: > "$tmp/curl.log"
chk="$(MOCK_LATEST=1.20.0 trun env PATH="$home/.local/bin:$bin:$sys" bash "$repo/bootstrap/install.sh" --dry-run)"; need "$chk" 'update BoxLang 1.19.0 to 1.20.0'
out="$(MOCK_LATEST=1.20.0 trun bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; need "$out" 'BoxLang 1.20.0 installed and verified.'
[[ ! -s "$tmp/curl.log" ]] || { echo 'FAIL: updating BoxLang downloaded an installer script' >&2; cat "$tmp/curl.log" >&2; exit 1; }
# Already latest: nothing to do. Lookup unavailable: the installed version is left alone, and says so.
out="$(MOCK_LATEST=1.20.0 trun bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; need "$out" 'Nothing to do'
mock curl 'exit 22'   # curl exists but the lookup fails (offline)
out="$(trun bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; need "$out" 'could not look up the latest version'
# A pinned BoxLang is honored.
chk="$(trun env BXRIG_BOXLANG_VERSION=1.19.0 bash "$repo/bootstrap/install.sh" check)"; need "$chk" '(want 1.19.0 (pinned))'
echo 'bootstrap latest-BoxLang tests passed'

# ---- box.json: the one place that names tool versions ----
# The real manifest is valid, complete and agrees with the source's version string.
for k in .name .version .toolchain.java.version .toolchain.java.package .toolchain.boxlang.version .toolchain.bvm.installer .toolchain.mvm.installer .toolchain.matchbox.version .toolchain.rust.channel; do
	jq -e "$k" "$root/box.json" >/dev/null || { echo "FAIL: real box.json lacks $k" >&2; exit 1; }
done
[[ "BxRig $(jq -r .version "$root/box.json")" == "$SRCVER" ]] || { echo 'FAIL: box.json version differs from src/bxrig/util/Version.bx (run bootstrap/gen-version.sh)' >&2; exit 1; }
# A different pin in box.json changes the plan (no copy of the version lives in the script).
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"; mock sudo 'exit 9'
jq '.toolchain.rust.channel="beta" | .toolchain.java.package="jdk-test-openjdk"' "$repo/box.json" > "$tmp/box-other.json"
plan="$(run env BXRIG_MANIFEST="$tmp/box-other.json" bash "$repo/bootstrap/install.sh" --dry-run)"
need "$plan" 'rustup default beta'; need "$plan" 'jdk-test-openjdk'
# BXRIG_BOXLANG_VERSION still beats the manifest.
chk="$(run env BXRIG_BOXLANG_VERSION=1.18.0 bash "$repo/bootstrap/install.sh" check)"; need "$chk" '(want 1.18.0 (pinned))'
# A broken manifest is an error that says what is wrong.
echo '{ not json' > "$tmp/box-bad.json"
if out="$(run env BXRIG_MANIFEST="$tmp/box-bad.json" bash "$repo/bootstrap/install.sh" check 2>&1)"; then echo 'FAIL: invalid box.json accepted' >&2; exit 1; fi; need "$out" 'not valid JSON'
jq 'del(.toolchain.mvm.installer)' "$repo/box.json" > "$tmp/box-gap.json"
if out="$(run env BXRIG_MANIFEST="$tmp/box-gap.json" bash "$repo/bootstrap/install.sh" --dry-run 2>&1)"; then echo 'FAIL: incomplete box.json accepted' >&2; exit 1; fi; need "$out" 'missing toolchain.mvm.installer'
jq 'del(.toolchain.matchbox)' "$repo/box.json" > "$tmp/box-nomb.json"   # the MatchBox version is not pinned any more
run env BXRIG_MANIFEST="$tmp/box-nomb.json" bash "$repo/bootstrap/install.sh" --dry-run >/dev/null 2>&1 || { echo 'FAIL: a box.json without toolchain.matchbox must work' >&2; exit 1; }
if out="$(run env BXRIG_MANIFEST="$tmp/nope.json" bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: missing box.json accepted' >&2; exit 1; fi; need "$out" 'box.json not found'
# Without jq the read-only modes explain what to do, and the installing modes point at --install.
rm -f "$sys/jq"
out="$(run bash "$repo/bootstrap/install.sh" check 2>&1)"; need "$out" 'jq is required to read box.json'
plan="$(run bash "$repo/bootstrap/install.sh" --dry-run 2>&1)"; need "$plan" 'sudo pacman -S --needed jq'
if out="$(run bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: toolchains ran without jq' >&2; exit 1; fi; need "$out" 'Run install.sh packages --yes first'
# --install installs jq first, then carries on with the manifest.
install_mocks; fresh_home; rm -f "$sys/jq"
out="$(irun bash "$repo/bootstrap/install.sh" packages --yes 2>&1)"
need "$out" 'Installing jq first'; [[ -e "$sys/jq" ]] || { echo 'FAIL: jq not installed' >&2; exit 1; }
log="$(cat "$tmp/pacman.log")"; need "$log" 'S --noconfirm --needed jq'; need "$log" 'Syu --noconfirm --needed jdk21-openjdk'
[[ "$(grep -n 'S --noconfirm --needed jq' "$tmp/pacman.log" | head -1 | cut -d: -f1)" -lt "$(grep -n '^Syu' "$tmp/pacman.log" | head -1 | cut -d: -f1)" ]] || { echo 'FAIL: jq was not installed before the other packages' >&2; exit 1; }
ln -sf "$REALJQ" "$sys/jq"
echo 'bootstrap manifest tests passed'

# ---- A rate-limited "mvm install" (GitHub 403) is retried; persistent failure is reported ----
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock sudo 'exit 9'; mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
case "$url" in *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;; *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;; *nvm-sh/nvm*) printf "%s\n" "$NVM_FAKE" > "$out" ;; *version-latest.properties*) printf "version=1.19.0+1\n" ;; *) exit 22 ;; esac'
# mvm whose "install" fails the first N times, counted in a file; "use" and "--version" behave.
FLAKY_MVM='mkdir -p "$HOME/.mvm/bin"
cat > "$HOME/.mvm/bin/mvm" <<"M"
#!/usr/bin/env bash
case "$1" in
  install) n=$(cat "$HOME/mvm-tries" 2>/dev/null || echo 0); echo $((n+1)) > "$HOME/mvm-tries"; [[ $n -ge ${MVM_FAIL_TIMES:-2} ]] || { echo "${MVM_ERR:-GitHub request failed with HTTP 403}" >&2; exit 1; } ;;
  use) printf "#!/usr/bin/env bash\necho \"MatchBox 0.13.2\"\n" > "$HOME/.mvm/bin/matchbox"; chmod +x "$HOME/.mvm/bin/matchbox" ;;
  --version) echo "MVM version: 2.0.1" ;;
esac
M
chmod +x "$HOME/.mvm/bin/mvm"'
fresh_home
out="$(MVM_FAKE="$FLAKY_MVM" trun env BXRIG_RETRY_WAITS="0 0 0" MVM_FAIL_TIMES=2 bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"
need "$out" 'MatchBox 0.13.2 (stable) installed and verified.'; [[ "$(cat "$home/mvm-tries")" == 3 ]] || { echo 'FAIL: expected exactly 3 install attempts' >&2; exit 1; }
fresh_home
if out="$(MVM_FAKE="$FLAKY_MVM" trun env BXRIG_RETRY_WAITS="0 0 0" MVM_FAIL_TIMES=9 bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: persistent failure treated as success' >&2; exit 1; fi
need "$out" 'Failed after 3 attempts'; need "$out" 'HTTP 403'; need "$out" 'rate limit'; refuse "$out" 'Could not reach GitHub'
# mvm's own output is shown; a proxy or certificate failure gets the proxy hint and the branch-build alternative, not the rate-limit hint.
fresh_home
if out="$(MVM_FAKE="$FLAKY_MVM" trun env BXRIG_RETRY_WAITS="0 0 0" MVM_FAIL_TIMES=9 MVM_ERR='Could not contact GitHub: HTTP request failed: error sending request' bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: proxy failure treated as success' >&2; exit 1; fi
need "$out" 'Could not contact GitHub: HTTP request failed: error sending request'; need "$out" 'Could not reach GitHub. Behind a corporate proxy or a TLS-inspecting firewall?'
need "$out" 'install.sh toolchains --yes --matchbox-branch bxrig'; refuse "$out" 'rate limit'
fresh_home
if out="$(MVM_FAKE="$FLAKY_MVM" trun env BXRIG_RETRY_WAITS="0 0 0" MVM_FAIL_TIMES=9 MVM_ERR='error: HTTP 429 Too Many Requests' bash "$repo/bootstrap/install.sh" toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: 429 treated as success' >&2; exit 1; fi
need "$out" 'rate limit'; refuse "$out" 'Could not reach GitHub'
echo 'bootstrap retry tests passed'

# ---- the whole install: every stage in order, stops at the first failing stage ----
mkdir -p "$tmp/all/bin"
dfmock() { printf '#!/usr/bin/env bash\nprintf "Filesystem 1024-blocks Used Available Capacity Mounted\nx 100 50 %%s 5%%%% /\n" "$((%s * 1048576))"\n' "$1" > "$tmp/all/bin/df"; chmod +x "$tmp/all/bin/df"; }
dfmock 20
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo 1000; else /usr/bin/id "$@"; fi\n' > "$tmp/all/bin/id"; chmod +x "$tmp/all/bin/id"
cat > "$tmp/all/stage.sh" <<'STAGE'
#!/usr/bin/env bash
echo "$*" >> "$ALL_LOG"
[[ "${ALL_FAIL:-}" == "$1" ]] && exit 7
exit 0
STAGE
: > "$tmp/all/log"
out="$(env PATH="$tmp/all/bin:$PATH" ALL_LOG="$tmp/all/log" BXRIG_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" --yes 2>&1)"
[[ "$(paste -sd'|' "$tmp/all/log")" == 'packages --yes|toolchains --yes|binary --yes|core --yes' ]] || { echo "FAIL: the whole install stage order or flags: $(paste -sd'|' "$tmp/all/log")" >&2; exit 1; }
: > "$tmp/all/log"
if env PATH="$tmp/all/bin:$PATH" ALL_FAIL=toolchains ALL_LOG="$tmp/all/log" BXRIG_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" --yes >/dev/null 2>&1; then echo 'FAIL: the whole install ignored a failing stage' >&2; exit 1; fi
[[ "$(wc -l < "$tmp/all/log")" == 2 ]] || { echo 'FAIL: the whole install went on after a failing stage' >&2; exit 1; }
if bash "$root/bootstrap/install.sh" </dev/null >/dev/null 2>&1; then echo 'FAIL: the whole install without --yes accepted' >&2; exit 1; fi
out="$(env PATH="$tmp/all/bin:$PATH" ALL_LOG="$tmp/all/log" BXRIG_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" --dry-run 2>&1)" || { echo 'FAIL: --dry-run exited non-zero' >&2; exit 1; }
[[ "$out" == *'bxrig profile-install core --yes'* && "$out" == *'Dry run: nothing was changed.'* ]] || { echo "FAIL: --dry-run plan lacks the core step: $out" >&2; exit 1; }
: > "$tmp/all/log"
out="$(printf 'n\n' | env BXRIG_INTERACTIVE=1 PATH="$tmp/all/bin:$PATH" ALL_LOG="$tmp/all/log" BXRIG_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" 2>&1)" && { echo 'FAIL: answering n went on' >&2; exit 1; }
[[ ! -s "$tmp/all/log" ]] || { echo 'FAIL: a stage ran after answering n' >&2; exit 1; }
printf 'y\n' | env BXRIG_INTERACTIVE=1 PATH="$tmp/all/bin:$PATH" ALL_LOG="$tmp/all/log" BXRIG_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" >/dev/null 2>&1 || { echo 'FAIL: answering y did not run the install' >&2; exit 1; }
[[ "$(paste -sd'|' "$tmp/all/log")" == 'packages --yes|toolchains --yes|binary --yes|core --yes|wizard' ]] || { echo "FAIL: stages after answering y (the wizard follows at a terminal): $(paste -sd'|' "$tmp/all/log")" >&2; exit 1; }
[[ "$out" != *'Everything is installed'* ]] || { echo 'FAIL: the old closing line is back' >&2; exit 1; }
# the closing line says what is true: tools only, the desktop and apps come with bxrig init
out="$(env PATH="$tmp/all/bin:$PATH" ALL_LOG="$tmp/all/log" BXRIG_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" --yes </dev/null 2>&1)"
need "$out" 'Tools installed. Run `bxrig init` for the desktop and apps.'; refuse "$out" 'Everything is installed'
# the whole install needs 8 GB up front: the plan says so, 6 GB fails before any stage runs, 9 GB passes, --dry-run only reports
out="$(env PATH="$tmp/all/bin:$PATH" ALL_LOG="$tmp/all/log" BXRIG_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" --dry-run 2>&1)"; need "$out" 'need 8 GB for the whole install'; need "$out" '20 GB free'
dfmock 6; : > "$tmp/all/log"
if out="$(env PATH="$tmp/all/bin:$PATH" ALL_LOG="$tmp/all/log" BXRIG_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" --yes 2>&1 </dev/null)"; then echo 'FAIL: 6 GB free accepted for the whole install' >&2; exit 1; fi
need "$out" 'need 8 GB for the whole install'; need "$out" 'Not enough free disk space: 6 GB free'; [[ ! -s "$tmp/all/log" ]] || { echo 'FAIL: a stage ran with too little disk' >&2; exit 1; }
out="$(env PATH="$tmp/all/bin:$PATH" ALL_LOG="$tmp/all/log" BXRIG_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" --dry-run 2>&1)" || { echo 'FAIL: --dry-run failed on low disk' >&2; exit 1; }; need "$out" 'not enough'
dfmock 9
env PATH="$tmp/all/bin:$PATH" ALL_LOG="$tmp/all/log" BXRIG_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" --yes >/dev/null 2>&1 </dev/null || { echo 'FAIL: 9 GB free refused for the whole install' >&2; exit 1; }
[[ "$(wc -l < "$tmp/all/log")" == 4 ]] || { echo 'FAIL: 9 GB did not run all stages' >&2; exit 1; }
dfmock 6; need "$(env PATH="$tmp/all/bin:$PATH" bash "$root/bootstrap/install.sh" check 2>&1)" 'disk-free: 6 GB (need 8 for the whole install)'
rm -f "$tmp/all/bin/df"
echo 'bootstrap whole-install tests passed'

# ---- nvm and Node.js are not part of the required install (they are the optional JavaScript toolchain: `bxrig toolchain node`) ----
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'; mock mvm 'echo "MVM version: 2.0.1"'; mock matchbox 'echo "MatchBox 0.12.0"'
mock bvm 'echo "bvm 1.40.0"'; mock boxlang 'echo "Ortus BoxLang v1.19.0+67"'; mock rustc 'echo "rustc 1.90.0"'; mock rustup 'exit 0'; mock yay 'exit 0'
mock bxrig '[[ "$1" == version ]] && echo "BxRig 0.11.0-dev"'
rm -rf "$home"; mkdir -p "$home/.local/bin"; cp "$bin/bxrig" "$home/.local/bin/bxrig"; rm "$bin/bxrig"
nplan() { env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXRIG_SKIP_NETWORK=1 BXRIG_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$repo/bootstrap/install.sh" "$@"; }
plan="$(nplan --dry-run)"
refuse "$plan" 'nvm'; refuse "$plan" 'Node.js'; refuse "$(nplan check)" 'nvm:'; refuse "$(nplan check)" 'node:'
echo 'bootstrap required-toolchain tests passed'

# ---- MatchBox: stable by default (mvm install latest), --snapshot, or a branch built with cargo; the capability check ----
# Fake mvm, git, cargo and curl; nothing touches the network, and the real mvm is never run (it is replaced by a fake that copies a MatchBox
# template). The three MatchBox templates: stable (0.13.2) and snapshot (0.14.1) have no terminal UI, the branch build (0.15.0) has it.
MBD="$tmp/mbtpl"; mkdir -p "$MBD"
for t in stable:0.13.2:0 snapshot:0.14.1:0 branch:0.15.0:1; do
	IFS=: read -r tn tv tt <<<"$t"
	cat > "$MBD/mb-$tn" <<TPL
#!/usr/bin/env bash
case "\${1:-}" in
	--version) echo "matchbox version $tv" ;;
	*probe.bxs) if [[ $tt == 1 ]]; then echo bxrig-tui-ok; else echo "Native class 'tui.TUI' not found" >&2; exit 1; fi ;;
	*--build*) if [[ "\${MOCK_SHARE:-$tt}" == 1 ]]; then echo "Error: Compiler Error: Circular class reference: A -> B -> A" >&2; exit 1; else echo "thread 'main' has overflowed its stack" >&2; exit 134; fi ;;
	*) out=bxrig; while [[ \$# -gt 0 ]]; do [[ "\$1" == --output ]] && { out="\$2"; break; }; shift; done; [[ -n "\${FAKE:-}" ]] && cp "\$FAKE" "\$out" && chmod 755 "\$out" ;;
esac
TPL
	chmod +x "$MBD/mb-$tn"
done
HEADFULL=425a2942aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; HEADNEW=beefcafe00000000000000000000000000000000
mbrepo="$tmp/mbrepo"; mkdir -p "$mbrepo/bootstrap"; cp "$root/bootstrap/install.sh" "$mbrepo/bootstrap/install.sh"
jq '.toolchain.matchbox = { version: "0.14.0", repo: "https://github.com/ortus-boxlang/matchbox", ref: "bxrig" }' "$repo/box.json" > "$mbrepo/box.json"
cp -rL "$root/src" "$mbrepo/src"
mbmocks() {
	reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
	mock sudo 'exit 9'; mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'; mock bvm 'echo "bvm 1.40.0"'
	mock boxlang 'echo "Ortus BoxLang v1.19.0+67"'; mock rustc 'echo "rustc 1.90.0"'; mock rustup 'exit 0'; mock yay 'exit 0'
	mock curl 'exit 22'
	mock mvm 'echo "mvm $*" >> "$MB_LOG"
case "$1" in
  use) mkdir -p "$HOME/.mvm/bin"; cp "$MB_TPL/mb-$([[ "$2" == latest ]] && echo stable || echo "$2")" "$HOME/.mvm/bin/matchbox"; chmod +x "$HOME/.mvm/bin/matchbox" ;;
  --version) echo "MVM version: 2.0.1" ;;
esac'
	mock git 'echo "git $*" >> "$MB_LOG"
[[ "$1" == -C ]] && shift 2
case "$1" in
  ls-remote) [[ "${MOCK_GIT_FAIL:-0}" == 1 ]] && exit 128; [[ -n "${MOCK_HEAD:-}" ]] && printf "%s\trefs/heads/%s\n" "$MOCK_HEAD" "${3#refs/heads/}"; exit 0 ;;
  clone) while [[ $# -gt 1 ]]; do shift; done; mkdir -p "$1"; exit 0 ;;
  rev-parse) echo "${MOCK_BUILT_COMMIT:-$HEADFULL}" ;;
esac'
	mock cargo 'echo "cargo $*" >> "$MB_LOG"; [[ "${MOCK_CARGO_FAIL:-0}" == 1 ]] && { echo "error: could not compile" >&2; exit 101; }; mkdir -p target/release; cp "$MB_TPL/mb-branch" target/release/matchbox'
}
mbrun() { env -i HOME="$home" PATH="$bin:$sys" BXRIG_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" MOCK_UID="${MOCK_UID:-1000}" MB_LOG="$tmp/mb.log" MB_TPL="$MBD" HEADFULL="$HEADFULL" \
	MOCK_HEAD="${MOCK_HEAD-$HEADFULL}" MOCK_GIT_FAIL="${MOCK_GIT_FAIL:-0}" MOCK_CARGO_FAIL="${MOCK_CARGO_FAIL:-0}" FAKE="${FAKE:-}" BXRIG_RETRY_WAITS=0 "$@"; }
mbinst() { mbrun bash "$mbrepo/bootstrap/install.sh" "$@"; }
mbhome="$home/.local/share/bxrig/matchbox"
mbfresh() { rm -rf "$home"; mkdir -p "$home/.local/bin" "$home/.mvm/bin"; cp "$bin/mvm" "$home/.mvm/bin/mvm" 2>/dev/null || true; : > "$tmp/mb.log"; }
mbmocks; mbfresh

# 1. stable is the default: mvm install latest, mvm use latest; no clone, no cargo
out="$(mbinst toolchains --yes 2>&1)" || { echo "FAIL: stable: $out" >&2; exit 1; }
need "$out" 'MatchBox 0.13.2 (stable) installed and verified.'; log="$(cat "$tmp/mb.log")"
need "$log" 'mvm install latest'; need "$log" 'mvm use latest'; refuse "$log" 'git '; refuse "$log" 'cargo'; refuse "$log" 'snapshot'
# stable cannot compile bxrig: said (not an error: the prebuilt bxrig only needs the toolchain)
need "$out" 'cannot compile BxRig well enough'; need "$out" '--matchbox-branch bxrig'
need "$(mbinst check)" 'matchbox: 0.13.2 (compiles BxRig: no)'
# a second run leaves an installed MatchBox alone
: > "$tmp/mb.log"; out="$(mbinst toolchains --yes 2>&1)"; need "$out" 'Nothing to do'; refuse "$(cat "$tmp/mb.log")" 'mvm install'
# the plan names it
mbfresh; plan="$(mbinst --dry-run 2>&1)"; need "$plan" 'mvm install latest && mvm use latest'; need "$plan" 'MatchBox: stable'; need "$plan" 'Dry run: nothing was changed.'

# 2. --snapshot (and BXRIG_MATCHBOX_CHANNEL=snapshot): mvm install snapshot, mvm use snapshot, every run (mvm skips an unchanged build)
mbfresh; out="$(mbinst toolchains --yes --snapshot 2>&1)" || { echo "FAIL: snapshot: $out" >&2; exit 1; }
need "$out" 'MatchBox 0.14.1 (snapshot) installed and verified.'; log="$(cat "$tmp/mb.log")"; need "$log" 'mvm install snapshot'; need "$log" 'mvm use snapshot'; refuse "$log" 'mvm install latest'
: > "$tmp/mb.log"; mbinst toolchains --yes --snapshot >/dev/null 2>&1; need "$(cat "$tmp/mb.log")" 'mvm install snapshot'
mbfresh; mbrun env BXRIG_MATCHBOX_CHANNEL=snapshot bash "$mbrepo/bootstrap/install.sh" toolchains --yes >/dev/null 2>&1 || { echo 'FAIL: env channel' >&2; exit 1; }; need "$(cat "$tmp/mb.log")" 'mvm install snapshot'
plan="$(mbinst --dry-run --snapshot 2>&1)"; need "$plan" 'mvm install snapshot && mvm use snapshot'; need "$plan" 'MatchBox: snapshot'
# conflicting or bad choices are exit 2 before anything runs
for args in "--snapshot --matchbox-branch x" "--snapshot --matchbox-from-source" "--matchbox-repo a/b" "--snapshot --matchbox-repo a/b"; do
	rc=0; out="$(mbinst toolchains --yes $args 2>&1)" || rc=$?; [[ "$rc" == 2 ]] || { echo "FAIL: '$args' exit $rc, not 2: $out" >&2; exit 1; }
done
rc=0; out="$(mbrun env BXRIG_MATCHBOX_CHANNEL=nightly bash "$mbrepo/bootstrap/install.sh" check 2>&1)" || rc=$?; [[ "$rc" == 2 ]] || { echo "FAIL: a bad channel exit $rc" >&2; exit 1; }; need "$out" 'BXRIG_MATCHBOX_CHANNEL'
rc=0; out="$(mbrun env BXRIG_MATCHBOX_CHANNEL=snapshot BXRIG_MATCHBOX_BRANCH=x bash "$mbrepo/bootstrap/install.sh" check 2>&1)" || rc=$?; [[ "$rc" == 2 ]] || { echo "FAIL: snapshot and a branch from the environment: exit $rc" >&2; exit 1; }

# 3. --matchbox-branch REF: shallow clone of the default repo, cargo build --release --features bif-tui, installed under the bxrig home
mbfresh; mbinst toolchains --yes >/dev/null 2>&1; : > "$tmp/mb.log"
out="$(mbinst toolchains --yes --matchbox-branch feature/x 2>&1)" || { echo "FAIL: branch: $out" >&2; exit 1; }
log="$(cat "$tmp/mb.log")"; need "$log" 'git clone --quiet --depth 1 --branch feature/x https://github.com/ortus-boxlang/matchbox'; need "$log" 'cargo build --release --features bif-tui'; refuse "$log" 'mvm install'
need "$out" 'MatchBox 0.15.0 (branch feature/x of https://github.com/ortus-boxlang/matchbox) installed and verified'; need "$out" 'can compile BxRig'; need "$out" "$mbhome/bin"
[[ -x "$mbhome/bin/matchbox" ]] || { echo 'FAIL: the branch build is not installed' >&2; exit 1; }
for kv in 'repo=https://github.com/ortus-boxlang/matchbox' 'branch=feature/x' "commit=$HEADFULL" 'source=branch'; do need "$(cat "$mbhome/build.info")" "$kv"; done
# it takes precedence over the MatchBox that mvm manages (which stays installed and untouched)
chk="$(mbinst check)"; need "$chk" 'matchbox: 0.15.0 (compiles BxRig: yes)'; [[ "$("$home/.mvm/bin/matchbox" --version)" == *0.13.2* ]] || { echo 'FAIL: the branch install replaced the mvm MatchBox' >&2; exit 1; }
# same repo, branch and head: nothing is rebuilt; the head moved, the repo or the branch changed, or the head is unreadable: rebuilt
: > "$tmp/mb.log"; out="$(mbinst toolchains --yes --matchbox-branch feature/x 2>&1)"; need "$out" 'Nothing to do'; refuse "$(cat "$tmp/mb.log")" 'cargo'
: > "$tmp/mb.log"; MOCK_HEAD=$HEADNEW mbinst toolchains --yes --matchbox-branch feature/x >/dev/null 2>&1 || { echo 'FAIL: moved head' >&2; exit 1; }; need "$(cat "$tmp/mb.log")" 'cargo build'
: > "$tmp/mb.log"; MOCK_GIT_FAIL=1 mbinst toolchains --yes --matchbox-branch feature/x >/dev/null 2>&1; need "$(cat "$tmp/mb.log")" 'cargo build'
: > "$tmp/mb.log"; mbinst toolchains --yes --matchbox-branch feature/y >/dev/null 2>&1; need "$(cat "$tmp/mb.log")" '--branch feature/y'
: > "$tmp/mb.log"; mbinst toolchains --yes --matchbox-branch feature/y --matchbox-repo someone/fork >/dev/null 2>&1; need "$(cat "$tmp/mb.log")" '--branch feature/y https://github.com/someone/fork'
need "$(cat "$mbhome/build.info")" 'repo=https://github.com/someone/fork'
# --matchbox-from-source is the old spelling of --matchbox-branch bxrig (the manifest branch)
mbfresh; : > "$tmp/mb.log"; mbinst toolchains --yes --matchbox-from-source >/dev/null 2>&1 || { echo 'FAIL: --matchbox-from-source' >&2; exit 1; }; need "$(cat "$tmp/mb.log")" '--branch bxrig https://github.com/ortus-boxlang/matchbox'
# the environment variables mean the same; flags win
mbfresh; : > "$tmp/mb.log"; mbrun env BXRIG_MATCHBOX_BRANCH=dev BXRIG_MATCHBOX_REPO=acme/mb bash "$mbrepo/bootstrap/install.sh" toolchains --yes >/dev/null 2>&1 || { echo 'FAIL: env branch' >&2; exit 1; }; need "$(cat "$tmp/mb.log")" '--branch dev https://github.com/acme/mb'
mbfresh; : > "$tmp/mb.log"; mbrun env BXRIG_MATCHBOX_BRANCH=dev bash "$mbrepo/bootstrap/install.sh" toolchains --yes --matchbox-branch other >/dev/null 2>&1; need "$(cat "$tmp/mb.log")" '--branch other '; refuse "$(cat "$tmp/mb.log")" '--branch dev '
# a failed clone or build installs nothing and keeps the earlier build
mbfresh; mbinst toolchains --yes --matchbox-branch feature/x >/dev/null 2>&1; before="$(cat "$mbhome/bin/matchbox")"
if out="$(MOCK_CARGO_FAIL=1 MOCK_HEAD=$HEADNEW mbinst toolchains --yes --matchbox-branch feature/x 2>&1)"; then echo 'FAIL: a failed build was accepted' >&2; exit 1; fi
need "$out" 'The MatchBox build failed; nothing was installed'; [[ "$(cat "$mbhome/bin/matchbox")" == "$before" ]] || { echo 'FAIL: a failed build changed the installed MatchBox' >&2; exit 1; }
# no cargo: said, with the way out
mbfresh; rm -f "$bin/cargo"; if out="$(mbinst toolchains --yes --matchbox-branch feature/x 2>&1)"; then echo 'FAIL: no cargo accepted' >&2; exit 1; fi; need "$out" 'cargo is required'
mbmocks; mbfresh
# the plan (dry run) shows the branch build
out="$(mbinst --dry-run --matchbox-branch feature/x --matchbox-repo someone/fork 2>&1)" || { echo "FAIL: dry run: $out" >&2; exit 1; }
need "$out" 'MatchBox: branch feature/x of https://github.com/someone/fork, built here with cargo'; need "$out" 'git clone --depth 1 --branch feature/x https://github.com/someone/fork, then cargo build --release --features bif-tui'

# 4. going back to stable or snapshot removes the branch build, so it does not shadow mvm's MatchBox; the default leaves a branch build alone
mbfresh; mbinst toolchains --yes --matchbox-branch feature/x >/dev/null 2>&1; : > "$tmp/mb.log"
out="$(mbinst toolchains --yes 2>&1)"; need "$out" 'Nothing to do'; [[ -x "$mbhome/bin/matchbox" ]] || { echo 'FAIL: the default removed a branch build' >&2; exit 1; }
out="$(mbinst toolchains --yes --snapshot 2>&1)"; need "$out" 'Removed the MatchBox built from a branch earlier'; [[ ! -e "$mbhome/bin/matchbox" && ! -e "$mbhome/build.info" ]] || { echo 'FAIL: the branch build is still there' >&2; exit 1; }
need "$(mbinst check)" 'matchbox: 0.14.1'

# 5. BXRIG_MATCHBOX_FILE=PATH installs a local build (no mvm, no clone), recorded as such; the same file again changes nothing
mbfresh; cp "$MBD/mb-branch" "$tmp/mine"; : > "$tmp/mb.log"
out="$(mbrun env BXRIG_MATCHBOX_FILE="$tmp/mine" bash "$mbrepo/bootstrap/install.sh" toolchains --yes 2>&1)" || { echo "FAIL: local file: $out" >&2; exit 1; }
need "$out" 'MatchBox 0.15.0'; refuse "$(cat "$tmp/mb.log")" 'mvm install'; refuse "$(cat "$tmp/mb.log")" 'cargo'; need "$(cat "$mbhome/build.info")" 'source=file'
out="$(mbrun env BXRIG_MATCHBOX_FILE="$tmp/mine" bash "$mbrepo/bootstrap/install.sh" toolchains --yes 2>&1)"; need "$out" 'Nothing to do'
if mbrun env BXRIG_MATCHBOX_FILE="$tmp/nope" bash "$mbrepo/bootstrap/install.sh" toolchains --yes >/dev/null 2>&1; then echo 'FAIL: a missing BXRIG_MATCHBOX_FILE was accepted' >&2; exit 1; fi

# 6. the branch and repository are validated strictly, and only ever reach git as argv items
mbfresh
for bad in '-x' 'a b' '$(id)' '../x' '/x' 'x/' 'a;b' "a'b" '' 'a|b'; do
	rc=0; out="$(mbinst toolchains --yes --matchbox-branch "$bad" 2>&1)" || rc=$?; [[ "$rc" == 2 ]] || { echo "FAIL: branch '$bad' exit $rc, not 2: $out" >&2; exit 1; }
	[[ -z "$bad" ]] || need "$out" 'Invalid MatchBox branch'
done
for bad in '-a/b' 'a' 'a/b/c' 'a b/c' '$(id)/x' '../x' 'a/..' 'a;b/c' 'https://github.com/a/b' ''; do
	rc=0; out="$(mbinst toolchains --yes --matchbox-branch ok --matchbox-repo "$bad" 2>&1)" || rc=$?; [[ "$rc" == 2 ]] || { echo "FAIL: repo '$bad' exit $rc, not 2: $out" >&2; exit 1; }
done
rc=0; out="$(mbrun env BXRIG_MATCHBOX_BRANCH=';touch /tmp/pwned' bash "$mbrepo/bootstrap/install.sh" toolchains --yes 2>&1)" || rc=$?; [[ "$rc" == 2 ]] && need "$out" 'Invalid MatchBox branch' || { echo 'FAIL: bad BXRIG_MATCHBOX_BRANCH accepted' >&2; exit 1; }
[[ ! -e /tmp/pwned ]] || { echo 'FAIL: the branch was run as a shell string' >&2; exit 1; }
[[ ! -s "$tmp/mb.log" ]] || { echo "FAIL: a refused option ran something: $(cat "$tmp/mb.log")" >&2; exit 1; }

# 7. compiling bxrig needs a MatchBox with the terminal UI. Stable, snapshot: stop with the message. The branch build: builds. --binary PATH needs none.
mbfresh; mbinst toolchains --yes >/dev/null 2>&1   # stable only
: > "$tmp/mb.log"; fake_bin "$SRCVER" > "$tmp/fake_built"; chmod 755 "$tmp/fake_built"
if out="$(mbrun env FAKE="$tmp/fake_built" bash "$mbrepo/bootstrap/install.sh" binary --yes 2>&1)"; then echo 'FAIL: stable compiled bxrig' >&2; exit 1; fi
need "$out" 'This MatchBox (0.13.2) cannot compile BxRig'; need "$out" 'toolchains --yes --matchbox-branch bxrig'; [[ ! -e "$home/.local/bin/bxrig" ]] || { echo 'FAIL: the stop installed bxrig' >&2; exit 1; }
mbinst toolchains --yes --snapshot >/dev/null 2>&1
if out="$(mbrun env FAKE="$tmp/fake_built" bash "$mbrepo/bootstrap/install.sh" binary --yes 2>&1)"; then echo 'FAIL: snapshot compiled bxrig' >&2; exit 1; fi; need "$out" 'This MatchBox (0.14.1) cannot compile BxRig'
# --binary PATH (the prebuilt bxrig of the web installer) needs no capable MatchBox
out="$(mbrun env FAKE="$tmp/fake_built" bash "$mbrepo/bootstrap/install.sh" binary --yes --binary "$tmp/fake_built" 2>&1)" || { echo "FAIL: --binary with a stable MatchBox: $out" >&2; exit 1; }; need "$out" 'Installed'
rm -f "$home/.local/bin/bxrig"
# the branch build is found first on the PATH and compiles it, although mvm's (not capable) MatchBox is installed too
mbinst toolchains --yes --matchbox-branch bxrig >/dev/null 2>&1
out="$(mbrun env FAKE="$tmp/fake_built" bash "$mbrepo/bootstrap/install.sh" binary --yes 2>&1)" || { echo "FAIL: the branch build did not compile bxrig: $out" >&2; exit 1; }
need "$out" 'Building bxrig with MatchBox 0.15.0'; need "$out" 'Installed'
# the capability is in the read-only report too
need "$(mbinst check)" 'compiles BxRig: yes'

# 8. the full install passes the MatchBox choice to the toolchains stage
mkdir -p "$tmp/all2"; printf '#!/usr/bin/env bash\necho "$*" >> "$ALL_LOG"\n' > "$tmp/all2/stage.sh"
all2() { : > "$tmp/all2/log"; mbrun env ALL_LOG="$tmp/all2/log" BXRIG_ALL_SCRIPT="$tmp/all2/stage.sh" bash "$mbrepo/bootstrap/install.sh" --yes "$@" >/dev/null 2>&1 || { echo "FAIL: full install with $*" >&2; exit 1; }; paste -sd'|' "$tmp/all2/log"; }
mbfresh; mock df 'printf "Filesystem 1024-blocks Used Available Capacity Mounted\nx 100 50 20971520 5%% /\n"'
[[ "$(all2)" == 'packages --yes|toolchains --yes|binary --yes|core --yes' ]] || { echo 'FAIL: the default full install passes no MatchBox option' >&2; exit 1; }
[[ "$(all2 --snapshot)" == 'packages --yes|toolchains --yes --snapshot|binary --yes|core --yes' ]] || { echo 'FAIL: --snapshot is not passed on' >&2; exit 1; }
[[ "$(all2 --matchbox-branch feature/x --matchbox-repo someone/fork)" == 'packages --yes|toolchains --yes --matchbox-branch feature/x --matchbox-repo someone/fork|binary --yes|core --yes' ]] || { echo 'FAIL: the branch options are not passed on' >&2; exit 1; }
[[ "$(all2 --matchbox-from-source)" == 'packages --yes|toolchains --yes --matchbox-branch bxrig|binary --yes|core --yes' ]] || { echo 'FAIL: --matchbox-from-source is not --matchbox-branch bxrig' >&2; exit 1; }
echo 'bootstrap MatchBox tests passed'
