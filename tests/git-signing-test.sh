#!/usr/bin/env bash
# `bxrig git signing`: SSH signing of commits and tags, with the real git in a throwaway HOME. Usage: git-signing-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
command -v git >/dev/null || { echo "skip: no git"; exit 0; }
mkdir -p "$tmp/home/.ssh" "$tmp/cfg"
run() { env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/cfg" GIT_CONFIG_NOSYSTEM=1 "$@"; }
g() { run git config --global --get "$1" || true; }

run "$binary" git signing --json | jq -e '.ok and .data.signing == "off"' >/dev/null || fail 'status on a fresh home'
[[ "$(code "$binary" git signing on --yes)" == 4 ]] || fail 'on without a key exits 4'
{ run "$binary" git signing on --yes 2>&1 || true; } | grep -q 'bxrig ssh key --yes' || fail 'on without a key says how to make one'
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxrigTestKeyOnlyForTheTestSuite000000000 ada@laptop' > "$tmp/home/.ssh/id_ed25519.pub"
[[ "$(code "$binary" git signing on --yes)" == 4 ]] || fail 'on without user.email exits 4'
run git config --global user.email ada@example.com
[[ "$(code "$binary" git signing on)" == 2 ]] || fail 'on without --yes is a plan (exit 2)'
[[ -z "$(g commit.gpgsign)" ]] || fail 'the plan changed git'
run "$binary" git signing on --dry-run --json | jq -e '.data.signer == "ada@example.com namespaces=\"git\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxrigTestKeyOnlyForTheTestSuite000000000"' >/dev/null || fail 'the allowed signers line'
run "$binary" git signing on --yes >/dev/null || fail 'on --yes'
[[ "$(g gpg.format)" == ssh && "$(g commit.gpgsign)" == true && "$(g tag.gpgsign)" == true && "$(g user.signingkey)" == "$tmp/home/.ssh/id_ed25519.pub" ]] || fail "git settings: $(run git config --global --list)"
[[ "$(g gpg.ssh.allowedSignersFile)" == "$tmp/cfg/git/allowed_signers" ]] && grep -q '^ada@example.com namespaces="git" ssh-ed25519 ' "$tmp/cfg/git/allowed_signers" || fail 'allowed signers file'
run "$binary" git signing on --yes >/dev/null
[[ "$(grep -c ada@example.com "$tmp/cfg/git/allowed_signers")" == 1 ]] || fail 'on twice adds the signer once'
run "$binary" git signing --json | jq -e '.data.signing == "on" and .data.commits and .data.tags' >/dev/null || fail 'status on'
run "$binary" git signing off --yes >/dev/null
[[ "$(g commit.gpgsign)" == false && "$(g tag.gpgsign)" == false && -n "$(g user.signingkey)" ]] || fail 'off stops signing and keeps the key'
[[ "$(code "$binary" git signing maybe)" == 2 && "$(code "$binary" git)" == 2 ]] || fail 'usage exits 2'
# --key: a private key path gets .pub
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIWorkKey0000000000000000000000000000000000 ada@work' > "$tmp/home/.ssh/work.pub"
run "$binary" git signing on --key="$tmp/home/.ssh/work" --yes >/dev/null; [[ "$(g user.signingkey)" == "$tmp/home/.ssh/work.pub" ]] || fail '--key'
echo "git signing tests passed"
