#!/usr/bin/env bash
# Read-only package commands on the catalog, with a fake pacman. Usage: packages-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home/.local/share/applications"
# A pacman that reports a fixed set of installed packages.
cat > "$tmp/bin/pacman" <<'SH'
#!/usr/bin/env bash
[[ "$1 $2" == "-Qq " || "$1" == "-Qq" ]] && { printf '%s\n' git curl neovim; exit 0; }
exit 1
SH
chmod +x "$tmp/bin/pacman"
run() { env -i HOME="$tmp/home" PATH="$tmp/bin:$PATH" BXRIG_DISTRO=arch "$@"; }
rc() { set +e; "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
j() { run "$binary" "$@" --json; }

# installed detection
[[ "$(run "$binary" package-status git)" == 'git: installed' ]] || fail 'git installed'
[[ "$(rc run "$binary" package-status git)" == 0 ]] || fail 'installed exits 0'
[[ "$(rc run "$binary" package-status lazygit)" == 1 ]] || fail 'missing exits 1'
[[ "$(rc run "$binary" package-status nope-app)" == 3 ]] || fail 'unknown id exits 3'
[[ "$(rc run "$binary" package-status 'bad;id')" == 2 ]] || fail 'bad id exits 2'
[[ "$(j package-status git | jq -r '.data.installed')" == true ]] || fail 'status json'
# a web app is installed when its launcher exists
[[ "$(rc run "$binary" package-status boxlang-docs)" == 1 ]] || fail 'web app missing'
touch "$tmp/home/.local/share/applications/bxrig-boxlang-docs.desktop"
[[ "$(rc run "$binary" package-status boxlang-docs)" == 0 ]] || fail 'web app launcher counts as installed'

# an app that conflicts with an installed package (timeshift and CachyOS's snapper support) is skipped with the reason, not failed
cat > "$tmp/bin/pacman.conflict" <<'SH'
#!/usr/bin/env bash
[[ "$1" == "-Qq" ]] && { printf '%s\n' git cachyos-snapper-support; exit 0; }
exit 1
SH
cp "$tmp/bin/pacman" "$tmp/bin/pacman.plain"; cp "$tmp/bin/pacman.conflict" "$tmp/bin/pacman"
j install timeshift --dry-run | jq -e '(.data.would_install | length) == 0 and (.data.skipped | map(select(.id == "timeshift" and (.reason | contains("cachyos-snapper-support")))) | length) == 1' >/dev/null || fail "a conflict is skipped: $(j install timeshift --dry-run)"
cp "$tmp/bin/pacman.plain" "$tmp/bin/pacman"
j install timeshift --dry-run | jq -e '(.data.would_install | map(.id) == ["timeshift"])' >/dev/null || fail 'timeshift installs when nothing conflicts'

# an app installed by a script counts as installed when the program it puts in ~/.local/bin is there (strata), so a re-run does not hit "already exists"
[[ "$(rc run "$binary" package-status strata)" == 1 ]] || fail 'strata is not installed before its program exists'
mkdir -p "$tmp/home/.local/bin"; printf '#!/bin/sh\n' > "$tmp/home/.local/bin/strata"; chmod +x "$tmp/home/.local/bin/strata"
[[ "$(rc run "$binary" package-status strata)" == 0 ]] || fail 'strata is installed once ~/.local/bin/strata exists'
j install strata --dry-run | jq -e '(.data.would_install | length) == 0 and (.data.skipped | map(.id) | index("strata") != null)' >/dev/null || fail 'install skips an app whose program is already there'

# package-source reads the catalog
[[ "$(j package-source vscode | jq -r '.data.source')" == aur ]] || fail 'vscode source aur'
[[ "$(j package-source git | jq -r '.data.targets[0]')" == git ]] || fail 'git target'
[[ "$(rc run "$binary" package-source nope-app)" == 3 ]] || fail 'source unknown id'

# plan: installed apps are skipped, profile uses the profile tier
out="$(j plan --profile=core)"
[[ "$(jq -r '[.data.would_install[].id]|sort|join(",")' <<<"$out")" == jq,unzip ]] || fail 'core plan minus installed git, curl'
[[ "$(jq -r '[.data.skipped[]|select(.reason=="installed").id]|sort|join(",")' <<<"$out")" == curl,git ]] || fail 'installed skipped'
[[ "$(jq -r '.data.selection.mode' <<<"$out")" == profile ]] || fail 'selection mode'
out="$(j plan --profile=terminal --optional)"
jq -e '[.data.would_install[].id]|index("eza")' <<<"$out" >/dev/null || fail '--optional adds eza to terminal'
out="$(j plan --profile=terminal)"
jq -e '[.data.would_install[].id]|index("eza")|not' <<<"$out" >/dev/null || fail 'eza is optional in terminal'

# shells
out="$(env -i HOME="$tmp/home" PATH="$tmp/bin:$PATH" BXRIG_DISTRO=arch XDG_CURRENT_DESKTOP=KDE "$binary" plan --json)"
[[ "$(jq -r '.data.selection.shell' <<<"$out")" == plasma ]] || fail 'KDE detected as plasma'
out="$(j plan --shell=plasma)"
jq -e '[.data.skipped[]|select(.reason=="wrong_shell").id]|index("walker")' <<<"$out" >/dev/null || fail 'walker is wrong_shell on plasma'
out="$(j plan --shell=hyprland --optional)"
jq -e '[.data.skipped[]|select(.reason=="wrong_shell").id]|index("walker")|not' <<<"$out" >/dev/null || fail 'walker stays on hyprland'
out="$(j plan --shell=plasma)"
jq -e '[.data.skipped[]|select(.reason=="optional").id]|index("walker")|not' <<<"$out" >/dev/null || fail 'walker is not reported optional on plasma'
[[ "$(rc run "$binary" plan --shell=gnome)" == 2 ]] || fail 'unknown shell exits 2'

# named apps
out="$(j plan hyprsunset --shell=plasma)"
[[ "$(jq -r '.data.would_install[0].id' <<<"$out")" == hyprsunset ]] || fail 'named app ignores shell'
[[ "$(rc run "$binary" plan nope-app)" == 2 ]] || fail 'unknown app exits 2'
[[ "$(rc run "$binary" plan neovim --profile=core)" == 2 ]] || fail 'ids with --profile exit 2'
[[ "$(rc run "$binary" plan --profile)" == 2 ]] || fail '--profile needs a value'

# web apps pull in brave
out="$(j plan gmail)"
[[ "$(jq -r '[.data.would_install[].id]|join(",")' <<<"$out")" == brave,gmail ]] || fail 'plan gmail includes brave first'

# lists
[[ "$(j profile-list | jq '.data|length')" -ge 12 ]] || fail 'profile-list'
[[ "$(j profile-list | jq -r '.data[]|select(.id=="core")|.default')" == 4 ]] || fail 'core has 4 default apps'
[[ "$(j web-list | jq '[.data[]|select(.kind!="web")]|length')" == 0 ]] || fail 'web-list only web'
[[ "$(j optional-list | jq '[.data[]|select(.tier!="optional")]|length')" == 0 ]] || fail 'optional-list only optional'
echo 'packages tests passed'
