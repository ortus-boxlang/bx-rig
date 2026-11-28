---
title: Desktop decisions
order: 93
hidden: true
summary: Owner decisions on the desktop shell (top bar, dock, icons, themes, helpers). Status is decided or planned.
---

# Desktop decisions (owner, 2026-11-17)

Status: **decided** means the owner chose it; **planned** means it is agreed and scheduled but not built yet.

## Top bar and dock

| Decision | Choice | Status |
|---|---|---|
| Top bar layout (wizard) | Asks Minimal, Standard (default, recommended) or Dense, with a preview in the TUI | decided |
| Minimal layout | Keeps workspaces, active window and quick settings | decided |
| Dock | ON by default; its first icon is the pinned Apps entry (`bxrig-apps.desktop`), which opens the BxRig app grid (`bxrig/launcher:apps`); the built-in launcher button is off; with the dock off, the same Apps button sits in the bar after the logo | decided |
| Clock | One widget showing `Nov 5 - 04:00` (format is user-configurable); its popover shows other zones and a route to the calendar; clock and world clock are merged | decided |
| Battery | Shows the percentage, and only on laptops | decided |
| Clipboard history | Top right of the bar | decided |
| Last two icons | Quick settings, then control center (control center is last) | decided |
| Caffeine | A switch inside quick settings | decided |
| Quick settings | The `bxrig/quick` plugin (evolved from the theme switcher): a popover of switches and pickers (Caffeine, Do Not Disturb, Dark/Light/Auto, Dock, Battery percentage, App grid style, Top bar layout, Clock format, Night light note, Control Center button), with the theme list and preview as its second page (Themes row) | decided |
| Battery and power | One panel: the built-in battery widget stays; left click opens the `bxrig/power` panel (profile, lid on battery and AC, Suspend, Hibernate, charge limit when supported), right click the control center Power tab; the `power_profile` widget stays off the bar | decided |
| Brightness, weather | Noctalia built-ins, not on the bar | decided |
| VPN | Its own bar icon; NordVPN, NordLayer, Tailscale, Mullvad and NetworkManager profiles in one pick-one list with data-driven adapters; an allow-several toggle (built: `bxrig vpn`, plugin `bxrig/vpn`; the look is checked on screen later) | decided |
| System popover | Updates and Backups (`bxrig/system`: bar glyph with the waiting-update count, tabs Updates and Backups; built, visual check pending) | decided |
| Developer panel | Separate from System: databases, containers, VMs (plugin `bxrig/dev`, `bxrig containers list\|start\|stop\|restart\|logs`) | decided |
| Capture icon | On Standard and Dense | decided |
| Noctalia control center | Reused, not extended (tabs cannot be added); only the screen-time tab is hidden | decided |
| Panel keys | `Super+Ctrl+A/B/N/P/D` fixed (they open the control center) | decided |
| Hardware menu (`Super+Ctrl+H`) | Kept | decided |

## Icons, apps and themes

| Decision | Choice | Status |
|---|---|---|
| Icon style on the bar | Hybrid: bare Tabler outline glyphs colored by one palette role; plates only on the logo button and on the Launchpad grid in the dock (plates need an outline or glow on dark and Retro) | decided |
| Icon theme | `BxRig`, style A (superellipse tile, vertical glow, Phosphor duotone, MIT notice), new `bxrig-*` names, `Inherits=Papirus-Dark`; our icon where we have one, else Papirus; the icon set is not asked in the wizard. Built: `tools/gen-icon-theme.py` (31 icons, 16 to 256 px, bold darker variant at 16 and 22 px), `bxrig appearance icons bxrig\|papirus\|status`, applied automatically by `init` | decided, built |
| App grid | Default Launchpad; a second style, Terminal-style grid, is selectable in quick settings via `appearance appgrid` | planned |
| Theme selection | A separate, bigger TUI selector plus a wizard Theme page (default BxRig); the Look page has no theme list (built: `bxrig tui themes`, list with swatches, filters, wallpaper, palette and sample terminal preview, `r` live preview; the wizard page keeps its own list) | decided |
| Retro theme | `bxrig-retro` (80s synthwave, neon magenta #ff2ec4) with Share Tech Mono Nerd (`ttf-sharetech-mono-nerd`, named by `font = "sharetech"` in its colors.toml); wallpaper drawn by `tools/gen-retro-wallpaper.py`; `bxrig banner` is its ASCII greeting. Not done: a starship accent and wiring the banner into the starter shell | decided |
| Wizard colors | The wizard follows the chosen theme (TuiKit must stop hard-coding the Frappe palette) | planned |
| Noctalia plugin store | The official store is not used; pinned own plugins only | decided |

## Helpers, defaults and roadmap

| Decision | Choice | Status |
|---|---|---|
| Logitech | Solaar is the helper; logiops is dropped; libratbag and Piper for gaming mice | decided |
| Password managers | Added to the catalog | decided |
| Default apps | Gwenview, Okular, Satty, Signed | decided |
| AI launcher (`bxrig ask`, Tab mode) | Deferred to later | planned |
| BxRig modules planning (MX1) | After the bar foundation | planned |
