---
title: The setup wizard
order: 3
summary: One guided form for every choice. Re-run it any time.
---

# The setup wizard

The wizard asks for your choices once, shows the commands it will run, and does nothing until you confirm. Re-run it any time with `bxrig init`.

```mermaid
flowchart LR
    A["Answer the pages"] --> B["Review: the exact commands"]
    B --> C{"Confirm?"}
    C -->|"yes"| D["Install screen"]
    C -->|"no"| E["Nothing changed"]
    D --> F["Summary and saved answers"]
```

`bxrig init` opens a full-screen form with these pages: **Desktop**, **Look**, **Top bar layout**, **App grid style**, **Theme**, **Input**, **Developer**, **Toolchains**, **Containers**, **NAS**, **Backups** (with the copy somewhere else), **Apps**, **AI**, **Extras** and **Import**, then a review screen that lists exactly the commands it will run. With the Customize choice on the Apps page there is one more page per catalog group. Nothing runs until you confirm.

<video src="../assets/clips/wizard.webm" poster="../assets/screenshots/wizard-welcome.webp" autoplay loop muted playsinline width="100%"></video>

| | |
| --- | --- |
| ![The welcome screen](../assets/screenshots/wizard-welcome.webp)<br>**Welcome** | ![The Look page: dark or light, dock and bar position](../assets/screenshots/wizard-look.webp)<br>**Look:** dark or light, dock, bar position |
| ![The Look page: the world clock and its time zones](../assets/screenshots/wizard-world-clock.webp)<br>**Look:** the world clock and its time zones | ![The Input page: keyboard layouts, scrolling, the Mac-style keys](../assets/screenshots/wizard-input.webp)<br>**Input:** layouts, scrolling, shortcut style |

## The look pages

After **Look** (dark, light or auto, the dock, where the bar sits, the world clock) come three pages that show what you are choosing:

- **Top bar layout** (Hyprland and Both): Minimal, Standard (the default and the recommendation) or Dense. Each option draws its bar as a strip of text chips with the dock line below the list. Standard has the capture icon, Minimal does not, Dense adds brightness and weather. The arrow keys select as they move, so the strips and the description follow your cursor and Enter keeps what is highlighted. Later: `bxrig appearance bar layout minimal|standard|dense` or the Look page of the Control Center.
- **App grid style** (Hyprland and Both): Launchpad (the default, big colored tiles on a rounded card) or Terminal-style (flat glyphs, key hints, square corners). Both grids are drawn side by side and the arrow keys switch. Later: `bxrig appearance appgrid launchpad|terminal`.
- **Theme** (every desktop): every theme in `themes/` on a row with a swatch, `BxRig` the default. A pane next to the list shows the palette of the highlighted theme, read from its `colors.toml`, and a sample terminal in those colors. The wizard itself is drawn in the highlighted theme, so what you see is what the desktop will get. The icon set is not asked: BxRig's own icons are used. Later: `bxrig theme set NAME` or the Themes page of the Control Center.

On a terminal narrower than 92 columns (no step list) the Theme page keeps the list and the pane side by side; between 92 and 96 columns the pane is dropped and the rows keep their swatches.

The **Input** page asks about keyboard layouts, natural scrolling, and the shortcut style: "Mac-style Super keys" (on by default) and, when it is on, "Which keyboard do you type on?" (PC: Alt and Win are swapped so Alt acts as Cmd; Apple: no swap). When an Apple Magic or Logitech device is paired or plugged in (or the Mac-style keys are on) it also asks "Input devices" (default: detect); the answer becomes the optional step `bxrig input offer`, see [Mice, trackpads and keyboards](../desktop/input.md). Off keeps the Traditional keys (classic Super-key tiling keys). The answers become `bxrig keys style` and the xremap setup, which is installed either way because copy, paste, cut and select all are remaps in both styles. See [Shortcuts](../desktop/shortcuts.md).

## The install screen

