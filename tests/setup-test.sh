#!/usr/bin/env bash
# `bxrig setup plasma|undo plasma|status` end to end with fake pacman, git, sudo and id. Usage: setup-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home"
cat > "$tmp/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Q) [[ "$2" == kwin ]] && { [[ -n "${MOCK_NO_KWIN:-}" ]] && exit 1; echo "kwin ${MOCK_KWIN:-6.6.2-1}"; } ;;
  -Qq) printf '%s\n' ${MOCK_INSTALLED:-git kpackage python-dbus python-gobject qt6-tools swayidle} ;;
  -S|-Rs) [[ -z "${MOCK_PACMAN_FAIL:-}" ]] || exit 1; printf 'pacman %s\n' "$*" >> "$SETUP_LOG" ;;
  --version) echo "Pacman v7.0" ;;
  *) exit 9 ;;
esac
MOCK
# git clone URL DIR makes a checkout with the three HyprKwin tools; everything they do is logged
cat > "$tmp/bin/git" <<'MOCK'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >> "$SETUP_LOG"
[[ -z "${MOCK_GIT_FAIL:-}" ]] || exit 1
if [[ "$1" == clone ]]; then
  d="${@: -1}"; mkdir -p "$d/tools"
  printf '#!/usr/bin/env bash\n[ -z "$MOCK_INSTALL_FAIL" ] || { echo "install.sh: cannot write /usr/lib/kwin: permission denied" >&2; exit 1; }\necho "INSTALL in $PWD" >> "$SETUP_LOG"\n' > "$d/tools/install.sh"
  printf '#!/usr/bin/env bash\necho "UNINSTALL in $PWD" >> "$SETUP_LOG"\n' > "$d/tools/uninstall.sh"
  printf 'import os,sys\nopen(os.environ["SETUP_LOG"],"a").write("SHORTCUTS %%s\\n" %% " ".join(sys.argv[1:]))\n' > "$d/tools/hyprkwin-shortcuts.py"
  chmod +x "$d/tools/install.sh" "$d/tools/uninstall.sh"
fi
MOCK
printf '#!/usr/bin/env bash\necho x86_64\n' > "$tmp/bin/uname"
# systemctl: is-enabled answers MOCK_BT_ENABLED (default: not enabled); everything else is logged
stub systemctl 'if [[ "$1" == is-enabled ]]; then [[ -n "${MOCK_BT_ENABLED:-}" ]]; exit; fi
printf "systemctl %s\n" "$*" >> "$SETUP_LOG"'
stub_sudo
stub_id
chmod +x "$tmp/bin/"*
export SETUP_LOG="$tmp/setup.log"
printf 'NAME="CachyOS Linux"\nID=cachyos\nID_LIKE=arch\n' > "$tmp/os-cachyos"; printf 'ID=fedora\n' > "$tmp/os-other"
mkdir -p "$tmp/sysd"   # systemd is "running" for the steps below (BXRIG_SYSTEMD_RUN_DIR names /run/systemd/system)
run() { env BXRIG_SYSTEMD_RUN_DIR="${SYSD_DIR:-$tmp/sysd}" BXRIG_OS_RELEASE="${OS_FILE:-$tmp/os-cachyos}" BXRIG_STATE_HOME="$tmp/state-home" HOME="$tmp/home" PATH="$tmp/bin:$PATH" XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland SETUP_LOG="$SETUP_LOG" MOCK_INSTALL_FAIL="${MOCK_INSTALL_FAIL:-}" "$@"; }
reset() { : > "$SETUP_LOG"; rm -rf "$tmp/home/.local" "$tmp/state-home"; }
leftovers() { { ls -d /tmp/bxrig-hyprkwin-* 2>/dev/null || true; } | wc -l; }
before="$(leftovers)"; reset
export MOCK_BT_ENABLED=1   # the plasma sections below run with bluetooth.service already enabled; its own section follows the undo checks

