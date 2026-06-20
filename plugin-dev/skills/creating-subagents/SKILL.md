---
name: creating-subagents
description: Use when scaffolding a cross-host AI coding subagent. Triggers on "create a subagent", "new agent for claude/codex/cursor/opencode", "multi-platform agent".
---

# creating-subagents

Guide the user through building one subagent definition that lives in four places at once: Claude Code, Codex CLI, Cursor, and OpenCode. The goal is a single source-of-truth core file plus thin per-host wrappers that declare host-specific metadata (tools, sandbox, globs, permissions) and affordances.

If you are a user invoking this skill, tell me the agent name and 2–3 sentences of purpose. I will interview for the rest, scaffold the bundle in the current working directory, and hand back a ready-to-install set of files.

## Why this pattern

Each host's agent system has different strengths and a different config language. Writing four parallel agent files by hand drifts — the Claude Code version gets a fix that never makes it to the Codex TOML. The fix: one `_core.md` holds the identity, operating model, rules, and output schemas; each host file is a thin wrapper with **only** host-specific framing (invocation style, tool list, sandbox mode, globs). A small `build.sh` embeds the core into every wrapper so they stay in lockstep. Adapted from the testing-expert bundle at `/home/user/dev/ai-tools/agents/agents/testing-expert/` — review it before starting if unfamiliar.

## Sibling platform plugins

This skill is the cross-host **scaffolding** workflow — one core, thin wrappers, build/install/verify scripts. Per-platform authoring depth (host-specific idioms, advanced config, debugging) now lives in the sibling plugins: `cursor-dev` (Cursor), `codex-dev` (Codex CLI), `opencode-dev` (OpenCode), and `cowork-dev` (Claude Cowork). Use them when the user wants to go deep on one host; stay here when the job is "one agent, many hosts".

## Hosts without subagents

Hermes Agent and OpenClaw have **no subagent surface** — there is nothing to scaffold for them here. Their unit of reuse is skills (agentskills.io format) and platform plugins. If the user wants this agent's behavior on those hosts, point them at the `hermes-dev` and `openclaw-dev` plugins and consider distilling `_core.md` into a skill instead.

## Do not hardcode the output path

Write the new bundle into the current working directory the user invoked this skill from. A sensible default is `./<agent-name>/`. Ask before writing if the directory already exists.

## When to plan first

For a single bounded agent, go straight to the interview below. Hand off to the `planning-projects` skill first when either: (a) the user wants a **suite** of coordinated agents that share responsibilities, or (b) the agent's house rules / protocols are themselves a research project (e.g. a citation-backed opinionated core where the rulebook needs design before any scaffolding). In both cases, plan the rulebook or suite decomposition with `planning-projects`, then return here to scaffold each agent.

## The interview

Before writing anything, collect:

1. **Name** — lowercase-hyphen identifier. Used as the filename stem across all hosts and as the `name:` / `@<name>` handle.
2. **One-paragraph purpose** — what task this agent owns. Used to derive descriptions.
3. **Trigger phrases / contexts** — what the user types when they need this agent. These get woven into each host's `description` field (routing is description-driven on every platform).
4. **Allowed tool surface** — read-only, edit, bash, web, MCP? This determines Claude Code's `tools:` / `disallowedTools:`, Codex's `sandbox_mode`, Cursor's `readonly`, and OpenCode's `permission:` block. Be specific.
5. **Model preference** — inherit, or a specific size (haiku/sonnet/opus equivalents). Most agents should `inherit`.
6. **Host-specific affordances** — any platform where this agent should behave differently (e.g. "on Cursor auto-attach to test files via globs", "on Codex use workspace-write sandbox").
7. **House rules / output schemas** — the opinionated content. This is the bulk of `_core.md` and the part the user actually cares about.

If the user gave a half-filled brief, restate what you heard and ask only for the gaps.

## Files to produce

```
<agent-name>/
├── _core.md                    # shared identity + rules, wrapped in <!-- CORE:BEGIN --> / <!-- CORE:END -->
├── build.sh                    # embeds _core.md into every host file
├── install-global.sh           # installs to ~/.claude/agents, ~/.codex/agents, ~/.cursor/agents, ~/.config/opencode/agents
├── verify.sh                   # checks installed files exist and shows head of each
├── claude-code/
│   └── <agent-name>.md         # YAML frontmatter + host affordances + <!-- CORE --> marker
├── codex/
│   ├── AGENTS.md               # auto-attach instructions (optional, for repo-scoped use)
│   ├── agents/
│   │   └── <agent-name>.toml   # TOML with developer_instructions = """ <!-- CORE --> """
│   └── prompts/
│       └── <agent-name>.md     # /<agent-name> slash-command prompt
├── cursor/
│   ├── <agent-name>.mdc        # rule file (globs + alwaysApply)
│   └── agents/
│       └── <agent-name>.md     # subagent file (auto-dispatch by description)
└── opencode/
    └── <agent-name>.md         # frontmatter with mode: subagent + permission block
```

You do not have to produce all of these — ask the user which hosts they want. Claude Code + Codex + Cursor + OpenCode is the full set; any subset is fine.

## The core file

`_core.md` is the canonical identity. It must be wrapped like this so `build.sh` can extract it:

```markdown
<!-- CORE:BEGIN -->
## Identity
You are **<agent-name>**, a <role>. <strong stance sentence.>

## Operating model
<how the agent decides what to do — e.g. enters through protocols, phases, or a direct task loop>

## <Protocols / procedures>
<the actual work>

## House rules
<numbered opinions with brief justification — cite sources where helpful>

## Output schemas
<templates the agent emits>

## Safety rails
<what the agent refuses, confirms, or escalates>
<!-- CORE:END -->
```

