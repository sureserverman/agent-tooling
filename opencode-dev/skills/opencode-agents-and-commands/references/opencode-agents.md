# OpenCode agents (verified 2026-06-09, OpenCode v1.16)

## Locations

| Scope | Path |
|---|---|
| Project | `.opencode/agents/<name>.md` |
| Global | `~/.config/opencode/agents/<name>.md` |
| JSON | `"agent"` key in `opencode.json` |

- **Filename = agent name** (`reviewer.md` → agent `reviewer`).
- The markdown **body is the system prompt**; frontmatter is the config.
- `opencode agent create` scaffolds interactively. Verify it wrote into
  **plural `agents/`** — issue #14410 had the scaffolder writing `agent/`
  while the loader expected `agents/`, producing a silently-missing agent.
- Agents were called **"modes"** in 0.x; a legacy `modes/` directory is still
  acknowledged but should never be authored anew.

## Frontmatter fields

| Field | Required | Meaning |
|---|---|---|
| `description` | **yes** | what the agent is for — for subagents this is the auto-dispatch trigger; write third person, specific |
| `mode` | no | `primary` \| `subagent` \| `all` (default behavior: usable as subagent) |
| `model` | no | `provider/model-id` (e.g. `anthropic/claude-sonnet-4-5`); inherits the session model if unset |
| `prompt` | no | path to a prompt file — alternative to the markdown body |
| `temperature` | no | sampling temperature |
| `top_p` | no | nucleus sampling |
| `steps` | no | max agentic iterations before the agent must stop |
| `permission` | no | per-tool `"ask"\|"allow"\|"deny"` map — see below |
| `tools` | **deprecated** | boolean enable/disable map — migrate to `permission` |
| `disable` | no | `true` to turn the agent off without deleting it |
| `hidden` | no | hide from the TUI cycle/selector |
| `color` | no | TUI accent color for the agent |

## Modes

- **`primary`** — Tab-cycled in the TUI; the user drives it directly.
  Built-ins: **`build`** (default, full permissions) and **`plan`**
  (restricted — read/analyze, no edits). **Define an agent with the same name
  to override a built-in** (e.g. tighten `build`'s bash permissions).
- **`subagent`** — invoked by `@name` in the prompt, or auto-dispatched by a
  primary when the work matches its `description`. Runs in its own context
  window; results come back as a task result.
- **`all`** — both.

## The permission model (replaces `tools`)

Values: `"ask"` (prompt the user), `"allow"`, `"deny"`. Keys:

`read`, `edit`, `glob`, `grep`, `list`, `bash`, `task`, `webfetch`,
`external_directory` (touching files outside the worktree).

`bash` accepts either a single value or a **glob map** over command lines:

```yaml
---
description: Reviews diffs for correctness and style; never edits files
mode: subagent
model: anthropic/claude-sonnet-4-5
temperature: 0.1
permission:
  edit: deny
  webfetch: deny
  bash:
    "*": ask
    "git status *": allow
    "git diff *": allow
    "git log *": allow
---
You are a meticulous code reviewer…
```

Glob-map rules: most-specific match wins; always include a `"*"` fallback —
otherwise unmatched commands fall through to defaults you didn't choose.

**Migrating from `tools`:** `tools: {bash: false}` → `permission: {bash: deny}`;
`tools: {webfetch: true}` → `permission: {webfetch: allow}`. The boolean map
still parses but is deprecated; opencode-dev's validator warns
(`opencode-tools-deprecated`).

## JSON form

Everything above also works under the `"agent"` key in `opencode.json` —
useful when an org-managed config layer must inject or restrict agents:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "reviewer": {
      "description": "Reviews diffs for correctness; never edits",
      "mode": "subagent",
      "permission": { "edit": "deny", "bash": { "*": "ask", "git diff *": "allow" } }
    }
  }
}
```

JSON-config agents merge with file-based agents across the config layers
(later layers override same-named keys).

## Checklist

1. Plural `agents/` dir; filename = intended name.
2. `description` present, third-person, dispatch-worthy.
3. `permission` (not `tools`); bash glob map has a `"*"` fallback.
4. `mode` matches intent — `primary` only for agents the user drives.
5. Overriding `build`/`plan`? Same filename, document why in the body.
6. Run opencode-dev's `scripts/validate.sh` — frontmatter parse
   (`opencode-frontmatter`), deprecated `tools` (`opencode-tools-deprecated`),
   singular dir (`opencode-singular-dir`).

Source: [opencode.ai/docs/agents](https://opencode.ai/docs/agents).
Verified 2026-06-09.
