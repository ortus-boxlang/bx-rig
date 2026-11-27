---
title: MCP and privacy
order: 4
summary: BxRig's own tools for every coding agent and editor, and what leaves your machine, with switches for a local model and telemetry.
---

# MCP and privacy

Use this page to give your coding agent BxRig's tools, and to see and limit what your AI tools send out.

## Try it

```bash
bxrig mcp link --yes              # BxRig's tools in every agent you have, read-only
bxrig privacy                     # what leaves this machine
bxrig privacy local-only --yes    # use your local model where an agent can
```

<video src="../assets/clips/mcp-cli.webm" poster="../assets/screenshots/mcp-cli.webp" autoplay loop muted playsinline width="100%"></video>

## Give your agent BxRig's tools

Your coding agent or editor can use BxRig the way Boxy does: ask how the battery is, list the themes, check your agenda, search the app catalog, see your databases. BxRig gives them its tools over MCP (Model Context Protocol), which every major agent speaks.

```mermaid
flowchart LR
  A["Your agent or editor"] -->|"MCP"| B["bxrig mcp serve"]
  B --> C["BxRig command"]
  C --> D{"Read or change?"}
  D -->|"read"| E["Runs"]
  D -->|"change (needs --write)"| F["Agent asks you first"]
```

The diagram shows how an agent's request reaches BxRig and where the read-only limit applies.

```bash
bxrig mcp                         # each agent and editor: linked or not
bxrig mcp link --yes              # every one you have installed, read-only
bxrig mcp link pi-agent --write --yes   # one agent, and it may change things too
bxrig mcp tools                   # the tools: what reads and what changes
bxrig mcp unlink --yes
```

**Read-only unless you say so.** A linked agent gets 17 tools that only read. With `--write` it also gets the 19 that change something (the theme, night light, reminders, installing an app, starting a database, a system update) and, like for its own tools, it asks you before each one.

**The same tools as Boxy.** They are Boxy's own tools, so each one runs a BxRig command: an agent can do only what BxRig does, through the same plans and checks.

**What it runs on.** The server is BoxLang with bx-ai, which [bx-agents](boxlang-agents.md) installs: `bxrig ai agents install --yes` once. The agent starts `bxrig mcp serve` itself, for its session.

## See what leaves your machine

```bash
bxrig privacy
```

![What leaves this machine](../assets/screenshots/privacy-cli.webp)

For each AI on this machine: where its model runs (here or in the cloud, and whose), whether it could use your local model, the keys you stored (by name, never a value), the MCP servers each agent can reach and where they are, each agent's telemetry, and the folders where agents keep your chats.

The **Privacy** page (`bxrig tui privacy`) shows the same report as rows: a cloud agent that could be local and a web MCP server are flagged. `l` turns local-only on (`L` off), `t` turns telemetry off (`T` back on). The bar's Agents panel has a **Privacy** button that opens it.

![The Privacy page of the Control Center](../assets/screenshots/privacy-page.webp)

## Use your local model

The agents that can use a local model get BxRig's server, `127.0.0.1:8089` (see [Local AI](local-ai.md)):

```bash
bxrig privacy local-only --yes        # OpenCode, Pi, Copilot CLI, Crush, Goose
bxrig privacy local-only --off --yes
```

OpenCode also makes your active model its default; in the others pick the BxRig provider.

## Turn off telemetry

Where the agent has a documented switch:

```bash
bxrig privacy telemetry off --yes
bxrig privacy telemetry on zed --yes   # one agent back to its own default
```

## Advanced

### Which agents can go local

The rest can not use a local model, and the report says why: Claude Code, Gemini CLI, Antigravity and Kiro only offer their makers' models, and Cursor and Amp send every request through their own servers. Kilo Code, Qwen Code, Grok Build, Zed, VS Code and Codex can be pointed at it by hand; the report says where (Codex needs the Responses API, which only recent llama.cpp builds offer).

### What the telemetry switch sets

| Agent | What BxRig sets |
|---|---|
| Claude Code | `DISABLE_TELEMETRY` and `DISABLE_ERROR_REPORTING` in `~/.claude/settings.json` |
| Codex | `[analytics] enabled = false` |
| Gemini CLI, Qwen Code | `privacy.usageStatisticsEnabled: false` |
| Pi | `enableInstallTelemetry: false` |
| Goose | `GOOSE_TELEMETRY_ENABLED: false` |
| Kiro | `kiro-cli settings telemetry.enabled false` |
| Zed | `telemetry.diagnostics` and `telemetry.metrics` off |
| VS Code | `telemetry.telemetryLevel: off` |

For the others the report says how, when there is a way: Crush with `CRUSH_DISABLE_METRICS=1` in your shell, Cursor with Privacy Mode in your account, Antigravity in its settings. Kilo Code has one you set yourself: `KILO_TELEMETRY_LEVEL=off` in your environment. OpenCode, Amp and Grok Build document no switch.

### Where `mcp link` writes

`link` writes only BxRig's own entry, in each agent's own place, and keeps the old file as `FILE.bxrig-backup`:

| Agent or editor | Where |
|---|---|
| Claude Code, Codex | their own `mcp add` command |
| Pi | `~/.pi/agent/mcp.json` |
| Gemini CLI | `~/.gemini/settings.json` |
| OpenCode | `~/.config/opencode/opencode.json` |
| Kilo Code | `~/.config/kilo/kilo.json` (or `kilo.jsonc` when you have that) |
| GitHub Copilot CLI | `~/.copilot/mcp-config.json` |
| Cursor and Cursor Agent | `~/.cursor/mcp.json` |
| Amp | `~/.config/amp/settings.json` |
| Crush | `~/.config/crush/crushrc` |
| Goose | `~/.config/goose/config.yaml` |
| Kiro | `~/.kiro/settings/mcp.json` |
| Qwen Code | `~/.qwen/settings.json` |
| Grok Build | `~/.grok/config.toml` |
| Antigravity | `~/.gemini/config/mcp_config.json` |
| Zed | `~/.config/zed/settings.json` (your comments stay) |
| VS Code | `~/.config/Code/User/mcp.json` |

A file BxRig can not change safely (JSON with comments where the agent does not allow them, or an entry of yours in the way) is left out with the reason; name the agent to see it as an error. Restart an agent that is running to see the tools.

Next: [AI agents and skills](agents.md) · [Local AI](local-ai.md) · [Security](../maintain/security.md)
