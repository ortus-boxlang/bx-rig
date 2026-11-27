---
title: Mice, trackpads and keyboards
order: 5
summary: Apple Magic Mouse and Trackpad and Logitech devices on Linux, with the helpers BxRig can install for them.
---

# Mice, trackpads and keyboards

BxRig finds Apple Magic and Logitech devices and offers the helpers around them. Magic Mouse and Magic Trackpad work through the Linux kernel; Logitech's Logi Options+ has a Linux equivalent in Solaar. Detection needs no root and no extra tool: it reads the kernel's `/sys/bus/hid/devices` (vendor `05AC` is Apple, `046D` is Logitech; bus `0005` is Bluetooth, `0003` USB), `bluetoothctl devices` for paired devices that are not connected now, and `upower` for a battery the kernel did not report.

```bash
bxrig input status          # devices, drivers, helpers, what is missing
bxrig input offer           # the plan: what to install for the devices found
bxrig input offer --yes     # install it
bxrig input undo --yes      # remove only what offer installed
```

## What is found

`input status` lists each device with its kind (`apple-mouse`, `apple-trackpad`, `apple-keyboard`, `logitech-mouse`, `logitech-keyboard`, `logitech-receiver`, `other`), how it is connected, and its battery. An Apple device counts when its name has "Magic" in it; no product ids are hard-coded. The kind is read from the name, so an unusual name can land in `other`. It also shows whether the drivers are **loaded** or **built in** (a built-in driver never shows in `lsmod`, which is why the old doctor could say "not loaded" for a working mouse).

## The offer

`input offer` is a plan until you add `--yes` (`--dry-run` shows it and changes nothing).

| Found | Installs | Why |
|---|---|---|
| a Logitech device | `solaar` | Buttons, DPI, scroll and battery: what Logi Options+ does on a Mac. Its package installs a udev rule, so no root daemon is needed. |
| a Logitech gaming mouse | `libratbag` and `piper` | Report rate, DPI and profiles of gaming mice. "Gaming mouse" is a **guess from the name** (G-series, G Pro, Superlight, Lightspeed, "Gaming"); the plan says so. |
| a Magic Trackpad on Hyprland | `libinput-gestures` (AUR) | Three-finger swipes. A Magic Mouse has no touchpad gestures here. On Plasma use System Settings, Touchpad. |
| any of them | `upower` | Battery levels. |

Choose by hand with `--for=apple`, `--for=logitech` or `--for=both` (`--for=detect` is the default). Use one tool per Logitech device: Solaar, libratbag and Piper can all talk to the same mouse and are not meant to run together. logiops is not offered.

`input undo` removes the packages `offer` installed and nothing else; your own settings in `~/.config` stay.

## Apple Magic

`bxrig input apple` checks the driver (`hid_magicmouse`), the Bluetooth service, the battery and the driver's module options: `scroll_speed`, `scroll_acceleration`, `emulate_scroll_wheel` and `emulate_3button`. It exits 4 when the kernel has no `hid_magicmouse`.

Scroll speed is a kernel module option, from 0 to 63 (default 32):

```bash
bxrig input apple --scroll-speed=48          # the plan
bxrig input apple --scroll-speed=48 --yes    # writes /etc/modprobe.d/bxrig-magicmouse.conf with sudo
```

It applies the next time the module loads: reconnect the mouse or reboot. If the driver is **built into** your kernel, modprobe options are not read; the command says so and you add `hid_magicmouse.scroll_speed=48` to the kernel command line instead. `bxrig input undo` removes the file.

**Gestures** stay with `libinput-gestures` (`bxrig input gestures --yes`, Hyprland): BxRig does not write Hyprland's own gesture configuration, because its syntax changed between versions and is not verified here. To pair a device use `bluetoothctl` (or the Bluetooth panel): `scan on`, `pair`, `trust`, `connect`.

## Logitech

`bxrig input logitech` shows the receivers (Unifying, Bolt, Lightspeed) and devices with their battery, the `hid_logitech_dj` and `hid_logitech_hidpp` drivers, whether Solaar's udev rule (`42-logitech-unify-permissions.rules`) is installed, and, when Solaar is installed, what `solaar show` lists. Firmware updates are not part of Solaar: use `fwupdmgr`.

## In the wizard

The **Input** page asks "Input devices" (Detect and offer helpers, None, Apple, Logitech, Apple and Logitech). It appears when a device is detected or the Mac-style keys are on; the default is Detect. The choice becomes one optional step, `bxrig input offer --for=CHOICE --yes`, that does nothing when nothing is found.

## Not verified on real hardware

Magic Trackpad 2, Magic Mouse 2 and an MX Master have not been tested here; the commands are tested against a fake sysfs and fake tools. Whether `upower` reports these batteries is unconfirmed (the kernel's own battery is read first), and whether `hid_magicmouse` is built in on CachyOS kernels is not known.
