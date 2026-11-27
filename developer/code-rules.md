---
title: Code rules
order: 12
summary: The fifteen rules that keep BxRig code DRY, grouped so you can scan them before a change.
---

# Code rules

The code review of 2026-11-14 ([CODE-REVIEW](../architecture/CODE-REVIEW.md)) found the same helper pasted into 20 to 57 classes. These rules keep that from coming back.

Rules marked **(ratchet)** are enforced by `bash tests/dry-test.sh`: each banned pattern has a maximum count that only goes down.

> **Note:** The rule numbers are the original ones; the page groups them by theme.

> **Tip:** Before you write a helper, run `grep -rn "function NAME" src/`. If it exists anywhere, use it or move it. Never paste it.

## Reuse before you write

**1. One home per concept.**
Why: ten copies means ten bugs.

**2. A command class never defines `say`, `fail`, `tryExec`, `has`, `env`, `home`, `self` or `merge` (ratchet).**
Why: each already has one home. Use `Cli`/`Out` for output, `Proc` for processes, `Env` for paths and variables, `Text` for strings.

**5. Parse each format once.**
Why: parsers drift apart. `.desktop` files go through `DesktopEntry` (parse, folders, entries, render).

The shared helpers are in `src/bxrig/util/`: `Cli`, `Out`, `Exit`, `Mutation`, `Proc`, `Env`, `Text`, `Fmt`, `Names`, `JsonStore`, `SystemFile`, `SystemdUnit`, `Systemd`, `Pacman`, `Aur`, `Http`, `Urls`, `Desktop`, `DesktopEntry`, `Ini`, `Props`, `Lua`, `Version`. The terminal UI helpers are `Modal`, `KeyMap` and `IntentRunner`. Copy what they do, not the old copies.

## Paths, processes and files

**3. Never read `HOME`, `XDG_*` or `BXRIG_*_HOME` directly. Ask `Env`.**
Why: one precedence everywhere: `BXRIG_*_HOME`, then `XDG_*_HOME`, then the default under `$HOME`. A new test override is added to `Env` and listed in [config files](../reference/config-files.md).

```boxlang
// yes
path = new bxrig.util.Env().config( "worldclock.json" );
// no
path = getSystemSetting( "HOME" ) & "/.config/bxrig/worldclock.json";
```

**4. Run programs only through `Proc`, with an argv array.**
Why: no shell string means no injection and one place to fake in tests. "Is it installed" is `Proc.has`; `Proc.works` is only for version checks.

**15. Start a program in the background with `Proc.detach`**, not another `setsid` string.
Why: one tested way to detach.

**7. Every file BxRig writes goes through `ConfigService`.**
Why: it gives backup, atomic replace and a journal, so `config restore` works. The config folder comes from `Env`.

## Commands and output

**6. Name exit codes by intent.**
Why: a typo must not become a wrong exit code. Use `out.usage` (2), `out.precondition` (4), `out.failed` (6). Do not invent new codes: the table in the [command contract](../architecture/COMMAND-CONTRACT.md) is the only list. An unknown command or flag exits 2.

**12. A new command is an entry in `docs/reference/cli.json` and a `case` in `src/Main.bx`.**
Why: `gen-docs.sh` fails when the two disagree. Usage text is `new bxrig.CommandSpec().usage( "name" )`, never a string. See [Add a command](add-a-command.md).

**13. Plans and dry runs are `Out.plan` (`util/Mutation`) (ratchet).**
Why: the wording and exit code are part of the contract. Write "Nothing was changed" nowhere else. A command that changes none of your files and only starts a program or flips your own setting acts at once and documents it.

**14. A key is a row of the one table in `Shortcuts.bx`**, with a Traditional and a Mac key.
Why: both styles must stay in sync. Run `keys conflicts` in both styles (`tests/shortcuts_test.bxs` does). A key that runs a command is `bx( ... )` with the words after `bxrig`, so `keys run ID` and the runner can run it, and the command gets a runner entry in `MenuTree`. See [Add a shortcut](add-a-shortcut.md).

## Data and generated files

**10. Data files are resources; a few files are generated.**
Why: edit data in place, regenerate only what is generated.

| Kind | Files | What you do |
|---|---|---|
| Resource | catalog, templates, themes, skills, wizard pages, brand images, `cli.json` (from `src/resources/`, which links to the real folders) | Edit the file. Nothing to regenerate. |
| Generated | `Version.bx`, `WallpaperData.bx`, `CommandFlagData.bx`, `docs/reference/commands.md`, `command-flags.md` | Change the source, run the `bootstrap/gen-*.sh`, commit both. CI runs them with `--check`. |

**11. One format, automated.**
Why: no style arguments in review. Tabs for indentation (shown 4 wide), LF, one final newline, no trailing spaces. Run `bash scripts/format.sh` before every commit; `bash scripts/format.sh --check` is the first thing CI runs, and a failure skips every other job. `git config core.hooksPath .githooks` installs a pre-commit hook that checks it. YAML keeps spaces and Markdown keeps its indentation. `.editorconfig` sets your editor.

## Tests

**9. Tests source `tests/lib/harness.sh` and do not define `fail`, `code` or the temp-dir trap again (ratchet).**
Why: one harness, no copies. `tests/run-all.sh` finds tests by name, and `tests/dry-test.sh` fails when a test file is not listed in `.github/workflows/ci.yml`. See [Tests](tests.md).

## MatchBox

**8. Respect the MatchBox quirks in shared code.**
Why: MatchBox differs from BoxLang on the JVM in ways that crash or silently misbehave.

- No base classes: compose and delegate.
- A class must not `new` its own class (stack overflow at load).
- No closures that call class methods.
- No postfix operators on indexes.
- Build large struct literals stepwise.
- Check a JSON key exists before reading it.
- Never name a variable like a function of the same class: `info = ...` hides `function info`.
- Strings compare case-insensitively with `==`. Compare exact-case keys with `compare()`.

## Documentation of your code

Every function and class in a `.bx` file has a DocBox comment, public or private: a one-sentence summary, `@param` for every argument and `@return`. Tests and generated classes are exempt. See `AGENTS.md` in the repository root, and the example in [Add a command](add-a-command.md).

## Advanced

The existing code is being brought up to the DocBox rule in a pass of its own. Until then, do not leave a function you add or change without its block.
