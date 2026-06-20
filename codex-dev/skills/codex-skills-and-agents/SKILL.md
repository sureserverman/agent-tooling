---
name: codex-skills-and-agents
description: Use when authoring skills or subagents for OpenAI Codex. Triggers on "Codex skill", "$skill in Codex", "agents/openai.yaml", "Codex subagent", "Codex custom agent TOML", "migrate Codex prompts to skills", "Codex skill discovery", "custom prompts deprecated".
---

# codex-skills-and-agents

Codex has supported skills since CLI v0.69.0 (December 10, 2025), implementing the **agentskills.io** standard — the same `SKILL.md` format Claude Code and Cursor read. What's Codex-specific: the discovery order, an optional `agents/openai.yaml` sidecar, a hard catalog budget, the deprecation of custom prompts in favor of skills, and a one-TOML-per-agent custom subagent format that is nothing like Claude Code's markdown agents.

All facts verified 2026-06-09 against developers.openai.com/codex (skills, subagents, changelog), Codex CLI v0.139.0.

## Reference map

| When you need… | Read first |
|---|---|
| SKILL.md layout, `agents/openai.yaml` fields, discovery order, invocation, catalog budget, per-skill disable, prompt migration | `references/skills.md` |
| Custom agent TOML fields, `[agents]` runtime config, spawning behavior, `/agent` inspection | `references/subagents.md` |

## The shape in 30 seconds

**Skill** — a directory with `SKILL.md` (YAML frontmatter: `name` + `description`) plus optional `scripts/`, `references/`, `assets/`, and a Codex-only `agents/openai.yaml` sidecar:

```yaml
# agents/openai.yaml — all optional, all Codex-specific
interface:
  display_name: Release Helper
  icon: rocket
  brand_color: "#0f766e"
policy:
  allow_implicit_invocation: false   # explicit-only: fires on $skill-name, never on description match
dependencies:
  tools:
    - type: mcp
      # the MCP server this skill expects
```

**Custom agent** — ONE TOML file per agent in `~/.codex/agents/` (personal) or `.codex/agents/` (repo). Required: `name`, `description`, `developer_instructions`. Everything else inherits from the parent session if omitted.

## Decision rules

### Skill, custom prompt, or subagent?

| You want… | Build |
|---|---|
| Reusable knowledge/workflow that fires on matching requests | **Skill** |
| A parameterized text macro | **Skill** — custom prompts (`~/.codex/prompts/*.md`) are **DEPRECATED**; migrate |
| Delegated work in a separate context with its own model/sandbox/tools | **Custom agent** (TOML) |
| A skill that must never auto-fire | Skill + `policy.allow_implicit_invocation: false` in `agents/openai.yaml` |

### Where should the skill live?

Discovery order (first match wins for a given name; **`~/.claude/skills` is NOT read**):

1. `<cwd>/.agents/skills` — current working directory
2. `$REPO_ROOT/.agents/skills` — repo root
3. `~/.agents/skills` — personal, cross-project
4. `/etc/codex/skills` — admin/machine-wide
5. Bundled system skills (`~/.codex/skills/.system` — e.g. `$skill-creator`, `plan`)

Symlinked skill folders are followed — keep one canonical copy and symlink it where needed. Repo-shared skills go in `$REPO_ROOT/.agents/skills`; yours-only skills in `~/.agents/skills`.

### Will the skill actually get selected?

Two budget facts shape description writing:

- The **catalog is capped at ~2% of the context window (~8,000 chars)** — every skill's name + description competes for that space. Long descriptions crowd out siblings; keep descriptions tight and front-load trigger phrases.
- The **body loads only on selection** — depth is free, so push detail into the body and `references/`, never into the description.

Invocation: explicit via `$skill-name` or the `/skills` picker; implicit via description match. If implicit firing is wrong for the skill (destructive operations, niche workflows), set `allow_implicit_invocation: false`.

### Migrating custom prompts to skills

Custom prompts (`~/.codex/prompts/*.md`, invoked `/prompts:name`) are **deprecated but still functional**. Their limits: top-level files only (no nesting), positional `$1`–`$9`, `$ARGUMENTS`, named uppercase `$KEY=value` interpolation — and a known regression (issue #15941) where prompts vanish from the slash menu. Migration per prompt:

1. Create `~/.agents/skills/<name>/SKILL.md`; move the prompt body into the skill body.
2. Replace `$1`–`$9` / `$ARGUMENTS` interpolation with prose: describe what the user supplies and let the model read it from the request.
3. Write a third-person `description` with trigger phrases so it can also fire implicitly.
4. Delete the prompt file once the skill is confirmed in `/skills`.

### When is a custom agent worth it?

Subagents went GA in v0.115.0 (March 16, 2026); the multi-agent v2 runtime is rolling out across v0.137–0.139. Key behavioral fact: **Codex spawns subagents only when explicitly asked** — a custom agent is not an auto-router, it's a named delegate the user (or a skill) invokes deliberately. Inspect running threads with `/agent`.

Define one TOML per agent with `name`, `description`, `developer_instructions` (all required — the validator errors on any missing). Pin `model`, `model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, or `skills.config` only when the agent genuinely needs to differ from the parent; omitted keys inherit. Runtime limits live in `[agents]` in config.toml: `max_threads` (default 6), `max_depth` (default 1 — subagents don't spawn sub-subagents by default), `job_max_runtime_seconds`.

## Deterministic gate

```bash
bash scripts/validate.sh path/to/artifact --json | jq .
```

Checks `skills/*/SKILL.md` frontmatter (`name` + `description` present) and every agent TOML under `agents/` (parses, has `name` + `description` + `developer_instructions`). Fix errors before shipping.

## Anti-patterns this skill catches

- New automation written as a custom prompt — deprecated; write a skill.
- Skills installed to `~/.claude/skills` and expected to load in Codex — Codex reads `~/.agents/skills`, not Claude's tree.
- An 800-char skill description in a catalog that's capped at ~8,000 chars total — starves sibling skills; tighten it.
- A destructive workflow left implicitly invocable — set `allow_implicit_invocation: false`.
- Agent TOML missing `developer_instructions` — required; the agent won't behave as intended (and the validator errors).
- A directory of agent TOMLs merged into one file — it's ONE TOML per agent.
- Designs assuming Codex auto-delegates to subagents — it spawns them only on explicit request.

## Sources

- OpenAI, *Codex skills* — format, `agents/openai.yaml`, discovery, invocation, catalog budget, prompt deprecation ([developers.openai.com/codex/skills](https://developers.openai.com/codex/skills)). Verified 2026-06-09 (Codex CLI v0.139.0).
- OpenAI, *Codex subagents* — custom agent TOML, `[agents]` config, spawning, `/agent` ([developers.openai.com/codex/subagents](https://developers.openai.com/codex/subagents)). Verified 2026-06-09.
- OpenAI, *Codex changelog* — skills v0.69.0 (Dec 10 2025), subagents GA v0.115.0 (Mar 16 2026), multi-agent v2 v0.137–0.139 ([developers.openai.com/codex/changelog](https://developers.openai.com/codex/changelog)). Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
