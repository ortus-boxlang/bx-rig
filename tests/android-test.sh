#!/usr/bin/env bash
# `bxrig android` with a fake Waydroid that keeps its state in files (running or not, the image it was set up with, two apps), fake
# sudo, pacman and systemctl that record what they are given, and a fake kernel config. Nothing is installed. Usage: android-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
export LOG="$tmp/log"; : > "$LOG"
H="$tmp/home"; mkdir -p "$H" "$tmp/state" "$tmp/pending" "$tmp/bin"
# the fake Waydroid lives in pending/ until the fake pacman "installs" it
cat > "$tmp/pending/waydroid" <<'EOF'
#!/usr/bin/env bash
echo "waydroid $*" >> "$LOG"
case "$1" in
status)
	if [[ -f "$STATE/running" ]]; then printf 'Session:\tRUNNING\nContainer:\tRUNNING\nVendor type:\tMAINLINE\nIP address:\t192.168.240.112\nSession user:\tyou(1000)\nWayland display:\twayland-1\n'
	else printf 'Session:\tSTOPPED\nVendor type:\tMAINLINE\n'; fi ;;
init)
	img=VANILLA; while [[ $# -gt 0 ]]; do [[ "$1" == -s ]] && img="$2"; shift; done
	mkdir -p "$WAYDROID_DIR"; printf '[waydroid]\nsystem_ota = https://ota.waydro.id/system/lineage/waydroid_x86_64/%s.json\n' "$img" > "$WAYDROID_DIR/waydroid.cfg" ;;
session)
	case "$2" in start) touch "$STATE/running" ;; stop) rm -f "$STATE/running" ;; esac ;;
app)
	if [[ "$2" == list ]]; then
		[[ -f "$STATE/running" ]] || { echo "[ERROR] WayDroid session is stopped" >&2; exit 0; }
		printf 'Name: Settings\npackageName: com.android.settings\ncategories:\n\tandroid.intent.category.LAUNCHER\nName: F-Droid\npackageName: org.fdroid.fdroid\ncategories:\n\tandroid.intent.category.LAUNCHER\n'
	fi ;;
shell) printf '3456789012345678901\n' ;;
esac
EOF
chmod +x "$tmp/pending/waydroid"
stub_sudo_log
stub pacman 'echo "pacman $*" >> "$LOG"; case "$*" in *-S*waydroid*) cp "$tmp_pending/waydroid" "$tmp_bin/waydroid" ;; *-R*waydroid*) rm -f "$tmp_bin/waydroid" ;; esac'
sed -i "s|\$tmp_pending|$tmp/pending|g; s|\$tmp_bin|$tmp/bin|g" "$tmp/bin/pacman"
stub systemctl 'echo "systemctl $*" >> "$LOG"'
stub xdg-open 'echo "xdg-open $*" >> "$LOG"'
stub zcat 'printf "CONFIG_ANDROID_BINDER_IPC=y\n"'
stub modinfo 'exit 1'
: > "$tmp/filesystems"
run() { env HOME="$H" XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY= BXRIG_SELF=bxrig STATE="$tmp/state" WAYDROID_DIR="$tmp/waydroid" BXRIG_WAYDROID_DIR="$tmp/waydroid" BXRIG_PROC_FILESYSTEMS="$tmp/filesystems" LOG="$LOG" PATH="$tmp/bin:$PATH" "$@"; }
an() { run "$binary" android "$@"; }
waitfor() { local i; for i in $(seq 1 60); do grep -q -- "$1" "$LOG" && return 0; sleep 0.1; done; fail "never logged: $1 (log: $(cat "$LOG"))"; }

# ---- off by default ----
an --json | jq -e '.data.installed == false and .data.initialized == false and .data.running == false and .data.supported and .data.wayland and .data.binder.ok' >/dev/null || fail "status off: $(an --json)"
an | grep -q 'Android (Waydroid) is off: it is not set up, and BxRig does nothing about it until you ask' || fail 'the status text says it is off'
for v in start stop apps; do [[ "$(code "$binary" android $v)" == 4 ]] || fail "$v before setup is a precondition"; done
[[ "$(code "$binary" android open)" == 4 && "$(code "$binary" android register)" == 4 ]] || fail 'open and register before setup'
[[ ! -s "$LOG" ]] || fail "nothing ran: $(cat "$LOG")"

