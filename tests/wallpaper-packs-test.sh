#!/usr/bin/env bash
# `bxrig assets wallpapers` and `theme wallpaper`: a local git repo stands in for the pack. Usage: wallpaper-packs-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
export BXRIG_BASE_URL=http://127.0.0.1:9
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/state"
stub_id
repo="$tmp/pack"
git init -q "$repo"
git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
mkdir -p "$repo/tokyo-night" "$repo/nord"
echo a > "$repo/tokyo-night/1.png"; echo b > "$repo/tokyo-night/2.jpg"; echo c > "$repo/nord/1.webp"; echo n > "$repo/tokyo-night/notes.txt"
echo "MIT test licence" > "$repo/LICENSE"
git -C "$repo" add -A; git -C "$repo" commit -q -m pack; git -C "$repo" tag v2026.11.27
commit="$(git -C "$repo" rev-parse HEAD)"
run() { env HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" BXRIG_WALLPAPER_PACK_REPO="$repo" BXRIG_WALLPAPER_PACK_COMMIT="$commit" "$@"; }
dest="$tmp/home/Pictures/BxRig/omarchy"
run "$binary" assets wallpapers | grep -q 'not installed' || fail 'list shows not installed'
run "$binary" assets wallpapers --json | jq -e '.data.packs[0].id == "omarchy" and .data.packs[0].installed == false' >/dev/null || fail 'list --json'
[[ "$(run "$binary" assets wallpapers install omarchy >/dev/null; echo $?)" == 2 ]] || fail 'install without --yes exits 2'
[[ "$(run "$binary" assets wallpapers install omarchy --dry-run >/dev/null; echo $?)" == 0 ]] || fail 'dry run exits 0'
[[ ! -e "$dest" ]] || fail 'plan wrote files'
[[ "$(run "$binary" assets wallpapers install nope --yes >/dev/null; echo $?)" == 4 ]] || fail 'unknown pack exits 4'
# a wrong commit is refused and leaves nothing
[[ "$(run env BXRIG_WALLPAPER_PACK_COMMIT=deadbeef "$binary" assets wallpapers install omarchy --yes >/dev/null; echo $?)" == 6 ]] || fail 'wrong commit exits 6'
[[ ! -e "$dest" && ! -e "$dest.download" ]] || fail 'a refused pack left files'
[[ "$(run "$binary" assets wallpapers install omarchy --yes >/dev/null; echo $?)" == 0 ]] || fail 'install --yes exits 0'
[[ -f "$dest/tokyo-night/1.png" && -f "$dest/tokyo-night/2.jpg" && -f "$dest/nord/1.webp" ]] || fail 'images missing'
[[ ! -e "$dest/tokyo-night/notes.txt" ]] || fail 'a non image was copied'
grep -q 'MIT test licence' "$dest/CREDITS.md" || fail 'CREDITS.md lacks the licence'
[[ ! -e "$dest.download" ]] || fail 'work folder left'
run "$binary" assets wallpapers --json | jq -e '.data.packs[0].installed_images == 3' >/dev/null || fail 'installed count'
# theme wallpaper next cycles the current theme's images
mkdir -p "$tmp/home/.config/bxrig"; echo '{"name":"tokyo-night","mode":"theme"}' > "$tmp/home/.config/bxrig/theme.json"
run "$binary" theme wallpaper next --dry-run --json | jq -e '.data.choices >= 2' >/dev/null || fail 'theme wallpaper plan'
run "$binary" theme wallpaper next >/dev/null; first="$(cat "$tmp/state/bxrig/wallpaper.txt")"
run "$binary" theme wallpaper next >/dev/null; second="$(cat "$tmp/state/bxrig/wallpaper.txt")"
[[ -n "$first" && "$first" != "$second" ]] || fail 'next did not move'
[[ "$(run "$binary" assets wallpapers remove omarchy >/dev/null; echo $?)" == 2 ]] || fail 'remove without --yes exits 2'
run "$binary" assets wallpapers remove omarchy --yes >/dev/null; [[ ! -e "$dest" ]] || fail 'remove left files'
echo "wallpaper pack tests passed"
