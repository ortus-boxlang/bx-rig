---
name: bxrig
description: "Use this skill when the user asks about BxRig, the developer rig tool: an opinionated, beautiful desktop for developers, built for CachyOS and Arch today (Hyprland + Noctalia, KDE Plasma): its commands, conventions, config files, how to run it safely, or how to change something on a machine that BxRig set up."
---

# BxRig

BxRig brings an opinionated, beautiful and efficient desktop to Linux, built for developers. Supported today: CachyOS and Arch Linux (Debian, Ubuntu and Fedora are the direction, not yet supported). It turns a CachyOS or Arch install into a finished developer rig: Hyprland with Noctalia (KDE Plasma stays installed beside it), BoxLang and MatchBox, apps, shell, AI agents. It is one native binary, `bxrig`, written in BoxLang and compiled with MatchBox. Docs: https://bxrig.boxlang.io

## Rules every command follows

- Read-only commands just run. A command that changes the system prints a **plan** and exits 2 until you add `--yes`. `--dry-run` prints the plan and exits 0.
- `--json` prints one envelope: `{ "command", "data", "exit", "ok", "schema": 1, "version", "warnings", "dry_run" }`. Use it when you parse output.
- Exit codes: 0 ok, 1 a check came out negative, 2 plan without `--yes` or bad usage (an unknown command or flag too), 3 timeout or not available, 4 a precondition failed (tool missing, bad name, unknown input), 5 the official (pacman) phase failed, 6 the AUR phase or the command you asked for failed, 7 partial success, 8 a config conflict (a file you edited, another run in progress), 9 internal error. `update check` uses 10 for "update available".
- Never edit generated files blindly: BxRig keeps a file you changed (it reports it as `drifted`) and only rewrites files it wrote itself.
- Never ask for or print API keys. Secrets live in the desktop keyring (`bxrig secrets`).

## Where things live

- Settings: `~/.config/bxrig/` (`answers.json` is the wizard's answers, `shortcuts.json` your key changes, `keystyle.json` the shortcut style, `runner.json`, `update.json`, `skills.json`).
- The binary: `~/.local/bin/bxrig`. Logs of the installer: `~/.cache/bxrig/install.log`.
- Hyprland module: `~/.config/hypr/bxrig.lua` (generated; your `hyprland.lua` is yours).

## Find your way

- `bxrig status`: what this machine already has. `bxrig init`: the setup wizard (`--rerun`, `--fresh`, `--defaults --yes`, `--answers=FILE --yes`).
- `bxrig menu`: the control center (`Super+Space`; `menu open ROUTE` opens one section, such as `capture` or `hardware`). `bxrig keys sheet`: every shortcut (`Super+K`).
- `bxrig doctor`, `bxrig gpu doctor`, `bxrig input doctor`, `bxrig dolphin doctor`: checks that print a fix for each problem.
- `bxrig help` lists every command by group, `bxrig help NAME` shows its usage and examples (the same text as the docs site's command reference).
- More: skills `bxrig-install-update`, `bxrig-desktop`, `bxrig-system`, `bxrig-apps`, `bxrig-ai`.
