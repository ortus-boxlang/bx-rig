---
title: Contributing and docs versions
order: 11
summary: How these docs are built, versioned and released.
---

# Contributing and docs versions

BxRig is written in BoxLang and compiled with MatchBox. The code is in `src/`, tests in `tests/`, and every command is described in the [command contract](../architecture/COMMAND-CONTRACT.md).

## These docs

The docs are built with [bxSites](https://bxsites.io) from `docs/` and `bxsites.yaml` and published to GitHub Pages at <https://bxrig.boxlang.io> by `.github/workflows/docs.yml` on every push to `development`.

```bash
bx-module install bx-sites
boxlang bxSites serve           # build and serve with live reload
boxlang bxSites build           # build to site/
```

## Versions

`docs/` is the version being written, **{{ version }}**. When it ships:

```bash
boxlang bxSites version:new --name=1.0.x      # freeze a copy in docs/versions/1.0.x
```

Then set `versions.default: "1.0.x"` in `bxsites.yaml`: the release is served at the root and `docs/` becomes `/next/`. Every theme gets a version switcher. Patch releases edit `docs/versions/1.0.x/` in place; a new minor or major cuts a new version.

## Languages

English only for now. Add one with `boxlang bxSites i18n:new --code=es` and list it under `i18n.locales` in `bxsites.yaml`; `i18n:status` reports coverage.

## Releases

Pushes to `development` publish the `beta` channel; a `v*` tag publishes `stable`. See [Updates and channels](updates.md) and [Security](security.md).

## Writing code that stays DRY

The code review of 2026-11-14 (`docs/architecture/CODE-REVIEW.md`) found the same helper pasted into 20 to 57 classes. These rules keep it from coming back. `tests/dry-test.sh` enforces the ones marked (ratchet): each banned pattern has a maximum count that only goes down.

1. **One home per concept.** Before writing a helper, `grep -rn "function NAME" src/`. If it exists anywhere, use it or move it; never paste it.
2. **A command class never defines `say`, `fail`, `tryExec`, `has`, `env`, `home`, `self` or `merge`** (ratchet). Use `Cli`/`Out` for output, `Proc` for processes, `Env` for paths and variables, `Text` for strings.
3. **Never read `HOME`, `XDG_*` or `BXRIG_*_HOME` directly.** Ask `Env` (`xdgConfig`, `xdgData`, `config`, `data`, `state`, `cache`). One precedence rule everywhere: `BXRIG_*_HOME`, then `XDG_*_HOME`, then the default under `$HOME`. A new override for tests is added to `Env` and listed in `docs/reference/config-files.md`.
4. **Run programs only through `Proc`**, with an argv array, never `sh -c` plus a concatenated name. "Is it installed" is `Proc.has` (`command -v`); `Proc.works` is only for version checks.
5. **Parse each format once.** `.desktop` files through `DesktopEntry` (parse, folders, entries, render). Compare exact-case keys with `compare()`, never `==`: strings compare case-insensitively on MatchBox.
6. **Name exit codes by intent** (`out.usage` 2, `out.precondition` 4, `out.failed` 6) and do not invent new ones; the table in the command contract is the only list. An unknown command or flag exits 2.
7. **Every file BxRig writes goes through `ConfigService`** (backup, atomic replace, journal), and the config folder comes from `Env`.
8. **Respect the MatchBox quirks in shared code:** no base classes (compose and delegate), a class must not `new` its own class (stack overflow at load), no closures that call class methods, no postfix operators on indexes, build large struct literals stepwise, check a JSON key exists before reading it, and never name a variable like a function of the same class (`info = ...` hides `function info`).
9. **Tests source `tests/lib/harness.sh`** and do not define `fail`, `code` or the temp-dir trap again (ratchet). Tests are found by name; `tests/run-all.sh` runs them all and `tests/dry-test.sh` fails when a test file is not listed in `.github/workflows/ci.yml`.
10. **Data files are resources, a few files are generated.** The catalog, templates, themes, skills, wizard pages, brand images and `cli.json` are packed into the binary from `src/resources/` (links to the real folders): edit the file, nothing to regenerate. `Version.bx`, `WallpaperData.bx`, `CommandFlagData.bx`, `docs/reference/commands.md` and `command-flags.md` are generated: change the source (`docs/reference/cli.json` is the curated one), run the `bootstrap/gen-*.sh`, commit both; CI runs them with `--check`.
11. **One format, automated.** Tabs for indentation (shown 4 wide), LF, one final newline, no trailing spaces; JSON in the standard layout with tabs. Run `bash scripts/format.sh` before every commit and make sure `bash scripts/format.sh --check` passes: it is the first thing CI job 1 runs, a failure there skips every other job (`tests/dry-test.sh` runs the same check, and `git config core.hooksPath .githooks` installs a pre-commit hook that does). YAML keeps spaces (YAML does not allow tabs) and Markdown keeps its indentation. Your editor picks the settings up from `.editorconfig`.
12. **A new command is an entry in `docs/reference/cli.json`** (summary, usage, examples, flags with types, whether it needs `--yes`) and a `case` in `src/Main.bx`; `gen-docs.sh` fails when the two disagree. Usage text is `new bxrig.CommandSpec().usage( "name" )`, never a string.
13. **Plans and dry runs are `Out.plan`** (`util/Mutation`): no wording of "Nothing was changed" outside it (ratchet). A command that changes none of your files and only starts a program or flips your own setting acts at once and documents it.
14. **A key is a row of the one table in `Shortcuts.bx`**, with a Traditional and a Mac key; then run `keys conflicts` in both styles (`tests/shortcuts_test.bxs` does). A key that runs a command is `bx( ... )` with the words after `bxrig`, so `keys run ID` and the runner can run it, and the command gets a runner entry in `MenuTree`.
15. **Start a program in the background with `Proc.detach`**, not another `setsid` string.

The shared helpers are in `src/bxrig/util/`: `Cli`, `Out`, `Exit`, `Mutation`, `Proc`, `Env`, `Text`, `Fmt`, `Names`, `JsonStore`, `SystemFile`, `SystemdUnit`, `Systemd`, `Pacman`, `Aur`, `Http`, `Urls`, `Desktop`, `DesktopEntry`, `Ini`, `Props`, `Lua`, `Version`. The TUI helpers are `Modal`, `KeyMap` and `IntentRunner`. All of them are built; copy what they do, not the old copies.

## Local setup

BxRig is always built with the MatchBox you choose. It needs both the terminal UI (the `bif-tui` feature) and the class-file sharing fix (MatchBox commit `e7812e6`); the snapshot has the first but not the second, because the MatchBox `bxrig` branch is ahead of `develop`. For now use the branch build. One script sets it up:

```bash
scripts/setup-local.sh                      # asks which MatchBox to use
bash scripts/setup-local.sh --matchbox branch --matchbox-branch bxrig   # or choose without the question
```

Without `--matchbox` it asks:

```text
Which MatchBox should BxRig use?
  1) stable    the released MatchBox from mvm
  2) snapshot  the snapshot MatchBox from mvm
  3) branch    build a branch of a MatchBox repository (needs git and Rust)
```

Choice 3 asks for the repository (default `ortus-boxlang/matchbox`) and the branch, tag or full commit id (default `bxrig`). With no terminal and no option it builds the `bxrig` branch and prints that choice.

| Choice | What it does | Needs |
|---|---|---|
| `stable` | `mvm install latest`, `mvm use latest`. | `mvm` |
| `snapshot` | `mvm install snapshot`, `mvm use snapshot`. | `mvm` |
| `branch` | Shallow clone of the repo and ref into `.cache/matchbox-src/<repo>-<ref>` (for example `ortus-boxlang-matchbox-bxrig`), refreshed with a shallow fetch when it exists, built with `cargo build --features bif-tui` (debug; `--release` for an optimized build). | `git`, Rust |

After the choice the script probes the MatchBox twice: it creates the terminal UI canvas (`createObject( "rust", "tui.TUI" )`) and compiles two cross-referencing class files to check that class files are compiled once (MatchBox commit `e7812e6`, on the `bxrig` branch). The snapshot has bif-tui now but not the class-sharing fix: with ~200 classes it takes minutes and >50 GB and produces a 1.2 GB binary instead of ~20 MB. If either probe fails it stops with the reason, records nothing and never switches to another MatchBox by itself. Otherwise it saves the choice in `.cache/dev.env` (gitignored), builds `dist/bxrig` with `scripts/dev-build.sh` and runs a smoke test. `--no-build` only probes and saves the choice. Run it again to switch. `scripts/dev-build.sh` and `tests/run-all.sh` read `.cache/dev.env`; a `MATCHBOX=/path/to/matchbox` variable overrides it (use it for your own `../matchbox` checkout: build it with `cargo build --features bif-tui`, then `MATCHBOX=../matchbox/target/debug/matchbox scripts/dev-build.sh`).

### Setting up the dev machine after the build

A successful build also provisions the machine through the same `bootstrap/install.sh` stages the web installer runs, in the same order:

1. `packages --yes` (missing packages, yay and Rust),
2. `toolchains --yes` with `BXRIG_MATCHBOX_FILE` pointing at the MatchBox selected above, so the compiler the machine uses is the one that built `dist/bxrig`,
3. `binary --yes --force --binary dist/bxrig`, so the installed `bxrig` is the binary just built (not a second compile and not a download),
4. `core --yes` (the core app profile),
5. `bxrig init` when there is a terminal.

If a stage fails, the script stops with that stage's name; the build stays in `dist/bxrig`. The download, signature and checksum work of the web installer is skipped because this tree is already the source of truth. Use `--no-setup` to build without touching the machine, `--no-wizard` to skip only `bxrig init`, and `--defaults` to run `bxrig init --defaults --yes` when there is no terminal (without either, a non-interactive run prints `Run: bxrig init` and finishes). Packages stage steps that need sudo can ask for a password; `packages --yes` also upgrades the system on Arch, exactly as the installer does.

`--matchbox edge` and `--matchbox source` were removed: use `--matchbox branch` (it builds the `bxrig` branch from source instead of downloading the published build).

### Testing with another MatchBox branch

To try a MatchBox pull request, a fork or any other branch, name it. The script clones that branch shallow (depth 1) into its own folder and builds it, so your `../matchbox` working tree is never touched:

```bash
scripts/setup-local.sh --matchbox-branch develop                         # ortus-boxlang/matchbox, branch develop
scripts/setup-local.sh --matchbox-branch feature/x --matchbox-repo someone/matchbox   # a fork (owner/name or a full https URL)
scripts/setup-local.sh --matchbox-branch v0.14.0 --release                # a tag, release build
scripts/setup-local.sh --matchbox-branch 0123456789abcdef0123456789abcdef01234567    # a commit: the full 40 character id
BXRIG_MATCHBOX_BRANCH=develop scripts/setup-local.sh                      # the same, from the environment
```

- `--matchbox-branch REF` (or `--matchbox-repo REPO`) alone means `--matchbox branch`. REF is anything `git clone --branch` accepts (branch or tag); a full commit id is fetched by itself. `--matchbox-repo REPO` is `owner/name` on GitHub or a full `https://` URL and defaults to `toolchain.matchbox.repo` in `box.json`. `BXRIG_MATCHBOX_BRANCH` and `BXRIG_MATCHBOX_REPO` do the same; the flags win. Values may contain only letters, digits and `. _ / @ + -` (a repo URL also `:` after `https`), may not start with a dash and are passed to git as arguments, never through a shell. Combined with `--matchbox stable` or `snapshot` they stop with exit 2.
- `.cache/dev.env` records `MATCHBOX` (the path), `MATCHBOX_REPO`, `MATCHBOX_REF` and `MATCHBOX_COMMIT` (for stable and snapshot the repo is `mvm (stable)` or `mvm (snapshot)` and the ref `latest` or `snapshot`), which `scripts/dev-build.sh` and `tests/run-all.sh` use.
- The MatchBox version does not matter: what counts are the two probes (terminal UI canvas and class-file sharing), not a version number.
- `scripts/get-matchbox.sh DEST --ref REF --repo REPO` does the same for scripts and CI: it builds that ref from source (release, no `--locked`) and writes `DEST` and `DEST.info` (with a `repo=` line). CI still uses it (and `.github/workflows/matchbox.yml`) to publish and consume the `bxrig` builds.
- At the end the script prints one summary: the MatchBox in use (repo, ref, commit, path), how to switch (`scripts/setup-local.sh --matchbox stable|snapshot|branch`) and the command that tests the end-user installer with it:

  ```bash
  BXRIG_MATCHBOX_FILE=/path/to/matchbox bash bootstrap/install.sh toolchains --yes
  ```

  `bootstrap/install.sh` installs that file under `~/.local/share/bxrig/matchbox/bin` instead of asking mvm (it must be an executable regular file, not a symlink, and run with `--version`); the file `cargo build` leaves in `target/debug/matchbox` (or `target/release/matchbox`) is such a file.

## Running the tests

```bash
scripts/dev-build.sh                      # rebuild dist/bxrig after a change
tests/run-all.sh                          # every shell and .bxs test (JOBS=3 by default)
tests/run-all.sh dist/bxrig theme         # only the tests whose name contains "theme"
bash tests/time-test.sh dist/bxrig        # one shell test
tests/run-all.sh dist/bxrig init_plan     # one .bxs test (runs from source, no build needed)
bash tests/dry-test.sh                    # the ratchet: banned patterns and the CI list
```

Shell tests (`*-test.sh`) run the binary against fake tools and need no root, so rebuild before running them. The `.bxs` unit tests run from `src/` and need no build. `wizard-test` is timing sensitive; run it alone with `JOBS=1` if it fails. Try a command by hand with `dist/bxrig COMMAND --dry-run`.
