# plugin-dev

Lean, security-aware authoring kit for **Claude Code** plugins, plus the shared cross-host core (deterministic validation kit, SKILL.md standard, leak audit, cross-host subagent scaffolding) used by its sibling platform plugins. Part of the [`coder-plugins`](..) marketplace.

**Sibling platform plugins** (split out 2026-06): [`cowork-dev`](../cowork-dev) (Claude Cowork), [`cursor-dev`](../cursor-dev), [`codex-dev`](../codex-dev), [`opencode-dev`](../opencode-dev), [`hermes-dev`](../hermes-dev), [`openclaw-dev`](../openclaw-dev). Each owns its platform's formats and validators; this plugin owns Claude Code and everything platform-independent.

## Why another plugin-dev?

Anthropic ships a [`plugin-dev`](https://github.com/anthropics/claude-plugins-official) (≈22k lines, v0.1.x). It's comprehensive but heavy and predates several 2026 surfaces. This one is positioned as:

- **2026-current** — covers the new hook events (`PostToolUseFailure`, `PostToolBatch`, `PermissionRequest`, `StopFailure`, `Notification`, `UserPromptExpansion`, `CwdChanged`, `FileChanged`, `SubagentStart/Stop`), new directories (`monitors/`, `bin/`, `.lsp.json`), and new env vars (`${CLAUDE_PLUGIN_DATA}`, `CLAUDE_ENV_FILE`).
- **Lean** — every `SKILL.md` is ≤500 lines; depth lives in `references/`, one level deep. Hard caps enforced at review.
- **Security-aware** — bakes in the description-leak audit pattern (Snyk ToxicSkills 2025, Repello SkillCheck) and prompt-injection screening for any user-controlled content in skills and agents.

If you want maximum coverage with examples, install Anthropic's. If you want a fast on-ramp that won't ship you a leaky skill, install this.

## Balanced by design — the determinism boundary

Plugin work splits cleanly into two lanes, and this plugin keeps them apart instead of asking an LLM to do everything:

- **Deterministic lane → bash scripts.** Anything decidable by a rule — JSON/YAML parse, required fields, `name`↔directory match, enum/whitelist checks (model, color, hook events, MCP transport), line/char caps, reference nesting, `${CLAUDE_PLUGIN_ROOT}` usage, the Stop-loop guard, `$ARGUMENTS` quoting, plaintext-secret detection — is checked by `scripts/`, fast and reproducibly, emitting a shared JSON finding contract.
- **Semantic lane → the LLM.** Judgment calls — confirming a description leak and rewriting it, prompt-injection risk, whether a description will actually trigger, design coherence, model-tier fit — stay with the skills and agents, which **consume** the script output rather than re-deriving the rules.

The validator agent runs the suite, reports its findings verbatim, then adds only the judgment layer. Creation works the same way: scaffolders generate guaranteed-valid structure; you (the LLM) write the content. See [`scripts/README.md`](scripts/README.md) for the contract and how to extend it.

### Deterministic suite (`scripts/`)

| Script | Does |
|---|---|
| `validate-plugin.sh <root> [--json]` | Orchestrator — discovers components, runs each per-domain validator, merges findings, prints one verdict. The single entry point. |
| `validate-{manifest,skill,command,agent,hooks,mcp,settings}.sh` | Per-domain validators; each emits the shared JSON contract and a human report. |
| `scaffold-{plugin,skill,command,hook}.sh` | Generate valid skeletons (correct frontmatter/layout), idempotent, self-validating. |
| `lib/findings.sh` | Shared finding accumulator + renderer — the one place the JSON contract lives. |

```bash
# deterministic gate (fast, free, reproducible)
bash scripts/validate-plugin.sh path/to/plugin --json | jq .
# scaffold a component, guaranteed to pass the gate
bash scripts/scaffold-skill.sh path/to/plugin my-skill
```

### Make another plugin balanced — the determinism kit

The same boundary is portable. The validators above check *plugin structure*
(plugin-dev's domain). A different plugin has its **own** mechanical work — its
configs, its invariants — that deserves the same treatment. The kit vendors a
self-contained deterministic lane into any plugin:

- `/refactor-plugin <path>` — survey a plugin, classify its work, vendor the kit, generate its domain validators, and rewire its agents/commands to run them. Brownfield.
- `/create-plugin` — vendors the kit into new plugins so they're balanced from birth.
- `determinism-boundary` skill — teaches the script-vs-judgment split (used by both).
- `scripts/install-kit.sh <plugin>` + `scripts/scaffold-validator.sh <scripts-dir> <domain>` — the deterministic primitives; each target gets `lib/findings.sh` (the shared contract, verbatim) + a generic `validate.sh` orchestrator + its own `validate-<domain>.sh` files.

Structure validation stays plugin-dev's external job; the kit gives a plugin its
*domain* lane on the same JSON contract.

## Installation

```bash
/plugin marketplace add sureserverman/coder-plugins
/plugin install plugin-dev@coder-plugins
```

## Components

### Skills (13)

| Skill | Triggers when you ask |
|---|---|
| `plugin-structure` | "how do I lay out a plugin", "what goes in `.claude-plugin/`", "marketplace.json schema" |
| `determinism-boundary` | "script vs judgment split", "add a deterministic lane", "make this plugin self-validating", "deterministic scripts vs LLM" |
| `skill-development` | "write a skill", "improve this SKILL.md", "skill description triggering" |
| `command-development` | "create a slash command", "command frontmatter", "$ARGUMENTS in commands" |
| `agent-development` | "create a subagent", "agent frontmatter", "model pinning for agents" |
| `hook-development` | "add a hook", "PreToolUse / PostToolUse", "session-end auto-capture", "block dangerous bash" |
| `mcp-integration` | "add an MCP server to my plugin", ".mcp.json", "stdio / SSE / HTTP MCP" |
| `mcp-server-development` | "build a custom MCP server", "MCP tool design", "FastMCP / @modelcontextprotocol/sdk", "MCP Inspector" |
| `plugin-settings` | "add user-configurable settings to my plugin", ".claude/plugins/<name>/" |
| `skill-description-leak-audit` | "audit this skill", "leak-proof my skill", "this skill runs a shortened version of itself", "review skill frontmatter" |
| `skill-best-practices-sync` | "improve my skills", "sync skills with best practices", "what's new in skill authoring", "refresh skills from Karpathy/community advice" |
| `creating-subagents` | "create a subagent that works on Claude Code + Codex + Cursor + OpenCode", "scaffold a cross-host agent", "port this agent to other tools" |
| `skill-workshop` | "what should be a skill", "mine my sessions", "find patterns in my history", "discover skill candidates" — explicit-invocation only (`disable-model-invocation: true`); pairs with the `session-analyzer` agent |

### Agents (4)

| Agent | Model | Tools | Purpose |
|---|---|---|---|
| `plugin-validator` | haiku | Read, Grep, Glob, Bash | Runs the deterministic suite (`scripts/validate-plugin.sh`), reports its findings, then adds the semantic layer (leak confirmation, injection, triggering, design). Read-only. |
| `skill-reviewer` | haiku | Read, Grep, Glob | Description leak-audit + injection scan + best-practice review on a SKILL.md. Read-only. |
| `agent-creator` | sonnet | Write, Read | Generates a new agent file from a brief. |
| `session-analyzer` | haiku | Bash, Read, Write, Grep, Glob | Parses Claude Code session JSONL files into ranked skill candidates. Driven by `skill-workshop`. |

### Commands (2)

- `/create-plugin` — guided flow: discover intent, **scaffold** structure with `scripts/scaffold-*.sh`, write content via the matching skills, dispatch `agent-creator` for each agent, then gate on `scripts/validate-plugin.sh` before a semantic `plugin-validator` pass. Vendors the determinism kit into the new plugin.
- `/refactor-plugin` — make an existing plugin balanced: survey, vendor the kit, generate its domain validators, rewire its agents/commands to consume them.

## Anti-patterns this plugin will catch

- Components placed inside `.claude-plugin/` (only `plugin.json` belongs there).
- `Stop` hooks without a `stop_hook_active` guard (#1 newbie infinite-loop bug).
- SKILL.md `description:` fields that contain executable instructions (description-leak risk — Claude may run a shortened version of the description and skip the body).
- First-person POV in skill descriptions.
- Hook commands with relative paths instead of `${CLAUDE_PLUGIN_ROOT}`.
- PostToolUse hooks that block on error instead of injecting feedback.

## License

MIT
