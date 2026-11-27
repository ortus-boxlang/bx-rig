---
title: Set up your dev machine
order: 2
summary: From git clone to a working loop of edit, build and test.
---

# Set up your dev machine

You will clone the repository, build `dist/bxrig`, and run the tests. The first run takes a while (it may build MatchBox); every run after that is quick.

## Quick start

1. Clone the repository.

   ```bash
   git clone https://github.com/ortus-boxlang/bxrig.git
   cd bxrig
   ```

2. Run the setup script once. It asks which MatchBox to use, builds `dist/bxrig`, runs a smoke test and sets up this machine.

   ```bash
   scripts/setup-local.sh
   ```

   To skip the question, name the choice:

   ```bash
   bash scripts/setup-local.sh --matchbox branch --matchbox-branch bxrig
   ```

3. Turn on the pre-commit hook so formatting never fails in CI.

   ```bash
   git config core.hooksPath .githooks
   ```

4. Check that everything works.

   ```bash
   dist/bxrig version
   tests/run-all.sh
   ```

> **Note:** Building needs a MatchBox with the terminal UI (`bif-tui`) and the class-file sharing fix. The script probes both and stops with the reason if one is missing. For now use the `branch` choice.

## The everyday loop

Each time you change code, do this.

```bash
scripts/dev-build.sh                 # rebuild dist/bxrig
dist/bxrig COMMAND --dry-run         # try your command by hand
tests/run-all.sh dist/bxrig NAME     # run the tests whose name contains NAME
bash scripts/format.sh               # tabs, LF, final newline
bash tests/dry-test.sh               # the ratchet and the CI test list
```

| Script | What it does |
|---|---|
| `scripts/setup-local.sh` | Picks a MatchBox, saves it in `.cache/dev.env`, builds, smoke-tests, provisions the machine. |
| `scripts/dev-build.sh` | Rebuilds `dist/bxrig` with the saved MatchBox. `MATCHBOX=/path/to/matchbox` overrides it. |
| `scripts/format.sh` | Formats the repository. `--check` lists what is unformatted and exits 1 (CI runs it first). |
| `tests/run-all.sh` | Runs every test. See [Tests](tests.md). |
| `tests/dry-test.sh` | The ratchet: banned patterns, the CI list and the format check. |

### Run from source, no build

The `.bxs` unit tests and one-off tries run straight from `src/`, so they need no build.

```bash
(cd src && matchbox ../tests/out_test.bxs)
```

`matchbox` is the one from `.cache/dev.env`, or the one on your `PATH`.

## Where things are

| Path | Contents |
|---|---|
| `src/Main.bx` | The router: one `case` per command. |
| `src/bxrig/` | One class per feature. |
| `src/bxrig/util/` | Shared helpers: `Cli`, `Out`, `Exit`, `Mutation`, `Proc`, `Env`, `Text`, `Res`, ... |
| `docs/reference/cli.json` | The command registry: summaries, usage, flags. |
| `catalog/`, `templates/`, `themes/`, `skills/`, `assets/` | Data files packed into the binary. |
| `bootstrap/` | The installer and the `gen-*.sh` scripts. |
| `scripts/` | Developer scripts (setup, build, format). |
| `tests/` | `*-test.sh` with fake tools, `*_test.bxs` unit tests, `lib/` shared harness. |
| `docs/` | This site. `docs/architecture/` holds the design records. |

## Advanced

### Choose another MatchBox

Name a branch, tag, fork or full commit id. Your own `../matchbox` checkout is never touched.

```bash
scripts/setup-local.sh --matchbox-branch develop
scripts/setup-local.sh --matchbox-branch feature/x --matchbox-repo someone/matchbox
scripts/setup-local.sh --matchbox-branch v0.14.0 --release
```

`BXRIG_MATCHBOX_BRANCH` and `BXRIG_MATCHBOX_REPO` do the same; the flags win. `stable` and `snapshot` come from `mvm`; the script stops if they fail the probes (the snapshot lacks the class-sharing fix for now).

### Build without touching the machine

After the build, `setup-local.sh` also installs packages and toolchains and starts `bxrig init`, like the web installer does.

| Flag | Effect |
|---|---|
| `--no-build` | Only probe and save the choice. |
| `--no-setup` | Build, but do not provision the machine. |
| `--no-wizard` | Provision, but skip `bxrig init`. |
| `--defaults` | Run `bxrig init --defaults --yes` when there is no terminal. |

### Generated files

`Version.bx`, `WallpaperData.bx`, `CommandFlagData.bx`, `docs/reference/commands.md` and `command-flags.md` are generated. Change the source and run `bootstrap/gen-*.sh`; CI runs each with `--check`. `dev-build.sh` already runs `gen-assets.sh` and `gen-version.sh`.