# ---- setup: the plan first, then the steps in order ----
{ an setup --json || true; } > "$tmp/plan.json"
jq -e '.data.image == "GAPPS" and (.data.steps | length) == 4 and (.data.steps[0].command | endswith("pacman -S --needed --noconfirm waydroid"))' "$tmp/plan.json" >/dev/null || fail "setup plan: $(jq -c .data "$tmp/plan.json")"
[[ "$(code "$binary" android setup)" == 2 ]] || fail 'setup without --yes is a plan (exit 2)'
[[ ! -s "$LOG" && ! -e "$tmp/bin/waydroid" ]] || fail 'the plan installed nothing'
an setup --yes > "$tmp/setup.out"
grep -q 'Android is running' "$tmp/setup.out" && grep -q 'bxrig android register' "$tmp/setup.out" || fail "setup output: $(cat "$tmp/setup.out")"
grep -n 'sudo pacman -S --needed --noconfirm waydroid\|sudo waydroid init -s GAPPS\|sudo systemctl enable --now waydroid-container.service\|^waydroid session start' "$LOG" | cut -d: -f2- > "$tmp/order"
[[ "$(sed 's/ .*//' "$tmp/order" | tr '\n' ' ')" == 'sudo sudo sudo waydroid ' ]] || fail "setup steps in order: $(cat "$tmp/order")"
grep -q 'system_ota.*GAPPS.json' "$tmp/waydroid/waydroid.cfg" || fail 'the Google Play image'
an --json | jq -e '.data.installed and .data.initialized and .data.image == "GAPPS" and .data.running and .data.ip == "192.168.240.112"' >/dev/null || fail "status after setup: $(an --json)"
an setup --yes | grep -q 'already set up and running' || fail 'setup again does nothing'

# ---- apps, open, install, register ----
an apps --json | jq -e '[.data.apps[].name] == ["F-Droid","Settings"] and .data.apps[1].package == "com.android.settings"' >/dev/null || fail "apps: $(an apps --json)"
an apps | grep -q 'F-Droid *org.fdroid.fdroid' || fail 'apps text'
an open > /dev/null; waitfor 'waydroid show-full-ui'
an open Settings > /dev/null; waitfor 'waydroid app launch com.android.settings'
an open droid | grep -q 'F-Droid is opening' || fail 'open by a part of the name'; waitfor 'waydroid app launch org.fdroid.fdroid'
[[ "$(code "$binary" android open nothing-like-it)" == 2 ]] || fail 'an unknown app is a usage error'
printf 'x' > "$tmp/demo.apk"; : > "$tmp/notes.txt"
[[ "$(code "$binary" android install "$tmp/demo.apk")" == 2 ]] || fail 'install without --yes is a plan'
! grep -q 'app install' "$LOG" || fail 'the plan installed nothing'
an install "$tmp/demo.apk" --yes | grep -q 'demo.apk is installed' || fail 'install'; grep -q "waydroid app install $tmp/demo.apk" "$LOG" || fail 'waydroid got the file'
[[ "$(code "$binary" android install "$tmp/notes.txt" --yes)" == 2 && "$(code "$binary" android install "$tmp/missing.apk" --yes)" == 2 && "$(code "$binary" android install)" == 2 ]] || fail 'not an apk, no file, no argument'
an register --json | jq -e '.data.android_id == "3456789012345678901" and .data.url == "https://www.google.com/android/uncertified"' >/dev/null || fail "register: $(an register --json)"
! grep -q xdg-open "$LOG" || fail 'register does not open a page unless asked'
an register --open >/dev/null; grep -q 'xdg-open https://www.google.com/android/uncertified' "$LOG" || fail 'register --open'
grep -q 'sudo waydroid shell -- sh -c sqlite3 /data/data/\*/\*/gservices.db' "$LOG" || fail "register reads the Android ID the documented way: $(grep shell "$LOG")"

