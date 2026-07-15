---
description: Guided end-to-end Claude Code plugin scaffold — discover intent, draft components, validate.
argument-hint: "[plugin-name] (optional)"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "AskUserQuestion", "Skill", "Agent", "Bash(bash:*)", "Bash(jq:*)", "Bash(find:*)", "Bash(ls:*)", "Bash(mkdir:*)", "Bash(python3:*)", "Bash(test:*)"]
model: inherit
---

# /create-plugin

Scaffolds a new Claude Code plugin under a marketplace directory the user names. Walks the user through the high-leverage decisions, drafts each component using the relevant `plugin-dev:*` skill, dispatches `agent-creator` for any agents, and finishes with a `plugin-validator` pass.

The user invoked this command with: `$ARGUMENTS`

## Determinism boundary

Structure is deterministic — generate it with the `scripts/scaffold-*.sh` tools
(they emit valid frontmatter/layout and self-validate). Content is judgment —
write descriptions and bodies yourself, guided by the matching skill. Validation
is deterministic first (`scripts/validate-plugin.sh`), semantic second (the
`plugin-validator` / `skill-reviewer` agents). Let `${SCRIPTS}` mean
`${CLAUDE_PLUGIN_ROOT}/scripts` below.

## Phase 1 — Discover intent

If `$ARGUMENTS` already names a plugin, use it. Otherwise ask the user (one `AskUserQuestion`):

- What is the plugin name? (kebab-case)
- Where is it going? (target marketplace dir, e.g., `~/dev/coder-plugins/` — must already have a `.claude-plugin/marketplace.json` you can register the new plugin in)
- One-sentence purpose.

Then ask which components to scaffold (multi-select):

- Skills (which domains?)
- Slash commands
- Subagents (read-only? write-capable?)
- Hooks (which events?)
- MCP server bundle?

Then ask the **three paradigm questions** — they decide how the determinism
boundary applies to this plugin (each maps to a later phase; a "no" cleanly skips
that wiring):

- **(a) Will the plugin persist a structured artifact** a consumer reads back (a
  report, a plan, an assessment)? → if yes, Phase 2 gives it a schema version +
  scanner + fixtures (per `plugin-dev:determinism-boundary` →
  `references/tiered-artifacts.md`).
- **(b) Can any skill's effort vary by ~an order of magnitude** with scope
  (research, report generation, a portfolio sweep)? → if yes, Phase 3 gives that
  skill depth tiers (`references/depth-tiers.md`).
- **(c) Does any skill do heavy non-interactive evidence-gathering** (reads many
  files/sources, fans out)? → if yes, Phase 3 extracts it as a dispatched agent
  rather than inlining it in the skill (`references/skill-to-agent.md`).

Don't overplan. The user can add more later. A "no" to all three is common and
correct for a small authoring/review plugin — it just means no artifact lane, no
tiers, no extraction.

## Phase 2 — Foundation (always)

Generate the skeleton deterministically — do not hand-write these files:

```bash
bash "${SCRIPTS}/scaffold-plugin.sh" <marketplace-root> <plugin-name>
```

This writes `.claude-plugin/plugin.json` (version `0.1.0`), a `README.md` stub,
a `LICENSE` copied from a sibling plugin, and self-validates the manifest. Then
**edit the generated `plugin.json`** to fill the `description` (one-line,
third-person), `author` (from the marketplace owner), and `keywords` (3–8
lowercase tags) — that content is yours to write.

Register the plugin in the marketplace's `marketplace.json` `plugins:` array.
Match the existing entries' shape (category, tags, source, strict).

If the plugin will do any mechanical domain work (parsing its configs, checking
invariants) **or persists a structured artifact (discovery answered (a) yes)**,
give it a deterministic lane from birth — vendor the kit (the artifact scanner in
the next paragraph needs `lib/findings.sh`, which the kit vendors):

```bash
bash "${SCRIPTS}/install-kit.sh" <marketplace-root>/<plugin-name>
```

Then, guided by `plugin-dev:determinism-boundary`, add a domain validator per
mechanical slice with `scaffold-validator.sh <plugin>/scripts <domain>` and fill
its checks. Skip the kit only for a plugin with neither mechanical work nor a
persisted artifact.

**If discovery answered (a) yes** (the plugin persists a structured artifact),
the kit's lane also covers the *artifact*: stamp a schema version on it and its
format doc, add a `validate-<artifact>.sh` scanner with per-artifact/per-tier
ceilings on the shared contract, and commit happy + deliberately-broken fixtures
proving each check fires — per `references/tiered-artifacts.md`. Skip if (a) was
no.

