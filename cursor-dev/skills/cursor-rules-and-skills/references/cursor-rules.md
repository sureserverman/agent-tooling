# Cursor rules — .mdc format, types, precedence, migration (verified 2026-06-09, Cursor 3.7)

## File format: `.mdc` only

Project rules live at `.cursor/rules/*.mdc`. The extension is load-bearing:

- **`.mdc` files are loaded. `.md` files in the same directory are silently
  ignored** — no warning anywhere in the UI. If a rule "doesn't work", check
  the extension first.
- An `.mdc` file is markdown with a YAML frontmatter block. Broken YAML in the
  frontmatter also breaks the rule.

In monorepos, **nested `.cursor/rules/` directories work** — e.g.
`packages/api/.cursor/rules/api-conventions.mdc` governs work in that subtree.
Put scoped rules next to the code they constrain instead of glob-gymnastics at
the root.

## The four rule types

Type is selected by the frontmatter combination of `description`, `globs`,
and `alwaysApply`:

### 1. Always Apply

```yaml
---
alwaysApply: true
---
```

Injected into **every** agent request. Reserve for short, genuinely universal
constraints — every line is a permanent context tax.

### 2. Apply Intelligently

```yaml
---
description: API endpoint conventions — error envelopes, pagination, auth middleware ordering
alwaysApply: false
---
```

The agent reads the `description` and decides relevance per request. The
description is the trigger — write it like a skill description: third person,
specific, naming the situations it should fire in.

### 3. Specific Files

```yaml
---
globs: "**/*.tsx, **/*.scss"
alwaysApply: false
---
```

Applied when files matching the globs are in context. `globs` is a
**comma-separated string**, not a YAML list.

### 4. Manual

```yaml
---
alwaysApply: false
---
```

(Or no meaningful frontmatter at all.) Applied **only** when the user
@-mentions the rule (`@rule-name`). This is also the accidental result of
setting `alwaysApply: false` with neither `description` nor `globs` — usually
a mistake; cursor-dev's validator warns (`cursor-rule-manual-only`).

Combination notes: `description` + `globs` together is legal — the rule
applies on glob match *and* is available for intelligent application.

## Precedence

When rules conflict, higher wins:

1. **Team Rules** — set by admins in the Cursor dashboard; org-wide; cannot be
   overridden locally.
2. **Project rules** — `.cursor/rules/` (including nested).
3. **User rules** — set in the GUI settings; plain text (no .mdc, no
   frontmatter, no globs); **agent-only** (they don't affect Tab).

## `.cursorrules` is dead — migrate it

The single root `.cursorrules` file is **deprecated since ~0.43** and is
**unreliable in Agent mode** — frequently not loaded at all. Migration recipe:

1. Read the old file; split it by concern (style, architecture, testing,
   per-language…).
2. One `.mdc` per concern in `.cursor/rules/`; choose a type:
   - universal & short → Always Apply
   - situational → Apply Intelligently with a precise description
   - file-type-bound → Specific Files with globs
3. Anything procedural ("when asked to deploy, do X then Y") → that's a
   **skill**, not a rule (see `cursor-skills.md`).
4. Delete `.cursorrules`. Keeping both invites divergence and the old file
   may or may not load depending on mode.

The built-in `/migrate-to-skills` flow also converts *dynamic* rules
(description-triggered, no globs, `alwaysApply: false`) into skills —
`alwaysApply: true` and glob-scoped rules stay rules.

## AGENTS.md in Cursor

A separate, tool-agnostic context surface — orientation, not constraints:

- **Project root `AGENTS.md`** is read by Cursor's agent.
- **Nested AGENTS.md** files (subdirectories) work with **nearest-wins
  semantics, combined with parents** — the nearest file is added on top of
  ancestor files, not a replacement. Caveat: nested loading has **open bug
  reports** as of June 2026; verify behavior before betting a monorepo's
  correctness on deep nesting.
- The Cursor **CLI** additionally reads a root **`CLAUDE.md`**.
- **No global `~/.cursor/AGENTS.md`** exists — it's an open feature request.
  Personal global instructions go in User rules (GUI).

Division of labor: AGENTS.md says *what this project is and how to work in
it* (build, test, layout); rules impose *constraints*; skills package
*capabilities*.

## Authoring checklist for a new rule

1. Right surface? Constraint → rule. Procedure/capability → skill.
   Orientation → AGENTS.md.
2. Extension is `.mdc`; file is in `.cursor/rules/` (or a nested one).
3. Frontmatter parses as YAML and encodes exactly one intended type from the
   table above.
4. Apply-Intelligently descriptions are specific enough to trigger — "React
   conventions" won't; "React component conventions: hooks rules, prop
   typing, server/client component split" will.
5. Run cursor-dev's `scripts/validate.sh` on the artifact dir — it parses
   every `.mdc` frontmatter (PyYAML), flags broken YAML
   (`cursor-rule-frontmatter-unparseable`), manual-only combos
   (`cursor-rule-manual-only`), and ignored `.md` files
   (`cursor-rules-md-ignored`).

Source: [cursor.com/docs/context/rules](https://cursor.com/docs/context/rules).
Verified 2026-06-09.
