---
name: skill-development
description: Use when authoring or auditing a SKILL.md. Triggers on "create a SKILL.md", "skill fires but runs wrong logic", "skill description leak", "injection in skill", "is this description safe".
---

# skill-development

Canonical rules for authoring, reviewing, and security-auditing Claude Code `SKILL.md` files.
Consult the `references/` files when a topic goes deep.

> **Determinism boundary.** The mechanical checks — frontmatter parse, `name` matches the directory, description length, SKILL.md ≤500 lines, reference nesting — are owned by the deterministic suite: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-skill.sh" <skill-dir>`. It only *flags* description POV/leak candidates; confirming and rewriting them is your judgment (see `references/leak-and-injection.md`). Run the script first, then spend attention on what it cannot decide.

## Reference map

| When you're… | Read first |
|---|---|
| Rewriting or auditing a description | `references/description-style.md` |
| Checking a skill for injection or leak risk | `references/leak-and-injection.md` |
| Test-driven iteration, description tuning, improvement principles | `references/eval-and-iteration.md` |

---

## 1. Skill anatomy

A skill is a directory `skills/<name>/` containing `SKILL.md` and optional subdirs:

```
skills/
  my-skill/
    SKILL.md          ← required
    references/       ← deep content, one level only
    scripts/          ← executable utilities
    assets/           ← non-code resources (also: templates/)
```

**Skills ≡ slash commands.** Custom slash commands are merged into skills:
`.claude/commands/x.md` and `.claude/skills/x/SKILL.md` are the same
mechanism with the same frontmatter. Claude Code follows the agentskills.io
open standard plus the extensions below. Every skill is `/name`-invocable
(unless `user-invocable: false`) and model-invocable via the Skill tool
(unless `disable-model-invocation: true`).

### 1.1 Frontmatter (between `---` fences)

All fields are optional upstream. This repo's validator still requires
`name` (matching the directory) and `description`.

| Field | Rules |
|---|---|
| `name` | Display name; sets the command name only for a plugin-root `SKILL.md`. Must match the directory name here (validator-enforced). |
| `description` | Trigger-spec only — see §2. Combined with `when_to_use` in the listing, truncated at 1,536 chars. |
| `when_to_use` | Extra trigger context, appended to `description` in the listing (same budget). |
| `argument-hint` | Hint shown in the `/` menu, e.g. `[skill-dir]`. |
| `arguments` | Named positional args; each becomes a `$name` substitution in the body. |
| `disable-model-invocation` | `true` = user-only. Description removed from context entirely; also blocks preloading into subagents. |
| `user-invocable` | `false` = hidden from the `/` menu. Does NOT block Skill-tool access — pair with `disable-model-invocation` for full lockdown. |
| `allowed-tools` | Pre-approves tools (skips permission prompts); does **not** restrict the pool. Project-scope skills need workspace trust. |
| `disallowed-tools` | (v2.1.152) Removes tools from the pool while the skill is active; clears on the next user message. |
| `model` | Model override while the skill runs. |
| `effort` | `low` \| `medium` \| `high` \| `xhigh` \| `max`. |
| `context` | `fork` = run in a forked subagent context; the body becomes the subagent's prompt. |
| `agent` | Subagent type for `context: fork`: `Explore`, `Plan`, `general-purpose`, or a custom agent. |
| `hooks` | Skill-scoped lifecycle hooks, active while the skill runs. |
| `paths` | Glob gating — auto-activation only when matching files are in play. |
| `shell` | `bash` (default) or `powershell` for dynamic-context commands. |

No `version` field in frontmatter.

### 1.2 Substitutions & dynamic context

Body substitutions: `$ARGUMENTS` (full arg string), `$ARGUMENTS[N]` / `$N`
(positional), `$name` (from `arguments:`), `${CLAUDE_SESSION_ID}`,
`${CLAUDE_EFFORT}`, `${CLAUDE_SKILL_DIR}`. Escape a literal dollar with
`\$` (v2.1.157).