## Phase 3 — Components (per user choice)

For each component, **scaffold the structure with a script, then write the content
guided by the matching skill**:

| Component | Scaffold (structure) | Then load (content) |
|---|---|---|
| Skills | `bash "${SCRIPTS}/scaffold-skill.sh" <root> <name>` | `plugin-dev:skill-development` |
| Commands | `bash "${SCRIPTS}/scaffold-command.sh" <root> <name>` | `plugin-dev:command-development` |
| Hooks | `bash "${SCRIPTS}/scaffold-hook.sh" <root> <event> [matcher]` | `plugin-dev:hook-development` |
| Agents | (dispatch `agent-creator`, below) | `plugin-dev:agent-development` |
| MCP | (hand-write `.mcp.json`) | `plugin-dev:mcp-integration` |
| Layout / manifest questions | — | `plugin-dev:plugin-structure` |

Each scaffolder emits valid frontmatter/layout and self-validates; you fill the
`description` (when, not how) and body afterward. Don't hand-create these files —
the scaffolder guarantees they pass the deterministic gate from the start.

For agents specifically: dispatch the `agent-creator` agent (Agent tool,
`subagent_type: agent-creator`) once per agent with a tight brief: target path,
purpose, scope, model preference. Don't write agent files inline — that's
`agent-creator`'s job.

**If discovery answered (b) yes** (a skill's effort varies ~10x with scope), give
that skill depth tiers as you write its body: ask the tier first (one
`AskUserQuestion`, in the skill), confirm scope before assuming, record the tier
in the artifact, and pass it as the dispatch parameter to any agent the skill
uses — per `references/depth-tiers.md`. Skip for a skill whose effort barely
varies.

**If discovery answered (c) yes** (a skill does heavy non-interactive
evidence-gathering), don't inline that work in the skill: keep the interactive
parts (interview, scope confirm) in the skill and **extract the batch work as a
dispatched agent** — add it to the agents list above and dispatch `agent-creator`
for it, pinned to the smallest model that can do the job — per
`references/skill-to-agent.md`. The one hard constraint: anything that must ask
the user stays in the skill (agents cannot run `AskUserQuestion`). Skip if no
skill does isolated batch work.

## Phase 4 — Self-validate (deterministic gate, then semantic)

1. **Deterministic gate** — run the suite directly and fix every error before
   going further:

   ```bash
   bash "${SCRIPTS}/validate-plugin.sh" <plugin-root> --json
   ```

   This is fast, free, and reproducible. Address all `error`-severity findings;
   surface `warn`/`info` to the user.

2. **Semantic pass** — dispatch the `plugin-validator` agent (Agent tool,
   `subagent_type: plugin-validator`) on the plugin root. It re-runs the gate and
   adds judgment-level findings (leak confirmation, injection, triggering,
   design). For each new skill, also run `plugin-dev:skill-reviewer` and triage
   its critical findings.

## Phase 5 — Wrap up

Show the user:

1. The new plugin's tree (`find <plugin-root> -maxdepth 3 -type f | sort`).
2. The validator verdict.
3. Install instructions: `/plugin marketplace add <marketplace-source>` then `/plugin install <plugin-name>@<marketplace-name>`.
4. Suggested next steps (write the README body, add tests for any bash hooks, push to remote when the marketplace has one).

## Defaults you can apply without asking

- `version: 0.1.0` for new plugins.
- `LICENSE` matches the marketplace's existing LICENSE (copy from a sibling plugin).
- `keywords` starts with kebab-case versions of the plugin's domain (the user said "rust", you start with `["rust"]` and ask them to extend).
- Skills and agents get model tier `inherit` and `haiku` respectively unless the user signals otherwise (read-only audits get haiku; write-capable get sonnet — see `agent-creator`'s model decision matrix).

## Anti-patterns to refuse

- Creating a plugin outside an existing marketplace (no `.claude-plugin/marketplace.json` to register in).
- Naming a plugin that already exists in the target marketplace.
- Putting components inside `.claude-plugin/` (only `plugin.json` belongs there — the validator will catch this, but you should preempt it).
- Skipping the validator pass at the end. Even on a fresh scaffold, run it.

## Out of scope

- Publishing the marketplace to GitHub (user does this).
- Pushing commits (user does this).
- Building binaries for `bin/` (user does this).
- Authoring substantive skill or agent content beyond a stub — your job is the scaffold and the wiring; the user fills in domain content.
