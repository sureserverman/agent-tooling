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

Plugin work splits into **three lanes**, and this plugin keeps them apart instead of asking an LLM to do everything:

- **Deterministic lane → bash scripts.** Anything decidable by a rule — JSON/YAML parse, required fields, `name`↔directory match, enum/whitelist checks (model, color, hook events, MCP transport), line/char caps, reference nesting, `${CLAUDE_PLUGIN_ROOT}` usage, the Stop-loop guard, `$ARGUMENTS` quoting, plaintext-secret detection — is checked by `scripts/`, fast and reproducibly, emitting a shared JSON finding contract. This lane also covers the **artifacts a plugin persists**: a plugin that writes a structured document a consumer reads back gets a schema version, a scanner with per-artifact/per-tier ceilings, and fixtures.
- **Judgment-interactive lane → skills / commands (main loop).** Anything that talks to the user or needs the conversation — an interview, a confirm-before-assume step, an approval gate — stays here. A dispatched agent cannot run `AskUserQuestion`, so interactive judgment is never extractable.
- **Judgment-batch-isolated lane → dispatched agents.** Heavy, self-contained judgment — reading many files/sources, fan-out, or work that wants a cheaper pinned model — is carved into an agent, but only on a concrete benefit (context isolation, fan-out, model pinning, tool scoping, reuse), never merely because it's possible.

The validator agent runs the suite, reports its findings verbatim, then adds only the judgment layer. Creation works the same way: scaffolders generate guaranteed-valid structure; you (the LLM) write the content. The `determinism-boundary` skill teaches all three lanes; four references go deeper — [`refactor-recipe.md`](skills/determinism-boundary/references/refactor-recipe.md) (brownfield walk-through), [`skill-to-agent.md`](skills/determinism-boundary/references/skill-to-agent.md) (when to carve a skill into an agent), [`tiered-artifacts.md`](skills/determinism-boundary/references/tiered-artifacts.md) (schema-versioning persisted artifacts), and [`depth-tiers.md`](skills/determinism-boundary/references/depth-tiers.md) (depth tiers for elastic skills). See [`scripts/README.md`](scripts/README.md) for the contract and how to extend it.

### Deterministic suite (`scripts/`)

| Script | Does |
|---|---|
| `validate-plugin.sh <root> [--json]` | Orchestrator — discovers components, runs each per-domain validator, merges findings, prints one verdict. The single entry point. |
| `validate-{manifest,skill,command,agent,hooks,mcp,settings}.sh` | Per-domain validators; each emits the shared JSON contract and a human report. |
| `curator-{inventory,usage,scan}.sh` | Read-only skill-lifecycle scan lane (driven by `skill-curator`): enumerate the estate, extract last-triggered from session history, classify fresh/stale/archive-candidate/pinned/report-only. |
| `curator-archive.sh` | The only mutating curator script — move-only snapshot / archive / restore (never deletes). |
| `validate-curator.sh <root>` | Validates the curator's runtime artifacts (`.curator-pins`, `.archive/` layout) on the shared contract; invoked by the skill, not the orchestrator. |
| `validate-evalset.sh <cases.yaml>` | Validates a skill eval set (`skill-eval`); YAML→JSON via python3+pyyaml, jq on the shared contract. |
| `evalset-mine.sh <skill>` | Drafts `source: session` eval cases from history (wraps `curator-usage.sh` as the usage gate). |
| `skill-eval-gate.sh <precheck\|verdict\|compare>` | The deterministic half of `skill-eval`: mechanical prechecks (15 KB ceiling, valid eval set), threshold verdict, and the rewrite baseline-comparison. |
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
- `determinism-boundary` skill — teaches the three-way split (script / skill-interactive / agent-batch-isolated), plus artifact schemas and depth tiers (used by both).
- `scripts/install-kit.sh <plugin>` + `scripts/scaffold-validator.sh <scripts-dir> <domain>` — the deterministic primitives; each target gets `lib/findings.sh` (the shared contract, verbatim) + a generic `validate.sh` orchestrator + its own `validate-<domain>.sh` files.

Structure validation stays plugin-dev's external job; the kit gives a plugin its
*domain* lane on the same JSON contract.

