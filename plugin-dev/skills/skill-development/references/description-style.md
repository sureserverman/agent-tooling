# description-style — Worked Examples and Patterns

## TOC

1. [The trigger-spec pattern](#1-the-trigger-spec-pattern)
2. [Good descriptions — annotated](#2-good-descriptions--annotated)
3. [Bad descriptions — annotated](#3-bad-descriptions--annotated)
4. [Before / after rewrites](#4-before--after-rewrites)
5. [Character-count discipline](#5-character-count-discipline)
6. [POV failures](#6-pov-failures)
7. [Quick checklist](#7-quick-checklist)

---

## 1. The trigger-spec pattern

A description has exactly one job: tell the model when to load this skill.
It is not a summary. It is not a tutorial. It is not a README.

**Pattern:**

```
[What it does in one phrase]. Triggers on "exact user phrase 1",
"exact user phrase 2", "exact user phrase 3", ..., or [other concrete signal].
```

The opening phrase gives the model a one-line anchor for the skill's domain.
The `Triggers on` clause lists the actual words users type. Quote them.
Unquoted phrases are less reliably matched.

---

## 2. Good descriptions — annotated

### Example A — rust-coding

```
Use when authoring, scaffolding, refactoring, or reviewing Rust code.
Triggers on greenfield requests like "create a Rust app", "cargo new",
"start a Rust library", "initialize a Rust workspace", or any "in Rust"
/ "using Rust" request. Also triggers on *.rs edits, Cargo.toml changes,
unsafe blocks, async/tokio code, serde derives, thiserror/anyhow error
enums, clippy warnings, borrow-checker errors (E0382, E0502, E0505,
E0597, E0716), edition 2024 migration, and cargo fix output.
```

**Why it works:**
- Opens with domain anchor ("Rust code").
- Front-loads quoted phrases users actually type.
- Lists concrete file signals (`*.rs`, `Cargo.toml`) — these are high-precision.
- Lists error codes — rare but unambiguous triggers.
- No procedure, no steps, no "I will".

### Example B — sec-review

```
Runs a multi-agent security review against project source trees. Triggers
on "run sec-review", "security audit", "audit this codebase", "check for
vulnerabilities", "review for injection", or any request to evaluate code
for security issues. Also triggers on PRs touching auth, crypto, network
handlers, or input parsing.
```

**Why it works:**
- Crisp domain anchor.
- Mixed quoted phrases + file-signal fallback.
- Under 300 chars — leaves budget for the harness to show the full text.

### Example C — skill-development (this skill)

```
Covers authoring, reviewing, and auditing Claude Code skill files (SKILL.md).
Triggers on "write a skill", "create a SKILL.md", "improve this SKILL.md",
"skill description triggering", "skill not loading", "description leak",
"progressive disclosure", "injection in skill", "skill security", or any
request to create, restructure, or security-audit a skill.
```

**Why it works:**
- Lists the exact vocabulary users use when they have skill problems.
- "skill not loading" and "description leak" catch symptom-first queries.
- No procedure anywhere.

---

## 3. Bad descriptions — annotated

### Bad A — workflow leak

```
description: "Audit shell scripts. Phase 1: run shellcheck on each file.
Phase 2: curl all embedded URLs and flag dead ones. Phase 3: grade findings
by severity and output a report."
```

**Problems:**
- Contains a three-phase procedure.
- Model reads this, executes the procedure from the description, and never
  opens the SKILL.md body.
- Silent failure — output looks "roughly right" but misses body logic.

### Bad B — first-person summary

```
description: "I help you write better Rust code by checking idioms,
error handling, and unsafe usage."
```

**Problems:**
- First-person ("I help you") degrades trigger matching.
- Pure summary — tells the model what the skill does, not when to fire it.
- Zero quoted trigger phrases, so it only matches on semantic similarity,
  which is unreliable.

### Bad C — injected path

```
description: "Processes files in the user's project at $PROJECT_ROOT.
Use when the user asks to analyze their codebase."
```

**Problems:**
- `$PROJECT_ROOT` is user-controlled. An adversary can set it to a string
  containing prompt-injection instructions.
- Environment variables are resolved at load time — this turns the description
  into a live injection vector.

### Bad D — over-length, tail-clipped

The harness combines `description` + `when_to_use` into one listing entry
and truncates it at 1,536 characters. If the most discriminating trigger
phrases appear after the cut, they are invisible to the model. The skill
then only fires on its domain anchor, missing all specific triggers. This
repo's validator additionally errors above 1,024 chars of `description`
to keep headroom.

---

## 4. Before / after rewrites

### Rewrite 1 — workflow → trigger-spec

**Before:**
```
description: "Helps with Docker. First, identify whether the user needs a
Dockerfile, docker-compose.yml, or a multi-stage build. Then generate the
appropriate file. Finally, advise on layer caching and image size."
```

**After:**
```
description: "Covers Docker authoring and optimization. Triggers on
\"write a Dockerfile\", \"docker-compose setup\", \"multi-stage build\",
\"reduce image size\", \"Docker layer caching\", or any request to
containerize a project."
```

Change: removed three-phase procedure, added quoted trigger phrases, kept
domain anchor.

### Rewrite 2 — first-person → third-person trigger-spec

**Before:**
```
description: "I review pull requests and tell you what to improve."
```

**After:**
```
description: "Reviews pull requests for style, correctness, and test
coverage. Triggers on \"review this PR\", \"look at my pull request\",
\"give me PR feedback\", or any request to evaluate a diff or branch."
```

Change: eliminated "I", added domain anchor, added quoted phrases.

### Rewrite 3 — vague → specific triggers

**Before:**
```
description: "Use when working with databases."
```

**After:**
```
description: "Covers SQL schema design, query optimization, and migration
authoring. Triggers on \"write a migration\", \"optimize this query\",
\"design a schema\", \"N+1 query\", \"add an index\", \"explain query
plan\", or any database-related request involving SQL, Postgres, MySQL,
or SQLite."
```

Change: domain anchor now names the specific domain; trigger phrases name
concrete user intents; technology names added as fallback signals.

---

## 5. Character-count discipline

```bash
# Count a description from a SKILL.md (heredoc avoids shell-quoting hazards)
python3 - "$1" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r'^description:\s*["\']?(.+?)["\']?\s*$', text, re.MULTILINE | re.DOTALL)
if m:
    desc = m.group(1).strip().strip('"').strip("'")
    print(f'{len(desc)} chars')
else:
    print('no description found')
PY
```

Save the snippet as a script and invoke as `./check-desc.sh path/to/SKILL.md`.

Budgets (Claude Code v2.1.170):
- **1,536 chars** — upstream truncation per listing entry (`description` +
  `when_to_use` combined; `maxSkillDescriptionChars` tunable).
- **1,024 chars** — this repo's validator hard cap on `description`.
- **800 chars** — effective working limit when the plugin ships more than
  6 skills (the whole listing shares ~1% of the context window, tunable
  via `skillListingBudgetFraction`).

If over cap, trim in this order:
1. Remove repetition (same trigger phrase listed twice).
2. Consolidate similar phrases into one representative phrase.
3. Remove the weakest signal phrases (generic terms that would match anything).
4. Move secondary trigger *context* (not the core phrases) to `when_to_use` —
   it is combined with the description in the listing but keeps the
   description field itself lean.
5. Never trim the domain anchor or the most specific trigger phrases.

---

## 6. POV failures

The model's trigger-matching pass treats description text as metadata.
First-person and second-person pronouns are noise tokens in that pass.

| POV | Example | Effect |
|---|---|---|
| First-person | "I help you..." | Matches weakly; "I" is filtered as boilerplate |
| Second-person | "You should use this when..." | Same — "you" is noise |
| Third-person | "Covers Docker authoring..." | Matches on content tokens; highest precision |

Always write descriptions in third person. The subject of every sentence is
the skill, not the author and not the user.

---

## 7. Quick checklist

Before shipping a description:

- [ ] Opens with a third-person domain anchor.
- [ ] Contains at least 3 quoted trigger phrases.
- [ ] No procedure, steps, or ordered instructions.
- [ ] No first-person or second-person pronouns.
- [ ] Under 1024 characters (run the counter); combined with `when_to_use`
      stays under the 1,536-char listing truncation.
- [ ] Most discriminating phrases appear in the first 800 characters.
- [ ] No user-controlled content (paths, env vars, URLs from user input).
- [ ] Does not restate the first paragraph of the SKILL.md body.
