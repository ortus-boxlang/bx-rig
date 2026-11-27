#!/usr/bin/env bash
# `bxrig clipboard list|show|copy`: cliphist and wl-copy are stubs. Usage: clipboard-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
export BXRIG_BASE_URL=http://127.0.0.1:9
mkdir -p "$tmp/bin" "$tmp/home"
stub_id
printf '12\tgit commit -m "fix"\n11\t[[ binary data 12 KiB png 800x600 ]]\n10\thttps://example.com/docs\n' > "$tmp/history"
cat > "$tmp/bin/cliphist" <<STUB
#!/usr/bin/env bash
case "\$1" in
	list) cat "$tmp/history" ;;
	decode) id="\$(cat)"; id="\$(printf %s "\$id" | tr -d '[:space:]')"; grep -P "^\${id}\t" "$tmp/history" | cut -f2- ;;
esac
STUB
chmod +x "$tmp/bin/cliphist"
stub wl-copy 'cat > "'"$tmp"'/copied"'
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$@"; }
c() { run "$binary" clipboard "$@" --json 2>/dev/null; }
c list | jq -e '.data.entries | length == 3 and .[0].id == "12" and .[0].kind == "text" and .[1].kind == "image"' >/dev/null || fail 'list rows, newest first, image kind'
c list docs | jq -e '.data.entries | length == 1 and .[0].id == "10"' >/dev/null || fail 'list filters by words'
c list image | jq -e '.data.entries | length == 1 and .[0].id == "11"' >/dev/null || fail 'images match the word image'
c list --limit=2 | jq -e '.data.entries | length == 2' >/dev/null || fail 'limit'
c show 12 | jq -e '.data.kind == "text" and (.data.text | contains("git commit"))' >/dev/null || fail 'show text'
c show 11 | jq -e '.data.kind == "image" and (.data.details | contains("png"))' >/dev/null || fail 'show image details'
[[ "$(run "$binary" clipboard show 99 >/dev/null 2>&1; echo $?)" == 4 ]] || fail 'unknown id exits 4'
[[ "$(run "$binary" clipboard show abc >/dev/null 2>&1; echo $?)" == 2 ]] || fail 'bad id exits 2'
c copy 10 | jq -e '.data.copied == true' >/dev/null || fail 'copy'
grep -q 'https://example.com/docs' "$tmp/copied" || fail 'wl-copy got the entry'
echo "clipboard tests passed"
