#!/usr/bin/env bash
# `bxrig setup hyprland --yes` end to end with fake pacman, sudo, id: packages, images, starter configs, shortcut files. Usage: hyprland-setup-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
export BXRIG_WALLPAPER_DIR="$root/assets/wallpapers" BXRIG_BASE_URL=http://127.0.0.1:9   # the theme wallpapers come from the checkout, never the network
mkdir -p "$tmp/bin" "$tmp/home"
export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Q) exit 1 ;;
  -Qq) true ;;
  -S) echo "pacman $*" >> "$LOG" ;;
  --version) echo "Pacman v7.0" ;;
  *) exit 9 ;;
esac
MOCK
stub_sudo
stub_id
# systemctl: logs what it is asked; the Bluetooth service starts out not enabled
stub systemctl 'echo "systemctl $*" >> "$LOG"; [[ " $* " == *" is-enabled "* ]] && exit 1; exit 0'
printf '#!/usr/bin/env bash\necho x86_64\n' > "$tmp/bin/uname"
chmod +x "$tmp/bin/"*
printf 'ID=cachyos\n' > "$tmp/os"
mkdir -p "$tmp/sysd"
run() { env BXRIG_SYSTEMD_RUN_DIR="${SYSD_DIR:-$tmp/sysd}" BXRIG_OS_RELEASE="$tmp/os" BXRIG_STATE_HOME="$tmp/state" BXRIG_CONFIG_HOME="$tmp/cfg" HOME="$tmp/home" USER=dev PATH="$tmp/bin:$PATH" XDG_CURRENT_DESKTOP=Hyprland LOG="$LOG" "$@"; }

# plan only: nothing written
[[ "$(code "$binary" setup hyprland)" == 2 ]] || fail 'no --yes exits 2'
[[ ! -e "$tmp/cfg" && ! -e "$tmp/home/Pictures" ]] || fail 'the plan wrote files'
run "$binary" setup hyprland --dry-run --json | jq -e '.ok and (.data.steps | map(.id) | index("starter") != null)' >/dev/null || fail 'dry-run --json lists the starter step'

# a hyprland.lua the user already has is never overwritten: setup only adds the one load line to the end of it
mkdir -p "$tmp/cfg/hypr"; echo '-- mine' > "$tmp/cfg/hypr/hyprland.lua"
out="$(run "$binary" setup hyprland --yes --json)" || fail 'setup hyprland --yes --json failed'
echo "$out" | jq -e '.ok and (.data.done | map(.id) == ["packages","bluetooth","images","starter","keys"])' >/dev/null || fail "stdout is not one clean JSON envelope with all five steps done: $out"
grep -q '^systemctl enable --now bluetooth.service' "$LOG" || fail "the Bluetooth service is turned on: $(grep systemctl "$LOG")"
[[ "$(head -n 1 "$tmp/cfg/hypr/hyprland.lua")" == '-- mine' && "$(grep -c '^require("bxrig")$' "$tmp/cfg/hypr/hyprland.lua")" == 1 ]] || fail 'existing hyprland.lua was overwritten, or the load line was not added once'
grep -q 'pacman -S --needed --noconfirm hyprland' "$LOG" || fail 'packages installed'
cmp "$tmp/home/Pictures/BxRig/bxrig.jpg" "$root/assets/wallpapers/bxrig.jpg" || fail "wallpaper written"
grep -q 'custom_palette = "BxRig"' "$tmp/cfg/noctalia/config.toml" || fail 'noctalia config written'
[[ -f "$tmp/cfg/noctalia/palettes/BxRig.json" ]] || fail 'palette written'
[[ -f "$tmp/cfg/hypr/bxrig.lua" && -f "$tmp/cfg/xremap/config.yml" ]] || fail 'shortcut files written'

# no systemd running (a container): the Bluetooth service step is skipped with the reason, not failed, and systemctl is not asked to enable it
: > "$LOG"; out="$(SYSD_DIR="$tmp/no-such-dir" run "$binary" setup hyprland --yes --json)" || fail "setup in a container failed: $out"
echo "$out" | jq -e '.ok and (.data.skipped | map(select(.id == "bluetooth" and (.reason | test("systemd is not running")))) | length == 1) and (.data.failed | length == 0) and (.data.warnings | any(test("systemd is not running")))' >/dev/null || fail "the Bluetooth step is skipped with a reason: $out"
grep -q 'systemctl enable' "$LOG" && fail 'systemctl enable ran without systemd'
txt="$(SYSD_DIR="$tmp/no-such-dir" run "$binary" setup hyprland --yes 2>&1)"
grep -q '^Skipped: bluetooth (systemd is not running here' <<<"$txt" || fail "the text output names the skipped step and why: $txt"

# fresh machine: hyprland.lua is created, loads the module; a changed Noctalia file is kept on re-run
rm -rf "$tmp/cfg" "$tmp/home/Pictures" "$tmp/state"
[[ "$(code "$binary" setup hyprland --yes)" == 0 ]] || fail 'fresh setup exits 0'
grep -q 'require("bxrig")' "$tmp/cfg/hypr/hyprland.lua" || fail 'starter hyprland.lua loads the bxrig module'
grep -q 'hl.dsp.window.close()' "$tmp/cfg/hypr/bxrig.lua" || fail 'the module has Super+Q close (the starter keeps no binds)'
! grep -q 'hl.bind(' "$tmp/cfg/hypr/hyprland.lua" || fail 'the starter file holds no hand-written bind'
grep -q 'workspace = "2", persistent = true' "$tmp/cfg/hypr/hyprland.lua" || fail 'two persistent workspaces'
grep -q 'natural_scroll = false' "$tmp/cfg/hypr/hyprland.lua" || fail 'natural scrolling is off'
echo '# mine' >> "$tmp/cfg/noctalia/config.toml"; echo '-- also mine' >> "$tmp/cfg/hypr/hyprland.lua"
[[ "$(code "$binary" setup hyprland --yes)" == 0 ]] || fail 're-run exits 0'
grep -q '# mine' "$tmp/cfg/noctalia/config.toml" || fail 'a changed noctalia config was overwritten'
grep -q -- '-- also mine' "$tmp/cfg/hypr/hyprland.lua" || fail 'hyprland.lua was overwritten'
# the starter is valid Lua when a Lua is around
if command -v luac >/dev/null; then luac -p "$tmp/cfg/hypr/hyprland.lua" "$tmp/cfg/hypr/bxrig.lua" || fail 'starter Lua does not parse'; fi
echo "hyprland setup tests passed"