When you press Enter on the review, the wizard stays on screen and installs. It does not drop back to a scrolling terminal.

- **Progress.** A bar in your theme's colours, `7 of 16 steps`, the step that runs now with a spinner and how long it has run, and the last line it printed. The apps step also shows its own count (`12 of 43`) while the package manager installs.
- **It says when it is quiet.** A download or a package build can print nothing for minutes. After 8 seconds without output the line says `no output for 42 s` and what the step is running right now (for example `pacman -S ...`, `makepkg`, `curl`), so a long step does not look stuck. Package installs, AUR builds and install scripts print as they go, so you see them in the log (`v`) while they run; a step that waits for a password shows as `sudo`.
- **`v` opens the log** under the bar: every line every step prints, live, with the step it came from. Arrows, PgUp and PgDn scroll it; `End` follows the newest line again; `v` closes it.
- **Ctrl+C asks first.** `y` stops: the running step is killed and the rest is not run.
- **When it ends** the screen shows what worked and what failed, with the exit code and the last line of each failure, and where the log and your answers are saved. `r` runs the failed steps again; Enter leaves. When the steps changed your session, groups or keys, `l` offers to log out (after a `y`); when they changed the boot screen, the login screen or a driver, `b` offers to reboot instead. Nothing happens without the `y`.
- **Your password once, on the screen.** The steps run in the background and the screen owns the terminal, so a sudo prompt could neither be seen nor answered. When sudo would ask for a password, the screen asks for it first (typed hidden, three tries, Esc cancels before anything runs). The steps then run with no terminal and a small helper that gives `sudo` the password. It lives in one file only you can read (mode 600, in a private folder under `$XDG_RUNTIME_DIR`, which is memory, not disk), is never on a command line or in the log, and is deleted when the install ends. If you have no `$XDG_RUNTIME_DIR` or no `setsid`, BxRig asks on the normal terminal before the screen starts instead, and relies on sudo's ticket. With a valid sudo ticket or `NOPASSWD`, nothing is asked.

A step that fails does not stop the others (a missing package should not cost you your keys and defaults): the plan goes on and the failure is shown at the end. Re-running the wizard repeats only what is still missing.

Some things are **skipped, not failed**, and the end says why and how to do them later: the LazyVim starter when `~/.config/nvim` already exists (your config is left alone), Podman's Docker compatibility when the `docker` package is installed (it conflicts with `podman-docker`: remove Docker first, or choose Docker as the engine), an app that conflicts with a package you have (timeshift next to CachyOS's `cachyos-snapper-support`), and an app your distribution's catalog does not offer. `bxrig init --dry-run` prints the first two as notes before anything runs.

### What it says when it ends

After you leave the screen the terminal keeps a summary:

```
Done: 29 steps

Already in place (nothing to do):
  editor-lazyvim  /home/you/.config/nvim already exists, so it was left alone. ...
                  later: bxrig editor lazyvim --yes
Needs your decision:
  docker-compat   the docker package is installed and conflicts with podman-docker. ...
                  later: bxrig containers docker-compat --yes
Skipped:
  session         SDDM's state folder /var/lib/sddm/ does not exist, so SDDM is not your login manager here. ...

Saved:
  Your answers  ~/.config/bxrig/answers.json   (run them again: bxrig reinstall)
  The log       ~/.local/state/bxrig/logs/init-20261127-160037.log

Next:
  1. Log out and back in, and pick Hyprland at the login screen: ... Log out now with: bxrig system logout --yes
  2. Open a new terminal to get the new shell and prompt.
  3. See what is set up on this machine: bxrig status        Change anything later: bxrig menu
```