## Installation

```bash
/plugin marketplace add sureserverman/coder-plugins
/plugin install plugin-dev@coder-plugins
```

## Components

### Skills (14)

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
| `skill-curator` | "curate my skills", "which skills are stale", "clean up my skills", "archive unused skills" — explicit-invocation only; the decay half of the skill lifecycle (staleness scan → keep/patch/consolidate/archive, archive-never-delete); pairs with the `curator-*.sh` scan lane |
| `skill-eval` | "evaluate this skill", "does this skill work", "score my skill", "skill eval" — explicit-invocation only; runs eval cases, judges them against rubrics with the separate `skill-judge` agent, gates on hard thresholds (≤15 KB, per-case pass), rewrite→eval→compare loop |

### Agents (5)

| Agent | Model | Tools | Purpose |
|---|---|---|---|
| `plugin-validator` | haiku | Read, Grep, Glob, Bash | Runs the deterministic suite (`scripts/validate-plugin.sh`), reports its findings, then adds the semantic layer (leak confirmation, injection, triggering, design). Read-only. |
| `skill-reviewer` | haiku | Read, Grep, Glob | Description leak-audit + injection scan + best-practice review on a SKILL.md. Read-only. |
| `agent-creator` | sonnet | Write, Read | Generates a new agent file from a brief. |
| `session-analyzer` | haiku | Bash, Read, Write, Grep, Glob | Parses Claude Code session JSONL files into ranked skill candidates. Driven by `skill-workshop`. |
| `skill-judge` | sonnet | Read, Grep, Glob | Scores one skill-eval case against its rubric from the case-runner transcript — evidence per criterion, no bare pass/fail. Driven by `skill-eval`. |

### Commands (2)

- `/create-plugin` — guided flow: discover intent, **scaffold** structure with `scripts/scaffold-*.sh`, write content via the matching skills, dispatch `agent-creator` for each agent, then gate on `scripts/validate-plugin.sh` before a semantic `plugin-validator` pass. Vendors the determinism kit into the new plugin. Discovery asks three paradigm questions — does the plugin persist an artifact (→ schema + scanner + fixtures), can a skill's effort vary ~10x (→ depth tiers), does a skill do heavy non-interactive evidence-gathering (→ extract it as an agent) — each with a clean skip for the common "no".
- `/refactor-plugin` — make an existing plugin balanced: survey each action into the three lanes (mechanical / judgment-interactive / judgment-batch-isolated), vendor the kit, generate its domain validators, add schema + scanner + fixtures for any persisted artifact and depth tiers for any elastic skill, and rewire its agents/commands — carving batch judgment into agents only on a concrete benefit.

## The skill lifecycle

Beyond authoring a skill, plugin-dev covers its whole life — **discover → build →
measure → maintain**:

- **Discover** — `skill-workshop` (+ `session-analyzer`) mines your session
  history for skill candidates, classified by four trigger heuristics
  (`user-correction`, `error-resolved`, `nonobvious-workflow`,
  `recurring-toolchain`).
- **Build** — `skill-development`.
- **Measure** — `skill-eval` (+ `skill-judge`) runs a skill against rubric-scored
  eval cases with a separate judge and hard gates, and gates rewrites against a
  baseline so an edit can't silently regress.
- **Maintain** — `skill-curator` finds stale/unused skills and keeps/patches/
  consolidates/archives them, archive-never-delete, with snapshots and pinning.

`skill-curator`, `skill-eval`, and `skill-workshop` are explicit-invocation only.
**Full guide: [`docs/skill-lifecycle.md`](./docs/skill-lifecycle.md).**

## Anti-patterns this plugin will catch

- Components placed inside `.claude-plugin/` (only `plugin.json` belongs there).
- `Stop` hooks without a `stop_hook_active` guard (#1 newbie infinite-loop bug).
- SKILL.md `description:` fields that contain executable instructions (description-leak risk — Claude may run a shortened version of the description and skip the body).
- First-person POV in skill descriptions.
- Hook commands with relative paths instead of `${CLAUDE_PLUGIN_ROOT}`.
- PostToolUse hooks that block on error instead of injecting feedback.

## License

MIT
