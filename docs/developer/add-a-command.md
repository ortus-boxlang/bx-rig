---
title: Add a command
order: 83
summary: A worked tutorial that adds a small command from the registry entry to a passing test.
---

# Add a command

You will add `bxrig dnsflush`, a made-up command that empties the system DNS cache. It changes the machine, so it shows a plan first and needs `--yes`. That makes it a good tour of every part.

The model is `bxrig gpu mode` (`src/bxrig/GpuMode.bx`, and the `gpu` case in `src/Main.bx`): a small class that calls `Mutation` for its plan.

> **Note:** `dnsflush` is an example. Do not commit it, or pick your own name and tool.

## What you will touch

```mermaid
flowchart LR
  A["1 cli.json entry"] --> B["2 case in Main.bx"]
  B --> C["3 class in src/bxrig"]
  C --> D["4 gen-docs.sh"]
  D --> E["5 test and CI list"]
```

## 1. Describe it in the registry

Open `docs/reference/cli.json` and add an entry to a group (here `tools`). The registry feeds `bxrig help`, flag checking and the docs.

```json
{
 "name": "dnsflush",
 "summary": "Empty the system DNS cache.",
 "usage": [
  "dnsflush [--yes] [--dry-run] [--json]"
 ],
 "examples": [
  "bxrig dnsflush",
  "bxrig dnsflush --yes"
 ],
 "mutates": true,
 "flags": []
}
```

Rules `gen-docs.sh` enforces: the summary ends with a full stop, every usage line starts with the command name, every example starts with `bxrig` and names a real command, and every `--flag` you mention is either global (`--json`, `--yes`, `--dry-run`, `--force`, `--quiet`) or listed in `flags`. `"mutates": true` adds the "needs `--yes`" note to the docs and to `bxrig help`.

## 2. Route it in `Main.bx`

Add one `case` before `default:`. Wrong usage prints the registry's usage text and exits 2. Doctor's `case` (`src/Main.bx`) is the model.

```boxlang
case "dnsflush":
	// Empties the DNS cache. See bxrig.DnsFlush.
	if ( p.len() != 1 ) {
		println( new bxrig.CommandSpec().usage( cmd ) );
		CLIExit( xit.usage() );
	}
	CLIExit( new bxrig.DnsFlush( cli ).run( structKeyExists( args.options, "yes" ), structKeyExists( args.options, "dry-run" ), asJson ) );
	break;
```

Use `xit.usage()`, never a bare `2`. `Main.bx` has already checked the flags against the registry, so an unknown `--flag` never reaches your class.

## 3. Write the class

Create `src/bxrig/DnsFlush.bx`. Every function and the class carry a DocBox comment (see [Code rules](code-rules.md)).

```boxlang
/**
 * `bxrig dnsflush [--yes] [--dry-run] [--json]`: empties the system DNS cache with systemd-resolved.
 *
 * Works with bxrig.util.Mutation (plan, dry run, run) and bxrig.util.Proc (starts the program).
 * Exit: 0 done or dry run, 2 a plan without --yes, 4 resolvectl is missing, 6 the flush failed.
 */
class DnsFlush {

	/**
	 * Builds the command.
	 *
	 * @param cli The shared output helper made in Main.bx (bxrig.util.Cli).
	 * @param runner A fake program runner for tests; "" runs real programs.
	 *
	 * @return This object.
	 */
	function init( cli, runner = "" ) {
		variables.cli = arguments.cli;
		variables.proc = new bxrig.util.Proc( arguments.runner );
		return this;
	}

	/**
	 * Shows the plan, or flushes the DNS cache when --yes is given.
	 *
	 * @param yes True when --yes was passed.
	 * @param dry True when --dry-run was passed.
	 * @param asJson True when --json was passed.
	 *
	 * @return The exit code: 0, 2 (plan), 4 (no resolvectl) or 6 (failed).
	 */
	function run( yes, dry, asJson ) {
		var out = variables.cli.scoped( "dnsflush" );
		// Check the tool first: a missing tool must be exit 4, before any plan is printed.
		if ( !variables.proc.has( "resolvectl" ) ) return out.precondition( "resolvectl was not found (systemd-resolved)", arguments.asJson );
		return new bxrig.util.Mutation( out, variables.proc ).run( "flush the DNS cache", [ [ "resolvectl", "flush-caches" ] ], arguments.yes, arguments.dry, arguments.asJson, {}, [], 30 );
	}
}
```