Something that is already there (Boxy, a Neovim config of yours) is **in place**, not an error. A conflict (the `docker` package against Podman's Docker compatibility) **needs your decision**. Anything else that could not run here is **skipped**, each with the command to do it later. Your answers are saved in `~/.config/bxrig/answers.json`; run them again with `bxrig reinstall`, or change them and import the file with `bxrig init --from=FILE`.

### The log file

Every install writes a log you can read later or send for debugging: `~/.local/state/bxrig/logs/init-YYYYMMDD-HHMMSS.log`. It has the BxRig version and the system, the plan, each step's command, every line it printed, its exit code and how long it took, and every exception with its message and stack. Next to it, a folder of the same name holds each step's raw output. The last 20 runs are kept. The path is printed when the install ends and shown on the screen.

`bxrig init --plain` keeps the old streaming output instead of the screen, and `bxrig init --answers=FILE --yes --screen` runs a saved answers file on the screen. Both write the same log.

## How do you want to start?

After the welcome screen the wizard asks how to begin:

| Choice | What happens |
|---|---|
| **New install** | The whole wizard, page by page, from the defaults (what this machine already has is still marked `✓ installed`). |
| **Import answers from a file** | You type the path of an answers file (`bxrig init --export=FILE` makes one; `~/` works). The answers go on top of the defaults and you land on the **review**, ready to go. Esc on the review goes back to the pages if you want to change something. A file that is not there, or is not an answers file, is an error on the screen; keys this version does not ask are ignored and counted ("Imported 24 answers from ... (2 not used by this version)"). |
| **Use my saved answers** | Shown only when you have run the wizard before: your last answers plus what the machine has, straight to the review. |

`bxrig init --fresh`, `--rerun` and `--from=FILE` already say how to begin, so they skip this question.

## Run it again

On a machine that is already set up the wizard starts from your saved answers plus what it finds on the system, and marks installed options with `✓ installed`.

| Command | Starts from |
|---|---|
| `bxrig init` | your saved answers and what the system has (tune) |
| `bxrig init --rerun` | your saved answers only |
| `bxrig init --fresh` | the defaults |
| `bxrig init --from=FILE` | an answers file from another machine |

Nothing the machine already has is ever removed. `bxrig status` shows the same scan without opening the wizard.

## Without a terminal

```bash
bxrig init --answers=answers.json --yes     # apply an answers file
bxrig init --defaults --yes                  # the wizard's default answers
bxrig init --dry-run                         # show the plan only
bxrig init --export=answers.json             # save your answers for another machine
```

Answers are saved in `~/.config/bxrig/answers.json` (mode 600). They never contain secrets.

## Defaults worth knowing

| Question | Default |
|---|---|
| Desktop | Hyprland + Noctalia |
| Shortcut style | Mac-style Super keys on a PC keyboard (Alt and Win swapped) |
| Top bar layout | Standard |
| App grid style | Launchpad |
| Color theme | BxRig |
| Default browser | Brave |
| Launcher, menu program | Vicinae, Vicinae |
| Workspaces | 4 |
| Shell | zsh with the Starship prompt (Catppuccin Powerline) |
| Terminal | Ghostty |
| File manager | Strata |
| Toolchains | Java and Rust |
| Containers | Podman (with `docker` commands mapped to it) |
| Dictation | Superwhisper (Voxtype is the alternative) |
| Updates | stable channel, daily notification |

## What is always installed

BoxLang, Java 21 (switched with jenv) and Rust (rustup, stable) are part of the stack, so the Toolchains page does not ask about them. It asks for extra Java versions (21 stays global), the IDEs and editors you want (VS Code, IntelliJ IDEA Community, Zed, Cursor, Sublime Text) and the other toolchains. The BoxLang extension question only appears when VS Code is ticked.

## When things are installed

The review lists the steps in order. Apps, including the IDEs and any local model apps you ticked, come first. The local AI setup (llama.cpp and the model downloads) is one step near the end, and only runs when you answered "now"; otherwise nothing is downloaded.

## When it finishes

The last screen is a summary: what failed (press `r` to retry), what to do next (log out, reboot, open a new terminal), what needs your decision, what was skipped and the command to do it later, and where your answers and log are saved. Press `d` to see every step.
