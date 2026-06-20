# Codex config.toml reference

Facts verified 2026-06-09 against [developers.openai.com/codex/config-reference](https://developers.openai.com/codex/config-reference), [developers.openai.com/codex/config-advanced](https://developers.openai.com/codex/config-advanced), and [developers.openai.com/codex/mcp](https://developers.openai.com/codex/mcp), Codex CLI v0.139.0.

## Layering

| Layer | File | Wins over |
|---|---|---|
| Enterprise mandate | `requirements.toml` (managed deployment) | everything — keys here cannot be loosened below |
| Overlay (ex-profile) | `$CODEX_HOME/<name>.config.toml`, applied via `codex --profile <name>` | user + project config for the keys it sets |
| Project | `.codex/config.toml` at the repo root | user config — with carve-outs below |
| User | `~/.codex/config.toml` | built-in defaults |

**Project carve-outs.** A project `.codex/config.toml` **cannot override**: model provider / auth settings, notifications, profile selection, or telemetry. Those keys are read only from the user (or managed) layer; in a project file they are silently ignored. Don't debug "my repo config isn't applying" before checking this list.

**requirements.toml** is enterprise-only and carries keys valid nowhere else — notably `allow_managed_hooks_only`, which restricts the hooks engine to managed hooks (see `hooks.md`).

`$CODEX_HOME` (default `~/.codex`) relocates the whole user tree: config.toml, overlay files, hooks.json, agents/, AGENTS.md.

## BREAKING: profiles removed in v0.134.0 (May 26, 2026)

`[profiles.<name>]` tables and the top-level `profile = "<name>"` key were **removed** — a config.toml that still contains either **fails at startup** (issue #24858). There is no deprecation grace; v0.133.x was the last release that read them.

Replacement — standalone overlay files:

```
$CODEX_HOME/work.config.toml      # ONLY the keys that differ from base config
codex --profile work              # base config.toml + overlay, overlay wins
```

Migration recipe:

1. For each `[profiles.work]` table, create `$CODEX_HOME/work.config.toml` and move the table body in as **top-level keys** (drop the table header).
2. Delete every `[profiles.*]` table from config.toml.
3. Delete any top-level `profile = "..."` line; select overlays per-invocation with `codex --profile <name>` instead.

The deterministic lane flags residue as `codex-legacy-profile` (error):

```bash
bash scripts/validate.sh <dir-containing-config.toml> --json
```

## Model keys

| Key | Values / type | Notes |
|---|---|---|
| `model` | string | Model slug |
| `model_provider` | string | Id of a `[model_providers.<id>]` table; user-layer only |
| `model_reasoning_effort` | `minimal` \| `low` \| `medium` \| `high` \| `xhigh` | |
| `model_verbosity` | string | Output verbosity |
| `model_context_window` | int | Override the assumed context window |
| `model_instructions_file` | path | Replaces `experimental_instructions_file` — the old key is **deprecated**; rename it |
| `[model_providers.<id>]` | table | Custom providers: base URL, auth env var, wire API |

## Approval and sandbox

| Key | Values |
|---|---|
| `approval_policy` | `untrusted` \| `on-request` \| `never` |
| `sandbox_mode` | `read-only` \| `workspace-write` \| `danger-full-access` |

`workspace-write` is tuned via `[sandbox_workspace_write]`:

| Key | Type | Effect |
|---|---|---|
| `writable_roots` | array of paths | Extra writable directories beyond the workspace |
| `network_access` | bool | Allow network from inside the sandbox |
| `exclude_slash_tmp` | bool | Drop `/tmp` from the writable set |
| `exclude_tmpdir_env_var` | bool | Drop `$TMPDIR` from the writable set |

Pairing guidance lives in the SKILL.md decision rules.

## [features]

Toggle with `codex features enable|disable <name>` or edit the table directly.

| Feature | Status (v0.139) | Default |
|---|---|---|
| `multi_agent` | stable | on |
| `unified_exec` | stable | on |
| `shell_snapshot` | stable | on |
| `undo` | stable | off |
| `memories` | — | off |
| `network_proxy` | experimental | off |
| `prevent_idle_sleep` | experimental | off |

## [tools]

| Key | Values | Notes |
|---|---|---|
| `web_search` | `disabled` \| `cached` \| `live` | The legacy boolean form (`web_search = true`) is **deprecated** |
| `view_image` | bool | Allow the agent to read images |

`[tools.web_search]` sub-table: `context_size`, `allowed_domains`, `location`.

## [otel]

`exporter = "none" | "otlp-http" | "otlp-grpc"` — telemetry export. User/managed layer only (telemetry is a project carve-out).

## MCP servers — [mcp_servers.<name>]

One table per server; two transports:

| Transport | Keys |
|---|---|
| stdio | `command`, `args`, `env` (inline map), `env_vars` (pass-through names), `cwd` |
| streamable HTTP | `url`, `bearer_token_env_var`, `http_headers`, `env_http_headers` |

Per-server knobs (either transport):

| Key | Default | Notes |
|---|---|---|
| `enabled` | true | Disable without deleting |
| `required` | false | **Fail startup** if the server is unreachable — set for load-bearing servers so failures surface at launch, not mid-task |
| `startup_timeout_sec` | 10 | |
| `tool_timeout_sec` | 60 | |
| `enabled_tools` / `disabled_tools` | — | Allow/deny lists of tool names |
| `default_tools_approval_mode` | — | Per-server approval default for tool calls |

Management: `codex mcp add`, `codex mcp login` (OAuth), `/mcp` in the TUI. OAuth callback overrides: top-level `mcp_oauth_callback_port` / `mcp_oauth_callback_url`.

## Sources

- OpenAI, *Config reference* — [developers.openai.com/codex/config-reference](https://developers.openai.com/codex/config-reference). Verified 2026-06-09 (Codex CLI v0.139.0).
- OpenAI, *Advanced config* — layering, carve-outs, requirements.toml, overlays — [developers.openai.com/codex/config-advanced](https://developers.openai.com/codex/config-advanced). Verified 2026-06-09.
- OpenAI, *MCP* — [developers.openai.com/codex/mcp](https://developers.openai.com/codex/mcp). Verified 2026-06-09.
- Profiles removal: changelog v0.134.0 (May 26, 2026) + issue #24858. Verified 2026-06-09.
