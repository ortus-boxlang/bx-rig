---
title: Displays, power and time
order: 4
summary: Monitors, laptop power, the time zone when you travel, DNS, kernels and stay awake.
---

# Displays, power and time

## Displays

```bash
bxrig display list
bxrig display scale DP-2 1.5          # auto or 0.5 to 4
bxrig display rotate DP-2 90
bxrig display mode DP-2 2560x1440@144
bxrig display position DP-2 2880x0
bxrig display mirror on               # the laptop panel on every external monitor
bxrig display laptop off              # refused when no other monitor would be on
bxrig display brightness up           # down, or set 40
bxrig display apply                   # push what is saved again
```

The starter `hyprland.lua` that `bxrig setup hyprland` writes gives each connected screen a first scale from its resolution, so a high-density laptop panel does not start too big: it aims at the room of a 1200 pixel high screen (2880x1800 gets 1.5, 3840x2160 gets 2, 1920x1080 stays at 1) and only uses a scale that divides the resolution evenly; otherwise it leaves Hyprland's own `auto`. The file is yours after that. On a machine that already has a `hyprland.lua`, set it yourself: `bxrig display scale eDP-1 1.5 --yes` (`bxrig display list` shows the names).

On Hyprland the settings are one generated file, `~/.config/bxrig/theme/monitors.lua`, loaded after your own `hyprland.lua`, and Hyprland reloads. On Plasma they go through `kscreen-doctor`.

## Laptop power

CachyOS does not ship laptop power tools, so BxRig adds them.

```bash
bxrig power status                    # charge, state, time left, watts, health, cycles, profile, lid actions
bxrig power setup --yes               # power-profiles-daemon and upower; nothing happens on a desktop
bxrig power profile saver             # performance, balanced, saver
bxrig power lid lock --yes            # suspend, hibernate, lock or ignore when the lid closes (battery and AC)
bxrig power lid battery hibernate --yes   # only on battery
bxrig power lid ac lock --yes             # only on AC power
bxrig power hibernate --yes           # save to disk and power off (exit 4 until swap and resume are ready)
bxrig power charge-limit 80 --yes     # stop charging at 80 percent (laptops whose battery supports it)
bxrig power charge-limit off --yes    # back to a full charge
bxrig power doctor                    # daemons, the lid, zram, swap, resume and the kernel for hibernation, the charge limit
```

The lid setting is a logind drop-in and applies from the next login. Hibernation is not configured for you: `power hibernate` and `doctor` tell you what is missing (disk swap at least the size of RAM, zram does not count; `resume=` on the kernel command line, with `resume_offset=` for a swap file; a kernel without secure boot lockdown). The charge limit uses the kernel attribute `charge_control_end_threshold`, kept across reboots and suspends by a small systemd unit; many laptops (ThinkPad, ASUS, Framework and others) have it, some do not, and then the command exits 4. The charge limit and hibernation are not verified on real hardware yet.

The bar's battery widget opens a Power panel with these settings (see Quick settings and Power in the appearance guide).

## Time zone and travel

```bash
bxrig time status
bxrig time zone Europe/Madrid --yes   # set it (bxrig time zone --list shows them all)
bxrig time sync --yes                 # after you land: set the zone from your IP address
bxrig time auto on --yes              # or follow your location by itself
bxrig time ntp on --yes
```

`time auto on` installs GeoClue and `automatic-timezoned`, writes the service and the GeoClue settings it needs, and enables it. **GeoClue looks your location up online (the Wi-Fi networks around you or your IP address)**, so the plan says so before you agree. `time auto off` removes everything it wrote. If the zone does not follow you, read `journalctl -u automatic-timezoned`.

## DNS, kernels and stay awake

```bash
bxrig dns                              # the servers in use
bxrig dns cloudflare --yes             # google, quad9, custom 9.9.9.10, dhcp
bxrig dns bench                        # time each provider and see the fastest
bxrig kernel list
bxrig kernel install linux-cachyos-lts --yes
bxrig toggle stay-awake                # keep the screen from idling (Noctalia)
```

`dns` changes the active NetworkManager connections. `dns bench` asks Cloudflare, Quad9, Google, your router and your own servers (when you use some) the same five names twice with `dig` and shows the median of the second round, the one in use marked; it needs `dig` (`bind` on Arch, `bind9-dnsutils` on Debian and Ubuntu, `bind-utils` on openSUSE). `kernel` installs or removes kernel packages with their headers; it never edits the bootloader, never removes the running or the last kernel, and you pick the kernel in the boot menu. Stay awake needs Noctalia (Hyprland); on Plasma use System Settings.

## When something is stuck

```bash
bxrig system restart shell        # Noctalia (or Plasma's shell)
bxrig system restart audio        # PipeWire and WirePlumber
bxrig system restart wifi         # unblock the radio, Wi-Fi on, rescan
bxrig system restart bluetooth    # unblock the radio, adapter on
```

Each shows a plan first; add `--yes` (the menu's Update > Restart does).

## Password, firmware and speed

```bash
bxrig system password             # passwd, on this terminal
bxrig system firmware             # firmware updates your vendors offer (fwupd, from LVFS)
bxrig system firmware update --yes
bxrig system speedtest network    # speedtest-cli: ping, download, upload
bxrig system speedtest disk       # write and read 1 GiB in ~/.cache
bxrig system speedtest dns        # the same as dns bench
bxrig system speedtest last       # the last result of each
```

Only the last result of each test is kept (`~/.local/state/bxrig/speedtest-last.json`), so the panels can show it when they open. On the bar, the System panel's Network tab has the Wi-Fi (with Share Wi-Fi, a QR code a phone scans), the speed and disk tests and a DNS list to pick from; the Quick panel has Share Wi-Fi and Control Center buttons at the top. The Control Center has the same on its Network page.

Firmware updates cover BIOS/UEFI, SSDs, docks and some keyboards and mice, from vendors that publish to LVFS (Dell, Lenovo, HP, Framework, Logitech and others). Many consumer laptops are not covered.

## Hardware switches

```bash
bxrig input touchpad off          # and on, toggle, status (Hyprland); also touchscreen
bxrig gpu mode                    # a laptop with two GPUs: the current mode
bxrig gpu mode integrated --yes   # the dedicated GPU off (battery); hybrid turns it back on
bxrig wifi qr                     # a QR code a phone scans to join your network
bxrig share file report.pdf       # LocalSend: a file, a folder or the clipboard to a device nearby
bxrig default editor neovim --yes # the app for text files, and EDITOR / VISUAL
```

`gpu mode` uses supergfxctl (supergfxd); log out or reboot after a switch. `share` needs LocalSend's command line, `localsend-cli` (LocalSend 1.18 and later); `bxrig share receive` opens the LocalSend app.
