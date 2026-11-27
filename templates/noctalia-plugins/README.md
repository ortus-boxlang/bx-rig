# BxRig Noctalia plugins

Noctalia v5 plugins (author id `bxrig`). Each folder is one plugin.

| Folder | Plugin id | Entries | Data source |
|---|---|---|---|
| `clock/` | `bxrig/clock` | bar widget `bar` (the time as text), panel `panel` | text: `noctalia.formatTime` with the `format` setting; panel: `bxrig time world --json`, every 30 s while open |
| `agents/` | `bxrig/agents` | bar widget `bar`, panel `panel` | `bxrig ai panel --json`, every 60 s while open; launch runs `bxrig ai launch <id>` |
| `system/` | `bxrig/system` | bar widget `bar` (a glyph and the number of waiting updates, hidden at 0), panel `panel` (tabs Updates and Backups) | `bxrig system updates --json` every 10 min in the background and every 60 s while open; `bxrig backup status --json` every 60 s while open; Update all runs `bxrig system update --yes` in a terminal; Back up now runs each row's own command in a terminal; Open Time Machine runs `bxrig timemachine` in a terminal |
| `dev/` | `bxrig/dev` | bar widget `bar` (a code glyph and the number running), panel `panel` (tabs Databases, Containers, VMs) | `bxrig db list --json`, `bxrig containers list --json`, `bxrig vm list --json`; every 15 s while open, every 2 min for the badge |
| `vpn/` | `bxrig/vpn` | bar widget `bar` (a shield glyph: primary green while connected, muted otherwise, hidden when nothing is installed), panel `panel` (one list, two groups, place picker) | `bxrig vpn list --json`, every 10 s while open and every 60 s in the background; places `bxrig vpn locations NAME --json`; `bxrig vpn connect NAME [--location=VALUE]`, `bxrig vpn disconnect NAME`, `bxrig vpn set allow_several=true|false --yes` |
| `quick/` | `bxrig/quick` | bar widget `bar`, panel `panel` (switches and pickers), panel `themes` (theme switcher) | the `status` of each setting on open; each control runs its bxrig command with `--yes`; themes: `bxrig theme list --json` on open, Enter runs `bxrig theme set <name> --yes` |
| `power/` | `bxrig/power` | panel `panel` only, no bar widget: the battery widget opens it | `bxrig power status --json`, every 15 s while open; profile `bxrig power profile`, lid `bxrig power lid battery|ac ACTION --yes`, `bxrig system suspend`, `bxrig power hibernate --yes`, `bxrig power charge-limit N --yes` |
| `launcher/` | `bxrig/launcher` | panel `panel` (the launcher), panel `clipboard` (clipboard history); no bar widget | `bxrig launcher search QUERY --limit=30 --json` on every keystroke, Enter runs `bxrig launcher run ID QUERY`; clipboard: `bxrig clipboard list QUERY --limit=60 --json`, `clipboard show ID --json`, `clipboard copy ID`, `clipboard clear --yes` |

The plugins use `plugin_api = 43`. They only draw with palette roles, so they follow the active Noctalia theme. Every file in a folder ships together. `bxrig.luau` is the same helper in every plugin: it runs bxrig and unwraps the `{"ok":…,"data":…}` envelope.

## Install

Noctalia finds hand-placed plugins in `~/.local/share/noctalia/plugins/<folder>/` (the built-in `local` source). Being installed does not make a plugin active: each one must also be enabled.

```sh
mkdir -p ~/.local/share/noctalia/plugins
for p in clock agents system quick dev power vpn launcher; do
  rm -rf ~/.local/share/noctalia/plugins/$p
  cp -r templates/noctalia-plugins/$p ~/.local/share/noctalia/plugins/$p
done
noctalia msg plugins enable bxrig/clock
noctalia msg plugins enable bxrig/agents
noctalia msg plugins enable bxrig/system
noctalia msg plugins enable bxrig/quick
noctalia msg plugins enable bxrig/dev
noctalia msg plugins enable bxrig/power
noctalia msg plugins enable bxrig/vpn
noctalia msg plugins enable bxrig/launcher
noctalia msg plugins list | grep bxrig     # each shows "enabled"
```

Enabling adds the id to `enabled = [...]` under `[plugins]` in Noctalia's state-dir `settings.toml` (`~/.local/state/noctalia/settings.toml`). As an alternative, BxRig can write the ids into its own `config.toml`:

```toml
[plugins]
enabled = ["bxrig/clock", "bxrig/agents", "bxrig/system", "bxrig/quick", "bxrig/dev", "bxrig/power", "bxrig/vpn", "bxrig/launcher"]
```

To disable a plugin and keep its files: `noctalia msg plugins disable bxrig/<name>`.

Noctalia hot-reloads edited `.luau` files. If you replace a whole plugin folder (`rm -rf` + `cp`), the reload is not reliable. Disable and re-enable the plugin after an upgrade.

## Open the panels (for keybinds)

```sh
noctalia msg panel-toggle bxrig/clock:panel
noctalia msg panel-toggle bxrig/agents:panel
noctalia msg panel-toggle bxrig/system:panel
noctalia msg panel-toggle bxrig/dev:panel
noctalia msg panel-toggle bxrig/quick:panel
noctalia msg panel-toggle bxrig/quick:themes
noctalia msg panel-toggle bxrig/power:panel
noctalia msg panel-toggle bxrig/vpn:panel
noctalia msg panel-toggle bxrig/launcher:panel
noctalia msg panel-toggle bxrig/launcher:clipboard
```

Example Hyprland binds:

```
bind = SUPER, W, exec, noctalia msg panel-toggle bxrig/clock:panel
bind = SUPER, A, exec, noctalia msg panel-toggle bxrig/agents:panel
bind = SUPER CTRL, T, exec, noctalia msg panel-toggle bxrig/quick:themes
```

Opened from a key, the clock, agents and quick settings panels are attached panels and appear near the bar. The theme switcher (`bxrig/quick:themes`, the second page of quick settings, opened by its Themes row) floats in the center of the screen and takes the keyboard:

- Typing filters the list.
- Up, Down, Page Up and Page Down move the selection.
- Enter applies the selected theme.
- Esc closes the panel.

## Bar widgets

A plugin widget is referenced as `<author>/<plugin>:<entry>`. Define a widget instance, then list it in a bar section:

```toml
[widget.bxrig-clock]
type = "bxrig/clock:bar"     # the time as text: click opens the panel, right click the calendar

[widget.bxrig-agents]
type = "bxrig/agents:bar"          # robot -> agents panel

[widget.bxrig-system]
type = "bxrig/system:bar"         # glyph + update count -> updates and backups

[widget.bxrig-quick]
type = "bxrig/quick:bar"           # sliders -> quick settings (the theme switcher is its second page)

[widget.bxrig-dev]
type = "bxrig/dev:bar"             # code glyph + number running -> developer popover

[widget.bxrig-vpn]
type = "bxrig/vpn:bar"             # shield (green while connected), hides itself when no VPN is installed -> VPN list

[bar.main]
center = ["bxrig-clock", "media"]
end = ["bxrig-agents", "screenshot", "bxrig-system", "bxrig-dev", "bxrig-vpn", "tray", "network", "bluetooth", "volume", "battery", "notifications", "bxrig-quick", "control-center"]
```

`bxrig appearance bar layout minimal|standard|dense` writes the whole bar (these widgets, the built-in ones, the dock) into config.toml for you; the three layouts are in `docs/guides/appearance.md`. Caffeine is not a bar widget: it is a switch in quick settings. The power panel (`bxrig/power`) has no bar widget either: the built-in battery widget opens it.

The battery widget is the built-in one (written only on a laptop). A left click opens the BxRig power panel, a right click the control center Power tab, and the separate `power_profile` widget stays off the bar (battery and power are one panel):

```toml
[widget.battery]
type = "battery"

[widget.battery.actions]
left = "panel-toggle bxrig/power:panel"     # a plugin panel is addressed <author>/<plugin>:<entry>
right = "panel-toggle control-center power"
```

`noctalia config validate` checks the config without loading any plugins. It therefore warns `unrecognized widget type "bxrig/…:bar"` and `no loaded plugin with this id`, but it still reports the config as valid. The running shell resolves the widget types once the plugins are enabled.

## Settings