# gating
[[ "$(code "$binary" setup plasma)" == 2 ]] || fail 'no --yes exits 2'
[[ "$(code "$binary" setup plasma --dry-run)" == 0 ]] || fail '--dry-run exits 0'
[[ ! -s "$SETUP_LOG" ]] || fail 'plan or dry run changed something'
run "$binary" setup plasma --dry-run | grep -F 'tools/install.sh' >/dev/null || fail 'the plan shows the exact command'
[[ "$(MOCK_UID=0 code "$binary" setup plasma --yes)" == 4 ]] || fail 'root exits 4'
[[ "$(MOCK_NO_KWIN=1 code "$binary" setup plasma --yes)" == 4 ]] || fail 'no Plasma exits 4'
[[ "$(MOCK_KWIN=6.4.0-1 code "$binary" setup plasma --yes)" == 4 ]] || fail 'unsupported Plasma exits 4'
[[ "$(env HOME="$tmp/home" PATH="$tmp/bin:$PATH" XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=x11 SETUP_LOG="$SETUP_LOG" "$binary" setup plasma --yes >/dev/null 2>&1; echo $?)" == 4 ]] || fail 'X11 exits 4'
[[ ! -s "$SETUP_LOG" ]] || fail 'a refused run changed something'

# install
run "$binary" setup plasma --yes >/dev/null 2>&1 || fail 'setup plasma --yes'
grep -Eq '^git clone --quiet https://github.com/DGBooth/HyprKwin.git /tmp/bxrig-hyprkwin-' "$SETUP_LOG" || fail "clone from the HyprKwin repo (log: $(cat "$SETUP_LOG"))"
grep -Eq '^git -C /tmp/bxrig-hyprkwin-.* checkout --quiet [0-9a-f]{40}$' "$SETUP_LOG" || fail 'checkout at a full commit'
grep -Eq '^INSTALL in /tmp/bxrig-hyprkwin-' "$SETUP_LOG" || fail 'install.sh ran inside the checkout'
grep -q SHORTCUTS "$SETUP_LOG" && fail 'keys must stay off by default'
[[ "$(leftovers)" == "$before" ]] || fail 'the temporary checkout was removed'
out="$(run "$binary" setup plasma --dry-run --json)"
[[ "$(jq -r '.data.steps|map(.id)|join(",")' <<<"$out")" == fetch,install ]] || fail 'json steps'
[[ "$(jq -r '.dry_run' <<<"$out")" == true ]] || fail 'json dry_run'

# keys
reset; run "$binary" setup plasma --keys --yes >/dev/null 2>&1 || fail '--keys'
grep -Fq 'SHORTCUTS apply' "$SETUP_LOG" || fail '--keys applies the shortcuts'
reset; [[ "$(code "$binary" setup plasma --undo-keys --yes)" == 4 ]] || fail '--undo-keys needs HyprKwin installed'
mkdir -p "$tmp/home/.local/share/hyprkwin"
run "$binary" setup plasma --undo-keys --yes >/dev/null 2>&1 || fail '--undo-keys'
grep -Fq 'SHORTCUTS restore' "$SETUP_LOG" || fail '--undo-keys restores'
grep -q '^INSTALL' "$SETUP_LOG" && fail '--undo-keys must not reinstall'
[[ "$(code "$binary" setup plasma --keys --undo-keys --yes)" == 4 ]] || fail '--keys with --undo-keys exits 4'

