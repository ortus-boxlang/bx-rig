---
title: Command reference
order: 1
summary: Every bxrig command with its usage, examples and exit codes.
---

# Command reference

Every command is `bxrig NAME ...`. This page is generated from `docs/reference/cli.json`; the same data answers `bxrig help` and `bxrig help NAME` in the terminal. The [command contract](../architecture/COMMAND-CONTRACT.md) has the details behind each one.

## How commands behave

| Flag | What it does |
|---|---|
| `--json` | Print one JSON object instead of text (see below). Every command takes it. |
| `--yes` | Apply a change that installs packages or edits system files. Without it you get the plan and exit code 2. |
| `--dry-run` | Print the plan or the exact commands and exit 0. Nothing is changed. |
| `--force` | Where it exists: replace a file BxRig would otherwise keep because you edited it. |

Settings that only touch your own config (a theme, the bar, the font) act at once and need no `--yes`.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Done, or nothing to do (also `--dry-run`). |
| 1 | A check came out negative (for example `package-status` says it is missing). |
| 2 | Usage error, or a plan was printed because `--yes` was not given. |
| 3 | Timeout, or the item is not available. |
| 4 | A precondition failed: not Arch or CachyOS, a tool or a monitor that is not there, an unknown name. |
| 5 | The official (pacman) phase failed. |
| 6 | The AUR phase, or the command you asked for, failed. |
| 7 | Partial success: some items were done, some failed. |
| 8 | Config conflict: a file you edited, or another run is in progress. |
| 9 | Internal error. |
| 10 | `update check`: an update is available. |

### JSON

```json
{ "schema": 1, "command": "dns", "version": "0.11.0", "ok": true, "exit": 0, "dry_run": false, "data": { }, "warnings": [] }
```

`data` is different for every command; `ok` is true when `exit` is 0. Scripts should read `exit` and `data`, never the text.

## All commands

