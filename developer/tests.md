---
title: Tests
order: 11
summary: How BxRig tests work, how to run one or all of them, and how to write a new one.
---

# Tests

Tests never touch your real machine. They run the program against fake tools in a scratch folder, so they need no root and no network.

## Run them

```bash
tests/run-all.sh                          # every test (JOBS=3 in parallel by default)
tests/run-all.sh dist/bxrig theme         # only tests whose name contains "theme"
bash tests/time-test.sh dist/bxrig        # one shell test
tests/run-all.sh dist/bxrig init_plan     # one .bxs test (runs from source, no build)
bash tests/dry-test.sh                    # the ratchet
```

Rebuild with `scripts/dev-build.sh` first: shell tests run `dist/bxrig`. The `.bxs` tests run from `src/` and need no build.

> **Tip:** `wizard-test` is timing sensitive. If it fails, run it alone with `JOBS=1 tests/run-all.sh dist/bxrig wizard`.

## Two kinds of test

| Kind | File | Runs | Use it for |
|---|---|---|---|
| Shell test | `tests/NAME-test.sh` | The built binary, with fake tools on `PATH` | A command end to end: exit codes, plan, `--json`, which tools were called |
| Unit test | `tests/NAME_test.bxs` | `matchbox` from `src/`, no build | A class or helper on its own |

`tests/run-all.sh` finds both by name. `native-package-integration.sh` is skipped (it needs a sandbox); `tests/arch/` holds the real-pacman suite.

## Write a shell test

A test starts by sourcing the harness. The harness gives you `binary`, `root`, `tmp` (a scratch folder removed on exit), `fail`, `stub` and `code`.

```bash
#!/usr/bin/env bash
# `bxrig dnsflush` with a fake resolvectl. Usage: dnsflush-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
export LOG="$tmp/log"; : > "$LOG"
stub resolvectl 'echo "resolvectl $*" >> "$LOG"'
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }

[[ "$(code "$binary" dnsflush)" == 2 ]] || fail 'without --yes it is a plan'
run "$binary" dnsflush --yes >/dev/null
grep -qF 'resolvectl flush-caches' "$LOG" || fail 'the flush did not run'
```

1. **Fake the tools.** `stub NAME 'bash body'` writes an executable into `$tmp/bin`. Log each call to a file and assert on the log.
2. **Define `run()`.** It sets the environment: `HOME`, `PATH="$tmp/bin:$PATH"` and any `BXRIG_*` override (for example `BXRIG_CONFIG_HOME`, `BXRIG_STATE_HOME`). The list of overrides is in `Env.names()`.
3. **Assert exit codes with `code`.** `code CMD...` prints the exit code of `run CMD...`.
4. **Check `--json` with `jq -e`.** Assert on `.ok`, `.exit`, `.dry_run` and `.data`.
5. **Prove a plan changed nothing.** Check the fake zone file or the log is untouched after a run without `--yes`.
6. **List it in CI.** See below.

Helpers in `tests/lib/harness.sh`:

| Helper | What it does |
|---|---|
| `stub NAME BODY` | An executable `$tmp/bin/NAME` with that bash body. |
| `stub_id` | `id -u` answers 1000 (`MOCK_UID` changes it). |
| `stub_sudo`, `stub_sudo_log` | `sudo` runs the command; the log variant records `sudo ARGS` in `$LOG` first. |
| `code CMD...` | The exit code of `run CMD...`, output hidden. |
| `fail MSG` | Print `FAIL: MSG` and exit 1. |

The harness also unsets the `XDG_*` variables and sets `BXRIG_DISTRO=arch`, so a CI runner behaves like the Arch the tests describe. Do not define `fail`, `code` or the temp-dir trap again in a test.

## Write a unit test

Unit tests use `lib.Check` (`tests/lib/Check.bx`) and run from `src/`.

```boxlang
testkit = new lib.Check( "out" );
cli = new bxrig.util.Cli( "0.0.0" );
testkit.check( "Out.usage is 2", cli.scoped( "demo" ).usage( "bad", false ) == 2 );
testkit.done();
```

`check( label, ok )` prints `ok` or `FAIL` lines, `tmp()` gives a scratch folder, and `done()` exits 1 when anything failed. Run it with `(cd src && matchbox ../tests/NAME_test.bxs)`. Tests (`*.bxs`) do not need DocBox comments.

## Every test is listed in CI

`tests/dry-test.sh` fails when a `*-test.sh` or `*_test.bxs` file is not named in `.github/workflows/ci.yml`, and when a tracked `*.sh` is missing from CI's `bash -n` list. So a new test needs two edits in `ci.yml`: a run line (shell tests use `bash tests/NAME-test.sh "$candidate"`, unit tests `(cd src && matchbox ../tests/NAME_test.bxs)`) and, for a shell test, its name in the `bash -n` list.

## Advanced

### The ratchet

`tests/dry-test.sh` counts banned patterns (a command class that defines its own `say`, `fail` or `has`, hand-written "Nothing was changed" footers, bare exit numbers, `getSystemSetting` outside `Env`, `pacman` or `curl` argv lists outside `util/`). Each has a maximum that only goes down. When a refactor removes copies, the script prints `note: ... lower the maximum` and you lower it. Never raise one. It also runs `scripts/format.sh --check`.

### What every changing command should test

From the [contract](../architecture/COMMAND-CONTRACT.md) (section 7): success, no-op, invalid input, dependency failure, privilege rejection, partial failure and recovery. Cases that need KDE, Wayland or real hardware are marked manual.

### Speed

Shell tests start the native binary for each call, so keep the number of calls small. For logic with many cases, prefer a `.bxs` unit test.