# failures
reset; [[ "$(MOCK_INSTALL_FAIL=1 code "$binary" setup plasma --keys --yes)" == 7 ]] || fail 'install failing after the checkout exits 7'
grep -Fq 'SHORTCUTS' "$SETUP_LOG" && fail 'the keys step must be skipped after a failed install'
out="$(MOCK_INSTALL_FAIL=1 run "$binary" setup plasma --keys --yes --json 2>/dev/null || true)"
[[ "$(jq -r '.data.skipped[0].id' <<<"$out")" == keys-apply && "$(jq -r '.data.failed[0].id' <<<"$out")" == install ]] || fail 'json failed and skipped lists'
# the real error text of the failed step, in --json and in the text output (not only "exit 1")
jq -e '.data.failed[0].output | test("permission denied")' <<<"$out" >/dev/null || fail "the failed step's error text is in --json: $out"
jq -e '.data.failed[0].command | test("install.sh")' <<<"$out" >/dev/null || fail 'the failed command is in --json'
txt="$(MOCK_INSTALL_FAIL=1 run "$binary" setup plasma --keys --yes 2>&1 || true)"
grep -q '| install.sh: cannot write /usr/lib/kwin: permission denied' <<<"$txt" || fail "the failed step's error text is printed: $txt"
reset; [[ "$(MOCK_GIT_FAIL=1 code "$binary" setup plasma --yes)" == 6 ]] || fail 'a failed checkout with nothing done exits 6'
[[ "$(leftovers)" == "$before" ]] || fail 'no checkout left after a failure'

# missing packages go through one sudo pacman call first
reset; out="$(MOCK_INSTALLED=git run "$binary" setup plasma --yes 2>&1)" || fail "install with missing packages: $out"
grep -Fq 'pacman -S --needed --noconfirm kpackage python-dbus python-gobject qt6-tools swayidle' "$SETUP_LOG" || fail 'one pacman call for the missing packages'
[[ "$(head -n1 "$SETUP_LOG")" == pacman* ]] || fail 'packages come first'
reset; [[ "$(MOCK_INSTALLED=git MOCK_PACMAN_FAIL=1 code "$binary" setup plasma --yes)" == 5 ]] || fail 'pacman failing exits 5'

# undo, status, usage
reset; mkdir -p "$tmp/home/.local/share/hyprkwin"; [[ "$(code "$binary" setup undo plasma --yes)" == 0 ]] || fail 'undo plasma'
grep -Eq '^UNINSTALL in /tmp/bxrig-hyprkwin-' "$SETUP_LOG" || fail 'undo runs tools/uninstall.sh'
rm -rf "$tmp/home/.local"; [[ "$(code "$binary" setup undo plasma --yes)" == 4 ]] || fail 'undo without HyprKwin exits 4'
[[ "$(run "$binary" setup status --json | jq -r '.data.plasma.kwin')" == 6.6.2 ]] || fail 'status shows the kwin version'
[[ "$(code "$binary" setup)" == 2 ]] || fail 'setup alone is a usage error'
[[ "$(code "$binary" setup nope)" == 2 ]] || fail 'unknown target is a usage error'