**Start here**: [`init`](#bxrig-init), [`refresh`](#bxrig-refresh), [`reinstall`](#bxrig-reinstall), [`wizard`](#bxrig-wizard), [`status`](#bxrig-status), [`doctor`](#bxrig-doctor), [`update`](#bxrig-update), [`scheduler`](#bxrig-scheduler), [`ascii`](#bxrig-ascii), [`about`](#bxrig-about), [`banner`](#bxrig-banner), [`version`](#bxrig-version), [`menu`](#bxrig-menu), [`apps`](#bxrig-apps), [`help`](#bxrig-help)

**Install and remove**: [`install`](#bxrig-install), [`remove`](#bxrig-remove), [`pkg`](#bxrig-pkg), [`catalog`](#bxrig-catalog), [`plan`](#bxrig-plan), [`install-plan`](#bxrig-install-plan), [`optional-plan`](#bxrig-optional-plan), [`profile-plan`](#bxrig-profile-plan), [`profile-install-plan`](#bxrig-profile-install-plan), [`profile-install`](#bxrig-profile-install), [`optional-install`](#bxrig-optional-install), [`profile-list`](#bxrig-profile-list), [`optional-list`](#bxrig-optional-list), [`desktop-list`](#bxrig-desktop-list), [`tui-list`](#bxrig-tui-list), [`web-list`](#bxrig-web-list), [`package-status`](#bxrig-package-status), [`package-source`](#bxrig-package-source), [`dev-plan`](#bxrig-dev-plan), [`prerequisites`](#bxrig-prerequisites), [`apps-doctor`](#bxrig-apps-doctor), [`web`](#bxrig-web), [`toolchain`](#bxrig-toolchain)

**Desktop setup**: [`setup`](#bxrig-setup), [`session`](#bxrig-session), [`tiling`](#bxrig-tiling), [`plasma`](#bxrig-plasma), [`keys`](#bxrig-keys), [`runner`](#bxrig-runner), [`launcher`](#bxrig-launcher), [`default`](#bxrig-default), [`layout`](#bxrig-layout), [`assets`](#bxrig-assets), [`launchers`](#bxrig-launchers), [`config`](#bxrig-config)

**Look and feel**: [`theme`](#bxrig-theme), [`appearance`](#bxrig-appearance), [`screensaver`](#bxrig-screensaver), [`hotcorners`](#bxrig-hotcorners), [`display`](#bxrig-display), [`power`](#bxrig-power), [`time`](#bxrig-time), [`calendar`](#bxrig-calendar), [`remind`](#bxrig-remind), [`accessibility`](#bxrig-accessibility), [`toggle`](#bxrig-toggle), [`nightshift`](#bxrig-nightshift), [`notify`](#bxrig-notify)

**System and security**: [`system`](#bxrig-system), [`security`](#bxrig-security), [`dns`](#bxrig-dns), [`kernel`](#bxrig-kernel), [`ssh`](#bxrig-ssh), [`git`](#bxrig-git), [`secrets`](#bxrig-secrets), [`vpn`](#bxrig-vpn), [`cloud`](#bxrig-cloud), [`settings`](#bxrig-settings), [`dotfiles`](#bxrig-dotfiles), [`nas`](#bxrig-nas), [`backup`](#bxrig-backup), [`timemachine`](#bxrig-timemachine), [`java`](#bxrig-java), [`sdk`](#bxrig-sdk), [`mail`](#bxrig-mail), [`tui`](#bxrig-tui), [`bxtimemachine`](#bxrig-bxtimemachine), [`privacy`](#bxrig-privacy)

**Develop**: [`boxlang`](#bxrig-boxlang), [`editor`](#bxrig-editor), [`db`](#bxrig-db), [`containers`](#bxrig-containers), [`vm`](#bxrig-vm), [`android`](#bxrig-android), [`boxy`](#bxrig-boxy), [`ai`](#bxrig-ai), [`mcp`](#bxrig-mcp), [`skills`](#bxrig-skills)

**Everyday tools**: [`screenshot`](#bxrig-screenshot), [`qr`](#bxrig-qr), [`share`](#bxrig-share), [`record`](#bxrig-record), [`browser`](#bxrig-browser), [`files`](#bxrig-files), [`webcam`](#bxrig-webcam), [`clipboard`](#bxrig-clipboard), [`emoji`](#bxrig-emoji), [`forcequit`](#bxrig-forcequit), [`window`](#bxrig-window), [`overview`](#bxrig-overview), [`quicklook`](#bxrig-quicklook), [`dolphin`](#bxrig-dolphin), [`dictation`](#bxrig-dictation), [`strata`](#bxrig-strata), [`gpu`](#bxrig-gpu), [`input`](#bxrig-input), [`audio`](#bxrig-audio), [`bluetooth`](#bxrig-bluetooth), [`wifi`](#bxrig-wifi), [`airplay`](#bxrig-airplay)

## Start here

Set up the machine, see where it stands, keep it current.

### `bxrig init` {#bxrig-init}

The setup wizard: asks the questions, shows a review, then installs on a progress screen (press v for the live log) and keeps a log file.

```text
bxrig init [--from=FILE] [--fresh | --rerun] [--plain] | init --answers=FILE [--yes [--screen]] [--dry-run] [--json] | init --print-answers [--from-system] [--json] | init --export=FILE [--force]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig init
bxrig init --answers=answers.json --yes
bxrig init --print-answers --from-system --json
```

### `bxrig refresh` {#bxrig-refresh}

Put a managed config back to what BxRig ships, with a backup first and without installing anything.

```text
bxrig refresh hyprland|noctalia|terminals|shell|nvim|theme|all [--starter] [--force] [--yes] [--dry-run] [--json]
bxrig refresh list [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig refresh list
bxrig refresh terminals --dry-run
bxrig refresh hyprland --yes
bxrig refresh shell --yes --force
```

> A file you edited is kept and reported; --force overwrites it after a backup (see config history and config restore). --starter also rewrites the starter hyprland.lua or Noctalia config.toml, which are yours.

### `bxrig reinstall` {#bxrig-reinstall}

Run the setup wizard again from your saved answers (the same as init --rerun).

```text
bxrig reinstall [--yes] [--dry-run] [--json]
```

```bash
bxrig reinstall
```

> This is the way to install packages again. refresh only puts config files back.

### `bxrig wizard` {#bxrig-wizard}

Wizard pieces for scripts: render the demo screens or a pages file.

```text
bxrig wizard --demo [--out=FILE] | --pages=FILE [--out=FILE] [--answers=FILE]
```

```bash
bxrig wizard --demo
```

### `bxrig status` {#bxrig-status}

What is installed and configured on this machine, compared with what BxRig would do.

```text
bxrig status [--json]
```

```bash
bxrig status
bxrig status --json
```

### `bxrig doctor` {#bxrig-doctor}

Checks every tool BxRig needs (git, curl, unzip, jq, Java 21, mvm, bvm, BoxLang, MatchBox, Rust, Cargo), one status line each. Exit 4 when one is missing. --dev adds advice on your developer setup.

```text
bxrig doctor [--dev] [--json]
```

```bash
bxrig doctor
bxrig doctor --dev
bxrig doctor --json
```

> --dev checks git name and email, an SSH key, the SSH agent, commit signing, a container engine and EDITOR. They print warn with the command that fixes them and never change the exit code.

### `bxrig update` {#bxrig-update}

Check for a BxRig update, apply it, pick a channel, turn the daily notification on or off.

```text
bxrig update check [--notify] | apply [--yes] | channel [stable|beta] | notifications on|off|status [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig update check
bxrig update apply --yes
bxrig update channel beta
bxrig update notifications on
```

> Exit 10 from `update check` means an update is available.

### `bxrig scheduler` {#bxrig-scheduler}

One scheduler on the BoxLang JVM: the update check, backups, BoxLang checks and your own tasks, with run history.

```text
bxrig scheduler [status|list] [--group=G] [--json]
bxrig scheduler show NAME [--limit=N] | history NAME [--limit=N] [--json]
bxrig scheduler add NAME --when=WHEN [--group=G] [--notify=failure|attention|always|never] [--timeout=SECONDS] -- COMMAND...
bxrig scheduler remove NAME | enable NAME | disable NAME | pause GROUP | resume GROUP | run NAME [--json]
bxrig scheduler install [--yes] [--dry-run] | uninstall [--yes] [--dry-run] | reload [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig scheduler
bxrig scheduler install --yes
bxrig scheduler show backup-data
bxrig scheduler add photos-to-nas --when="daily 23:00" --group=sync -- rsync -a ~/Pictures nas:/photos
bxrig scheduler add tidy-downloads --when="weekly sun 10:00" -- bxrig files tidy
bxrig scheduler pause backups
```

> WHEN is every N minutes, every N hours, hourly, daily HH:MM, weekdays HH:MM, weekly DAY HH:MM or cron M H DOM MON DOW. install writes the runner (a BoxLang scheduler class) and bxrig-scheduler.service (`boxlang schedule` on it), adds the update check, the file backup and the BoxLang check as tasks, and turns off bxrig-update-check.timer and bxrig-backup.timer; it is a plan until --yes. Every run is recorded in ~/.local/state/bxrig/scheduler/history; a failure sends a notice. Exit 10 from a task counts as "needs attention" where the task lists it as ok.

### `bxrig ascii` {#bxrig-ascii}

Text in large letters (FIGlet fonts) or a picture as text art, painted with a colour or a gradient.

```text
bxrig ascii TEXT... [--font=dos-rebel|ansi-shadow|calvin-s] [--color=COLOR | --gradient=SPEC] [--direction=horizontal|vertical|diagonal] [--plain] [--json]
bxrig ascii fonts [--json]
bxrig ascii image PATH [--width=N] [--style=blocks|ascii] [--plain] [--json]
```

```bash
bxrig ascii BxRig
bxrig ascii "Hello" --font=ansi-shadow --gradient=sunset
bxrig ascii OK --color=#00ff78
bxrig ascii Rainbow --gradient=rainbow --direction=diagonal
bxrig ascii Theme --gradient=theme
bxrig ascii deploy --gradient=#ff5f6d,#ffc371,#00dbff
bxrig ascii fonts
bxrig ascii image ~/Pictures/logo.png
bxrig ascii image logo.svg --width=60
bxrig ascii image photo.jpg --style=ascii --width=80
```

> COLOR is #rrggbb, #rgb, theme (the accent of the theme that is on) or a name (black, white, gray, red, orange, yellow, green, cyan, blue, purple, magenta, pink, boxlang, bxrig). SPEC is a preset (brand, theme, sunset, ocean, fire, forest, candy, rainbow) or two or more colours separated by commas. Without --color or --gradient the brand gradient is used in a terminal and no colour into a pipe; --plain and NO_COLOR leave colour out. With no TEXT the first line of stdin is drawn. `ascii image` draws a PNG, JPEG, GIF, WebP or SVG (read by the embedded bx-image module) WIDTH columns wide (default 48): blocks are half blocks in 24-bit colour, ascii is a brightness ramp in the picture's colours; transparent pixels stay blank.

### `bxrig about` {#bxrig-about}

About this rig: the BxRig laptop logo beside the hardware, your dev stack and the look (fastfetch).

```text
bxrig about [--wait] [--plain] [--json]
```

```bash
bxrig about
bxrig about --plain
bxrig about --json
```

> Runs fastfetch with ~/.config/bxrig/fastfetch.jsonc; the logo (~/.config/bxrig/theme/fastfetch-logo.ans) follows the theme and is rewritten by `bxrig theme set`. A missing logo or config is written first. Without fastfetch the logo, version and tagline are shown. --wait asks for Enter before returning (the launcher's About window uses it).

### `bxrig banner` {#bxrig-banner}

The BXRIG wordmark in block letters, painted in the colors of the current theme (the retro greeting).

```text
bxrig banner [--plain] [--json]
```

```bash
bxrig banner
bxrig banner --plain
bxrig banner --json
```

> Five rows, painted top to bottom with the theme's accent, magenta and cyan. A pipe, --plain and NO_COLOR give plain text; --json gives the lines and the three colors.

### `bxrig version` {#bxrig-version}

The BxRig version and build.

```text
bxrig version [--json]
```

```bash
bxrig version
```

### `bxrig menu` {#bxrig-menu}

The control center: every command as a menu on your launcher (Rofi, Walker, Wofi, Fuzzel or Vicinae).

```text
bxrig menu | menu items [--json] | menu search TEXT [--json] | menu open [ROUTE] [--json]
bxrig menu ids [--json] | menu file [--yes] [--dry-run] [--json]
```

```bash
bxrig menu
bxrig menu search 'time zone'
bxrig menu open capture
bxrig menu ids
bxrig menu file --yes
```

> Bind it to a key; the first entry, Search, lists every entry as one flat list. `menu open ROUTE` opens one submenu (system, capture, toggle, hardware, agent, shortcuts, trigger > capture); `menu open` lists the routes. A tick marks the current value (bar position, dock, window look, theme mode, power profile). Entries that do not apply here are hidden (laptop, touchpad, touchscreen, webcam, hybrid GPU, Hyprland, Plasma, installed apps); Install hides apps you have. Your own ~/.config/bxrig/menu.json adds entries (a program or a bxrig command under a submenu id), hides and renames entries by id: `menu ids` lists the ids, `menu file --yes` writes an example, `menu file` checks yours.

### `bxrig apps` {#bxrig-apps}

Your installed catalog apps, as a list or a launcher grid.

```text
bxrig apps | apps list [--json]
```

```bash
bxrig apps list
```

### `bxrig help` {#bxrig-help}

This list, or the usage of one command. `bxrig --help` and `bxrig -h` print the same list.

```text
bxrig help [COMMAND]
```

```bash
bxrig help
bxrig help appearance
```

## Install and remove

Apps from the catalog, any package from the repositories or the AUR, and the reverse.

### `bxrig install` {#bxrig-install}

Install catalog apps by id (or a whole group or profile).

```text
bxrig install [NAME] [--optional] [--shell=hyprland|plasma|all] [--json] [--yes] [--dry-run]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig install --dry-run
bxrig install --yes
```

> With no name it installs the default set; without --yes it prints the plan and changes nothing.

### `bxrig remove` {#bxrig-remove}

Uninstall catalog apps (their packages or web launchers).

```text
bxrig remove ID_OR_PACKAGE... [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig remove lazygit --yes
```

> Protected packages (the base system, the kernel, bxrig itself) are refused.

### `bxrig pkg` {#bxrig-pkg}

Search, inspect, install and remove any package from the repositories and the AUR.

```text
bxrig pkg search TEXT [--source=all|repo|aur] [--limit=N] | info NAME | installed [--explicit] | install NAME... [--aur] [--yes] [--dry-run] | remove NAME... [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig pkg search ripgrep
bxrig pkg install ripgrep --yes
bxrig pkg remove htop --yes
```

### `bxrig catalog` {#bxrig-catalog}

Browse the app catalog.

```text
bxrig catalog list [--group=G] [--category=C] [--tier=default|optional] [--kind=K] [--source=S] [--distro=D] [--json] | show ID [--distro=D] | groups | check | coverage [--distro=D] | version
bxrig catalog map suse|debian|ubuntu [--write] [--json]
```

```bash
bxrig catalog coverage
bxrig catalog list --distro=suse --tier=default
bxrig catalog groups
bxrig catalog list --group=ai --tier=default
bxrig catalog show lazygit
```

### `bxrig plan` {#bxrig-plan}

Show what installing would do, without doing it.

```text
bxrig plan [NAME] [--optional] [--shell=hyprland|plasma|all] [--json]
```

```bash
bxrig plan
bxrig plan --shell=hyprland --json
```

### `bxrig install-plan` {#bxrig-install-plan}

The install plan for the selection (same as plan).

```text
bxrig install-plan [NAME] [--optional] [--shell=hyprland|plasma|all] [--json]
```

### `bxrig optional-plan` {#bxrig-optional-plan}

The plan for the optional apps.

```text
bxrig optional-plan [--shell=hyprland|plasma|all] [--json]
```

### `bxrig profile-plan` {#bxrig-profile-plan}

The plan for one profile.

```text
bxrig profile-plan NAME [--optional] [--shell=hyprland|plasma|all] [--json]
```

```bash
bxrig profile-plan jvm
```

### `bxrig profile-install-plan` {#bxrig-profile-install-plan}

The install steps for one profile.

```text
bxrig profile-install-plan NAME [--optional] [--shell=hyprland|plasma|all] [--json]
```

### `bxrig profile-install` {#bxrig-profile-install}

Install a profile (jvm, containers, terminal, editors, ...).

```text
bxrig profile-install NAME [--optional] [--shell=hyprland|plasma|all] [--json] [--yes] [--dry-run]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig profile-install terminal --yes
```

### `bxrig optional-install` {#bxrig-optional-install}

Install the optional apps of the catalog.

```text
bxrig optional-install [--shell=hyprland|plasma|all] [--json] [--yes] [--dry-run]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

### `bxrig profile-list` {#bxrig-profile-list}

List the profiles.

```text
bxrig profile-list [--json]
```

### `bxrig optional-list` {#bxrig-optional-list}

List the optional apps.

```text
bxrig optional-list [--json]
```

### `bxrig desktop-list` {#bxrig-desktop-list}

List the desktop apps in the catalog.

```text
bxrig desktop-list [--json]
```

### `bxrig tui-list` {#bxrig-tui-list}

List the terminal apps in the catalog.

```text
bxrig tui-list [--json]
```

### `bxrig web-list` {#bxrig-web-list}

List the web apps in the catalog.

```text
bxrig web-list [--json]
```

### `bxrig package-status` {#bxrig-package-status}

Whether a catalog app is installed.

```text
bxrig package-status ID
```

```bash
bxrig package-status lazygit
```

### `bxrig package-source` {#bxrig-package-source}

Where a catalog app comes from (pacman, AUR, PKGBUILD, web).

```text
bxrig package-source ID
```

```bash
bxrig package-source lazygit
```

### `bxrig dev-plan` {#bxrig-dev-plan}

What the developer toolchain install would use: Java 21, Maven, Gradle, BVM, MVM.

```text
bxrig dev-plan
```

### `bxrig prerequisites` {#bxrig-prerequisites}

The same check as doctor: one status line per tool BxRig needs.

```text
bxrig prerequisites [--json]
```

### `bxrig apps-doctor` {#bxrig-apps-doctor}

Checks the catalog apps for missing or broken installs.

```text
bxrig apps-doctor [--json]
```

### `bxrig web` {#bxrig-web}

Web apps: create one from a URL, install a set (Google, Microsoft, Apple, BoxLang).

```text
bxrig web add [NAME URL] [--browser=brave|chromium|google-chrome|edge|firefox] [--yes] | list | rm NAME [--yes] | install google|microsoft|apple|boxlang|all [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig web add Notes https://notes.example.com --yes
bxrig web install google --yes
bxrig web rm Notes --yes
```

### `bxrig toolchain` {#bxrig-toolchain}

Language toolchains outside the always-installed BoxLang one (Node via nvm, Rust, Python, Go, PHP).

```text
bxrig toolchain node [--yes] [--dry-run] [--json]   (Bun and Deno: bxrig install bun deno)
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig toolchain node --yes
```

## Desktop setup

Hyprland with Noctalia, or KDE Plasma beside it: the session, the keys, the defaults.

### `bxrig setup` {#bxrig-setup}

Set up a desktop: Hyprland with Noctalia, Plasma with HyprKwin tiling, terminals, keyboards, status.

```text
bxrig setup plasma [--keys | --undo-keys] | hyprland [--terminal=ghostty|kitty|alacritty|foot|konsole] [--layout=dwindle|master|columns|scrolling|monocle|floating] [--workspaces=N] [--natural-scroll] [--layouts=us-intl,es] [--theme=dark|light|auto] [--wallpaper=box|grid|aurora|minimal] | terminal [--default=ghostty] [--also=a,b] | shell [--shell=zsh|fish|bash] | keyboard [--layouts=us-intl,es] | xremap [--build=hypr|kde] | undo plasma|hyprland|xremap | status [--yes] [--dry-run] [--json]
bxrig setup boot [status] | setup undo boot [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig setup hyprland --yes
bxrig setup terminal --default=ghostty --also=kitty --yes
bxrig setup boot --yes
```

### `bxrig session` {#bxrig-session}

Which desktop SDDM starts: Hyprland or Plasma.

```text
bxrig session show | set hyprland|plasma [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig session show
```

### `bxrig tiling` {#bxrig-tiling}

Tiling inside Plasma (HyprKwin): on, off, status, layouts.

```text
bxrig tiling on|off|status | layout [dwindle|master|monocle|scrolling|stage] [--json]
```

```bash
bxrig tiling on
bxrig tiling layout dwindle
```

### `bxrig plasma` {#bxrig-plasma}

Plasma extras: panel layouts (apply, undo, status) and the islands preset.

```text
bxrig plasma panels apply [--agenda] [--without-weather] [--desktops=N] [--preset=NAME] [--yes] [--dry-run]
bxrig plasma panels undo [--yes]
bxrig plasma panels status [--json]
bxrig plasma desktops N [--yes]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig plasma panels apply --preset=islands --yes
bxrig plasma desktops 4 --yes
```

### `bxrig keys` {#bxrig-keys}

The shortcut table: show, search, run, rebind, check conflicts, apply to Hyprland and Plasma, Traditional or Mac style.

```text
bxrig keys show | search TEXT | run ID | style [traditional|mac] [--keyboard=pc|apple] [--swap=on|off] [--yes] | mac [on|off|status] [--yes] | set ID KEYS [--yes] [--force] | reset ID [--yes] | conflicts | sheet | render xremap|hyprland|plasma | check | apply [--yes] [--dry-run] [--force] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig keys show
bxrig keys search screenshot
bxrig keys run color-picker
bxrig keys style mac --keyboard=pc --yes
bxrig keys set emoji Super+Ctrl+E --yes
bxrig keys mac on --yes
bxrig keys conflicts
```

> Two styles share one table: Traditional (classic Super-key tiling keys) and Mac (Cmd-style keys through xremap). The Mac style on a PC keyboard swaps Alt and Win; an Apple keyboard never swaps. `keys conflicts` checks the table, the remaps of the style that is on and your own hl.bind lines. keys sheet (Super+K) opens the shortcuts browser: groups as tabs, keycaps, a live filter; the same page is bxrig tui shortcuts.

### `bxrig runner` {#bxrig-runner}

Which launcher and which menu program BxRig uses (Rofi, Walker, Wofi, Fuzzel, Vicinae).

```text
bxrig runner list | show | doctor | launch | select JSON_ENTRIES [--prompt=TEXT] | set PROVIDER | menu-set PROVIDER | icon-theme NAME|auto | launcher-command PROVIDER JSON_ARGV | menu-command PROVIDER JSON_ARGV [--json]
```

```bash
bxrig runner list
bxrig runner set rofi
bxrig runner icon-theme Papirus
bxrig runner doctor
```

### `bxrig launcher` {#bxrig-launcher}

Vicinae as BxRig's launcher: the BxRig theme, BxRig's actions as script commands, and file search.

```text
bxrig launcher [status] [--json]
bxrig launcher setup [--yes] [--dry-run] [--json]
bxrig launcher scripts [--yes] [--dry-run] | scripts remove [--yes] [--json]
bxrig launcher files [QUERY]
bxrig launcher search [QUERY] [--limit=N] [--json]
bxrig launcher run ID [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig launcher
bxrig launcher setup --yes
bxrig launcher scripts --yes
bxrig launcher files invoice
bxrig launcher search capture --json
bxrig launcher run theme:nord
```

> setup is a plan until --yes: it makes Vicinae the launcher and the menu, writes ~/.local/share/vicinae/themes/bxrig.toml (rewritten by every `bxrig theme set`) and selects it with `vicinae theme set bxrig`, writes the script commands to ~/.local/share/vicinae/scripts/bxrig and starts `vicinae server` when it is not running. Vicinae's settings.json is never edited. files opens vicinae://launch/files/search with QUERY typed in. search gives one ranked list for what you type: a calculator answer first, then menu actions (with their path), applications and themes, then web searches. Rows you run often rise (frecency, kept in ~/.local/state/bxrig/launcher.json). run does what a row says; ids come from search --json.

### `bxrig default` {#bxrig-default}

Default apps: browser, terminal, file manager.

```text
bxrig default show | browser ID | terminal ID | filemanager ID | editor neovim|vscode|zed|kate [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig default show
bxrig default browser brave --yes
bxrig default editor neovim --yes
```

> editor sets the app for text files (xdg-mime) and EDITOR and VISUAL in ~/.config/environment.d/50-bxrig-editor.conf (from the next login).

### `bxrig layout` {#bxrig-layout}

Window layout at runtime: tile or float (toggle).

```text
bxrig layout [toggle|float|tile|status] [--dry-run] [--json]
```

```bash
bxrig layout toggle
```

### `bxrig assets` {#bxrig-assets}

Brand assets (logo, icon, wallpapers): list, or install them; wallpaper packs you can download.

```text
bxrig assets list | install [--yes] [--dry-run] [--json]
bxrig assets wallpapers [list] | install PACK [--yes] [--dry-run] | remove PACK [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig assets list
bxrig assets wallpapers
bxrig assets wallpapers install omarchy --yes
```

> A wallpaper pack is downloaded only when you ask (about 74 MB for omarchy: 101 backgrounds of the Omarchy themes, MIT licensed). It is fetched with git at a pinned release and checked against a known commit, then unpacked into ~/Pictures/BxRig/omarchy/THEME/ with a CREDITS.md. bxrig theme wallpaper next cycles the current theme's images.

### `bxrig launchers` {#bxrig-launchers}

A BxRig submenu in your application menu (opt-in): the setup wizard, the runner menu, the Control Center and its pages.

```text
bxrig launchers on|off|status [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig launchers status
bxrig launchers on --dry-run
bxrig launchers on --yes
bxrig launchers off --yes
```

> `on` writes one entry per page to ~/.local/share/applications (BxRig Databases, ...), each opening `bxrig tui PAGE` in your terminal, and the BxRig icon (16 to 256 px PNGs and the scalable SVG) to ~/.local/share/icons/hicolor/SIZExSIZE/apps/bxrig.png. An entry you edited is kept, never overwritten or removed. `off` (or `bxrig remove launchers`) takes them out again. Nothing is added unless you ask.

### `bxrig config` {#bxrig-config}

The managed config files: list, diff, apply, restore a backup, history. A file you edited is never overwritten.

```text
bxrig config list|diff NAME|apply NAME|restore NAME ID|history [NAME] [--yes] [--dry-run] [--force] [--json]
bxrig config restore NAME ID --yes
```

```bash
bxrig config list
bxrig config diff hypr/bxrig.lua
bxrig config history
```

> BxRig never overwrites a file you edited; `config status` shows which ones are yours.

## Look and feel

Themes, fonts, bar, dock, windows, monitors and power.

### `bxrig theme` {#bxrig-theme}

Themes: 15 bundled (10 community themes, 5 BxRig), set one, light or dark, install from git.

```text
bxrig theme list | show NAME | set NAME [--mode=theme|dark|light|auto] [--keep-wallpaper] | random | next | wallpaper next|random | mode theme|dark|light|auto | install GIT_URL [--name=N] [--force] | import PATH [--name=N] [--force] | remove NAME | vscode [--yes] [--dry-run] | status [--dry-run] [--json]
```

```bash
bxrig theme list
bxrig theme set tokyo-night --mode=dark
bxrig theme install https://github.com/user/theme --name=mine
bxrig theme mode auto
bxrig theme vscode --yes
```

> A theme colours the bar, terminals, btop, Neovim, GTK and Qt apps, tmux, fzf, launchers and (on Plasma) the colour scheme. VS Code is opt-in.

### `bxrig appearance` {#bxrig-appearance}

Bar layout, dock, app grid, battery percentage, windows, animations, layout, fonts and backgrounds, one setting at a time.

```text
bxrig appearance status|apply [--json]
bxrig appearance bar show|hide|toggle
bxrig appearance bar position top|bottom|left|right
bxrig appearance bar style opaque|glassy|clear
bxrig appearance bar clock ID
bxrig appearance bar battery on|off
bxrig appearance bar layout minimal|standard|dense|status [--yes]
bxrig appearance dock show|hide
bxrig appearance dock on|off|toggle|status [--yes]
bxrig appearance dock mode always|autohide|off
bxrig appearance dock position bottom|left|right
bxrig appearance appgrid launchpad|terminal|status [--yes]
bxrig appearance battery-percent on|off|status [--yes]
bxrig appearance windows gaps on|off
bxrig appearance windows corners theme|rounded|sharp
bxrig appearance windows opacity opaque|glassy
bxrig appearance windows one-window-ratio on|off
bxrig appearance windows snap on|off
bxrig appearance animations on|off
bxrig appearance layout dwindle|master|columns|scrolling|monocle|floating
bxrig appearance font list
bxrig appearance font ID
bxrig appearance font install ID [--yes]
bxrig appearance ui-font list
bxrig appearance ui-font ID
bxrig appearance ui-font install ID [--yes]
bxrig appearance font-rendering default|smooth|crisp|sharp|status
bxrig appearance background list
bxrig appearance background set NAME_OR_PATH
bxrig appearance background next
bxrig appearance background random
bxrig appearance icons bxrig|papirus|status [--yes]
```

```bash
bxrig appearance bar position bottom
bxrig appearance bar layout minimal --yes
bxrig appearance dock off --yes
bxrig appearance windows gaps off
bxrig appearance layout columns
bxrig appearance font install cascadia --yes
bxrig appearance ui-font inter
bxrig appearance font-rendering smooth
bxrig appearance background random
bxrig appearance icons papirus --yes
```

> Settings act at once (no --yes); --dry-run shows the commands. What you choose is remembered, and `appearance apply` pushes it again. `bar layout`, `dock on|off|toggle`, `appgrid` and `battery-percent` rewrite ~/.config/noctalia/config.toml (backup kept; a file with changes of your own needs --yes). The `terminal` app grid style is only stored for now: nothing draws it yet. `icons` is the exception to "act at once": it installs papirus-icon-theme and writes the BxRig icon theme and settings files, so it prints a plan (exit 2) until --yes; `bxrig` (the default after setup) is the BxRig icons over Papirus-Dark, `papirus` is Papirus-Dark alone. `font` is the coding font (terminals, and the shell until an interface font is set); `ui-font` is the font of the bar, panels and GTK apps; `font-rendering` writes ~/.config/fontconfig/conf.d/60-bxrig-rendering.conf (`default` removes it unless you edited it).

### `bxrig screensaver` {#bxrig-screensaver}

The screensaver: terminal art in the theme's colours on every monitor after a while idle, then the lock.

```text
bxrig screensaver [status] [--json]
bxrig screensaver on|off [--yes]
bxrig screensaver set screensaver=SECONDS lock=SECONDS effects=NAME,NAME [--yes]
bxrig screensaver logo text TEXT|image PATH|reset [--yes]
bxrig screensaver effects [--json]
bxrig screensaver start [--effect=NAME] [--idle]
bxrig screensaver stop
bxrig screensaver preview [EFFECT]
bxrig screensaver run [--effect=NAME]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig screensaver preview clock
bxrig screensaver set screensaver=300 lock=600 --yes
bxrig screensaver logo text ACME --yes
bxrig screensaver off --yes
```

> Effects: sweep, laptop, rain, clock, stars, logo; they take turns, a minute each. Defaults: the screensaver after 150 s idle, the lock after 300 s (0 for never), both counted from the start of idle. On Hyprland, Noctalia runs them as idle behaviors (bxrig screensaver start, with stop as the resume command). On Plasma, a user service runs swayidle with the same two commands (start --idle does nothing while Plasma's power manager says something holds the screen awake), a KWin script puts one full-screen window on each screen, and lock= sets Plasma's own lock timeout (whole minutes, rounded up). start opens a full-screen terminal per monitor; preview runs it in this terminal. Any key, click, scroll or mouse move closes it. Settings: ~/.config/bxrig/screensaver.json.

### `bxrig hotcorners` {#bxrig-hotcorners}

Hot corners: an action for each screen corner (overview, notifications, show desktop, lock, launcher, agents, themes).

```text
bxrig hotcorners [status] [--json]
bxrig hotcorners set CORNER=ACTION... [--yes]
bxrig hotcorners off [--yes]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig hotcorners set top-left=overview bottom-right=lock --yes
bxrig hotcorners off --yes
```

> CORNER is top-left, top-right, bottom-left or bottom-right. Hyprland uses Noctalia's hot corners; Plasma uses KWin screen edges (notifications, agents and themes have no Plasma edge action).

### `bxrig display` {#bxrig-display}

Monitors: scale, rotation, mode, position, mirroring the laptop panel, turning it off, brightness.

```text
bxrig display list|status [--json]
bxrig display scale NAME auto|0.5..4
bxrig display rotate NAME 0|90|180|270
bxrig display mode NAME preferred|WxH[@R]
bxrig display position NAME auto|XxY
bxrig display mirror on|off
bxrig display laptop on|off
bxrig display brightness up|down|set N
bxrig display apply | reset
```

```bash
bxrig display list
bxrig display scale DP-2 1.5
bxrig display mirror on
bxrig display brightness set 40
```

> On Hyprland it writes theme/monitors.lua and reloads; on Plasma it uses kscreen-doctor.

### `bxrig power` {#bxrig-power}

Laptop power: battery details, profile, lid action on battery and on AC, hibernate, charge limit, setup of the power tools, doctor.

```text
bxrig power status [--json]
bxrig power profile [performance|balanced|saver]
bxrig power lid [battery|ac] suspend|hibernate|lock|ignore [--yes]
bxrig power hibernate [--yes]
bxrig power charge-limit [PERCENT|off|status] [--yes]
bxrig power setup [--yes] [--force]
bxrig power doctor [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig power status --json
bxrig power profile saver
bxrig power lid battery hibernate --yes
bxrig power lid ac lock --yes
bxrig power hibernate --dry-run
bxrig power charge-limit 80 --yes
bxrig power doctor
```

> `power status --json` has one entry per battery (percent, state, watts, time_remaining_minutes, health_percent, cycles, charge_limit; -1 when unknown) and the lid action on battery and on AC. `power lid ACTION` without battery or ac sets both. `power hibernate` exits 4 unless disk swap (zram does not count), the kernel resume= parameter and the kernel are ready; it is a plan (exit 2) without --yes. `power charge-limit` writes the kernel attribute charge_control_end_threshold and keeps it with a small systemd unit; it exits 4 on a battery without that attribute (not verified on real hardware). `power setup` does nothing on a machine without a battery unless you add --force.

### `bxrig time` {#bxrig-time}

The time zone: show, set, set from your IP after travelling, follow your location, network time, the bar clock format, and the world clock.

```text
bxrig time status [--json]
bxrig time zone [--list | ZONE] [--yes]
bxrig time sync [--yes]
bxrig time auto on|off|status [--yes]
bxrig time ntp on|off [--yes]
bxrig time format [FORMAT | default]
bxrig time world [status | set ZONE,ZONE... | add ZONE | remove ZONE | on | off] [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig time zone Europe/Madrid --yes
bxrig time sync --yes
bxrig time auto on --yes
bxrig time world set Europe/Madrid,America/New_York --yes
bxrig time format "%a %-I:%M %p"
```

> `time auto on` sends your Wi-Fi networks or IP address to a location web service; the plan says so first. `time format` sets the bar clock's text in Noctalia date format tokens (or MMM d - HH:mm patterns); it acts at once and rewrites the Noctalia config.

### `bxrig calendar` {#bxrig-calendar}

Your calendars on this machine (iCal addresses and Google Calendar), kept in sync by vdirsyncer, and the agenda read from them.

```text
bxrig calendar [list] [--json]
bxrig calendar add ical NAME URL [--json]
bxrig calendar add google NAME --client-id=ID --client-secret-file=FILE [--json]
bxrig calendar remove NAME [--yes] [--dry-run]
bxrig calendar sync [NAME] [--json]
bxrig calendar agenda [--days=N] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig calendar add ical holidays webcal://example.org/holidays.ics
bxrig calendar add google work --client-id=123.apps.googleusercontent.com --client-secret-file=~/Downloads/secret.txt
bxrig calendar sync
bxrig calendar agenda --days=3
```

> BxRig writes its own vdirsyncer config (~/.config/bxrig/vdirsyncer/config, mode 600, passed as VDIRSYNCER_CONFIG), so a vdirsyncer setup of your own is never touched. An iCal address is read only; webcal:// is fetched as https://. Google needs the CalDAV API on and an OAuth client of type Desktop app; the first sync, in a terminal, opens Google's sign-in. With the scheduler installed, adding a calendar adds the task calendar-sync (every 15 minutes). remove deletes only the local copy.

### `bxrig remind` {#bxrig-remind}

A reminder that pops up at a time you choose.

```text
bxrig remind TEXT --at=HH:MM | --at="YYYY-MM-DD HH:MM" | --in=30m|2h|1d [--json]
bxrig remind [list] [--json]
bxrig remind done ID | remove ID [--json]
bxrig remind due [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig remind "Call Ana" --in=30m
bxrig remind "Stand up" --at=09:25
bxrig remind "Renew the domain" --at="2026-12-01 10:00"
bxrig remind list
bxrig remind done 3
```

> Reminders are kept in ~/.config/bxrig/reminders.json. An HH:MM that has passed today means tomorrow. `due` shows the reminders whose time has come as notices; the scheduler task reminders runs it every minute (added with the first reminder when the scheduler is installed).

### `bxrig accessibility` {#bxrig-accessibility}

Zoom like a Mac, reduce motion, and three high-contrast themes. All off until you turn them on.

```text
bxrig accessibility [status] [--json]
bxrig accessibility zoom on|off|status|in|out|toggle [--dry-run] [--json]
bxrig accessibility reduce-motion on|off|status [--dry-run] [--json]
bxrig accessibility contrast dark|light|colorblind|off|status [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig accessibility
bxrig accessibility zoom on
bxrig accessibility reduce-motion on
bxrig accessibility contrast dark
```

> zoom on makes the zoom keys work: Option+Cmd+8 toggles, Option+Cmd+= zooms in, Option+Cmd+- zooms out (Option is Alt, Cmd is Super). While zoom is off the keys only say how to turn it on. Hyprland zooms around the pointer (cursor:zoom_factor); Plasma uses KWin's Zoom effect. reduce-motion turns off window, bar and app animations. contrast picks bxrig-contrast-dark, bxrig-contrast-light or bxrig-colorblind (every text colour at least 7:1, WCAG AAA); off goes back to your theme. Settings act at once; --dry-run shows the commands.

### `bxrig toggle` {#bxrig-toggle}

Quick switches. Today: stay awake (Noctalia caffeine).

```text
bxrig toggle stay-awake [on|off]
```

```bash
bxrig toggle stay-awake
```

### `bxrig nightshift` {#bxrig-nightshift}

Night light: on, off, toggle, status (sunset to sunrise from your time zone).

```text
bxrig nightshift [on|off|toggle|status] [--location=LAT,LON] [--json]
```

```bash
bxrig nightshift toggle
bxrig nightshift on --location=40.4,-3.7
```

### `bxrig notify` {#bxrig-notify}

Notifications through Noctalia: do not disturb, snooze, clear, and notices for the time, battery and weather.

```text
bxrig notify dnd on|off|toggle|status | snooze [30m|2h|90s|off] | clear [--history] | time | battery | weather [--json]
```

```bash
bxrig notify dnd toggle
bxrig notify snooze 2h
bxrig notify clear --history
bxrig notify battery
```

> time, battery and weather show one notice through notify-send. weather asks wttr.in over the network.

## System and security

Updates, snapshots, DNS, kernels, keys and secrets.

### `bxrig system` {#bxrig-system}

See what is waiting to be updated, update the system (a snapshot first), lock, suspend, log out, reboot, shut down.

```text
bxrig system updates [--json]
bxrig system update [--repo | --aur | --all] [--yes] [--dry-run] [--json]
bxrig system lock | suspend | logout|reboot|shutdown [--yes] [--dry-run] [--json]
bxrig system restart shell|audio|wifi|bluetooth [--yes] [--dry-run] [--json]
bxrig system password
bxrig system firmware [check] [--json] | system firmware update [--yes] [--dry-run] [--json]
bxrig system speedtest network|disk|dns|last [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig system updates --json
bxrig system update --yes
bxrig system update --repo --dry-run
bxrig system update --aur --yes
bxrig system reboot --yes
bxrig system restart audio --yes
bxrig system firmware
bxrig system speedtest disk
```

> updates only reads: repository and AUR counts and the package list, and whether a restart is needed (exit 4 without checkupdates from pacman-contrib). update takes a snapshot first, then updates the repository (--repo), the AUR (--aur, exit 4 without yay or paru) or both (--all, the default). lock and suspend act at once; logout, reboot and shutdown need --yes (the menu asks first). restart shell stops and starts Noctalia (or restarts Plasma's plasmashell service); audio restarts PipeWire and WirePlumber; wifi and bluetooth unblock the radio and turn it on. password runs passwd on your terminal. firmware asks fwupd (LVFS: BIOS/UEFI, SSDs, docks) for updates; update installs them on your terminal. speedtest network runs speedtest-cli; disk writes and reads 1 GiB in ~/.cache with direct I/O; dns is dns bench; last shows the last result of each test (only the latest is kept, in ~/.local/state/bxrig/speedtest-last.json).

### `bxrig security` {#bxrig-security}

Fingerprint and security key for sudo, SSH server, passwordless sudo, with guards.

```text
bxrig security status [--json]
bxrig security fingerprint on|off|enroll [--yes]
bxrig security fido2 on|off|register [--yes]
bxrig security ssh-server on|off [--yes]
bxrig security passwordless-sudo on|off [--yes]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig security status
bxrig security fingerprint on --dry-run
bxrig security passwordless-sudo on --yes
```

> Only /etc/pam.d/sudo is ever changed, with a `sufficient` line and a backup; sudoers is checked with visudo first. `--dry-run` prints the exact line.

### `bxrig dns` {#bxrig-dns}

DNS servers of the active connections: Cloudflare, Google, Quad9, your own, or back to DHCP. bench times each one to pick the fastest.

```text
bxrig dns [cloudflare|google|quad9|dhcp|custom IP[,IP...]] [--yes] [--dry-run]
bxrig dns bench [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig dns
bxrig dns bench
bxrig dns cloudflare --yes
bxrig dns custom 9.9.9.10 --yes
```

### `bxrig kernel` {#bxrig-kernel}

List, install and remove kernels. Never edits the bootloader.

```text
bxrig kernel list | install NAME | remove NAME [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig kernel list
bxrig kernel install linux-cachyos-lts --yes
```

### `bxrig ssh` {#bxrig-ssh}

Create an SSH key (ed25519; an existing one is kept).

```text
bxrig ssh key [--email=ADDRESS] [--yes] [--dry-run] [--json]
```

```bash
bxrig ssh key --email=me@example.com --yes
```

### `bxrig git` {#bxrig-git}

Sign commits and tags with your SSH key.

```text
bxrig git signing [status] [--json]
bxrig git signing on [--key=PATH] [--yes] [--dry-run] [--json]
bxrig git signing off [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig git signing
bxrig git signing on --yes
bxrig git signing on --key=~/.ssh/work_ed25519 --yes
```

> on sets gpg.format ssh, user.signingkey, commit.gpgsign and tag.gpgsign, and adds your email and key to ~/.config/git/allowed_signers so git can verify. It needs the key (bxrig ssh key --yes) and git user.email. off stops signing and keeps the key. Add the key to GitHub as a Signing key for the Verified badge.

### `bxrig secrets` {#bxrig-secrets}

API keys and tokens in the system keyring, loaded per command, exported encrypted.

```text
bxrig secrets status | setup [--keyring=kwallet|gnome-keyring|none] [--yes] | list [--type=ai|other] | set NAME [--from-file=F] [--type=ai|other] [--provider=ID] | get NAME [--show] | unset NAME --yes | apply [--yes] | global on NAME --yes|off NAME|show | unlock | lock | export FILE [--plain] [--force] --yes | import FILE [--overwrite] --yes | env [NAMES...] | run [NAMES...] [--strict] -- COMMAND [ARGS...] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig secrets set ANTHROPIC_API_KEY
bxrig secrets run ANTHROPIC_API_KEY -- claude
bxrig secrets list
```

### `bxrig vpn` {#bxrig-vpn}

VPNs in one list: saved NetworkManager profiles and the VPN apps (NordVPN, NordLayer, Tailscale, Mullvad); connect, disconnect, pick a place.

```text
bxrig vpn list | status [NAME] | locations NAME [--json]
bxrig vpn connect NAME [--location=PLACE] | disconnect [NAME] [--dry-run] [--json]
bxrig vpn set allow_several=true|false [--yes] [--dry-run] [--json]
bxrig vpn nordvpn setup [--yes] [--json]
```

```bash
bxrig vpn list
bxrig vpn connect tailscale
bxrig vpn connect nordvpn --location=Germany
bxrig vpn disconnect
bxrig vpn set allow_several=true --yes
bxrig vpn nordvpn setup --yes
```

> NAME is a provider from `vpn list` (nordvpn, nordlayer, tailscale, mullvad) or a saved profile as listed there (`nm:Home`). Choosing one disconnects the one that is connected first, unless `allow_several=true` (Tailscale next to another VPN; routes and DNS can clash). connect and disconnect act at once and take `--dry-run`; `set` and `nordvpn setup` need `--yes`. The providers are data (`catalog/vpn-providers.json`, extend with `~/.config/bxrig/vpn-providers.json`). `list` is empty when no VPN is installed; the other verbs exit 4 then. `--location` takes a value from `vpn locations NAME` (`default` connects as it is, `none` clears a Tailscale exit node). The top bar VPN icon (plugin `bxrig/vpn`) is the same list.

### `bxrig cloud` {#bxrig-cloud}

Cloud storage with rclone: remotes, mounts as systemd user units.

```text
bxrig cloud remotes | configure | mount NAME [--path=DIR] [--yes] | unmount NAME [--yes] | status [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig cloud remotes
bxrig cloud mount gdrive --path=~/Drive --yes
```

### `bxrig settings` {#bxrig-settings}

Export and import your BxRig settings as one archive.

```text
bxrig settings export FILE.tar.gz [--force] | import FILE.tar.gz [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig settings export my-settings.tar.gz
bxrig settings import my-settings.tar.gz --yes
```

### `bxrig dotfiles` {#bxrig-dotfiles}

Apply your dotfiles repo with chezmoi, yadm, stow or plain links, never overwriting unasked, with undo.

```text
bxrig dotfiles plan REPO [--method=chezmoi|yadm|stow|links] | apply REPO [--method=M] [--overwrite] [--yes] [--dry-run] | status | undo [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig dotfiles plan https://github.com/me/dotfiles
bxrig dotfiles apply https://github.com/me/dotfiles --yes
```

### `bxrig nas` {#bxrig-nas}

Your NAS boxes: find them, save their details, list shares, mount them (also automatically), test them, mirror folders to them, use one as a backup target.

```text
bxrig nas setup [--yes]
bxrig nas discover [--json]
bxrig nas add NAME --host=H [--protocol=smb|nfs] [--user=U] [--vers=3.1.1] [--ask-password | --password-file=F]
bxrig nas list | show NAME | remove NAME [--yes]
bxrig nas shares NAME
bxrig nas mount|unmount NAME SHARE [--yes]
bxrig nas auto on|off NAME SHARE [--yes]
bxrig nas test NAME [SHARE]
bxrig nas sync NAME SRC --to=SHARE[/PATH] [--delete] [--yes]
bxrig nas use NAME SHARE [--path=bxrig-backup]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig nas discover
bxrig nas add synology --host=ds920.local --user=me --ask-password
bxrig nas shares synology
bxrig nas mount synology backups --yes
bxrig nas auto on synology backups --yes
bxrig nas use synology backups
```

> SMB mounts are made by root, so the password is also kept in /etc/bxrig/nas/NAME.cred (mode 600); the plan says so. The SMB version is negotiated unless you give --vers. Nothing on the NAS is deleted unless you add --delete to a sync.

### `bxrig backup` {#bxrig-backup}

Backups of your BxRig setup, of the system and of your files, and a way to move them around.

```text
bxrig backup config now [--reason=TEXT] [--with-secrets]
bxrig backup config list
bxrig backup config show ID
bxrig backup config diff ID
bxrig backup config restore ID [--only=PATH] [--packages] [--yes] [--dry-run]
bxrig backup config auto on|off|status
bxrig backup config prune [--keep=N] [--yes]
bxrig backup config paths
bxrig backup config add PATH
bxrig backup config remove PATH
bxrig backup snapshots status
bxrig backup snapshots list [--json]
bxrig backup snapshots setup [--home] [--yes]
bxrig backup snapshots create [--description=TEXT] [--yes]
bxrig backup snapshots delete ID
bxrig backup snapshots changes ID
bxrig backup snapshots restore ID PATH [--yes]
bxrig backup data status
bxrig backup data targets [--json]
bxrig backup data target add NAME --type=local|sftp|rest|s3|b2|azure|gs|rclone [--path=P --host=H --user=U --url=U --bucket=B --endpoint=URL --region=R --container=C --project=ID --credentials=FILE --remote=R] [--ask-keys | --keys-file=F]
bxrig backup data target remove NAME [--yes]
bxrig backup data init NAME [--yes]
bxrig backup data run [--target=NAME] [--yes]
bxrig backup data list [--target=NAME]
bxrig backup data files ID [PATH]
bxrig backup data restore ID --to=DIR [--include=PATH] [--yes]
bxrig backup data verify [--deep]
bxrig backup data forget [--yes]
bxrig backup data retention [--daily=N --weekly=N --monthly=N]
bxrig backup data schedule hourly|daily|off|status [--yes]
bxrig backup data include|exclude add|remove PATH_OR_PATTERN
bxrig backup send ID|all --to=TARGET [--from=TARGET] [--yes]
bxrig backup export data ID --to=FILE.tar|FILE.zip [--path=/PATH] [--target=NAME] [--yes]
bxrig backup export config ID --to=FILE.tar.gz [--yes]
bxrig backup status [--json]
bxrig backup timeline [--local] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig backup status --json
bxrig backup config now
bxrig backup config list
bxrig backup config diff 20261113T153000
bxrig backup config restore 20261113T153000 --dry-run
bxrig backup config restore 20261113T153000 --only=.config/hypr --yes
bxrig backup snapshots setup --yes
bxrig backup snapshots list
bxrig backup snapshots restore 12 /home/me/projects/app --dry-run
bxrig backup data target add do --type=s3 --endpoint=https://nyc3.digitaloceanspaces.com --bucket=mybackups --ask-keys
bxrig backup data init do --yes
bxrig backup data run --yes
bxrig backup data schedule daily --yes
bxrig backup data restore latest --to=~/restored --yes
bxrig backup send latest --from=usb --to=do --yes
bxrig backup export data latest --to=~/projects.zip --path=/home/me/Projects --yes
bxrig backup export config 20261113T153000 --to=~/my-setup.tar.gz --yes
bxrig backup timeline --local
```

> A config snapshot is taken by itself before update, system update, init, reinstall and refresh (turn it off with backup config auto off). Secrets and SSH keys are never in it unless you add --with-secrets, which stores your secrets export, encrypted with a passphrase you type.

### `bxrig timemachine` {#bxrig-timemachine}

BxTimeMachine: every backup of your system, setup and files on one timeline, with browse, restore, export and send.

```text
bxrig timemachine [--demo] [--local]
```

```bash
bxrig timemachine
bxrig timemachine --local
bxrig timemachine --demo
```

> It needs a terminal (also available as bxtimemachine). Restore, export, send and back up now show the plan first and change nothing until you press y. --local skips the network targets so it opens at once; --demo shows made-up data and runs nothing.

### `bxrig java` {#bxrig-java}

Your Java versions: jenv switches them, SDKMAN or Temurin supplies them. 21 is always there.

```text
bxrig java setup [--versions=25,17] [--yes] | status | list | available | install MAJOR|IDENTIFIER [--yes] [--dry-run] | global ID|MAJOR [--yes] | local ID|MAJOR [--yes] | remove ID [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig java setup --yes
bxrig java setup --versions=25,17 --yes
bxrig java install 25 --yes
bxrig java global 21 --yes
bxrig java local 25 --yes
```

> jenv (in ~/.jenv) only switches versions; the JDKs come from SDKMAN (when installed: bxrig sdk setup) or are downloaded as Temurin from Adoptium into ~/.local/share/bxrig/java. setup installs jenv, enables its export, maven and gradle plugins, installs JDK 21 plus any --versions, and makes 21 the global version. New shells load jenv through ~/.config/bxrig/jenv.sh and jenv.fish (run bxrig refresh shell once on an existing setup). global is `jenv global`, local is `jenv local`. The system's own JDKs are never deleted. default still works as the old name of global.

### `bxrig sdk` {#bxrig-sdk}

Java, Maven and Gradle through SDKMAN: install, switch, remove.

```text
bxrig sdk status | setup [--yes] | list java|maven|gradle | available java|maven|gradle | install CANDIDATE VERSION [--yes] | default CANDIDATE VERSION [--yes] | remove CANDIDATE VERSION [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig sdk setup --yes
bxrig sdk available maven
bxrig sdk install maven 3.9.9 --yes
bxrig sdk default gradle 8.10.2 --yes
```

> setup installs SDKMAN into ~/.sdkman without touching your shell files. Maven and Gradle reach your shells through ~/.config/bxrig/sdk.sh and sdk.fish, which the shell starters source (bxrig refresh shell on an existing setup). Version lists come from api.sdkman.io.

### `bxrig mail` {#bxrig-mail}

A mail catcher for development: a local inbox for the mail your apps send, in a container.

```text
bxrig mail start [--keep] [--smtp-port=N] [--ui-port=N] [--yes] | stop | status | remove [--keep-data] [--yes] | list [--limit=N] | show ID | delete ID [--yes] | clear [--yes] | open [ID] | test [--to=ADDR] [--subject=TEXT] | env [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig mail start --yes
bxrig mail env
bxrig mail test
bxrig mail list
bxrig mail start --keep --yes
```

> Runs Mailpit in a container (the engine bxrig db engine chose). SMTP is 127.0.0.1:1025 and the web inbox is http://127.0.0.1:8025, both local only. Mail is thrown away when the catcher stops unless you start it with --keep. The Control Center has a Mail page that refreshes by itself.

### `bxrig tui` {#bxrig-tui}

Control Center: every BxRig screen in one terminal, or one page on its own.

```text
bxrig tui [PAGE] [--sidebar|--no-sidebar] [--demo] [--icons=on|off] [--json]
bxrig tui list [--json]
```

```bash
bxrig tui
bxrig tui databases
bxrig tui apps
bxrig tui list
bxrig tui dashboard --json
bxrig tui --demo
```

> It needs a terminal. `bxrig tui` opens the Control Center with the sidebar; `bxrig tui PAGE` opens that page alone with the sidebar collapsed, like an app of its own (an unknown page exits 2). The backslash key or Ctrl+b (or a click on the left strip or the breadcrumb) opens and closes the sidebar, Tab and Shift+Tab still change page, and Left opens a collapsed sidebar. --sidebar and --no-sidebar force it either way; below 90 columns it starts collapsed. Nothing is remembered. `tui list` prints the page ids and titles. Enter on a warning shows the plan of the fix before anything changes. --json prints a page's data without a terminal; --demo shows made-up data and runs nothing. Icons are Nerd Font glyphs: on when a Nerd Font is installed, or force them with --icons=on|off or BXRIG_ICONS. `tui apps` is the Apps manager: Installed, Discover and Updates tabs, a search box that is always there, install and remove with a plan first (see the Apps guide).

### `bxrig bxtimemachine` {#bxrig-bxtimemachine}

The same as timemachine: BxTimeMachine, your backups through time.

```text
bxrig bxtimemachine [--demo] [--local]
```

```bash
bxrig bxtimemachine
```

### `bxrig privacy` {#bxrig-privacy}

What leaves this machine: which AI runs where, your keys, agent data, MCP servers, telemetry; and switches for local only and telemetry.

```text
bxrig privacy [--json] | local-only [--off] [--yes] | telemetry off|on [AGENT...] [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig privacy
bxrig privacy local-only --yes
bxrig privacy telemetry off --yes
```

## Develop

BoxLang, editors, databases, containers, virtual machines and AI agents.

### `bxrig boxlang` {#bxrig-boxlang}

BoxLang status, MatchBox home, logs and .env, modules (ForgeBox), the VS Code extension, links.

```text
bxrig boxlang status | check | update [--yes] [--dry-run] | home [--open] | run FILE [ARGS...] | repl | use VERSION [--json]
bxrig boxlang modules list|search TEXT|installed|outdated [--json] | install SLUG... | update [SLUG...] | remove SLUG... [--yes] [--dry-run]
bxrig boxlang servers [list] | status NAME | add PATH [--name=NAME] | scan DIR [--depth=N] [--yes] | remove NAME | start|stop|restart NAME [--dry-run] | log NAME [--follow] | open NAME | folder NAME [--json]
bxrig boxlang matchbox use VERSION | matchbox status | matchbox log-level LEVEL [--yes] | matchbox env list|set KEY VALUE|unset KEY [--yes] | vscode | links | welcome [--json]
```

```bash
bxrig boxlang servers scan ~/code --yes
bxrig boxlang servers start shop-api
bxrig boxlang servers open shop-api
bxrig boxlang check
bxrig boxlang update --yes
bxrig boxlang home --open
bxrig boxlang run hello.bxs
bxrig boxlang modules outdated --json
bxrig boxlang modules remove bx-ftp --yes
bxrig boxlang status
bxrig boxlang modules list
bxrig boxlang use 1.8.0
bxrig boxlang matchbox status
bxrig boxlang matchbox log-level debug --yes
bxrig boxlang matchbox env set OPENAI_API_KEY sk-... --yes
```

> check compares the BoxLang you run (the jar next to `boxlang`) with downloads.ortussolutions.com version-latest.properties and runs `bx-module outdated`; it exits 10 when anything is behind, like `update check`. update uses bvm (`bvm install latest`, `bvm use latest`) when it is there, else the quick installer (`install-boxlang latest --non-interactive`). home is BOXLANG_HOME or ~/.boxlang. run and repl hand the terminal to the real `boxlang`. Module commands wrap bx-module; installed and outdated --json give rows. servers registers BoxLang MiniServer apps (miniserver.json) and CommandBox apps (server.json) in ~/.config/bxrig/servers.json; a MiniServer runs detached with its log in ~/.local/state/bxrig/servers, a CommandBox app through `box server start|stop|log directory=PATH`; running means its port is listening.

### `bxrig editor` {#bxrig-editor}

Neovim with LazyVim, the BoxLang plugin and themes that follow the BxRig theme.

```text
bxrig editor lazyvim [--yes] | boxlang [--yes] | status | refresh [--force] [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig editor lazyvim --yes
bxrig editor status
```

### `bxrig db` {#bxrig-db}

Databases as containers (Podman or Docker): PostgreSQL, MySQL, Redis, MongoDB, Couchbase, vector stores.

```text
bxrig db engines | list | start ENGINE [--name N] [--port P] [--password-file FILE | --ask-password] [--yes] [--dry-run] | stop|status|logs ENGINE [--name N] | remove ENGINE [--name N] [--keep-data] --yes | info ENGINE [--name N] [--show-password] | engine [podman|docker] | menu [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig db engines
bxrig db start postgres --yes
bxrig db info postgres
```

### `bxrig containers` {#bxrig-containers}

Containers on the configured engine (Podman or Docker): list, start, stop, restart, logs; Podman helpers: doctor, rootless socket, docker compatibility.

```text
bxrig containers doctor | socket enable [--yes] | docker-compat [--yes] [--json]
bxrig containers list [--json]
bxrig containers start|stop|restart NAME [--json]
bxrig containers logs NAME [--lines=N] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig containers doctor
bxrig containers list --json
bxrig containers logs web --lines=100
```

### `bxrig vm` {#bxrig-vm}

Virtual machines in containers: Windows (dockur) and Linux desktops (webtop), with sizes and status.

```text
bxrig vm list | status [NAME] | size [NAME] | info NAME [--show-password] | doctor | versions linux|windows | create windows [NAME] [--version=V] [--ram=8G] [--cpus=N] [--disk=64G] [--share=PATH|none] | create linux NAME [--tag=ubuntu-xfce] [--cpus=N] [--memory=4G] [--share=PATH|none] [--gpu=none|auto|intel|amd|nvidia] | start|stop|logs NAME | open NAME [--web] [--fullscreen] | remove NAME [--keep-data] [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig vm doctor
bxrig vm create linux dev --tag=ubuntu-xfce --yes
bxrig vm open dev
```

### `bxrig android` {#bxrig-android}

Android apps on your desktop with Waydroid. Off until you set it up; Google Play by default.

```text
bxrig android [--json] | setup [--vanilla] [--yes] | start | stop | apps | open [APP] | install FILE.apk [--yes] | register [--open] | remove [--data] [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig android
bxrig android setup --yes
bxrig android apps
bxrig android open Firefox
bxrig android install ~/Downloads/app.apk --yes
```

### `bxrig boxy` {#bxrig-boxy}

Boxy's character and voice: name, colour, seasonal outfits, hold-to-talk with Voxtype, speech on this machine (English and Spanish) or from a server. All opt in.

```text
bxrig boxy [--json] | look [--name=N] [--color=theme|#RRGGBB] [--outfit=auto|none|ID] [--holidays=LIST|none] [--birthday=MM-DD]
bxrig boxy export [--dir=DIR] | state | listen start|stop|toggle | say TEXT
bxrig boxy voice [on|off|set] [--url=URL] [--model=M] [--voice=V] [--key=SECRET_NAME] [--format=wav|mp3|opus|flac] [--json]
bxrig boxy voice local [--lang=auto|en|es] [--voice=NAME] [--accent=latam|castilian] [--speed=N] [--hear=auto|en|es] [--yes] | list [--lang=en|es] | test [--lang=en|es]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig boxy
bxrig boxy look --name=Pixel --color=#ff8800 --outfit=auto --holidays=christmas,halloween
bxrig boxy voice set --url=https://api.openai.com/v1/audio/speech --model=tts-1 --voice=alloy --key=OPENAI_API_KEY
bxrig boxy voice local --lang=auto --accent=latam --hear=auto --yes
bxrig boxy voice test --lang=es
bxrig boxy listen toggle
```

### `bxrig ai` {#bxrig-ai}

AI: local models on llama.cpp (hardware, engine, models, the server with OpenAI and Anthropic APIs), BoxLang agents (bx-agents), coding agents, tmux sessions, the pull-down AI shell.

```text
bxrig ai session start [ID] [--name=N] [--dir=PATH] [--dry-run]
bxrig ai session list
bxrig ai session attach NAME
bxrig ai session stop NAME --yes [--json]
bxrig ai status [--json]
bxrig ai hardware [--json]
bxrig ai setup [--models=ID,ID|--picks=all] [--tune] [--yes] [--dry-run]
bxrig ai engine [status|install|update] [--source=official|aur] [--yes] [--dry-run]
bxrig ai models [list] [--json]
bxrig ai models recommend [--all] [--json]
bxrig ai models pull ID|hf:OWNER/REPO[/FILE]... [--no-test] [--background] [--yes]
bxrig ai models use ID
bxrig ai models test [ID]
bxrig ai models tune [ID] [--yes]
bxrig ai models remove ID [--yes] [--dry-run]
bxrig ai serve [status|start|stop|restart] [--listen=127.0.0.1|0.0.0.0] [--port=N] [--yes] [--json]
bxrig ai discover [QUERY] [--fits] [--tools] [--vision] [--embeddings] [--limit=N] [--json]
bxrig ai downloads [clear | cancel ID] [--json]
bxrig ai bench [ID] [--json]
bxrig ai link [opencode|crush [--off] [--default] [--yes] [--dry-run]] [--json]
bxrig ai text summarize|rewrite|fix|explain|translate|reply|menu [--lang=L] [--from=selection|clipboard] [--text=T] [--to=clipboard|notify|stdout] [--json]
bxrig ai ask TEXT [--model=ID] [--json]
bxrig ai agents [list] [--json]
bxrig ai agents install|update [--snapshot|--stable] [--yes] [--dry-run]
bxrig ai agents new NAME [bxAgents new flags]
bxrig ai agents NAME VERB [bxAgents flags]
bxrig ai agents start|stop|status NAME [--json]
bxrig ai agents open [NAME]
bxrig ai agents chat [NAME] [--window]
bxrig ai agents ask TEXT [--agent=NAME] [--thread=ID] [--json]
bxrig ai agents approve|reject THREAD [--agent=NAME] [--session] [--json]
bxrig ai agents setup [--no-start] [--yes] [--dry-run]
bxrig ai agents skills [NAME] [show|approve|remove SKILL] [--all] [--yes] [--json]
bxrig ai agents default [NAME]
bxrig ai agents dir [PATH]
bxrig ai agents add PATH
bxrig ai agents forget NAME [--yes]
bxrig ai agents profile [--off]
bxrig ai list
bxrig ai default [ID] [--yes]
bxrig ai launch [ID] [--dry-run]
bxrig ai panel [--json]
bxrig ai panel list [--json]
bxrig ai panel add ID... [--yes]
bxrig ai panel remove ID... [--yes]
bxrig ai panel reset [--yes]
bxrig ai shell [toggle|status] [--backend=hyprland|yakuake] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig ai setup --yes
bxrig ai models recommend
bxrig ai models pull gemma-4-e4b --yes
bxrig ai discover qwen --fits
bxrig ai agents install --yes
bxrig ai agents Boxy chat
bxrig ai agents setup --yes
bxrig ai serve status
bxrig ai list
bxrig ai session start --name=work
```

### `bxrig mcp` {#bxrig-mcp}

BxRig's own tools for any coding agent or editor, as an MCP server (Boxy's tools, read-only unless --write).

```text
bxrig mcp [--json] | tools | serve [--write] | link [AGENT...] [--write] [--yes] | unlink [AGENT...] [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig mcp
bxrig mcp link --yes
bxrig mcp link pi-agent claude-code --write --yes
bxrig mcp tools
```

### `bxrig skills` {#bxrig-skills}

Agent skills for BoxLang and BxRig: install, update, remove.

```text
bxrig skills list [--tag=T] | search TEXT | show OWNER/REPO/SLUG | install [bxrig|boxlang|matchbox|OWNER/REPO/SLUG]... [--yes] | installed | update [--yes] | remove NAME [--yes] | status | link [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig skills install --yes
bxrig skills list
bxrig skills status
```

## Everyday tools

Screenshots, clipboard, windows, dictation and hardware helpers.

### `bxrig screenshot` {#bxrig-screenshot}

Screenshots: screen, region, window, OCR text, QR codes, a color picker, or a menu.

```text
bxrig screenshot screen|region|window [--edit] | ocr | qr | color | menu [--dry-run] [--json]
```

```bash
bxrig screenshot region
bxrig screenshot screen --edit
bxrig screenshot ocr
bxrig screenshot color
```

### `bxrig qr` {#bxrig-qr}

Make a QR code from text (printed in the terminal, or saved with --out).

```text
bxrig qr TEXT [--out=FILE.png] [--json]
```

```bash
bxrig qr https://boxlang.io
bxrig qr 'wifi text' --out=wifi.png
```

### `bxrig share` {#bxrig-share}

Send files, a folder or the clipboard to a phone or computer nearby with LocalSend, or open it to receive.

```text
bxrig share file [PATH...] | folder [PATH] | clipboard [--to=DEVICE] [--dry-run] [--json]
bxrig share receive [--dry-run] [--json]
```

```bash
bxrig share file report.pdf
bxrig share folder ~/Photos/trip --to="Pixel 9"
bxrig share clipboard
bxrig share receive
```

> Sending uses LocalSend's command line, localsend-cli (LocalSend 1.18 and later): without --to it lists the devices it finds and you pick one, on your terminal (the menu opens one). Without a path a file chooser asks (kdialog on Plasma, else zenity). clipboard sends what you copied as a text file. receive opens the LocalSend app. Exit 4 when localsend-cli or LocalSend is missing.

### `bxrig record` {#bxrig-record}

Screen recording: start, stop, toggle, with desktop or microphone audio if you like.

```text
bxrig record [toggle|start|stop|status] [--region] [--audio=desktop|mic] [--webcam[=bottom-right|bottom-left|top-right|top-left]] [--webcam-size=small|medium|large] [--dry-run] [--json]
```

```bash
bxrig record toggle
bxrig record start --region
bxrig record toggle --audio=desktop
bxrig record toggle --webcam
bxrig record start --webcam=top-left --webcam-size=small --audio=mic
```

> --audio=desktop adds what the speakers play, --audio=mic the default microphone (both through pactl). Desktop and microphone together are not offered: wf-recorder takes one audio source. Exit 2 for another audio value. --webcam puts your webcam in a corner while it records (bottom-right unless you name another), so it is in the video; it ends with the recording. Hyprland pins it (the BxRig module's rules); on Plasma it is a small window you can drag.

### `bxrig browser` {#bxrig-browser}

Your default browser in a private window.

```text
bxrig browser private [URL] [--dry-run] [--json]
```

```bash
bxrig browser private
bxrig browser private https://example.com --dry-run
```

> Reads the default web browser (set by `default browser` or the wizard) and starts it with its private flag: Firefox --private-window, Chromium, Brave and Chrome --incognito, Edge --inprivate. Another browser exits 4.

### `bxrig files` {#bxrig-files}

Your default file manager in the folder of the focused window.

```text
bxrig files here [DIR] [--dry-run] [--json]
```

```bash
bxrig files here
bxrig files here ~/Documents
```

> Without DIR it uses the working directory of the focused window's newest child process (Hyprland), else your home folder, and opens it with xdg-open, so `default filemanager` decides which file manager.

### `bxrig webcam` {#bxrig-webcam}

A small live webcam preview, on or off with one key.

```text
bxrig webcam toggle|status [--dry-run] [--json]
```

```bash
bxrig webcam toggle
bxrig webcam status
```

> mpv on /dev/video0 in a window of class bxrig-webcam, which the Hyprland module floats and sizes. Exit 4 without mpv or a webcam.

### `bxrig clipboard` {#bxrig-clipboard}

Clipboard history (cliphist): pick, list, clear, setup.

```text
bxrig clipboard pick | clear [--yes] | status [--json]
```

```bash
bxrig clipboard pick
bxrig clipboard status
```

### `bxrig emoji` {#bxrig-emoji}

The emoji picker (rofimoji).

```text
bxrig emoji
```

```bash
bxrig emoji
```

### `bxrig forcequit` {#bxrig-forcequit}

Pick a window or process and force quit it.

```text
bxrig forcequit
```

```bash
bxrig forcequit
```

### `bxrig window` {#bxrig-window}

Minimize, restore and snap windows, and the quake console.

```text
bxrig window minimize|restore|quake [--json]
bxrig window quake send [--json]
bxrig window snap left|right|top|bottom [--json]
bxrig window close-all | tiled-fullscreen [--json]
```

```bash
bxrig window minimize
bxrig window restore
bxrig window quake
bxrig window quake send
bxrig window snap left
bxrig window tiled-fullscreen
```

> quake shows or hides the special workspace qconsole (the default terminal starts there the first time); quake send moves the focused window onto it. snap left|right|top|bottom floats the focused window onto that half of its monitor. Hyprland only. close-all asks every window to close (apps with unsaved work still ask), then goes to workspace 1; tiled-fullscreen makes the app full screen inside its tile (again to undo).

### `bxrig overview` {#bxrig-overview}

The workspace and window overview.

```text
bxrig overview [setup]
```

```bash
bxrig overview
```

### `bxrig quicklook` {#bxrig-quicklook}

Quick Look for files (Kiview): preview with a key.

```text
bxrig quicklook [PATH] [--dry-run] [--json]
```

```bash
bxrig quicklook photo.jpg
```

### `bxrig dolphin` {#bxrig-dolphin}

Dolphin diagnostics: why it is slow or missing features.

```text
bxrig dolphin doctor [--fix] [--json]
```

```bash
bxrig dolphin doctor
bxrig dolphin doctor --fix
```

### `bxrig dictation` {#bxrig-dictation}

Dictation with Superwhisper or Voxtype: setup and toggle.

```text
bxrig dictation setup [superwhisper|voxtype] [--yes] | status | key [ENGINE] | toggle [--dry-run] [--json]
```

```bash
bxrig dictation setup voxtype --yes
bxrig dictation status
bxrig dictation toggle
```

### `bxrig strata` {#bxrig-strata}

Strata, the file manager: its integrations.

```text
bxrig strata integrations [--dry-run] [--json]
```

```bash
bxrig strata integrations --dry-run
```

### `bxrig gpu` {#bxrig-gpu}

GPU check: driver, rendering, NVIDIA specifics; the mode of a laptop with two GPUs.

```text
bxrig gpu doctor [--json]
bxrig gpu mode [status] [--json]
bxrig gpu mode hybrid|integrated [--yes] [--dry-run] [--json]
```

```bash
bxrig gpu doctor
bxrig gpu mode
bxrig gpu mode integrated --yes
```

> mode needs two GPUs (counted in /sys/bus/pci/devices) and supergfxctl (supergfxd); a switch is `supergfxctl -m Hybrid|Integrated`, then log out or reboot.

### `bxrig input` {#bxrig-input}

Input devices: Apple Magic Mouse and Trackpad, Logitech, the helpers for them, the older doctor and trackpad gestures.

```text
bxrig input status [--json]
bxrig input offer [--for=detect|apple|logitech|both|none] [--yes] [--dry-run] [--json]
bxrig input apple [--scroll-speed=0..63] [--yes] [--dry-run] [--json]
bxrig input logitech [--json]
bxrig input undo [--yes] [--dry-run] [--json]
bxrig input doctor | gestures [--yes] [--dry-run] [--json]
bxrig input touchpad|touchscreen [on|off|toggle|status] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig input status
bxrig input offer --dry-run
bxrig input apple --scroll-speed=48 --yes
bxrig input logitech
bxrig input touchpad off
```

> touchpad and touchscreen switch the device off and on in a Hyprland session (hyprctl eval hl.device); a login turns it back on.

### `bxrig audio` {#bxrig-audio}

Sound server status: outputs, inputs, volumes and the defaults.

```text
bxrig audio status [--json]
```

```bash
bxrig audio status
bxrig audio status --json
```

> Read only, through `pactl`. Volume and mixing are in the bar panel (Super+Ctrl+A) and in the terminal mixer in the Hardware menu. Exit 4 when `pactl` is missing or no sound server answers.

### `bxrig bluetooth` {#bxrig-bluetooth}

Bluetooth status: the service, the adapter and the paired devices.

```text
bxrig bluetooth status [--json]
```

```bash
bxrig bluetooth status
bxrig bluetooth status --json
```

> Read only, through `bluetoothctl` and `systemctl`. Pairing is in the bar panel (Super+Ctrl+B) and in the terminal UI in the Hardware menu. Exit 4 when `bluetoothctl` is missing.

### `bxrig wifi` {#bxrig-wifi}

Wi-Fi status: the radio, the Wi-Fi devices and the network you are on; a QR code to join it.

```text
bxrig wifi status [--json]
bxrig wifi qr [--out=FILE.png] [--json]
```

```bash
bxrig wifi status
bxrig wifi status --json
bxrig wifi qr
bxrig wifi qr --out=wifi.png
```

> Read only, through `nmcli` (NetworkManager). Joining a network is in the bar panel (Super+Ctrl+N). Exit 4 when `nmcli` is missing. qr draws the network you are on as a QR code a phone camera reads to join (qrencode); the password is in the code only, never printed.

### `bxrig airplay` {#bxrig-airplay}

AirPlay receiver: on, off, status.

```text
bxrig airplay on|off|status [--json]
```

```bash
bxrig airplay on
```
