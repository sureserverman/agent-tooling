# Cursor skills — discovery, frontmatter, progressive loading, commands migration (verified 2026-06-09, Cursor 3.7)

Cursor implements the **agentskills.io** open Agent Skills standard. A skill
is a directory containing `SKILL.md` plus optional supporting material; the
agent sees every skill's name + description up front and loads the body only
when relevant (progressive disclosure).

## Discovery paths

Project-level (workspace):

- `.agents/skills/` — the standard's tool-agnostic location
- `.cursor/skills/` — Cursor's own location; **nested** `.cursor/skills/`
  dirs in subdirectories also work (monorepos)
- `.claude/skills/` — **legacy compat**: Claude Code project skills load as-is
- `.codex/skills/` — legacy compat for Codex skills

User-level (home):

- `~/.agents/skills/`
- `~/.cursor/skills/`
- `~/.claude/skills/` and `~/.codex/skills/` (compat)

Practical consequence: a team already running Claude Code skills gets them in
Cursor for free — don't duplicate trees, and don't be surprised when a
`.claude/skills/` skill fires inside Cursor. For new cross-tool skills prefer
`.agents/skills/` (the standard location every implementing tool reads).

## SKILL.md frontmatter

Standard fields plus Cursor extensions:

```yaml
---
name: deploy-check          # MUST equal the folder name — mismatch breaks discovery
description: Use when validating a deploy before shipping. Triggers on "check the deploy", "pre-ship validation".
paths: "**/*.tf, deploy/**" # Cursor-specific — see below
disable-model-invocation: false
metadata:
  author: acme
---
```

- **`name`** — must equal the containing folder name. cursor-dev's validator
  errors on mismatch (`cursor-skill-name-mismatch`).
- **`description`** — the trigger. Third person, situation-rich, no workflow
  steps (the description is always in context; procedure belongs in the
  body — see plugin-dev's `skill-description-leak-audit`).
- **`paths`** (Cursor-specific) — comma-separated globs, e.g.
  `"**/*.tsx, **/*.test.ts"`. The skill is only **visible to the model** when
  matching files are in play — glob-scoped visibility, cutting skill-list
  noise in big setups. `globs` is accepted as a **legacy fallback** for the
  same behavior; write `paths` in new skills.
- **`disable-model-invocation: true`** — the skill never auto-fires; the user
  invokes it explicitly as `/skill-name`. This is the modern replacement for
  commands.
- **`metadata`** — free-form map for author/version bookkeeping.

## Directory layout and progressive loading

```
.cursor/skills/deploy-check/
├── SKILL.md          # always: name+description visible; body loaded on trigger
├── references/       # depth — loaded only when SKILL.md points at them
│   └── rollback.md
├── scripts/          # executables the skill calls
│   └── preflight.sh
└── assets/           # templates, fixtures
```

Loading is staged: metadata always; body on trigger; `references/`, `scripts/`
and `assets/` only when the body directs the agent there. So: keep SKILL.md
lean and put depth in `references/` (one level — the body must name each file
for it to be reachable).

## Built-in skill tooling

- **`/create-skill`** — scaffolds a new skill interactively (folder, SKILL.md,
  frontmatter).
- **`/migrate-to-skills`** — converts legacy surfaces to skills:
  - `.cursor/commands/*.md` and `~/.cursor/commands/` → skills with
    `disable-model-invocation: true`;
  - **dynamic rules** (`alwaysApply: false`, no `globs` — i.e.
    description-triggered) → ordinary auto-firing skills;
  - `alwaysApply: true` rules and glob-scoped rules **stay rules**.

## Commands are soft-deprecated

`.cursor/commands/*.md` (project) and `~/.cursor/commands/` (user) **still
load** in 3.7 — nothing breaks today. But the docs page that served commands
now serves Skills, and the direction is unambiguous:

- **Never create new commands.** A new explicit-invocation prompt is a skill
  with `disable-model-invocation: true` — same `/name` UX, plus
  scripts/references/assets and the standard's portability.
- **Migrate existing ones** with `/migrate-to-skills` when touching them.

## Skill vs rule, restated

| Question | Yes → |
|---|---|
| Is it a standing constraint the agent must always/conditionally respect? | Rule |
| Does it have steps, helper scripts, or reference docs? | Skill |
| Should the user explicitly invoke it by name? | Skill with `disable-model-invocation: true` |
| Is it project orientation (build/test/layout)? | AGENTS.md |

Sources: [cursor.com/docs/skills](https://cursor.com/docs/skills),
[agentskills.io](https://agentskills.io). Verified 2026-06-09.