Explain **why** each rule exists — the agent is smarter when it understands the reasoning, not just the rule.

## Host wrappers

Each wrapper file follows the same shape: host-specific frontmatter → short "Host affordances" section (what this host does better/worse, any invocation notes) → a literal `<!-- CORE -->` marker line where `build.sh` will splice in `_core.md`.

The exact frontmatter schema for each host is in the references:

- **Claude Code** → `references/claude-code-format.md`
- **Codex CLI** → `references/codex-format.md`
- **Cursor** → `references/cursor-format.md`
- **OpenCode** → `references/opencode-format.md`

Do not guess fields — read the relevant reference. They cover required vs. optional fields, tool-restriction mechanisms, sandbox/permission models, and file locations.

## Design principles

See `references/subagent-best-practices.md` for the full writeup. The short version:

1. **Single responsibility.** One agent = one clear job. If the description needs "and also…", split it.
2. **Description is the router.** On every host, description is what decides whether the agent gets delegated to. Include the trigger phrases, the domain keywords, and the stance ("opinionated: …") so routing is sharp. Keep it under ~400 chars.
3. **Minimal tool surface.** Grant the smallest set that gets the job done. Read-only agents should be read-only on every host — not just one.
4. **Explain the why.** A rule with a short justification survives edge cases; a bare MUST does not.
5. **Host-specific affordances live in the wrapper, not the core.** If it references `TaskCreate`, `apply_patch`, `.mdc`, or `permission:` blocks, it belongs in the host file.
6. **No proprietary framework names in the core.** The core should read identically on all four platforms.

## Writing the build script

`build.sh` walks a list of host files and replaces the `<!-- CORE -->` marker (or the previous `<!-- CORE:BEGIN -->…<!-- CORE:END -->` block) with the current contents of `_core.md`. Idempotent — running twice is a no-op. A working version is in `assets/templates/build.sh`; copy it and adjust the `BUILDS=(…)` list to match whichever host files you produced.

## Writing the install/verify scripts

- `install-global.sh` — `install -d` the target dirs, `install -m 0644` each built file. Templates in `assets/templates/install-global.sh`.
- `verify.sh` — `test -f` each installed path, optionally `head -n 5` to sanity-check. Template in `assets/templates/verify.sh`.

## Scaffold helper

`scripts/scaffold.sh <agent-name> [<target-dir>]` creates the directory tree and drops templated starter files with `<AGENT_NAME>` placeholders. Use it as a first step, then fill in the content. It does not overwrite existing files.

## Workflow

1. Interview the user on the seven items above.
2. Run `scripts/scaffold.sh <name>` from the current working directory. Review the dropped tree.
3. Fill in `_core.md` with the user's actual house rules and output schemas.
4. Fill in each host wrapper's frontmatter and Host-affordances section. Use the reference files to get fields right.
5. Run `./build.sh`. Confirm the `_core.md` body is now embedded in every host file.
6. Offer to run `./install-global.sh` (ask first — it writes to `~/.claude`, `~/.codex`, `~/.cursor`, `~/.config/opencode`).
7. Run `./verify.sh`.
8. Tell the user the invocation syntax per host (e.g. "In Claude Code: `Use the <name> agent to …`; in Cursor: `@<name> …`; in Codex: `spawn <name> …`; in OpenCode: `@<name>`").

## When to split this across multiple agents

If the user describes two distinct jobs (e.g. "review my code AND run my tests"), propose two agents. Each with one description, one tool surface, one set of house rules. Routing gets sharper and each agent stays under the context budget its host prefers.

## Things to avoid

- Copying `_core.md` content into a wrapper instead of using the `<!-- CORE -->` marker — drift follows.
- Encoding tool names from one host into another host's file (Claude Code's `Read, Grep` list is not Codex's `sandbox_mode`).
- Writing "ALWAYS / NEVER / MUST" walls without justification. Reframe as: rule, then why.
- Producing an `AGENTS.md` alongside a Codex `agents/<name>.toml` without deciding which is authoritative. Usually pick one per project: `AGENTS.md` for single-agent repos, `agents/<name>.toml` for multi-agent.

## Delegation (Claude Code only)

> **Skip this section unless you are Claude Code.** The Agent tool with
> `subagent_type:` parameters is a Claude Code feature. Codex, Cursor, Gemini,
> OpenCode, and other hosts do not have it — run the full workflow yourself
> instead.

Once the agent's name, purpose, tool list, target hosts, and authoritative
format are decided, scaffolding the files is a Sonnet-tier code-generation
job. If you are on Opus, delegate the write phase to the `code-generator`
subagent (model: sonnet) via the Agent tool with `subagent_type: code-generator`.
Give it:

- the name, one-sentence purpose, target hosts (Claude Code / Codex / Cursor /
  OpenCode), and tool/permission list,
- the `<!-- CORE -->` marker convention so shared content doesn't get copied
  into each wrapper,
- the per-host file layouts (`.claude/agents/<name>.md`,
  `.cursor/rules/<name>.mdc`, `agents/<name>.toml` or `AGENTS.md`),
- the constraint that tool-name translation across hosts stays faithful (no
  encoding Claude Code's `Read, Grep` list into a Codex `sandbox_mode` field).

Keep the host/authority decisions, the design of the agent's actual behavior,
and any review of host-specific idioms in this session.
