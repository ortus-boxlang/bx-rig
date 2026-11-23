---
title: Command flags
order: 2
summary: The flags each command accepts, for review.
---

# Command flags

Generated from `docs/reference/cli.json`. These flags work on every command: `--json`, `--yes`, `--dry-run`, `--force`, `--quiet`. Any other flag must be listed for the command; an unknown flag is a usage error (exit 2) and nothing runs.

Type `value` is written `--flag=VALUE`, `bool` is written bare, and `any` was found in the command code but is not in its usage line yet: add it to the usage, or remove it if the code no longer reads it.

| Command | Flag | Type | Default |
|---|---|---|---|
| `init` | `--answers` | value | `answers.json` |
| `init` | `--bucket` | any |  |
| `init` | `--container` | any |  |
| `init` | `--defaults` | any |  |
| `init` | `--export` | value |  |
| `init` | `--fresh` | bool |  |
| `init` | `--from` | value |  |
| `init` | `--from-system` | bool |  |
| `init` | `--print-answers` | bool |  |
| `init` | `--remote` | any |  |
| `init` | `--rerun` | bool |  |
| `init` | `--workspaces` | any |  |
| `refresh` | `--starter` | bool |  |
| `reinstall` | `--answers` | any |  |
| `reinstall` | `--bucket` | any |  |
| `reinstall` | `--container` | any |  |
| `reinstall` | `--defaults` | any |  |
| `reinstall` | `--export` | any |  |
| `reinstall` | `--fresh` | any |  |
| `reinstall` | `--from` | any |  |
| `reinstall` | `--from-system` | any |  |
| `reinstall` | `--print-answers` | any |  |
| `reinstall` | `--remote` | any |  |
| `reinstall` | `--rerun` | any |  |
| `reinstall` | `--workspaces` | any |  |
| `wizard` | `--answers` | value |  |
| `wizard` | `--demo` | bool |  |
| `wizard` | `--out` | value |  |
| `wizard` | `--pages` | value |  |
| `doctor` | `--dev` | bool |  |
| `update` | `--notify` | bool |  |
| `scheduler` | `--group` | value | `sync` |
| `scheduler` | `--when` | value |  |
| `scheduler` | `--notify` | value |  |
| `scheduler` | `--timeout` | value |  |
| `scheduler` | `--limit` | value |  |
| `ascii` | `--font` | value | `dos` |
| `ascii` | `--color` | value |  |
| `ascii` | `--gradient` | value | `sunset` |
| `ascii` | `--direction` | value | `diagonal` |
| `ascii` | `--plain` | bool |  |
| `ascii` | `--width` | value | `60` |
| `ascii` | `--style` | value | `ascii` |
| `about` | `--wait` | bool |  |
| `about` | `--plain` | bool |  |
| `banner` | `--plain` | bool |  |
| `apps` | `--name` | any |  |
| `help` | `--help` | bool |  |
| `help` | `--h` | bool |  |
| `install` | `--default` | any |  |
| `install` | `--optional` | bool |  |
| `install` | `--profile` | any |  |
| `install` | `--shell` | value |  |
| `remove` | `--name` | any |  |
| `pkg` | `--aur` | bool |  |
| `pkg` | `--explicit` | bool |  |
| `pkg` | `--limit` | value |  |
| `pkg` | `--name` | any |  |
| `pkg` | `--source` | value |  |
| `catalog` | `--distro` | value | `suse` |
| `catalog` | `--write` | bool |  |
| `catalog` | `--category` | value |  |
| `catalog` | `--group` | value | `ai` |
| `catalog` | `--kind` | value |  |
| `catalog` | `--source` | value |  |
| `catalog` | `--tier` | value | `default` |
| `catalog` | `--url` | any |  |
| `plan` | `--default` | any |  |
| `plan` | `--optional` | bool |  |
| `plan` | `--profile` | any |  |
| `plan` | `--shell` | value |  |
| `install-plan` | `--default` | any |  |
| `install-plan` | `--optional` | bool |  |
| `install-plan` | `--profile` | any |  |
| `install-plan` | `--shell` | value |  |
| `optional-plan` | `--default` | any |  |
| `optional-plan` | `--optional` | any |  |
| `optional-plan` | `--profile` | any |  |
| `optional-plan` | `--shell` | value |  |
| `profile-plan` | `--default` | any |  |
| `profile-plan` | `--optional` | bool |  |
| `profile-plan` | `--profile` | any |  |
| `profile-plan` | `--shell` | value |  |
| `profile-install-plan` | `--default` | any |  |
| `profile-install-plan` | `--optional` | bool |  |
| `profile-install-plan` | `--profile` | any |  |
| `profile-install-plan` | `--shell` | value |  |
| `profile-install` | `--default` | any |  |
| `profile-install` | `--optional` | bool |  |
| `profile-install` | `--profile` | any |  |
| `profile-install` | `--shell` | value |  |
| `optional-install` | `--default` | any |  |
| `optional-install` | `--optional` | any |  |
| `optional-install` | `--profile` | any |  |
| `optional-install` | `--shell` | value |  |
| `profile-list` | `--default` | any |  |
| `profile-list` | `--optional` | any |  |
| `profile-list` | `--profile` | any |  |
| `profile-list` | `--shell` | any |  |
| `optional-list` | `--default` | any |  |
| `optional-list` | `--optional` | any |  |
| `optional-list` | `--profile` | any |  |
| `optional-list` | `--shell` | any |  |
| `desktop-list` | `--default` | any |  |
| `desktop-list` | `--optional` | any |  |
| `desktop-list` | `--profile` | any |  |
| `desktop-list` | `--shell` | any |  |
| `tui-list` | `--default` | any |  |
| `tui-list` | `--optional` | any |  |
| `tui-list` | `--profile` | any |  |
| `tui-list` | `--shell` | any |  |
| `web-list` | `--default` | any |  |
| `web-list` | `--optional` | any |  |
| `web-list` | `--profile` | any |  |
| `web-list` | `--shell` | any |  |
| `package-status` | `--default` | any |  |
| `package-status` | `--optional` | any |  |
| `package-status` | `--profile` | any |  |
| `package-status` | `--shell` | any |  |
| `package-source` | `--default` | any |  |
| `package-source` | `--optional` | any |  |
| `package-source` | `--profile` | any |  |
| `package-source` | `--shell` | any |  |
| `web` | `--browser` | value |  |
| `toolchain` | `--also` | any |  |
| `toolchain` | `--build` | any |  |
| `toolchain` | `--default` | any |  |
| `toolchain` | `--keys` | any |  |
| `toolchain` | `--shell` | any |  |
| `setup` | `--also` | value | `a` |
| `setup` | `--build` | value |  |
| `setup` | `--default` | value | `ghostty` |
| `setup` | `--keys` | bool |  |
| `setup` | `--layout` | value |  |
| `setup` | `--layouts` | value | `us-intl` |
| `setup` | `--natural-scroll` | bool |  |
| `setup` | `--shell` | value |  |
| `setup` | `--terminal` | value |  |
| `setup` | `--theme` | value |  |
| `setup` | `--undo-keys` | bool |  |
| `setup` | `--wallpaper` | value |  |
| `setup` | `--workspaces` | value |  |
| `plasma` | `--agenda` | bool |  |
| `plasma` | `--desktops` | value |  |
| `plasma` | `--preset` | value | `islands` |
| `plasma` | `--without-weather` | bool |  |
| `keys` | `--keyboard` | value | `pc` |
| `keys` | `--swap` | value |  |
| `runner` | `--prompt` | value |  |
| `launcher` | `--yes` | bool |  |
| `launcher` | `--dry-run` | bool |  |
| `config` | `--theme` | any |  |
| `config` | `--wallpaper` | any |  |
| `theme` | `--keep-wallpaper` | bool |  |
| `theme` | `--mode` | value | `dark` |
| `theme` | `--name` | value | `mine` |
| `appearance` | `--mode` | any |  |
| `screensaver` | `--effect` | value |  |
| `screensaver` | `--idle` | bool |  |
| `time` | `--demo` | any |  |
| `time` | `--host` | any |  |
| `time` | `--list` | bool |  |
| `time` | `--local` | any |  |
| `time` | `--packages` | any |  |
| `time` | `--path` | any |  |
| `calendar` | `--client-id` | value | `123.apps.googleusercontent.com` |
| `calendar` | `--client-secret-file` | value |  |
| `calendar` | `--days` | value | `3` |
| `calendar` | `--yes` | bool |  |
| `calendar` | `--dry-run` | bool |  |
| `remind` | `--at` | value | `09` |
| `remind` | `--in` | value | `3` |
| `nightshift` | `--location` | value | `40.4` |
| `notify` | `--history` | bool |  |
| `system` | `--repo` | bool |  |
| `system` | `--aur` | bool |  |
| `system` | `--all` | bool |  |
| `ssh` | `--email` | value | `me` |
| `git` | `--key` | value |  |
| `secrets` | `--from-file` | value |  |
| `secrets` | `--keyring` | value |  |
| `secrets` | `--overwrite` | bool |  |
| `secrets` | `--plain` | bool |  |
| `secrets` | `--provider` | value |  |
| `secrets` | `--show` | bool |  |
| `secrets` | `--strict` | bool |  |
| `secrets` | `--type` | value |  |
| `vpn` | `--location` | value |  |
| `cloud` | `--path` | value |  |
| `dotfiles` | `--method` | value |  |
| `dotfiles` | `--overwrite` | bool |  |
| `nas` | `--ask-password` | bool |  |
| `nas` | `--delete` | bool |  |
| `nas` | `--host` | value | `ds920.local` |
| `nas` | `--password-file` | value |  |
| `nas` | `--path` | value | `bxrig-backup` |
| `nas` | `--protocol` | value |  |
| `nas` | `--to` | value |  |
| `nas` | `--user` | value | `me` |
| `nas` | `--vers` | value | `3.1.1` |
| `backup` | `--all` | any |  |
| `backup` | `--ask-keys` | bool |  |
| `backup` | `--bucket` | value | `mybackups` |
| `backup` | `--container` | value |  |
| `backup` | `--credentials` | value |  |
| `backup` | `--daily` | value |  |
| `backup` | `--deep` | bool |  |
| `backup` | `--default` | any |  |
| `backup` | `--description` | value |  |
| `backup` | `--endpoint` | value | `https` |
| `backup` | `--from` | value | `usb` |
| `backup` | `--home` | bool |  |
| `backup` | `--host` | value |  |
| `backup` | `--include` | value |  |
| `backup` | `--keep` | value |  |
| `backup` | `--keys-file` | value |  |
| `backup` | `--local` | bool |  |
| `backup` | `--monthly` | value |  |
| `backup` | `--only` | value | `.config` |
| `backup` | `--packages` | bool |  |
| `backup` | `--path` | value |  |
| `backup` | `--project` | value |  |
| `backup` | `--reason` | value |  |
| `backup` | `--region` | value |  |
| `backup` | `--remote` | value |  |
| `backup` | `--scheduled` | any |  |
| `backup` | `--target` | value |  |
| `backup` | `--to` | value | `do` |
| `backup` | `--type` | value | `s3` |
| `backup` | `--url` | value |  |
| `backup` | `--user` | value |  |
| `backup` | `--weekly` | value |  |
| `backup` | `--with-secrets` | bool |  |
| `timemachine` | `--demo` | bool |  |
| `timemachine` | `--host` | any |  |
| `timemachine` | `--local` | bool |  |
| `timemachine` | `--packages` | any |  |
| `timemachine` | `--path` | any |  |
| `java` | `--unset` | bool |  |
| `mail` | `--keep` | bool |  |
| `mail` | `--keep-data` | bool |  |
| `mail` | `--limit` | value |  |
| `mail` | `--smtp-port` | value |  |
| `mail` | `--subject` | value |  |
| `mail` | `--to` | value |  |
| `mail` | `--ui-port` | value |  |
| `tui` | `--demo` | bool |  |
| `tui` | `--icons` | value |  |
| `tui` | `--no-sidebar` | bool |  |
| `tui` | `--sidebar` | bool |  |
| `bxtimemachine` | `--demo` | bool |  |
| `bxtimemachine` | `--host` | any |  |
| `bxtimemachine` | `--local` | bool |  |
| `bxtimemachine` | `--packages` | any |  |
| `bxtimemachine` | `--path` | any |  |
| `boxlang` | `--list` | any |  |
| `boxlang` | `--no-open` | any |  |
| `boxlang` | `--yes` | bool |  |
| `boxlang` | `--dry-run` | bool |  |
| `boxlang` | `--open` | bool |  |
| `boxlang` | `--name` | value |  |
| `boxlang` | `--depth` | value |  |
| `boxlang` | `--follow` | bool |  |
| `db` | `--ask-password` | bool |  |
| `db` | `--keep-data` | bool |  |
| `db` | `--name` | bool |  |
| `db` | `--password-file` | bool |  |
| `db` | `--port` | bool |  |
| `db` | `--show-password` | bool |  |
| `containers` | `--lines` | value | `100` |
| `vm` | `--cpus` | value |  |
| `vm` | `--disk` | value | `6` |
| `vm` | `--fullscreen` | bool |  |
| `vm` | `--gpu` | value |  |
| `vm` | `--keep-data` | bool |  |
| `vm` | `--memory` | value |  |
| `vm` | `--name` | any |  |
| `vm` | `--ram` | value |  |
| `vm` | `--share` | value |  |
| `vm` | `--show-password` | bool |  |
| `vm` | `--tag` | value | `ubuntu-xfce` |
| `vm` | `--version` | value |  |
| `vm` | `--web` | bool |  |
| `ai` | `--backend` | value |  |
| `ai` | `--dir` | value |  |
| `ai` | `--name` | value | `work` |
| `skills` | `--tag` | value |  |
| `screenshot` | `--edit` | bool |  |
| `qr` | `--out` | value | `wifi.png` |
| `share` | `--to` | value |  |
| `record` | `--region` | bool |  |
| `record` | `--audio` | value | `desktop` |
| `record` | `--webcam` | any | `top-left` |
| `record` | `--webcam-size` | value | `small` |
| `dolphin` | `--fix` | bool |  |
| `input` | `--for` | value |  |
| `input` | `--scroll-speed` | value | `0..63` |
| `wifi` | `--out` | value | `wifi.png` |
