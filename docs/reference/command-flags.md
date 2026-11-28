---
title: Command flags
order: 2
summary: The flags each command accepts, for review.
---

# Command flags

Generated from `docs/reference/cli.json`. These flags work on every command: `--json`, `--yes`, `--dry-run`, `--force`, `--quiet`. Any other flag must be listed for the command; an unknown flag is a usage error (exit 2) and nothing runs.

Type `value` is written `--flag=VALUE`, `bool` is written bare, and `any` was found in the command code but is not in its usage line yet: add it to the usage, or remove it if the code no longer reads it.

| Command | Flag | Type | Default | What it does |
|---|---|---|---|---|
| `init` | `--answers` | value | `answers.json` | Run the install from this answers file, no wizard |
| `init` | `--defaults` | any |  | Run the install with the wizard's default answers |
| `init` | `--export` | value |  | Write a copy of your saved answers to this file |
| `init` | `--fresh` | bool |  | Start the wizard from the defaults, not your saved answers |
| `init` | `--from` | value |  | Start the wizard from answers exported on another machine |
| `init` | `--from-system` | bool |  | With --print-answers, read answers from what this machine has |
| `init` | `--plain` | bool |  | After the wizard, print the steps as they run, no progress screen |
| `init` | `--print-answers` | bool |  | Print your saved answers and exit |
| `init` | `--rerun` | bool |  | Start the wizard from your saved answers only |
| `init` | `--screen` | bool |  | With --answers --yes, show the install on the progress screen |
| `refresh` | `--starter` | bool |  | Also rewrite the starter config file (hyprland, noctalia) |
| `reinstall` | `--answers` | any |  | Run the install from this answers file, no wizard |
| `reinstall` | `--defaults` | any |  | Run the install with the wizard's default answers |
| `reinstall` | `--export` | any |  | Write a copy of your saved answers to this file |
| `reinstall` | `--fresh` | any |  | Start the wizard from the defaults, not your saved answers |
| `reinstall` | `--from` | any |  | Start the wizard from answers exported on another machine |
| `reinstall` | `--from-system` | any |  | With --print-answers, read answers from what this machine has |
| `reinstall` | `--print-answers` | any |  | Print your saved answers and exit |
| `reinstall` | `--rerun` | any |  | Always on for reinstall (starts from your saved answers) |
| `wizard` | `--answers` | value |  | Start the pages from the answers in this JSON file |
| `wizard` | `--demo` | bool |  | Show the built-in demo pages |
| `wizard` | `--out` | value |  | Write the final answers to this JSON file |
| `wizard` | `--pages` | value |  | Show the pages defined in this JSON file |
| `doctor` | `--dev` | bool |  | Also check the developer setup (git, SSH, signing, containers) |
| `update` | `--notify` | bool |  | Show a desktop notice when an update is available |
| `scheduler` | `--group` | value | `sync` | Only list tasks in this group, or the group of a new task |
| `scheduler` | `--when` | value |  | When the task runs, like daily 02:30 or every 2 hours |
| `scheduler` | `--notify` | value |  | When to notify: failure, attention, always or never |
| `scheduler` | `--timeout` | value |  | Seconds a run may take before it is stopped (default 3600) |
| `scheduler` | `--limit` | value |  | How many past runs to show |
| `ascii` | `--font` | value | `dos` | Font to draw the text in (see ascii fonts) |
| `ascii` | `--color` | value |  | One colour for the text: #rrggbb, #rgb or a name |
| `ascii` | `--gradient` | value | `sunset` | Colour gradient to paint the text with |
| `ascii` | `--direction` | value | `diagonal` | Which way the gradient runs across the text |
| `ascii` | `--plain` | bool |  | Leave the colour out |
| `ascii` | `--width` | value | `60` | Width of the picture in columns, 4 to 300 (default 48) |
| `ascii` | `--style` | value | `ascii` | Art style: blocks or ascii |
| `about` | `--wait` | bool |  | Wait for Enter before returning |
| `about` | `--plain` | bool |  | Leave the colour out |
| `banner` | `--plain` | bool |  | Leave the colour out |
| `help` | `--help` | bool |  | Show the help for the command |
| `help` | `--h` | bool |  | Same as --help |
| `install` | `--optional` | bool |  | Also include the optional apps of the selection |
| `install` | `--profile` | any |  | Install the apps of this profile instead of the default set |
| `install` | `--shell` | value |  | Pick apps for this shell: hyprland, plasma or all |
| `pkg` | `--aur` | bool |  | Install from the AUR, not the repositories |
| `pkg` | `--explicit` | bool |  | List only packages you asked for, not dependencies |
| `pkg` | `--limit` | value |  | Show at most this many search results (default 40) |
| `pkg` | `--source` | value |  | Search the repos, the AUR or both: all, repo, aur |
| `catalog` | `--distro` | value | `suse` | Show the catalog as seen on this distro (arch, suse, debian, ubuntu) |
| `catalog` | `--write` | bool |  | Write the generated distro map to the catalog files |
| `catalog` | `--category` | value |  | Only list apps in this category |
| `catalog` | `--group` | value | `ai` | Only list apps in this group |
| `catalog` | `--kind` | value |  | Only list apps of this kind |
| `catalog` | `--source` | value |  | Only list apps from this install source |
| `catalog` | `--tier` | value | `default` | Only list apps in this tier: default or optional |
| `plan` | `--optional` | bool |  | Also include the optional apps of the selection |
| `plan` | `--profile` | any |  | Plan the apps of this profile instead of the default set |
| `plan` | `--shell` | value |  | Pick apps for this shell: hyprland, plasma or all |
| `install-plan` | `--optional` | bool |  | Also include the optional apps of the selection |
| `install-plan` | `--profile` | any |  | Plan the apps of this profile instead of the default set |
| `install-plan` | `--shell` | value |  | Pick apps for this shell: hyprland, plasma or all |
| `optional-plan` | `--shell` | value |  | Shell name is checked, but named apps are chosen anyway |
| `profile-plan` | `--optional` | bool |  | Also include the optional apps of the selection |
| `profile-plan` | `--shell` | value |  | Pick apps for this shell: hyprland, plasma or all |
| `profile-install-plan` | `--optional` | bool |  | Also include the optional apps of the selection |
| `profile-install-plan` | `--shell` | value |  | Pick apps for this shell: hyprland, plasma or all |
| `profile-install` | `--optional` | bool |  | Also include the optional apps of the selection |
| `profile-install` | `--shell` | value |  | Pick apps for this shell: hyprland, plasma or all |
| `optional-install` | `--shell` | value |  | Shell name is checked, but named apps are chosen anyway |
| `web` | `--browser` | value |  | Browser that opens the web app: brave, chromium, edge, firefox... |
| `setup` | `--also` | value | `a` | Extra terminals to install besides the default, comma separated |
| `setup` | `--build` | value |  | Which xremap build to install: hypr or kde (default: by session) |
| `setup` | `--default` | value | `ghostty` | Terminal to make the default (ghostty if not given) |
| `setup` | `--keys` | bool |  | Hand Plasma's clashing keys to HyprKwin (backed up first) |
| `setup` | `--layout` | value |  | Starting Hyprland window layout, such as dwindle or master |
| `setup` | `--layouts` | value | `us-intl` | Keyboard layouts to set, comma separated, such as us-intl,es |
| `setup` | `--natural-scroll` | bool |  | Use natural (reversed) touchpad scrolling in the Hyprland config |
| `setup` | `--shell` | value |  | Shell to set up with Starship: zsh, fish or bash |
| `setup` | `--terminal` | value |  | Terminal bound to Super+Enter in the new Hyprland config |
| `setup` | `--theme` | value |  | Color mode of the starter config: dark, light or auto |
| `setup` | `--undo-keys` | bool |  | Give the keys back to Plasma's old owners |
| `setup` | `--wallpaper` | value |  | Starting wallpaper, named after a bundled theme |
| `setup` | `--workspaces` | value |  | Number of workspaces always shown in the bar (1 to 10) |
| `plasma` | `--agenda` | bool |  | Use the Event Calendar widget instead of the digital clock |
| `plasma` | `--desktops` | value |  | Number of virtual desktops (default 4) |
| `plasma` | `--preset` | value | `islands` | Panel Colorizer preset for the panel look (default Rounded Widgets) |
| `plasma` | `--without-weather` | bool |  | Leave the weather widget out of the top panel |
| `keys` | `--keyboard` | value | `pc` | Keyboard you type on: pc or apple |
| `keys` | `--swap` | value |  | Swap Alt and Win keys in the Mac style: on or off |
| `runner` | `--prompt` | value |  | Prompt text shown in the menu for select |
| `launcher` | `--yes` | bool |  | Apply the change instead of only showing the plan |
| `launcher` | `--dry-run` | bool |  | Show what would change without changing anything |
| `launcher` | `--limit` | value |  | The most rows search returns (default 20) |
| `theme` | `--keep-wallpaper` | bool |  | Apply the theme but leave the current wallpaper as it is |
| `theme` | `--mode` | value | `dark` | Light or dark choice for this set: theme, dark, light or auto |
| `theme` | `--name` | value | `mine` | Name to save an installed or imported theme under |
| `screensaver` | `--effect` | value |  | Run this one effect instead of letting the effects take turns |
| `screensaver` | `--idle` | bool |  | Mark the start as coming from the idle watcher |
| `time` | `--list` | bool |  | With zone, print every available time zone |
| `calendar` | `--client-id` | value | `123.apps.googleusercontent.com` | Google OAuth client ID, needed to add a Google calendar |
| `calendar` | `--client-secret-file` | value |  | File holding the Google OAuth client secret |
| `calendar` | `--days` | value | `3` | How many days ahead the agenda shows (1 to 60, default 7) |
| `calendar` | `--yes` | bool |  | Confirm removing the calendar and its local copy |
| `calendar` | `--dry-run` | bool |  | Show what remove would do without changing anything |
| `remind` | `--at` | value | `09` | HH:MM, "tomorrow HH:MM" or "YYYY-MM-DD HH:MM" |
| `remind` | `--in` | value | `3` | Remind after a delay such as 30m, 2h or 1d |
| `remind` | `--done` | bool |  | On clear: only the finished reminders |
| `nightshift` | `--location` | value | `40.4` | Latitude and longitude as LAT,LON, instead of the time zone guess |
| `notify` | `--history` | bool |  | Also empty the notification history, not just visible ones |
| `system` | `--repo` | bool |  | Update only the repository packages, not the AUR |
| `system` | `--aur` | bool |  | Update only the AUR packages (needs yay or paru) |
| `system` | `--all` | bool |  | Update repository and AUR packages (the default) |
| `ssh` | `--email` | value | `me` | Email address used as the comment of the new key |
| `git` | `--key` | value |  | Path of the SSH key used to sign commits |
| `secrets` | `--from-file` | value |  | Read the secret value from this file instead of asking |
| `secrets` | `--keyring` | value |  | Keyring to set up: kwallet, gnome-keyring or none |
| `secrets` | `--overwrite` | bool |  | Replace secrets that already exist with a different value |
| `secrets` | `--plain` | bool |  | Export a readable .env file instead of an encrypted one |
| `secrets` | `--provider` | value |  | AI provider this secret belongs to |
| `secrets` | `--show` | bool |  | Print the secret value instead of hiding it |
| `secrets` | `--strict` | bool |  | Stop with an error if a named secret is not set |
| `secrets` | `--type` | value |  | Kind of secret: ai or other (lists only that kind with list) |
| `vpn` | `--location` | value |  | Place to connect to (see vpn locations) |
| `cloud` | `--path` | value |  | Folder to mount the remote at |
| `dotfiles` | `--method` | value |  | Force the method: chezmoi, yadm, stow or links |
| `dotfiles` | `--overwrite` | bool |  | Approve replacing files you already have |
| `nas` | `--ask-password` | bool |  | Type the password at a hidden prompt |
| `nas` | `--delete` | bool |  | Remove files on the NAS that are not in the source |
| `nas` | `--host` | value | `ds920.local` | Host name or address of the NAS |
| `nas` | `--password-file` | value |  | Read the NAS password from this file |
| `nas` | `--path` | value | `bxrig-backup` | Folder on the share used for backups (default bxrig-backup) |
| `nas` | `--protocol` | value |  | Share protocol: smb (default) or nfs |
| `nas` | `--to` | value |  | Target share, or SHARE/PATH, to copy to |
| `nas` | `--user` | value | `me` | User name to log in to the NAS |
| `nas` | `--vers` | value | `3.1.1` | SMB protocol version, for example 3.1.1 |
| `backup` | `--all` | any |  | With data run: back up to every initialized target |
| `backup` | `--ask-keys` | bool |  | Type the target's access keys at a hidden prompt |
| `backup` | `--bucket` | value | `mybackups` | Bucket name for an s3, b2 or gs target |
| `backup` | `--container` | value |  | Container name for an azure target |
| `backup` | `--credentials` | value |  | Service account JSON key file for a gs target |
| `backup` | `--daily` | value |  | Number of daily backups to keep |
| `backup` | `--deep` | bool |  | Also read a sample (5%) of the stored data to check it |
| `backup` | `--description` | value |  | Text to describe the new snapshot |
| `backup` | `--endpoint` | value | `https` | Custom server address for an s3 target |
| `backup` | `--from` | value | `usb` | Target to copy the backup from (default target if omitted) |
| `backup` | `--home` | bool |  | Also snapshot /home |
| `backup` | `--host` | value |  | Server name for an sftp target |
| `backup` | `--include` | value |  | Restore only this path, as it was backed up |
| `backup` | `--keep` | value |  | Number of newest config snapshots to keep |
| `backup` | `--keys-file` | value |  | File with KEY=VALUE lines holding the target's access keys |
| `backup` | `--local` | bool |  | Skip targets that are read over the network |
| `backup` | `--monthly` | value |  | Number of monthly backups to keep |
| `backup` | `--only` | value | `.config` | Restore only this path under your home |
| `backup` | `--packages` | bool |  | Also install packages from the snapshot that are missing |
| `backup` | `--path` | value |  | Folder of a local or sftp target; with export, path inside the backup |
| `backup` | `--project` | value |  | Google Cloud project ID for a gs target |
| `backup` | `--reason` | value |  | Label stored with the config snapshot |
| `backup` | `--region` | value |  | Region for an s3 target |
| `backup` | `--remote` | value |  | Name of the rclone remote for an rclone target |
| `backup` | `--scheduled` | any |  | Marks a scheduled run: a failure sends a desktop notification |
| `backup` | `--target` | value |  | Backup target to use (default target if omitted) |
| `backup` | `--to` | value | `do` | Where to put it: folder, target name or export file |
| `backup` | `--type` | value | `s3` | Kind of target: local, sftp, rest, s3, b2, azure, gs or rclone |
| `backup` | `--url` | value |  | Address of the rest server target |
| `backup` | `--user` | value |  | User name for an sftp target |
| `backup` | `--weekly` | value |  | Number of weekly backups to keep |
| `backup` | `--with-secrets` | bool |  | Include the encrypted secrets in the snapshot |
| `timemachine` | `--demo` | bool |  | Show made-up backups; nothing is run |
| `timemachine` | `--local` | bool |  | Skip targets that are read over the network |
| `java` | `--versions` | value | `25` | Comma list of Java major versions to install |
| `mail` | `--keep` | bool |  | Store the inbox on disk so it survives stop and start |
| `mail` | `--keep-data` | bool |  | Keep the stored mail when removing the catcher |
| `mail` | `--limit` | value |  | Maximum number of messages to show |
| `mail` | `--smtp-port` | value |  | Local port for the SMTP server |
| `mail` | `--subject` | value |  | Subject of the test message |
| `mail` | `--to` | value |  | Recipient address of the test message |
| `mail` | `--ui-port` | value |  | Local port for the web inbox |
| `tui` | `--demo` | bool |  | Use made-up data |
| `tui` | `--icons` | value |  | Show icons: on or off |
| `tui` | `--no-sidebar` | bool |  | Hide the sidebar |
| `tui` | `--sidebar` | bool |  | Show the sidebar |
| `bxtimemachine` | `--demo` | bool |  | Show made-up backups; nothing is run |
| `bxtimemachine` | `--local` | bool |  | Skip targets that are read over the network |
| `privacy` | `--off` | bool |  | With local-only, turn local-only mode off |
| `boxlang` | `--no-open` | any |  | For welcome: write the page but do not open it in a browser |
| `boxlang` | `--yes` | bool |  | Apply the change (update, install, remove, scan) instead of a plan |
| `boxlang` | `--dry-run` | bool |  | Show what would change without changing anything |
| `boxlang` | `--open` | bool |  | For home: open the BoxLang home folder; for register: the web page |
| `boxlang` | `--name` | value |  | For servers add: the name to register the server under |
| `boxlang` | `--depth` | value |  | For servers scan: how many folder levels to search (default 3) |
| `boxlang` | `--follow` | bool |  | For servers log: keep printing new log lines as they come |
| `db` | `--ask-password` | bool |  | Type the database password at a prompt instead of generating one |
| `db` | `--keep-data` | bool |  | On remove: keep the data volume so a restart reuses it |
| `db` | `--name` | value |  | Name of this instance, so you can run several (default: default) |
| `db` | `--password-file` | value |  | Read the database password from this file |
| `db` | `--port` | value |  | Host port to publish the database on (1024 to 65535) |
| `db` | `--show-password` | bool |  | On info: print the password instead of the file holding it |
| `containers` | `--lines` | value | `100` | On logs: how many last log lines to show (1 to 10000, default 200) |
| `vm` | `--cpus` | value |  | Number of CPU cores to give the VM |
| `vm` | `--disk` | value | `6` | Windows disk size, such as 64G |
| `vm` | `--fullscreen` | bool |  | On open: start the Windows RDP viewer full screen |
| `vm` | `--gpu` | value |  | Linux desktop GPU access: none, auto, intel, amd or nvidia |
| `vm` | `--keep-data` | bool |  | On remove: keep the VM's data folder on disk |
| `vm` | `--memory` | value |  | Linux desktop memory limit, such as 4G |
| `vm` | `--ram` | value |  | Windows memory size, such as 8G |
| `vm` | `--share` | value |  | Host folder shared with the VM, or none to turn sharing off |
| `vm` | `--show-password` | bool |  | On info: print the VM password instead of hiding it |
| `vm` | `--tag` | value | `ubuntu-xfce` | Linux desktop image flavour (see: vm versions linux) |
| `vm` | `--version` | value |  | Windows version to install (see: vm versions windows) |
| `vm` | `--web` | bool |  | On open: use the browser viewer instead of an RDP client |
| `android` | `--data` | bool |  | On remove: also delete Android's images, apps and their data |
| `android` | `--open` | bool |  | On register: open the Google device registration page |
| `android` | `--vanilla` | bool |  | On setup: use the image without Google apps or Play |
| `boxy` | `--accent` | value | `latam` | Local voice accent: latam or castilian Spanish |
| `boxy` | `--birthday` | value |  | Boxy's birthday as MM-DD (empty clears it) |
| `boxy` | `--color` | value |  | Boxy's colour: theme or a hex colour like #00ff78 |
| `boxy` | `--dir` | value |  | On export: folder to write the state images to |
| `boxy` | `--format` | value |  | Audio format the speech server returns: wav, mp3, opus or flac |
| `boxy` | `--hear` | value | `auto` | Language Voxtype listens for when you talk: auto, en or es |
| `boxy` | `--holidays` | value | `christmas` | Holiday outfits to wear, comma separated, or none |
| `boxy` | `--key` | value |  | Name of the stored secret or env variable holding the API key |
| `boxy` | `--lang` | value | `auto` | Voice language: auto, en or es (on list and test: en or es) |
| `boxy` | `--model` | value | `tts-1` | Speech model name sent to the voice server |
| `boxy` | `--name` | value |  | Boxy's display name (1 to 24 characters) |
| `boxy` | `--outfit` | value | `auto` | Outfit to wear: auto, none or an outfit ID |
| `boxy` | `--speed` | value |  | Local speech speed, 0.25 to 4 (1 is the voice's own pace) |
| `boxy` | `--url` | value | `https` | Address of an OpenAI-compatible speech server |
| `boxy` | `--voice` | value | `alloy` | Voice name (for local, needs --lang=en or es to pick the language) |
| `ai` | `--agent` | value |  | Which agent project to talk to (default: the default agent) |
| `ai` | `--all` | bool |  | List every model that fits; or approve all skills at once |
| `ai` | `--backend` | value |  | Pull-down shell backend: hyprland or yakuake |
| `ai` | `--background` | bool |  | On models pull: download in the background and return at once |
| `ai` | `--default` | bool |  | On link opencode: also make the active model opencode's default |
| `ai` | `--dir` | value |  | On session start: folder the agent session starts in |
| `ai` | `--embeddings` | bool |  | On discover: only show embedding models |
| `ai` | `--fits` | bool |  | On discover: only show models that fit this machine |
| `ai` | `--from` | value |  | On text: take the text from the selection or the clipboard |
| `ai` | `--lang` | value |  | On text: language to translate into or answer in |
| `ai` | `--limit` | value |  | On discover: maximum number of results (1 to 30, default 8) |
| `ai` | `--listen` | value | `127.0.0.` | On serve: listen on 127.0.0.1 (this machine) or 0.0.0.0 (network) |
| `ai` | `--model` | value |  | On ask and text: model ID to use instead of the active one |
| `ai` | `--models` | value |  | On setup: comma separated model IDs to download instead of picks |
| `ai` | `--name` | value | `work` | On session start: name added to the tmux session |
| `ai` | `--no-start` | bool |  | On agents setup: make the Boxy project but do not start it |
| `ai` | `--no-test` | bool |  | On models pull: skip the test question after download |
| `ai` | `--off` | bool |  | On link and agents profile: remove the link instead of adding it |
| `ai` | `--picks` | value |  | On setup: use all for every recommended model, not just defaults |
| `ai` | `--port` | value |  | On serve: port the AI server listens on (1024 to 65535) |
| `ai` | `--session` | bool |  | On agents approve: approve this kind of action for the whole session |
| `ai` | `--snapshot` | bool |  | On agents install and update: use the snapshot build (the default) |
| `ai` | `--source` | value |  | On engine: install llama.cpp from official or aur |
| `ai` | `--stable` | bool |  | On agents install and update: use the stable release |
| `ai` | `--start` | bool |  | Use --start=false to skip starting the agent on agents setup |
| `ai` | `--test` | bool |  | Use --test=false to skip the test question on models pull |
| `ai` | `--text` | value |  | On text: the text to work on, instead of selection or clipboard |
| `ai` | `--thread` | value |  | On agents ask: continue this conversation thread by its ID |
| `ai` | `--to` | value |  | On text: where the result goes: clipboard, notify or stdout |
| `ai` | `--tools` | bool |  | On discover: only show models that support tool calling |
| `ai` | `--tune` | bool |  | On setup: also tune each chat model for this machine |
| `ai` | `--vision` | bool |  | On discover: only show models that can read images |
| `ai` | `--window` | bool |  | On agents chat: open the chat in a new terminal window |
| `mcp` | `--write` | bool |  | Allow tools that change things (the agent asks first each time) |
| `skills` | `--tag` | value |  | On list: only show skills with this tag |
| `screenshot` | `--edit` | bool |  | Open the capture in the annotation editor (Noctalia only) |
| `qr` | `--out` | value | `wifi.png` | Write the QR code to this PNG file instead of the terminal |
| `share` | `--to` | value |  | Name of the device to send to, skips the device picker |
| `record` | `--region` | bool |  | Record an area you drag with the mouse, not the whole screen |
| `record` | `--audio` | value | `desktop` | Add sound: desktop (what plays) or mic (default microphone) |
| `record` | `--webcam` | any | `top-left` | Show the webcam in a corner (default bottom-right, or name one) |
| `record` | `--webcam-size` | value | `small` | Size of the webcam picture: small, medium (default) or large |
| `clipboard` | `--limit` | value |  | The most entries list returns (default 50) |
| `emoji` | `--category` | value | `food` | On list: one category, a part of its name (food, flags) |
| `emoji` | `--limit` | value | `20` | On list and recent: the most rows (default 200 and 30) |
| `dolphin` | `--fix` | bool |  | Rebuild KDE's service cache to repair an empty Open with menu |
| `input` | `--for` | value |  | Devices to plan helpers for: detect, apple, logitech, both, none |
| `input` | `--scroll-speed` | value | `0..63` | Set Magic Mouse and Trackpad scroll speed, 0 to 63 (default 32) |
| `wifi` | `--out` | value | `wifi.png` | Write the Wi-Fi QR code to this PNG file instead of the terminal |
