---
title: Launcher
order: 5
summary: The BxRig launcher on Super+Space (apps, actions, themes, calculator, clipboard), and Vicinae as an alternative.
---

# Launcher

On other desktops, or if you prefer it, search apps, files, your clipboard and BxRig's own actions from one keyboard-first box. [Vicinae](https://github.com/vicinaehq/vicinae) is the launcher and menu BxRig recommends and the wizard's default (Noctalia's own launcher, Walker, Rofi, Fuzzel and Wofi are still choices), drawn in your BxRig theme.

## The BxRig launcher (Noctalia panel)

On the Noctalia desktop, `Super+Space` opens the BxRig launcher: one flat search box, drawn in your theme. Type and it ranks, best first:

- a **calculator answer** (`2*(3+4)` gives `14`; Enter copies it);
- **menu actions** with their path, such as `Trigger › Capture`, so every action of `bxrig menu` is one search away;
- **applications** with their icons, and **themes** (Enter applies the theme);
- a **Clipboard history** row, which opens the clipboard panel: the history on the left, the full text of the highlighted entry on the right, Enter copies it back (`Super+Ctrl+V` opens it directly);
- **web searches** (DuckDuckGo, Google, GitHub, BoxLang docs) at the end.

Things you run often rise to the top (kept in `~/.local/state/bxrig/launcher.json`). Tab opens the Actions list for the highlighted row. The drill-down menu stays on `Super+Alt+Space`, for browsing by section.

The panels are the `bxrig/launcher` plugin. They call the same commands you can run yourself:

```bash
bxrig launcher search capture --json     # the ranked rows
bxrig launcher run theme:nord            # what Enter does for a row
bxrig launcher run web:ddg bash docs     # answer and web rows take the words typed
bxrig clipboard list token --json        # the clipboard history, filtered
bxrig clipboard copy 42                  # put one entry back
```

The clipboard needs `cliphist` and `wl-clipboard` (`bxrig install cliphist wl-clipboard`). The ranking idea follows [oma-cast](https://github.com/typecraft-dev/oma-cast) (MIT).

## Vicinae

### Try it

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

## It follows your theme

Every `bxrig theme set` rewrites `~/.local/share/vicinae/themes/bxrig.toml` from the theme's colours: the background, the text, the accent for selection and focus, and the theme's red, green, yellow, blue, magenta and cyan. Vicinae watches that folder, so the change shows at once. When Vicinae is your launcher, BxRig also selects the theme.

![The Vicinae theme BxRig writes](../assets/screenshots/launcher-theme.webp)

## Run BxRig from the search

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

## Search your files

Vicinae indexes your home folder in the background and keeps the index up to date.

```bash
bxrig launcher files            # Vicinae's file search
bxrig launcher files invoice    # with "invoice" already typed
```

Next: [The menu](menu.md), [Themes](../customize/themes.md).