Dynamic context: inline `` `!command` `` and multi-line fenced ```` ```! ````
blocks run at invocation time (interpreter per `shell:`) and splice their
output into the body. Orgs can kill all skill shell execution with the
`disableSkillShellExecution` setting. Treat both forms as injection
surface — see §4.

### 1.3 Discovery, listing budget, invocation control

- **Discovery:** project + parent + nested `.claude/skills/` dirs,
  `~/.claude/skills/`, `--add-dir` trees, and plugin `skills/`.
- **Listing budget:** the skill listing gets ~1% of the context window
  (`skillListingBudgetFraction` tunable); each entry is truncated at
  1,536 chars (`maxSkillDescriptionChars` tunable). On compaction, the
  first 5,000 tokens per loaded skill are kept within a 25,000-token
  shared budget.
- **Live reload:** SKILL.md text edits are detected live; other plugin
  components need `/reload-plugins`.
- **Per-skill control:** the `skillOverrides` setting takes
  `on` / `name-only` / `user-invocable-only` / `off`; permission rules
  support `Skill(name)` matchers.

### 1.4 Body structure

1. One-sentence purpose (do not restate the description).
2. Reference map table — one row per `references/` file, if any exist.
3. Skill content.

---

## 2. Description rules (security-critical)

See `references/description-style.md` for worked examples and before/after rewrites.

### 2.1 Third-person only

Wrong: "I help you write skills..." or "You should trigger this when..."
Right: "Covers authoring and reviewing Claude Code skill files..."

Mixed or first-person POV degrades trigger matching (Anthropic-confirmed).

### 2.2 Trigger-spec, not summary

The description must answer only: *when should this skill fire?*

Pattern:
```
[What it does in one phrase]. Triggers on "exact phrase 1", "exact phrase 2",
..., or [other concrete signal].
```

Front-load the most discriminating trigger phrases — the listing combines
`description` + `when_to_use` and truncates the entry at 1,536 chars,
clipping from the tail. Overflow trigger context belongs in `when_to_use`,
never in the body.

### 2.3 Length budget

Upstream truncation: 1,536 chars per listing entry (`description` +
`when_to_use` combined). This repo enforces a stricter 1024-char cap on
`description` (validator error) for headroom. Effective cap is tighter
under load. Count characters before committing. If over cap, cut worked
examples and summaries first — never cut trigger phrases.

### 2.4 Description-leak hazard (silent failure)

If the description contains a procedure ("First X, then Y..."), Claude may
execute the description and skip the body entirely. The skill appears loaded
but runs a truncated version of its own trigger spec.

**Symptom:** skill produces output that looks like a paraphrase of its
description, not the detailed logic in the body.

**Fix:** description = trigger spec only. All procedure lives in the body or
in `references/`.

Full audit checklist: `references/leak-and-injection.md §Leak`.

### 2.5 No user-controlled content in descriptions

Never embed user-controlled URLs, file paths, secret names, or env-var
contents in the description. Adversaries can plant prompt-injection there.
Details: `references/leak-and-injection.md §Injection`.

---

## 3. Progressive disclosure

### 3.1 Line limits

| Scope | Limit |
|---|---|
| `SKILL.md` | ≤500 lines (community hard cap); ≤200 for coder-plugins |
| Any single `references/` file | ≤300 lines recommended |

When a SKILL.md approaches the limit, split content into `references/`.

### 3.2 Reference file rules

- **One level deep only.** No `references/foo/bar.md`. Claude tends to `head -100`
  on deeply nested paths and misses the body.
- **Domain-split over generic.** `references/finance.md` + `references/sales.md`
  beats `references/details.md`.
- **TOC required** when a reference file exceeds 100 lines.
- **Mark intent in the reference map:** "Run `scripts/check.sh`" vs "See
  `references/patterns.md`" — the model behaves differently for each.

### 3.3 Subdirectory purposes

| Subdir | Contains |
|---|---|
| `references/` | Markdown deep-dives, looked up not executed |
| `scripts/` | Executable utilities (bash, python, etc.) |
| `assets/` or `templates/` | Non-code resources |

---

## 4. Injection safety

The SKILL.md body is injected into the system prompt. Treat any embedded
content as potentially adversarial.

**Hard rules:**

1. Never embed user-controlled URLs, file paths, or env-var contents in the
   skill body. Adversaries can plant instructions there.
2. Never embed content fetched at runtime (API responses, file contents from
   user repos) directly into skill text.
3. Static text aside, the only dynamic content is `` `!command` `` /
   ```` ```! ```` blocks — their output splices into context as trusted
   text, so never feed user-controlled strings into them. Orgs can disable
   them wholesale via `disableSkillShellExecution`.