What the helpers give you for free:

| You write | You get |
|---|---|
| `cli.scoped( "dnsflush" )` | An `Out` bound to the command name for the `--json` envelope. |
| `out.precondition( msg, asJson )` | `error: msg` (or `{ "error": ... }`) and exit 4. Also `out.usage` (2) and `out.failed` (6). |
| `Mutation.run( title, cmds, yes, dry, asJson, data, shown, timeout )` | "Plan: ..." and exit 2 without `--yes`; "Dry run: ..." and exit 0 with `--dry-run`; otherwise runs each argv in order and stops at the first failure with exit 6. |
| `proc.has( "tool" )` | A `command -v` check. Programs run only through `Proc`, with an argv array. |

If your command writes a file, do not write it yourself: build an entry and pass it to `ConfigService` for the backup, atomic replace and journal.

## 4. Regenerate the docs

```bash
bash bootstrap/gen-docs.sh
```

This rewrites `docs/reference/commands.md`, `docs/reference/command-flags.md` and `src/bxrig/CommandFlagData.bx`. It fails when `Main.bx` and `cli.json` disagree (a `case` with no entry, or an entry with no `case`). Commit both the source and the generated files; CI runs it with `--check`.

## 5. Test it

Create `tests/dnsflush-test.sh`. It runs the real binary against a fake `resolvectl`, so no root and no network is needed. More in [Tests](tests.md).

```bash
#!/usr/bin/env bash
# `bxrig dnsflush` with a fake resolvectl. Usage: dnsflush-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
export LOG="$tmp/log"; : > "$LOG"
stub resolvectl 'echo "resolvectl $*" >> "$LOG"'
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }

[[ "$(code "$binary" dnsflush)" == 2 ]] || fail 'without --yes it is a plan (exit 2)'
[[ ! -s "$LOG" ]] || fail 'the plan ran something'
run "$binary" dnsflush --dry-run --json | jq -e '.dry_run and .data.commands[0] == "resolvectl flush-caches"' >/dev/null || fail 'dry run'
run "$binary" dnsflush --yes >/dev/null
grep -qF 'resolvectl flush-caches' "$LOG" || fail '--yes did not run the flush'
[[ "$(code "$binary" dnsflush extra)" == 2 ]] || fail 'extra words are a usage error'
[[ "$(code "$binary" dnsflush --bogus)" == 2 ]] || fail 'an unknown flag is a usage error'
echo "dnsflush-test: ok"
```

Then make CI know about it, or `tests/dry-test.sh` fails:

1. Add `bash tests/dnsflush-test.sh "$candidate"` next to the other test lines in `.github/workflows/ci.yml`.
2. Add `tests/dnsflush-test.sh` to the `bash -n` list in the same file.

## 6. Run it all

```bash
scripts/dev-build.sh
bash tests/dnsflush-test.sh dist/bxrig
dist/bxrig dnsflush              # the plan, exit 2
dist/bxrig dnsflush --dry-run
bash scripts/format.sh
bash tests/dry-test.sh
```

## Checklist

- [ ] Entry in `docs/reference/cli.json`, then `bootstrap/gen-docs.sh`
- [ ] `case` in `src/Main.bx` with `xit.usage()` on bad usage
- [ ] Class in `src/bxrig/` with DocBox on the class and every function
- [ ] Plan, `--dry-run` and `--yes` through `Mutation` (or `ConfigService` for files)
- [ ] Output through `Out`, so `--json` works
- [ ] A shell test, listed twice in `ci.yml`
- [ ] `bash scripts/format.sh` and `bash tests/dry-test.sh` pass

## Advanced

- **Commands with sub-verbs** (`time zone`, `gpu mode`) collect the words after the command into an array and pass them to a `run( words, ... )` method that dispatches on the first word; see `Time.run` in `src/bxrig/Time.bx`.
- **A command that only changes your own settings** (a theme, the bar) may act at once without `--yes`, but must take `--dry-run` and be documented as an exception in the [contract](../architecture/COMMAND-CONTRACT.md) (section 2, rule 11).
- **Commands that pass flags to another program** (`secrets run`, `scheduler add ... --`, `ai agents NAME VERB`) are exempt from the flag check in `Main.bx`.
- **Unit tests.** Logic that needs no binary can be tested from source with a `tests/NAME_test.bxs` that uses `lib.Check`; see `tests/out_test.bxs`.
