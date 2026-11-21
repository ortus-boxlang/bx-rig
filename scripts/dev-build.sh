#!/usr/bin/env bash
# Build bxrig with the MatchBox chosen by scripts/setup-local.sh (saved in .cache/dev.env).
# Output: ./dist/bxrig
#   MATCHBOX=/path/to/matchbox  override the compiler
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[[ -z "${MATCHBOX:-}" && -f "$root/.cache/dev.env" ]] && source "$root/.cache/dev.env"
mb="${MATCHBOX:-}"
[[ -n "$mb" && -x "$mb" ]] || { echo "No MatchBox set up (run scripts/setup-local.sh, or set MATCHBOX)" >&2; exit 4; }
# a MatchBox without the terminal UI (stable, snapshot) cannot compile bxrig: stop with the reason, never build with another one
. "$root/scripts/lib/matchbox-ref.sh"
mb_require_bxrig_capable "$mb" || exit 1
mkdir -p "$root/dist"
echo "  generating assets and version ..."
"$root/bootstrap/gen-assets.sh" >/dev/null
"$root/bootstrap/gen-version.sh" >/dev/null
# the BoxLang modules bxrig embeds (box.json toolchain.modules), passed to MatchBox with --module
echo "  resolving BoxLang modules ..."
modlist="$(MATCHBOX="$mb" "$root/scripts/get-modules.sh" "$root/.cache/modules")"
mods=()
while IFS= read -r m; do [[ -n "$m" ]] && mods+=( --module "$m" ); done <<<"$modlist"
echo "  compiling src/Main.bx -> dist/bxrig (native) ..."
# build beside the target and move it in: writing over a binary that is running fails with
# "Text file busy", and renaming over it does not
new="$root/dist/.bxrig.new"
rm -f "$new"
(cd "$root" && "$mb" "${mods[@]}" --target native --output "$new" src/Main.bx)
chmod 755 "$new"
mv -f "$new" "$root/dist/bxrig"
echo "built $root/dist/bxrig with $("$mb" --version 2>&1 | head -1)"