# ---- stop and start ----
an stop | grep -q 'Android is stopped' || fail 'stop'; [[ ! -f "$tmp/state/running" ]] || fail 'stopped'
an stop | grep -q 'already stopped' || fail 'stop again'
[[ "$(code "$binary" android apps)" == 4 ]] || fail 'apps needs it running'
an start | grep -q 'Android is running' || fail 'start'; [[ -f "$tmp/state/running" ]] || fail 'started'
an start | grep -q 'already running' || fail 'start again'
an open Settings > /dev/null; [[ "$(grep -c 'app launch com.android.settings' "$LOG")" -ge 2 ]] || fail 'open starts Android first when it is stopped'

# ---- another image replaces the first, and the vanilla image has nothing to register ----
{ an setup --vanilla --json || true; } | jq -e '(.data.steps | length) == 3 and (.data.steps[0].command | endswith("waydroid init -s VANILLA -f")) and (.data.steps[0].title | startswith("replace"))' >/dev/null || fail 'vanilla over Google Play is a forced replacement'
an setup --vanilla --yes >/dev/null; grep -q 'VANILLA.json' "$tmp/waydroid/waydroid.cfg" || fail 'the vanilla image'
[[ "$(code "$binary" android register)" == 4 ]] || fail 'no Google Play on the vanilla image: precondition'

# ---- remove: the plan, then the steps; data only with --data ----
mkdir -p "$H/.local/share/waydroid"; : > "$tmp/waydroid/keep"
{ an remove --json || true; } | jq -e '(.data.steps | map(.title) | join(",") | contains("waydroid package")) and (.data.steps | map(.command) | join(" ") | contains("rm -rf") | not)' >/dev/null || fail 'remove plan has no rm'
[[ "$(code "$binary" android remove)" == 2 ]] || fail 'remove without --yes is a plan'
: > "$LOG"; an remove --yes >/dev/null
grep -q 'sudo systemctl disable --now waydroid-container.service' "$LOG" && grep -q 'sudo pacman -Rns --noconfirm waydroid' "$LOG" || fail "remove steps: $(cat "$LOG")"
[[ -e "$tmp/waydroid/keep" && -d "$H/.local/share/waydroid" ]] || fail 'without --data its files stay'
cp "$tmp/pending/waydroid" "$tmp/bin/waydroid"; touch "$tmp/state/running"
{ an remove --data --json || true; } | jq -e '(.data.steps | map(.command) | join(" ") | contains("rm -rf")) and (.data.steps | map(.title) | join(",") | contains("DELETE"))' >/dev/null || fail 'remove --data says DELETE'
: > "$LOG"; an remove --data --yes >/dev/null
grep -q "sudo rm -rf $tmp/waydroid $H/.local/share/waydroid" "$LOG" || fail "remove --data: $(cat "$LOG")"
[[ ! -e "$tmp/waydroid" && ! -e "$H/.local/share/waydroid" ]] || fail 'the data is gone'
rm -f "$tmp/bin/waydroid"; an remove | grep -q 'not set up; nothing to remove' || fail 'remove when there is nothing'

# ---- what stops setup, with the reason ----
: > "$LOG"
{ run env BXRIG_DISTRO=suse "$binary" android setup --yes 2>&1 || true; } | grep -q 'openSUSE has no Waydroid package' || fail 'openSUSE is refused with a reason'
{ run env XDG_SESSION_TYPE=x11 "$binary" android setup --yes 2>&1 || true; } | grep -q 'needs a Wayland session' || fail 'X11 is refused'
stub zcat 'exit 1'
{ an setup --yes 2>&1 || true; } | grep -q 'no binder driver' || fail 'no binder is refused'
[[ "$(code "$binary" android setup --yes)" == 4 ]] || fail 'no binder is a precondition'
printf 'nodev\tbinder\n' > "$tmp/filesystems"
{ an setup --json || true; } | jq -e '.data.steps | length > 0' >/dev/null || fail 'binderfs in /proc/filesystems counts'
[[ ! -s "$LOG" ]] || fail "a refused setup ran nothing: $(cat "$LOG")"

# ---- Ubuntu and Debian add Waydroid's repository first ----
{ run env BXRIG_DISTRO=ubuntu "$binary" android setup --json || true; } | jq -e '(.data.steps | length) == 5 and (.data.steps[0].command | contains("repo.waydro.id")) and (.data.steps[1].command | contains("apt"))' >/dev/null || fail 'Ubuntu: the repository, then apt'
echo 'android-test: ok'
