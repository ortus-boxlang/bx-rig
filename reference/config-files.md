---
title: Files and folders
order: 2
summary: Where BxRig keeps things.
---

# Files and folders

**Where the folders are.** One rule for every file BxRig writes: `BXRIG_CONFIG_HOME`, then `XDG_CONFIG_HOME`, then `~/.config` for the config folder (the same for `BXRIG_STATE_HOME`/`XDG_STATE_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`). If you set `XDG_CONFIG_HOME`, everything below that says `~/.config` lives under it instead, including `bxrig/`, `menus/`, `nvim/` and `strata/`. `BXRIG_DATA_HOME` and `BXRIG_CACHE_HOME` name BxRig's own data and cache folder directly (default `~/.local/share/bxrig`, `~/.cache/bxrig`). The tests use these overrides. `BXRIG_APPS_DIRS` replaces the folders read for `.desktop` files.

| Path | What |
|---|---|
| `~/.local/bin/bxrig` | the program |
| `~/.config/bxrig/answers.json` | your wizard answers (mode 600, no secrets) |
| `~/.config/bxrig/shortcuts.json` | your shortcut changes (`keys set`) |
| `~/.config/bxrig/keystyle.json` | the shortcut style (`traditional` or `mac`), the keyboard (`pc` or `apple`) and the Alt/Win swap |
| `~/.config/xremap/config.yml` | generated xremap remaps (Cmd-style keys, and the Alt/Win swap in the Mac style on a PC keyboard); never edit |
| `~/.config/systemd/user/xremap.service` | runs xremap with that file |
| `~/.config/bxrig/runner.json` | launcher and menu program |
| `~/.config/bxrig/update.json` | update channel and notification setting |
| `~/.config/bxrig/skills.json` | the agent skills BxRig installed |
| `~/.config/bxrig/appearance.json` | what you chose in `bxrig appearance` (bar layout, dock, app grid, battery percentage, clock format, windows, font) |
| `~/.local/share/bxrig/plates/` | the logo-button and Launchpad-grid plates (SVG and PNG) the Noctalia bar and dock point at |
| `~/.matchbox.env` | your MatchBox environment variables (`bxrig boxlang matchbox env`, mode 600); a MatchBox with a runtime home reads it on every run |
| `~/.matchbox/config/boxlang.json` | the MatchBox runtime config (`bxrig boxlang matchbox log-level` changes `logging.rootLevel`); `MATCHBOX_HOME` moves the home |
| `~/.boxlang` | BoxLang's home: modules (`bxrig boxlang modules`), `config/boxlang.json` and logs; `BOXLANG_HOME` moves it (`bxrig boxlang home`) |
| `~/.config/bxrig/display.json` | what you chose in `bxrig display` (scale, rotation, mirror, laptop panel) |
| `~/.config/bxrig/theme.json` | the current theme and mode |
| `~/.config/bxrig/theme/hypr.lua` | generated Hyprland border colours of the theme; never edit |
| `~/.config/bxrig/theme/look.lua` | generated Hyprland window looks (gaps, corners, opacity); never edit |
| `~/.config/bxrig/theme/monitors.lua` | generated Hyprland monitor settings; never edit |
| `~/.config/bxrig/nas.json` | your NAS boxes (no passwords) |
| `~/.config/bxrig/backup.json` | backup places, what is backed up, retention, schedule (no keys) |
| `~/.local/share/bxrig/backups/config/` | your BxRig config snapshots |
| `/etc/bxrig/nas/NAME.cred` | the SMB credentials of a NAS, root only (mode 600) |
| `~/.config/systemd/user/bxrig-backup.{service,timer}` | the automatic file backup |
| `~/.config/bxrig/vms/` | one record per virtual machine |
| `/etc/systemd/logind.conf.d/50-bxrig-lid.conf` | what closing the lid does (`bxrig power lid`); remove it to go back to the defaults |
| `/etc/pam.d/sudo` and `.bxrig-backup` | one marked line per `bxrig security fingerprint\|fido2 on`; the backup is the original |
| `/etc/sudoers.d/50-bxrig-nopasswd` | passwordless sudo (`bxrig security passwordless-sudo on`) |
| `/etc/systemd/system/automatic-timezoned.service`, `/etc/geoclue/conf.d/90-bxrig-timezone.conf` | the automatic time zone (`bxrig time auto on`) |
| `~/.config/bxrig/plasma-panels/` | the Plasma panel layout and its backup |
| `~/.config/bxrig/welcome.html` | the getting-started page |
| `~/.config/bxrig/agents.json` | BoxLang agents: each project's port, the default agent, the projects folder when you changed it, projects added by path, the agents' skills you reviewed |
| `~/.config/systemd/user/bxrig-agent-NAME.service` | one BoxLang agent running in the background (`bxrig ai agents start NAME`) |
| `~/Agents/` | your BoxLang agent projects (`BXRIG_AGENTS_DIR` or `bxrig ai agents dir PATH` moves it) |
| `~/.bxagents/Agent.yml` | bx-agents' settings for all your agents; BxRig writes only its marked `bxrig` profile block (`BXAGENTS_USER_CONFIG` names another file) |
| `~/.bxagents/NAME/` | each agent's data (chats, notes, files, skills, logs): bx-agents' own default |
| `~/.config/hypr/bxrig.lua` | generated Hyprland module (never edit); `hyprland.lua` is yours |
| `~/.agents/skills/` | the agent skills store, linked into each agent |
| `~/.config/systemd/user/bxrig-*.service` | night shift, AirPlay, update check, cloud mounts |
| `~/.cache/bxrig/install.log` | the installer's log |
| `~/Videos/bxrig-YYYYMMDD-HHMMSS.mp4` | screen recordings (`bxrig record`; `BXRIG_VIDEOS` changes the folder) |

Every file BxRig writes goes through one safe writer: atomic replace, a backup, a journal, and a **drift** check. A file you changed is kept and reported as drifted. `bxrig config diff NAME` shows how it differs from what BxRig would write.