The clock has a second plugin-level setting, `format`: the text of the bar clock in Noctalia date format tokens (https://docs.noctalia.dev/noctalia/configuration/date-format-tokens/), default `%b %-d - %H:%M` ("Nov 5 - 04:00"). `bxrig time format FORMAT` writes it:

```toml
[plugin_settings."bxrig/clock"]
format = "%a %-I:%M %p"
```

The bar text is redrawn on the minute (every second when the format shows seconds). The id was `bxrig/world-clock` before the clock and the world clock became one widget; this is the first version, so there is nothing to migrate.

Each plugin has a plugin-level setting `command`, which defaults to `bxrig`. It is the bxrig executable: a name on Noctalia's PATH, an absolute path, or a `~/` path. The shell may be started without `~/.local/bin` on its PATH. In that case, BxRig should pin the path:

```toml
[plugin_settings."bxrig/clock"]
command = "~/.local/bin/bxrig"

[plugin_settings."bxrig/agents"]
command = "~/.local/bin/bxrig"

[plugin_settings."bxrig/quick"]
command = "~/.local/bin/bxrig"

[plugin_settings."bxrig/power"]
command = "~/.local/bin/bxrig"

[plugin_settings."bxrig/dev"]
command = "~/.local/bin/bxrig"

[plugin_settings."bxrig/vpn"]
command = "~/.local/bin/bxrig"
```

## JSON contracts

The plugins read the envelope `{"ok": true, "data": {...}}`. When `ok` is false, the panel shows `data.error` (or a top-level `error`).

- `bxrig time world --json`:
  - `data.here`: `{city, time}`.
  - `data.zones[]`: `{label, tz, time, date, relative_day ("today"|"tomorrow"|"yesterday"), abbrev, offset ("+6h"; "+0h" is hidden), day_fraction (0..1 from local midnight), is_day}`.
- `bxrig ai panel --json`:
  - `data.tokens_today`: a number, or null to hide the count.
  - `data.agents[]`: `{id, name, installed, accounts[]}`.
  - `accounts[]`: `{name, plan, active, meters[]}`.
  - `meters[]`: `{label, used_fraction, resets_in}`.
  - An account with no meters, or an agent with no accounts, shows "no usage data".
- `bxrig system updates --json` (System, tab Updates and the bar badge):
  - `data.total`, `data.repo_count`, `data.aur_count`: the counts (the badge shows `total`, hidden at 0).
  - `data.packages[]`: `{name, old, new, repo ("repo"|"aur")}`.
  - `data.needs_reboot`, `data.reboot_pending`, `data.reboot_stale`, `data.reboot_reasons[]`: the restart banner. A pending kernel, systemd, glibc, firmware, microcode or NVIDIA driver update, or a running kernel that was already replaced.
  - `data.last_update_ago`: "3 days ago" or "" (not found in the pacman log); `data.snapshot_tool`: snapper, timeshift or "" (the snapshot-first note); `data.aur_error`: set when the AUR helper failed.
  - Exit 4 (no `checkupdates`, no network) arrives as `ok` false and `data.error`; the tab shows it, and offers to install pacman-contrib when that is the cause.
- `bxrig backup status --json` (System, tab Backups):
  - `data.rows[]` (config, system, data): `{id, label, kind, last_ago, next, size_text, health ("ok"|"warn"|"none"), note, action[]}`. `action` is the `bxrig` words that back that row up now, `[]` when it cannot be done yet (the row's play button is disabled).
  - `data.warn_count` puts a warning glyph on the Backups tab.
- Quick settings page 1 reads `bxrig theme status --json` (`data.mode`, `data.name`), `bxrig notify dnd status --json` (`data.output`, `on` or `off`), `bxrig appearance dock|appgrid|bar layout|battery-percent status --json` (`data.dock`, `data.appgrid`, `data.layout`, `data.battery_percent` and `data.battery_found`) and `bxrig time format status --json` (`data.format`). It writes with `bxrig toggle stay-awake on|off`, `notify dnd on|off`, `theme mode theme|dark|light|auto`, `appearance dock on|off`, `appearance appgrid launchpad|terminal`, `appearance bar layout minimal|standard|dense`, `appearance battery-percent on|off` and `time format FORMAT`, always with `--yes`. A bar config.toml with changes of your own is replaced (a backup is kept) because of that `--yes`. Caffeine has Noctalia IPC to switch it (`noctalia msg caffeine-enable|disable|toggle`) but none to read it back, so its switch shows what the panel last set (kept until Noctalia restarts). Night light has no command here: a button opens the control center Home tab.
- `bxrig power status --json` (the power panel):
  - `data.battery[]`: `{name, percent, status, state ("charging"|"discharging"|"full"|"not_charging"|"unknown"), watts, time_remaining_minutes, health_percent, cycles, charge_limit, charge_limit_supported}`; a number the battery does not report is `-1`.
  - `data.on_ac`, `data.profile` (`power-saver`, `balanced`, `performance`), `data.lid_battery` and `data.lid_ac` (`suspend`, `hibernate`, `lock`, `ignore`, `default` for the systemd default), `data.charge_limit_supported`.
  - The panel greys Hibernate out with the reason when `bxrig power hibernate --dry-run --json` fails (exit 4, `data.error`). The lid and charge limit commands need sudo, so the panel runs them in a terminal window, where the password is asked.
- `bxrig theme list --json`:
  - `data.current`: the active theme's name.
  - `data.themes[]`: `{name, label, light, preview?, wallpaper?}`.
  - The preview pane uses `preview`, falls back to `wallpaper`, and shows a placeholder otherwise. Paths must be local files (absolute or `~/`).
- `bxrig db list --json`:
  - `data.databases[]`: `{container, status, state ("running"|"paused"|"created"|"exited"), image, engine, name, port}`. `engine` is empty for a container that has no BxRig record; its row only offers logs.
  - The connection string comes from `bxrig db info ENGINE --name=NAME --show-password --json` (`data.url`) when the copy button is clicked.
- `bxrig containers list --json`:
  - `data.containers[]`: `{name, image, state, ports (host port numbers), ports_text, created, kind ("container"|"database"|"vm")}`. The Containers tab shows `kind` "container" only; databases and VMs have their own tabs.
- `bxrig vm list --json`:
  - `data.vms[]`: `{name, kind ("linux"|"windows"), what, state, ports {web, rdp?}, url, size_kb}`; `state` is the engine state, or "missing" when the container is gone.

## The Developer popover

- Rows show a state dot (running, paused, stopped, missing), the name, the host ports as chips and the image.
- Start and stop run `bxrig db start ENGINE --name=NAME --yes` and `db stop`, `bxrig containers start|stop|restart NAME`, `bxrig vm start|stop NAME`. Stop and restart ask for a second click: the button turns into "Sure?" for 4 seconds.
- Copy puts a database connection string (with its password) or a VM address on the clipboard through the shell (`noctalia.copyToClipboard`), so nothing secret is on a command line; `wl-copy` is the fallback when the shell cannot.
- Logs opens `bxrig containers logs NAME --lines=500` in a terminal (`noctalia.runInTerminal`), paged with `less`. "Open Machines page" opens `bxrig tui machines`.
- Without a container engine the Databases and Containers tabs say "No container engine installed" and how to install Podman; the VMs tab still lists the saved VMs.

## The VPN popover

- One pick-one list in two groups. **Network profiles** are the saved NetworkManager connections of type `vpn` or `wireguard` (`nmcli`); **VPN apps** are NordVPN, NordLayer, Tailscale and Mullvad, the ones that are installed. A row has a state dot, the name, one line of state ("Connected · Berlin, Germany", "Off", "Log in first"), a pin button where the app can pick a place, and a switch. The adapters (which command each app takes) are data in `catalog/vpn-providers.json`; see `docs/architecture/COMMAND-CONTRACT.md` 13.58.
- Switching one on disconnects the VPN that is connected first. The switch at the bottom, "Allow more than one at the same time" (`bxrig vpn set allow_several=true --yes`), lifts that (Tailscale next to another VPN); a line then warns that two VPNs can clash on routes and DNS.
- The pin button opens a second page with a search box and the places of that app (`bxrig vpn locations NAME --json`: NordVPN countries, Tailscale exit nodes, Mullvad countries and cities, NordLayer gateways); a click runs `bxrig vpn connect NAME --location=VALUE`.
- The shield in the bar is a bare glyph in one palette role: `primary` (the brand green) with a check while a VPN is connected, `on_surface_variant` while none is. Noctalia has no success role, so `primary` is "connected". It hides itself when `bxrig vpn list` is empty (no VPN app and no saved VPN profile); when two VPNs are connected it shows their number.
- Empty list: the popover (open it with `noctalia msg panel-toggle bxrig/vpn:panel`) says "No VPN is installed" and has an install button per app that runs `bxrig install NAME --yes` in a terminal that waits for Enter.
- `bxrig vpn list --json`: `data.providers[]`: `{id, name, group ("profiles"|"apps"), kind, state ("connected"|"connecting"|"disconnected"|"login"|"unavailable"|"unknown"), connected, location, detail, can_pick, coexist, verified, note}`, plus `data.connected[]` (ids), `data.allow_several` and `data.install[]` (`{id, name, install}`).
- The bar shield refreshes every 60 s; the popover every 10 s while it is open, and the shield follows the popover through `noctalia.state`.