Pre-flight scanner: Repello SkillCheck (https://repello.ai/blog/claude-code-skill-security).

Required reading: Snyk ToxicSkills 2025 audit — found injection in 36% of
audited community skills (https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub).

Full checklist and injection vectors: `references/leak-and-injection.md §Injection`.

---

## 5. Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| First-person POV in description ("I help you...") | Degrades trigger matching |
| Description summarizes skill instead of triggering it | Triggers are missed; model reads summary instead of body |
| Description contains procedure ("First X, then Y") | Leak — model skips body and executes description |
| SKILL.md >500 lines without splitting references | Body is partially read or skipped |
| Nested references (`references/foo/bar.md`) | Partial reads; model misses content |
| Restating the description in the body's first paragraph | Token waste, no added value |
| Embedding user input or fetched content in skill body | Injection vector |

---


## 6. Common mistakes — worked examples


### Mistake 1: Weak Trigger Description

❌ **Bad:**
```yaml
description: Provides guidance for working with hooks.
```

**Why bad:** Vague, no specific trigger phrases, not third person

✅ **Good:**
```yaml
description: This skill should be used when the user asks to "create a hook", "add a PreToolUse hook", "validate tool use", or mentions hook events. Provides comprehensive hooks API guidance.
```

**Why good:** Third person, specific phrases, concrete scenarios

### Mistake 2: Too Much in SKILL.md

❌ **Bad:**
```
skill-name/
└── SKILL.md  (8,000 words - everything in one file)
```

**Why bad:** Bloats context when skill loads, detailed content always loaded

✅ **Good:**
```
skill-name/
├── SKILL.md  (1,800 words - core essentials)
└── references/
    ├── patterns.md (2,500 words)
    └── advanced.md (3,700 words)
```

**Why good:** Progressive disclosure, detailed content loaded only when needed

### Mistake 3: Second Person Writing

❌ **Bad:**
```markdown
You should start by reading the configuration file.
You need to validate the input.
You can use the grep tool to search.
```

**Why bad:** Second person, not imperative form

✅ **Good:**
```markdown
Start by reading the configuration file.
Validate the input before processing.
Use the grep tool to search for patterns.
```

**Why good:** Imperative form, direct instructions

### Mistake 4: Missing Resource References

❌ **Bad:**
```markdown
# SKILL.md

[Core content]

[No mention of references/ or examples/]
```

**Why bad:** Claude doesn't know references exist

✅ **Good:**
```markdown
# SKILL.md

[Core content]

## Reference map

| When you're… | Read first |
|---|---|
| Doing X | `references/x.md` |
```

**Why good:** The reference map tells Claude the references exist and when
to read them.

---

## 7. Iteration & evaluation (pointer)

Authoring is one half of skill-building. Empirically validating that the
skill triggers on the right requests and produces the right outputs is the
other half. When the task is to *test*, *benchmark*, *tune for triggering*,
or *iterate* on an existing skill, read `references/eval-and-iteration.md`
before drafting changes. It covers:

- the four-question intent capture
- the test-driven iteration loop (with-skill vs baseline subagents, grading,
  benchmark aggregation, review with the user)
- improvement principles (generalize, lean, explain why, bundle repeated work)
- description tuning (eval-query design, train/test split, anti-overfit)
- how skill triggering actually works (why trivial prompts don't trigger)

The full automated harness — viewer scripts, run_loop, etc. — lives upstream
in Anthropic's `skill-creator` plugin; install it from the
`claude-plugins-official` marketplace if the tooling is needed.

---

## Sources

- https://code.claude.com/docs/en/skills (verified 2026-06-09 against Claude Code v2.1.170)
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- https://repello.ai/blog/claude-code-skill-security
- https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub
- https://github.com/obra/superpowers (community skill-writing patterns)
- Vault: [[Claude Code Skill Description Leak]], [[Claude Code Plugins]]
