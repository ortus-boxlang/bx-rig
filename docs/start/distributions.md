---
title: Distributions
order: 1
summary: CachyOS and Arch, openSUSE Tumbleweed and Slowroll, Ubuntu 26.04 and Debian 13: what differs and what is Arch-only.
---

# Distributions

BxRig runs on:

| Distribution | Package manager | Notes |
| --- | --- | --- |
| CachyOS, Arch Linux | pacman, AUR (yay) | The reference platform: every app and feature. |
| openSUSE Tumbleweed, Slowroll | zypper | Flatpak for apps zypper lacks. |
| Ubuntu 26.04 LTS | apt | Noctalia from its own apt repository. Flatpak for apps apt lacks. |
| Debian 13 (trixie) | apt | Hyprland from trixie-backports, Noctalia from its own apt repository. kitty is the default terminal (Debian has no ghostty). |

BxRig works out which one you are on from `/etc/os-release`. Other systems are not supported.

## The catalog per distribution

The app catalog has two parts:

- `catalog/apps.json` says what each app is: its name, category, tier and profiles. It is the same everywhere.
- `catalog/install/DISTRO.json` says how to install it on that distribution: the packages, Flathub, or a script. `ubuntu.json` extends `debian.json` and lists only what differs.

An app that a distribution's file does not list is not offered there. `bxrig catalog show ID` says so.

```bash
bxrig catalog coverage                 # how many apps each distribution offers
bxrig catalog list --distro debian     # the catalog as another distribution sees it
bxrig catalog check                    # validates every install file
```

When the distribution has no package for an app, BxRig installs it from Flathub, for your user only (`flatpak install --user`). It adds the Flathub remote, and installs flatpak first, when they are missing.

## Extra repositories

Some packages come from outside the main archive. BxRig adds these repositories only when the install needs them, and only once:

- **Debian 13:** `trixie-backports`, for Hyprland and its tools (hyprland, hypridle, hyprlock, uwsm, the portal, quickshell). They install with `apt-get install -t trixie-backports`, so the newer libraries they need come from backports too. A system that already lists backports is left as it is.
- **Debian 13 and Ubuntu 26.04:** Noctalia's apt repository at pkg.noctalia.dev, for the `noctalia` shell.

## Plasma tiling (HyprKwin)

`bxrig setup plasma` installs HyprKwin, which needs Plasma 6.6 or newer on Wayland. Debian 13 ships Plasma 6.3, so `setup plasma` stops there with that reason; use `bxrig setup hyprland` instead. Check your version with `bxrig setup status`.

## What is Arch-only

- **The AUR.** `bxrig pkg search --aur` and AUR installs work only on Arch.
- **`bxrig kernel`.** Kernel switching uses Arch's kernel packages.
- **The boot splash.** It is built with mkinitcpio.
- **xremap.** On other distributions, install it yourself (its release binary or `cargo install`). BxRig then configures it the same way.
- **Nerd Fonts packages.** openSUSE, Debian and Ubuntu do not package them. `bxrig appearance font install` says so and points to nerdfonts.com.

## Contributing an install file

`bxrig catalog map DISTRO` proposes the install file for a distribution. Run it on that distribution (a container is enough). It asks the package manager for each app's Arch package names, then Flathub, and reports each app as found, flatpak or missing. With `--write` it updates `catalog/install/DISTRO.json`. Review the result before you commit it.

```bash
docker run --rm -it -v "$PWD":/src -w /src debian:trixie bash
bxrig catalog map debian --write
```

Arch names spelled differently on a distribution go in the file's `names` map (for example `fd` is `fd-find` on Debian). An empty value means the distribution needs nothing for that package. In a file that `extends` another, `{ "source": "none" }` drops an app the parent offers and this release lacks.