# ---- plasma: bluetooth.service is turned on here too (skipped when enabled), remembered, and turned off again by undo
unset MOCK_BT_ENABLED
reset; out="$(run "$binary" setup plasma --dry-run --json)"
[[ "$(jq -r '.data.steps|map(.id)|join(",")' <<<"$out")" == packages,bluetooth,fetch,install ]] || fail 'plasma plan: bluez packages and the Bluetooth step when it is off'
[[ "$(jq -r '.data.steps[1].commands[0]|join(" ")' <<<"$out")" == 'sudo systemctl enable --now bluetooth.service' ]] || fail 'plasma plan: the exact systemctl argv'
[[ ! -s "$SETUP_LOG" && ! -e "$tmp/state-home" ]] || fail 'plasma plan changed something'
run "$binary" setup plasma --yes >/dev/null 2>&1 || fail 'setup plasma --yes with the service off'
grep -Fq 'pacman -S --needed --noconfirm bluez bluez-utils' "$SETUP_LOG" || fail 'plasma installs bluez when it is missing'
grep -Fxq 'systemctl enable --now bluetooth.service' "$SETUP_LOG" || fail 'plasma turns the Bluetooth service on'
[[ "$(jq -r .bluetooth "$tmp/state-home/bxrig/setup-plasma.json")" == true && "$(stat -c %a "$tmp/state-home/bxrig/setup-plasma.json")" == 600 ]] || fail 'plasma remembers it turned the service on (private file)'
# already enabled: no step, nothing remembered
reset; MOCK_BT_ENABLED=1 run "$binary" setup plasma --yes >/dev/null 2>&1 || fail 'setup plasma with the service on'
grep -Fq 'bluetooth' "$SETUP_LOG" && fail 'an enabled service is left alone'
[[ ! -e "$tmp/state-home/bxrig/setup-plasma.json" ]] || fail 'nothing is remembered when setup did not enable it'
# bluez present, service off: only the service step comes before the checkout
reset; out="$(MOCK_INSTALLED="git kpackage python-dbus python-gobject qt6-tools swayidle bluez bluez-utils" run "$binary" setup plasma --dry-run --json)"
[[ "$(jq -r '.data.steps|map(.id)|join(",")' <<<"$out")" == bluetooth,fetch,install ]] || fail 'plasma plan: only the service step when bluez is there'
# --undo-keys never turns the service on
reset; mkdir -p "$tmp/home/.local/share/hyprkwin"; run "$binary" setup plasma --undo-keys --yes >/dev/null 2>&1 || fail '--undo-keys with the service off'
grep -Fq 'bluetooth' "$SETUP_LOG" && fail '--undo-keys must not touch the Bluetooth service'
# undo: turned off only when setup plasma turned it on
reset; mkdir -p "$tmp/home/.local/share/hyprkwin" "$tmp/state-home/bxrig"; echo '{"bluetooth":true}' > "$tmp/state-home/bxrig/setup-plasma.json"
MOCK_BT_ENABLED=1 run "$binary" setup undo plasma --yes >/dev/null 2>&1 || fail 'undo plasma with a remembered service'
grep -Fxq 'systemctl disable --now bluetooth.service' "$SETUP_LOG" || fail 'undo plasma turns the service off'
[[ "$(grep -n 'systemctl disable' "$SETUP_LOG" | cut -d: -f1)" -lt "$(grep -n '^UNINSTALL' "$SETUP_LOG" | cut -d: -f1)" ]] || fail 'the service goes off before the uninstall'
[[ ! -e "$tmp/state-home/bxrig/setup-plasma.json" ]] || fail 'undo forgets the record'
reset; mkdir -p "$tmp/home/.local/share/hyprkwin"; MOCK_BT_ENABLED=1 run "$binary" setup undo plasma --yes >/dev/null 2>&1 || fail 'undo plasma without a record'
grep -Fq 'bluetooth' "$SETUP_LOG" && fail 'undo leaves a service setup did not enable'
export MOCK_BT_ENABLED=1
reset; rm -rf "$tmp/home/.local"
unset MOCK_BT_ENABLED

