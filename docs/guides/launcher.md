---
title: Launcher
order: 2
summary: Vicinae as your launcher, in your theme's colours, with BxRig's actions and file search.
---

# Launcher

[Vicinae](https://github.com/vicinaehq/vicinae) is the launcher and the menu BxRig recommends, and the wizard's default (Noctalia's own launcher, Walker, Rofi, Fuzzel and Wofi are still choices). It is a launcher: a fast, keyboard-first search for apps, files, your clipboard and BxRig's own actions, drawn in your BxRig theme.

```bash
bxrig pkg install vicinae
bxrig launcher setup --yes
bxrig launcher                  # what is set up
```

<video src="../assets/clips/launcher-cli.webm" poster="../assets/screenshots/launcher-status.webp" autoplay loop muted playsinline width="100%"></video>

`bxrig launcher setup` shows its plan first. With `--yes` it:

- makes Vicinae BxRig's launcher and menu (the same as `bxrig runner set vicinae` and `bxrig runner menu-set vicinae`), so `bxrig menu` opens in Vicinae;
- writes the **BxRig theme** for Vicinae and selects it;
- adds BxRig's actions to Vicinae's search as **script commands**;
- starts the Vicinae server when it is not running.

Vicinae's own `settings.json` is never edited.

## The theme

Every `bxrig theme set` rewrites `~/.local/share/vicinae/themes/bxrig.toml` from the theme's colours: the background, the text, the accent for selection and focus, and the theme's red, green, yellow, blue, magenta and cyan. Vicinae watches that folder, so the change shows at once. When Vicinae is your launcher, BxRig also selects the theme.

![The Vicinae theme BxRig writes](../assets/screenshots/launcher-theme.webp)

## BxRig in Vicinae's search

| Command | What it does |
|---|---|
| BxRig Control Center | Every BxRig command as one menu |
| Agenda | Your calendars for the next 7 days |
| Next event | Your next event today, shown under the command's name |
| Remind me | A reminder: what, then `30m`, `2h` or `09:25` |
| Reminders | The reminders still to come |
| World clock | The time in your world clock zones |
| Next theme | Switch to the next BxRig theme |
| Check for updates | Whether a BxRig update is waiting |
| Scheduled tasks | The scheduler's tasks and how they ran |
| BoxLang servers | Your BoxLang apps and their ports |
| Lock screen | Lock the screen |

They live in `~/.local/share/vicinae/scripts/bxrig`. Vicinae reads its script folders when it starts, every 15 minutes, and when you run **Reload Script Directories**. `bxrig launcher scripts --yes` writes them again, and `bxrig launcher scripts remove --yes` deletes them. Script commands of your own in other folders are not touched.

## File search

Vicinae indexes your home folder in the background and keeps the index up to date.

```bash
bxrig launcher files            # Vicinae's file search
bxrig launcher files invoice    # with "invoice" already typed
```
