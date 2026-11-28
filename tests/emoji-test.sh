#!/usr/bin/env bash
# `bxrig emoji list|recent|copy`: the gemoji data is packed, wl-copy is a stub. Usage: emoji-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
export BXRIG_BASE_URL=http://127.0.0.1:9
mkdir -p "$tmp/bin" "$tmp/home"
stub wl-copy 'cat > "'"$tmp"'/copied"'
run() { env HOME="$tmp/home" XDG_STATE_HOME="$tmp/home/.local/state" PATH="$tmp/bin:$PATH" "$@"; }
e() { run "$binary" emoji "$@" --json 2>/dev/null; }
e list | jq -e '.data.total > 1500 and (.data.categories | length == 9) and (.data.emoji | length == 200) and .data.emoji[0].emoji == "😀"' >/dev/null || fail 'list: all in Unicode order, 200 by default, nine categories'
e list --limit=5 | jq -e '.data.emoji | length == 5' >/dev/null || fail 'limit'
e list rocket | jq -e '.data.emoji[0].emoji == "🚀" and .data.emoji[0].name == "rocket"' >/dev/null || fail 'a name match ranks first'
e list happy --limit=50 | jq -e '.data.emoji | length > 3 and all(.[]; (.name + " " + .keywords) | contains("happy"))' >/dev/null || fail 'every word must match'
e list thumbs up | jq -e '.data.emoji | length > 0 and all(.[]; (.name + " " + .keywords) | (contains("thumb") and contains("up")))' >/dev/null || fail 'two words'
e list --category=flags --limit=300 | jq -e '.data.emoji | length > 200 and all(.[]; .category == "Flags")' >/dev/null || fail 'category part of the name'
e list --category=food pizza | jq -e '.data.emoji[0].emoji == "🍕"' >/dev/null || fail 'category and words'
e list zzzzqq | jq -e '.data.emoji | length == 0' >/dev/null || fail 'no match is an empty list'
[[ "$(run "$binary" emoji list --category=nope >/dev/null 2>&1; echo $?)" == 2 ]] || fail 'unknown category exits 2'
e recent | jq -e '.data.emoji | length == 0' >/dev/null || fail 'recent starts empty'
e copy 🎉 | jq -e '.data.copied == true' >/dev/null || fail 'copy'
[[ "$(cat "$tmp/copied")" == "🎉" ]] || fail 'wl-copy got the emoji'
e copy 🚀 >/dev/null; e copy 🎉 >/dev/null
e recent | jq -e '[.data.emoji[].emoji] == ["🎉","🚀"]' >/dev/null || fail 'recent: newest first, no repeats'
rm -f "$tmp/bin/wl-copy"
[[ "$(env HOME="$tmp/home" PATH="/usr/bin:/bin" "$binary" emoji copy 🎉 >/dev/null 2>&1; echo $?)" == 4 ]] || fail 'no wl-copy exits 4'
echo "emoji tests passed"