# ---- hyprland: packages only
ALL="hyprland noctalia uwsm hyprlock xdg-desktop-portal-hyprland hyprpolkitagent qt6ct nwg-look hyprpicker grim slurp wl-clipboard brightnessctl playerctl ghostty adw-gtk-theme papirus-icon-theme noto-fonts noto-fonts-emoji bluez bluez-utils"
reset; [[ "$(code "$binary" setup hyprland)" == 2 ]] || fail 'hyprland without --yes exits 2'
[[ "$(code "$binary" setup hyprland --dry-run)" == 0 ]] || fail 'hyprland --dry-run exits 0'
run "$binary" setup hyprland --dry-run | grep -F 'sudo pacman -S --needed --noconfirm' >/dev/null || fail 'the plan shows the exact pacman command'
[[ ! -s "$SETUP_LOG" && ! -e "$tmp/state-home" ]] || fail 'plan or dry run changed something'
[[ "$(MOCK_UID=0 code "$binary" setup hyprland --yes)" == 4 ]] || fail 'hyprland as root exits 4'
[[ "$(OS_FILE="$tmp/os-other" code "$binary" setup hyprland --yes)" == 4 ]] || fail 'hyprland on an unsupported OS exits 4'
[[ ! -s "$SETUP_LOG" ]] || fail 'a refused run changed something'
# install: one pacman call with the missing packages; the added list is remembered
run "$binary" setup hyprland --yes >/dev/null 2>&1 || fail 'setup hyprland --yes'
call="$(grep '^pacman -S' "$SETUP_LOG")"
for p in $ALL; do grep -Fq " $p" <<<"$call" || fail "pacman call misses $p"; done
for bad in cachyos-hypr-noctalia noctalia-shell noctalia-qs; do grep -Fq "$bad" <<<"$call" && fail "$bad must not be installed"; done
[[ "$(jq -r '.packages|length' "$tmp/state-home/bxrig/setup-hyprland.json")" == "$(wc -w <<<"$ALL")" ]] || fail 'the added packages are remembered'
[[ "$(stat -c %a "$tmp/state-home/bxrig/setup-hyprland.json")" == 600 ]] || fail 'the state file is private'
# bluetooth.service is enabled after the packages (it is not enabled by itself); an enabled one is left alone
grep -Fxq 'systemctl enable --now bluetooth.service' "$SETUP_LOG" || fail 'the Bluetooth service is enabled'
[[ "$(grep -n '^pacman -S' "$SETUP_LOG" | cut -d: -f1)" -lt "$(grep -n '^systemctl enable' "$SETUP_LOG" | cut -d: -f1)" ]] || fail 'the service is enabled after bluez is installed'
run "$binary" setup hyprland --dry-run | grep -F 'sudo systemctl enable --now bluetooth.service' >/dev/null || fail 'the plan shows the exact systemctl command'
: > "$SETUP_LOG"; MOCK_BT_ENABLED=1 run "$binary" setup hyprland --yes >/dev/null 2>&1 || fail 'hyprland with the service already on'
grep -Fq 'systemctl enable' "$SETUP_LOG" && fail 'an enabled Bluetooth service is not enabled again'
reset; run "$binary" setup hyprland --yes >/dev/null 2>&1
# everything already there (packages, starter files and the Noctalia plugins of the run above): nothing to do
: > "$SETUP_LOG"; rm -rf "$tmp/state-home"; MOCK_BT_ENABLED=1 MOCK_INSTALLED="git $ALL" run "$binary" setup hyprland --yes | grep -F 'already installed' >/dev/null || fail 'already installed is reported'
[[ ! -s "$SETUP_LOG" && ! -e "$tmp/state-home" ]] || fail 'nothing to do must change nothing'
# some there: only the rest is installed and remembered
reset; MOCK_INSTALLED="git hyprland ghostty" run "$binary" setup hyprland --yes >/dev/null 2>&1 || fail 'partial install'
call="$(grep '^pacman -S' "$SETUP_LOG")"
grep -Fq ' hyprland' <<<"$call" && fail 'an installed package is not reinstalled'
jq -e '.packages|index("noctalia") and (index("ghostty")|not)' "$tmp/state-home/bxrig/setup-hyprland.json" >/dev/null || fail 'only added packages are remembered'
# pacman failing: exit 5 and nothing remembered
reset; [[ "$(MOCK_PACMAN_FAIL=1 code "$binary" setup hyprland --yes)" == 5 ]] || fail 'pacman failing exits 5'
[[ ! -e "$tmp/state-home" ]] || fail 'a failed install is not remembered'
# undo removes only what setup installed
reset; [[ "$(code "$binary" setup undo hyprland --yes)" == 4 ]] || fail 'undo without a record exits 4'
run "$binary" setup hyprland --yes >/dev/null 2>&1; : > "$SETUP_LOG"
MOCK_INSTALLED="git $ALL" run "$binary" setup undo hyprland --yes >/dev/null 2>&1 || fail 'undo hyprland'
grep -Fq 'pacman -Rs --noconfirm hyprland noctalia' "$SETUP_LOG" || fail 'undo removes the remembered packages'
grep -Fxq 'systemctl disable --now bluetooth.service' "$SETUP_LOG" || fail 'undo turns the Bluetooth service off first'
[[ ! -e "$tmp/state-home/bxrig/setup-hyprland.json" ]] || fail 'undo forgets them'
[[ "$(MOCK_INSTALLED=git run "$binary" setup status --json | jq -r '.data.hyprland.installed')" == 0 ]] || fail 'status counts the hyprland packages'
echo 'setup tests passed'
