---
name: cursor-rules-and-skills
description: Use when writing or migrating Cursor rules, skills, commands, or AGENTS.md context. Triggers on "write a Cursor rule", ".mdc file", ".cursor/rules", "cursorrules migration", "migrate .cursorrules", "Cursor skill", ".cursor/skills", "migrate commands to skills", "Cursor commands deprecated", "AGENTS.md in Cursor".
---

# cursor-rules-and-skills

Cursor has four overlapping ways to feed standing instructions to its agent — **rules** (`.cursor/rules/*.mdc`), **skills** (agentskills.io standard), **commands** (soft-deprecated), and **AGENTS.md** — plus two deprecated ancestors (`.cursorrules`, `.cursor/commands/`) that still half-work and generate most of the confusion. This skill picks the right surface, writes it correctly, and migrates the legacy ones.

All facts verified 2026-06-09 against cursor.com/docs/context/rules and cursor.com/docs/skills (Cursor 3.7).

## The number-one gotcha

**Rules must be `.mdc`. A plain `.md` file in `.cursor/rules/` is silently ignored** — no error, no warning, the rule simply never applies. This is the single most common "my rule doesn't work" cause. cursor-dev's deterministic lane flags it (`cursor-rules-md-ignored`).

## Reference map

| When you need… | Read first |
|---|---|
| `.mdc` anatomy, the four rule types and their frontmatter combos, precedence (Team → Project → User), nested rules, `.cursorrules` migration, AGENTS.md semantics | `references/cursor-rules.md` |
| Skill discovery paths (incl. `.claude/skills/` compat), SKILL.md frontmatter (`paths`, `disable-model-invocation`), progressive loading, commands→skills migration | `references/cursor-skills.md` |

## Decision rules

### Rule, skill, or AGENTS.md?

| Signal | Surface |
|---|---|
| Short standing constraint ("always", "never", style/convention), possibly file-scoped | **Rule** (`.mdc`) |
| A capability with procedure, scripts, or reference docs the agent should pull in on demand | **Skill** |
| Explicit-invocation prompt the user types deliberately | **Skill with `disable-model-invocation: true`** (not a command — commands are soft-deprecated) |
| Repo orientation: what this project is, how to build/test, tool-agnostic | **AGENTS.md** (works in Cursor, Claude Code, Codex, …) |
| Cross-repo, org-enforced policy | **Team Rule** (dashboard) |

Heuristic: rules are *constraints*, skills are *capabilities*, AGENTS.md is *orientation*.

### Which rule type? (the frontmatter combos)

Four types, selected purely by the `description` / `globs` / `alwaysApply` frontmatter combination — details and templates in `cursor-rules.md`:

| Type | Frontmatter | When applied |
|---|---|---|
| **Always Apply** | `alwaysApply: true` | Every agent request |
| **Apply Intelligently** | `alwaysApply: false` + `description` | When the agent judges the description relevant |
| **Specific Files** | `alwaysApply: false` + `globs` (comma-separated) | When matching files are in context |
| **Manual** | all unset | Only when @-mentioned |

The trap combo: `alwaysApply: false` with **neither** description **nor** globs — that's an accidental Manual rule that never auto-applies. The deterministic lane warns on it (`cursor-rule-manual-only`).

Precedence when rules conflict: **Team Rules** (admin dashboard, org-wide) → **Project rules** (`.cursor/rules/`) → **User rules** (GUI settings, plain text, agent-only). In monorepos, nested `.cursor/rules/` directories work — put scoped rules next to the code they govern.

### Migrate `.cursorrules`?

Yes, always. `.cursorrules` (single root file) has been **deprecated since ~0.43** and is **unreliable in Agent mode** — it sometimes simply isn't loaded. Don't debug it; migrate it: split by concern into `.cursor/rules/*.mdc`, pick a type per rule, delete the old file. Recipe in `cursor-rules.md`.

### Where do skills live, and what's Cursor-specific about them?

Cursor implements the **agentskills.io** open standard — a Claude Code SKILL.md loads as-is. Discovery paths (project + home), in addition to `.cursor/skills/` and `.agents/skills/`: Cursor **also reads legacy `.claude/skills/` and `.codex/skills/`** — so existing Claude Code project skills just work. Full path list in `cursor-skills.md`.

Cursor-specific frontmatter on top of the standard:

- `paths` — comma-separated globs (`"**/*.tsx, **/*.jsx"`); the skill is only *visible to the model* when matching files are in play. (`globs` accepted as a legacy fallback.)
- `disable-model-invocation: true` — slash-command behavior: never auto-fires, user invokes `/skill-name`.
- `name` **must equal the folder name** — mismatch breaks discovery; the deterministic lane errors on it (`cursor-skill-name-mismatch`).

Built-in helpers: `/create-skill` scaffolds a new skill; `/migrate-to-skills` converts legacy surfaces.

### What about existing commands?

`.cursor/commands/*.md` and `~/.cursor/commands/` **still load**, but commands are soft-deprecated — the docs page that used to describe them now serves Skills. Policy:

- **New** explicit-invocation prompts → skill with `disable-model-invocation: true`. Never create new commands.
- **Existing** commands → run `/migrate-to-skills`.
- The same migration also converts **dynamic rules** (rules with `alwaysApply: false` and no `globs`, i.e. description-triggered) into skills; `alwaysApply: true` and glob-scoped rules **stay rules**.

### AGENTS.md — what Cursor actually does with it

- Project root `AGENTS.md` is read; **nested** AGENTS.md files work with **nearest-wins, combined-with-parents** semantics (the closer file augments, not replaces) — though nested loading has open bug reports, so don't bet correctness on deep nesting.
- The Cursor **CLI** also reads a root `CLAUDE.md`.
- There is **no global `~/.cursor/AGENTS.md`** — that's an open feature request; use User rules (GUI) for personal global instructions.

## Anti-patterns this skill catches

- A rule saved as `.md` in `.cursor/rules/` — silently ignored; rename to `.mdc` (`cursor-rules-md-ignored`).
- `alwaysApply: false` with no `description` and no `globs` — accidental manual-only rule (`cursor-rule-manual-only`).
- Still feeding `.cursorrules` and wondering why Agent mode ignores it — deprecated since ~0.43; migrate.
- A skill whose frontmatter `name` differs from its folder name — discovery breaks (`cursor-skill-name-mismatch`).
- Creating new `.cursor/commands/*.md` files in 2026 — soft-deprecated; use `disable-model-invocation: true` skills.
- A 400-line "Always Apply" rule — always-on context tax; demote the bulk to an Apply Intelligently rule or a skill.
- Expecting `~/.cursor/AGENTS.md` to exist — it doesn't; open feature request.
- Workflow steps in a skill `description` — the description decides *when*, the body says *how* (see plugin-dev's `skill-description-leak-audit`).

## Sources

- Cursor, *Rules* — `.mdc` requirement, four types, frontmatter, nested rules, Team/Project/User precedence, `.cursorrules` deprecation ([cursor.com/docs/context/rules](https://cursor.com/docs/context/rules)). Verified 2026-06-09.
- Cursor, *Skills* — agentskills.io standard, discovery paths incl. `.claude/skills/` + `.codex/skills/` compat, `paths`, `disable-model-invocation`, `/create-skill`, `/migrate-to-skills`, commands soft-deprecation ([cursor.com/docs/skills](https://cursor.com/docs/skills)). Verified 2026-06-09.
- Agent Skills standard ([agentskills.io](https://agentskills.io)). Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
