<p align="center"><img src="docs/brand/bxrig-banner.png" alt="BxRig, your Linux dev rig, anywhere." width="720"></p>

# BxRig

BxRig brings an opinionated, beautiful and efficient desktop to Linux, built for developers.

BxRig turns a fresh Linux install into a polished developer rig: a themed desktop, the languages and tools you use, and one terminal screen to manage it all.

**Supported: CachyOS, Arch Linux, openSUSE Tumbleweed and Slowroll, Ubuntu 26.04 LTS and Debian 13.** See [Distributions](docs/guides/distributions.md) for what each one offers.

> **Your dev rig. Beautiful by default.**

One command installs the toolchains, the desktop and your apps, then a setup wizard configures the rest. Hyprland with Noctalia is the default desktop and KDE Plasma stays installed beside it.

BxRig is a [BoxLang](https://boxlang.io) program compiled to a native executable with [MatchBox](https://github.com/ortus-boxlang/matchbox).

Docs: <https://bxcachy.boxlang.io> (built with bxSites from `docs/`).

## Install

```bash
curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxrig/install.sh | bash
```

It shows the plan, asks once, installs, and starts the wizard. The release information is signed (Ed25519) and checked before anything is installed.

Unattended, with saved answers:

```bash
curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxrig/install.sh | bash -s -- --yes --answers answers.json
```

Add `--channel beta` (or `--source beta`) for the bleeding-edge snapshots. Update later with `bxrig update apply --yes`.

Testing a branch (unsigned, for developers: it builds whatever that branch holds; it needs `--yes` or the typed word `unsigned`):

```bash
curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxrig/install.sh | bash -s -- --source github:ortus-boxlang/BxRig@development --yes
```

The installer installs MatchBox with `mvm`: the stable release by default, the snapshot build with `--snapshot`, or a branch built here with `--matchbox-branch REF` (the prebuilt BxRig only needs MatchBox as a toolchain; compiling BxRig needs the `bxrig` branch for now):

```bash
curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxrig/install.sh | bash -s -- --snapshot
curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxrig/install.sh | bash -s -- --matchbox-branch bxrig
```

Details: [getting started](docs/getting-started.md).

## What you get

| Area | What |
|---|---|
| Toolchains | Java 21, bvm, mvm, BoxLang, MatchBox, Rust. Optional: PHP, Python, Go, JavaScript runtimes |
| Desktop | Hyprland and Noctalia, KDE Plasma with HyprKwin tiling, one shortcut table in two styles (Traditional, classic Super-key tiling keys, or Mac, Cmd-style keys with the Alt and Win swap on a PC keyboard), xremap for the Cmd remaps, key cheat sheet |
| Control center | `bxrig menu` (`Super+Space`): every command as one searchable menu on your launcher (Rofi, Walker, Wofi, Fuzzel, Vicinae), with Shortcuts and Hardware sections; `bxrig menu open ROUTE` opens one section |
| Appearance and hardware | Bar, dock, windows, fonts, backgrounds, monitors, laptop power, time zone and DNS, each one command (`appearance`, `display`, `power`, `time`, `dns`) |
| Backups | BxRig setup snapshots, system snapshots (snapper), encrypted file backups (restic) to a NAS, a disk or the cloud, and **BxTimeMachine**, one screen for all of them (`bxrig timemachine`) |
| NAS | Synology or any SMB or NFS share: discover, mount, automatic mounts, mirror (`bxrig nas`) |
| Themes | 15 color themes in the `colors.toml` format (10 community themes, 5 of ours); follows into terminals, btop, window borders and Neovim |
| Shell and editor | zsh, fish or bash with Starship (shows the BoxLang version), Ghostty and other terminals, Neovim with LazyVim and BoxLang syntax |
| Apps | A curated catalog of about 290 apps by category, chosen in the wizard |
| Databases | PostgreSQL, MySQL, Redis, MongoDB, vector databases and more as local containers (`bxrig db`) |
| Virtual machines | Windows and Linux desktops in containers, any number of each (`bxrig vm`) |
| AI | Every major coding agent (Pi, Claude Code, Codex, Gemini CLI, OpenCode, Copilot, Cursor, Amp, Crush, Goose, Kiro, Qwen Code, Grok Build), local models on llama.cpp picked for your hardware (`bxrig ai setup`), your own BoxLang agents with bx-agents (`bxrig ai agents`) and Boxy, a desktop assistant that asks before it changes anything (`bxrig ai agents setup`, `Super+Period`), BxRig's tools in any agent or editor over MCP (`bxrig mcp link`), what leaves your machine with switches for a local model and telemetry (`bxrig privacy`), AI on the selected text (`Super+Alt+E`), API keys in your keyring (`bxrig secrets`), and agent skills (`bxrig skills`) |
| Safety | Every change is a plan until `--yes`; config files go through a backup and journal service and your own edits are never overwritten |

## Everyday commands

```bash
bxrig init                    # the wizard
bxrig menu                    # the control center
bxrig keys search screenshot  # find a shortcut by words or keys
bxrig record toggle --audio=desktop   # a screen recording with desktop audio
bxrig browser private         # your default browser in a private window
bxrig status                  # what is set up on this machine
bxrig theme set tokyo-night   # change the look
bxrig appearance bar position bottom
bxrig display scale DP-2 1.5
bxrig time sync --yes         # after you travel
bxrig timemachine             # every backup on one timeline
bxrig tui                     # the Control Center: dashboard and pages
bxrig tui apps                # find, install and remove software, Windows easy
bxrig tui databases           # one page on its own, like an app (bxrig tui list shows them all)
bxrig launchers on --yes      # optional: an application-menu entry per page
bxrig mail start --yes        # a local inbox for your app's mail
bxrig help                    # every command, or: bxrig help appearance (also bxrig --help, bxrig -h)
bxrig vm create linux dev     # a Linux desktop in a container
bxrig db start postgres --yes
bxrig skills install --yes    # BxRig, BoxLang and MatchBox skills for your agents
bxrig update check
```

The full list (113 commands) is in the [command reference](https://bxcachy.boxlang.io/reference/commands/). Every command supports `--json`, and mutating commands support `--dry-run`. A command that only touches your own settings or starts a program (themes, the bar, `window quake`, `webcam toggle`) acts at once and needs no `--yes`.

## Exit codes

`0` ok, `1` a check came out negative, `2` a plan was shown (no `--yes`) or bad usage (an unknown command or flag too), `3` timeout or not available, `4` a precondition failed (a tool is missing, an unknown name), `5` the official (pacman) phase failed, `6` the AUR phase or the command you asked for failed, `7` partial success, `8` a config conflict, `9` internal error, `10` an update is available. The names are in `src/bxrig/util/Exit.bx`.

## Development

```bash
scripts/setup-local.sh                       # one time: asks stable, snapshot or a MatchBox branch, builds dist/bxrig, smoke test
bash scripts/setup-local.sh --matchbox branch --matchbox-branch bxrig   # no question; any other branch or fork works the same
scripts/dev-build.sh                         # rebuilds dist/bxrig with that MatchBox
tests/run-all.sh                             # every test by discovery: *-test.sh with the binary, *_test.bxs with matchbox
bash tests/theme-test.sh dist/bxrig        # script tests, one per area (fake tools, no root needed)
(cd src && matchbox ../tests/init_plan_test.bxs)   # unit tests (35 `.bxs` files; they need no native build)
bash tests/dry-test.sh                       # ratchet: patterns that must not come back
```

Layout:

| Path | Contents |
|---|---|
| `src/Main.bx` | The CLI and its routes (the flags and usage of each command come from `docs/reference/cli.json`, the command registry) |
| `src/bxrig/` | One class per feature (`Vm`, `Theme`, `Db`, `Shortcuts`, `Skills`, ...) |
| `src/bxrig/util/` | The shared helpers: `Cli` and `Out` (output and the `--json` envelope), `Exit` (exit code names), `Mutation` (plan, dry run, run), `Proc`, `Env`, `JsonStore`, `Pacman`, `Aur`, `Systemd`, `Http`, ... |
| `catalog/apps.json` | The app catalog |
| `templates/`, `themes/`, `assets/`, `skills/` | Starter configs, themes, the wizard definition, images, and the agent skills that ship with BxRig |
| `bootstrap/` | The one-line installer and the `gen-*.sh` scripts that embed data into generated classes |
| `docs/` | The documentation site; `docs/architecture/COMMAND-CONTRACT.md` is the design record |
| `tests/` | 75 script tests (`*-test.sh`, with fake tools) and 35 unit tests (`*_test.bxs`); `tests/lib/` holds the shared harness |

Data files (the catalog, templates, themes, skills, wizard pages, brand images, the release key, `cli.json`, `box.json`) are packed into the binary as MatchBox resources: `src/resources/` links to them, `bxrig.util.Res` reads them, and running from source reads the same files from disk. Only `Version`, `WallpaperData` and `CommandFlagData` and `docs/reference/commands.md` and `command-flags.md` are still generated, by the matching `bootstrap/gen-*.sh`; CI runs each with `--check`.

Changes follow the contract in `docs/architecture/COMMAND-CONTRACT.md`: plan before `--yes`, `--dry-run`, the `--json` envelope, argument arrays instead of shell strings, and the exit codes above.

## Status

The version is the one in `box.json` (`bxrig version` prints it). The tests run against fake tools, so features that need real hardware or a live desktop (Hyprland, Noctalia, KVM virtual machines, GPUs, the signed install from the download bucket) are marked as unverified in the contract until they have been run on a real CachyOS machine.
