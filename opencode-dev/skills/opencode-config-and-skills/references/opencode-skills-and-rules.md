# OpenCode skills and rules (verified 2026-06-09, OpenCode v1.16)

## Skills — native Agent Skills support

OpenCode loads Agent Skills **natively** via its built-in skill tool — the
model sees each skill's name + description and pulls the body in on demand
(progressive disclosure). Community skill-loader plugins
(`opencode-agent-skills` and friends) are **obsolete**; remove them.

### Discovery paths

| Path | Notes |
|---|---|
| `.opencode/skills/<name>/SKILL.md` | project, canonical |
| `~/.config/opencode/skills/<name>/SKILL.md` | global |
| **`.claude/skills/<name>/SKILL.md`** | **Claude Code compat** — existing Claude Code project skills just work |
| `.agents/skills/<name>/SKILL.md` | cross-tool standard path |

Project paths are **walked from the cwd up to the worktree root** (so nested
packages in a monorepo can carry their own skills), plus the global dirs.
Plural `skills/` is canonical; singular `skill/` is legacy
(`opencode-singular-dir`).

### SKILL.md frontmatter

Required:

- `name` — 1–64 chars, regex `^[a-z0-9]+(-[a-z0-9]+)*$` (lowercase
  alphanumeric, single hyphens, no leading/trailing hyphen)
- `description` — 1–1024 chars; this is what the model reads to decide to
  load the skill — third person, specific, trigger-rich

Optional: `license`, `compatibility`, `metadata` (a string→string map).

Recent fixes worth knowing (so you don't code around fixed bugs):

- **Multi-line YAML descriptions** (`>-` folded style) now parse correctly.
- **Directory name ≠ frontmatter `name` is allowed** — the frontmatter name
  wins. (Contrast with Cursor, which requires them to match.)

Violating the name regex/length or omitting the description means the skill
silently fails to load — opencode-dev's validator errors
(`opencode-skill-frontmatter`).

```markdown
---
name: release-checklist
description: Use when preparing a release of this project. Triggers on "cut a release", "tag a version", "publish the package".
---

# release-checklist
…body loaded only when the skill fires…
```

## Rules — AGENTS.md and the instructions array

### AGENTS.md (canonical)

- **Project**: `AGENTS.md` at the repo root — scaffold with `/init`.
- **Global**: `~/.config/opencode/AGENTS.md` — personal, applies everywhere.

Both are injected as standing context. Keep them orientation-level (what the
project is, how to build/test, conventions); push procedures into skills.

### CLAUDE.md fallback

When **no AGENTS.md exists**, OpenCode reads `CLAUDE.md` (project root) and
`~/.claude/CLAUDE.md` (global) instead. Disable the fallback with
`OPENCODE_DISABLE_CLAUDE_CODE=1`. The fallback eases migration — but two
sources of truth diverge; `/init` an AGENTS.md and retire the dependence on
CLAUDE.md for OpenCode's purposes.

### The `instructions` array

Top-level config key listing **additional** rule files to inject. Entries may
be:

- plain paths — `"docs/style.md"`
- **globs** — `".cursor/rules/*.md"`, `"packages/*/AGENTS.md"` (reuse Cursor
  rules or per-package AGENTS.md in a monorepo without copying)
- **remote URLs** — fetched with a **5-second timeout**; a slow/down host
  means the rule is skipped that session

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    ".cursor/rules/*.md",
    "packages/*/AGENTS.md",
    "https://example.com/org-rules.md"
  ]
}
```

`instructions` merges across config layers, so global config can add personal
rule files on top of the project's.

### Choosing a surface

| Need | Surface |
|---|---|
| Always-on repo orientation | `AGENTS.md` |
| Always-on personal preferences | global `AGENTS.md` |
| Reuse rule files that already exist (other tools, other packages) | `instructions` |
| On-demand capability/procedure | skill |
| Constraint enforcement (not prose) | `permission` config — prose rules are advisory, permissions are enforced |

## Checklist

1. Skill names pass the regex; descriptions 1–1024 chars, trigger-rich.
2. Plural `skills/`; one dir per skill with `SKILL.md` inside.
3. AGENTS.md exists (`/init`), CLAUDE.md fallback not load-bearing.
4. `instructions` globs actually match files (test with `ls`); remote URLs
   only for content that may be skipped on timeout.
5. Run opencode-dev's `scripts/validate.sh`
   (`opencode-skill-frontmatter`, `opencode-singular-dir`).

Source: [opencode.ai/docs/skills](https://opencode.ai/docs/skills);
[opencode.ai/docs/rules](https://opencode.ai/docs/rules).
Verified 2026-06-09.
