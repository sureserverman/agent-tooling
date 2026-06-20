---
name: codex-config-and-hooks
description: Use when configuring OpenAI Codex or writing Codex hooks. Triggers on "config.toml for Codex", "Codex profile", "Codex hooks", "Codex MCP server", "AGENTS.md discovery", "Codex sandbox config", "codex approval policy", "Codex features flags", "hooks.json for Codex".
---

# codex-config-and-hooks

Codex is configured through TOML (`config.toml`), extended through a hooks engine (10 lifecycle events since v0.114.0), wired to tools through MCP server tables, and briefed through AGENTS.md files. Two things bite hardest in mid-2026: the **v0.134.0 breaking removal of legacy profiles** (old configs fail at startup), and the **hook trust model** (non-managed command hooks silently don't run until reviewed via `/hooks`).

All facts verified 2026-06-09 against developers.openai.com/codex (config-reference, config-advanced, mcp, hooks, guides/agents-md, changelog), Codex CLI v0.139.0.

## Reference map

| When you need… | Read first |
|---|---|
| config.toml layering, the profiles breaking change, model/provider keys, approval + sandbox, [features], [tools], [otel], MCP server tables | `references/config.md` |
| Hook events, file locations + precedence, JSON/TOML shapes, stdin/stdout contracts, trust model, legacy notify | `references/hooks.md` |
| AGENTS.md discovery order, override files, byte budget, CODEX_HOME | `references/agents-md.md` |

## Critical facts first

### BREAKING: legacy profiles removed in v0.134.0 (May 26, 2026)

`[profiles.<name>]` tables and the top-level `profile = "<name>"` key are **gone — Codex fails at startup** if config.toml still contains them (issue #24858). Replacement: standalone overlay files.

```
$CODEX_HOME/work.config.toml     # overlay: only the keys that differ
codex --profile work             # apply it
```

Migration: move each `[profiles.work]` body into `$CODEX_HOME/work.config.toml` as top-level keys; delete the `[profiles.*]` tables and any `profile =` line from config.toml. The deterministic validator flags residue as `codex-legacy-profile`.

### Hooks don't run until trusted

**Non-managed command hooks must be reviewed and trusted via `/hooks` before they execute.** A hook that "doesn't fire" is usually an untrusted hook. `--dangerously-bypass-hook-trust` skips review for one invocation — CI escape hatch, not a workflow. Enterprises can pin `allow_managed_hooks_only` in `requirements.toml` (valid only there).

## Decision rules

### Where does this setting go?

| Scope | File | Notes |
|---|---|---|
| Personal default | `~/.codex/config.toml` | Everything allowed |
| Per-project | `.codex/config.toml` in the repo | **Cannot override**: provider/auth, notifications, profile selection, telemetry |
| Situational | `$CODEX_HOME/<name>.config.toml` + `codex --profile <name>` | Overlay; only the diffs |
| Enterprise mandate | `requirements.toml` | e.g. `allow_managed_hooks_only` — only valid here |

### Approval and sandbox: pick the pair deliberately

- `approval_policy`: `untrusted` | `on-request` | `never`
- `sandbox_mode`: `read-only` | `workspace-write` | `danger-full-access`
- `workspace-write` is tuned via `[sandbox_workspace_write]`: `writable_roots`, `network_access`, `exclude_slash_tmp`, `exclude_tmpdir_env_var`.

Sane defaults: `on-request` + `workspace-write` for daily work; `never` + `read-only` for unattended review jobs; `danger-full-access` only inside disposable containers.

### Hook or notify?

The hooks engine (v0.114.0, March 11 2026) supersedes the older single-purpose `notify` setting. `notify = ["python3", "..."]` receives one JSON arg and fires **only** on `agent-turn-complete` — keep it for simple desktop notifications, use hooks for everything else (and don't confuse either with `tui.notifications`). Ten events: `SessionStart`, `SubagentStart`, `UserPromptSubmit` (v0.116), `PreToolUse`, `PermissionRequest`, `PostToolUse` (~v0.117), `PreCompact`, `PostCompact`, `SubagentStop`, `Stop`. Contracts, locations, and precedence in `references/hooks.md`.

### MCP: stdio or streamable HTTP?

`[mcp_servers.<name>]` with either `command`/`args`/`env`/`env_vars`/`cwd` (stdio) or `url`/`bearer_token_env_var`/`http_headers`/`env_http_headers` (streamable HTTP). Per-server knobs: `enabled`, `required` (fail startup if unreachable — use for servers your workflow can't live without), `startup_timeout_sec` (default 10), `tool_timeout_sec` (default 60), `enabled_tools`/`disabled_tools`, `default_tools_approval_mode` = `auto` | `prompt` | `approve`. Manage with `codex mcp add`, `codex mcp login`, `/mcp` in the TUI; OAuth callback via `mcp_oauth_callback_port`/`mcp_oauth_callback_url`.

### Feature flags and tools

- `[features]`: `multi_agent`, `unified_exec`, `shell_snapshot` (stable, on), `undo` (stable, off), `memories` (off), `network_proxy` (experimental), `prevent_idle_sleep`. Toggle via `codex features enable|disable`.
- `[tools]`: `web_search = "disabled" | "cached" | "live"` (the legacy boolean form is deprecated), `view_image`, plus `[tools.web_search]` `context_size`/`allowed_domains`/`location`.
- `[otel]`: `exporter` = `none` | `otlp-http` | `otlp-grpc`.

### AGENTS.md: who briefs the agent?

Global: `~/.codex/AGENTS.override.md` if present, else `~/.codex/AGENTS.md`. Project: Codex walks **git root → cwd**, and in each directory takes `AGENTS.override.md` → `AGENTS.md` → `project_doc_fallback_filenames`. Combined budget `project_doc_max_bytes` (default **32 KiB**, truncates beyond). `CODEX_HOME` relocates the global files; the context is rebuilt per run. Details in `references/agents-md.md`.

## Deterministic gate

```bash
bash scripts/validate.sh path/to/artifact --json | jq .
```

Flags `[profiles.*]` / top-level `profile =` residue (`codex-legacy-profile`, error), unparseable config.toml, hooks.json with unknown event names (warning), and agent TOML / SKILL.md / manifest problems.

## Anti-patterns this skill catches

- `[profiles.work]` or `profile = "work"` in any config.toml — **startup failure** since v0.134.0; migrate to overlay files.
- A hook shipped without telling users to trust it via `/hooks` — it will silently never run.
- `experimental_instructions_file` — deprecated; use `model_instructions_file`.
- `web_search = true` — legacy boolean; use `"cached"` or `"live"`.
- Provider/auth or telemetry keys in a project `.codex/config.toml` — projects can't override those; they're ignored.
- A load-bearing MCP server without `required = true` — failures surface mid-task instead of at startup.
- An AGENTS.md tree whose combined size blows past 32 KiB — silent truncation; raise `project_doc_max_bytes` or trim.
- `notify` used for tool-event automation — it only fires on `agent-turn-complete`; use hooks.

## Sources

- OpenAI, *Config reference* + *Advanced config* — layering, profiles change, model keys, sandbox/approvals, features, tools, otel ([developers.openai.com/codex/config-reference](https://developers.openai.com/codex/config-reference), […/config-advanced](https://developers.openai.com/codex/config-advanced)). Verified 2026-06-09 (Codex CLI v0.139.0).
- OpenAI, *Hooks* — events, locations, contracts, trust model ([developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks)). Verified 2026-06-09.
- OpenAI, *MCP* — server tables, timeouts, approval modes, OAuth ([developers.openai.com/codex/mcp](https://developers.openai.com/codex/mcp)). Verified 2026-06-09.
- OpenAI, *AGENTS.md guide* — discovery, overrides, byte budget ([developers.openai.com/codex/guides/agents-md](https://developers.openai.com/codex/guides/agents-md)). Verified 2026-06-09.
- OpenAI, *Changelog* — hooks v0.114.0, UserPromptSubmit v0.116, PostToolUse ~v0.117, profiles removal v0.134.0 ([developers.openai.com/codex/changelog](https://developers.openai.com/codex/changelog)); issues #24858, #15941. Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
