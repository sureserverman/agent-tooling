# leak-and-injection — Audit Checklist, Vectors, and Screening

## TOC

1. [Background — what are these two threats?](#1-background)
2. [Leak — description-to-body bypass](#2-leak--description-to-body-bypass)
3. [Injection — adversarial content in skill body](#3-injection--adversarial-content-in-skill-body)
4. [Leak audit checklist](#4-leak-audit-checklist)
5. [Injection audit checklist](#5-injection-audit-checklist)
6. [Screening tools](#6-screening-tools)
7. [Required reading](#7-required-reading)

---

## 1. Background

Two distinct security failure modes affect SKILL.md files. They are unrelated
and require separate mitigations.

**Leak** — a skill description that contains procedural content causes the
model to execute the description instead of reading the body. The body is
skipped. The skill "runs" but produces incomplete, description-derived output.
This is a *silent* failure.

**Injection** — adversarial text planted in locations that flow into the skill
body (user-controlled file paths, fetched URLs, env-var values) is processed
as trusted system-prompt content. The adversary can redirect the model to
perform arbitrary actions.

---

## 2. Leak — description-to-body bypass

### Mechanism

Claude Code loads every skill description into session context before the
session begins. The model uses descriptions for two passes:

1. **Trigger pass** — decide which skills apply to the current task.
2. **Summary pass** — maintain a working model of what each loaded skill does.

If the description is rich enough to act on (contains steps, checklists, or
decision trees), the model satisfies both passes from the description alone
and never reads the SKILL.md body.

### How to recognize a leaky skill in production

- Skill output looks like a paraphrase or abbreviation of the description text.
- Structured sections defined in the body (tables, decision trees, code
  snippets) do not appear in output.
- Asking the model "what did you just do?" produces an answer that maps to the
  description wording, not the body.
- Behavior changes when you remove procedure from the description — body logic
  appears. That confirms the leak.

### Leak risk taxonomy

| Risk level | Description content | Effect |
|---|---|---|
| None | Trigger phrases only | Body always read |
| Low | One vague process word ("reviews", "checks") | Occasional body-skip on short tasks |
| Medium | One explicit step ("First, run X") | Body skipped ~50% of the time |
| High | Ordered steps, phase labels, checklists | Body almost never read |
| Critical | Full workflow in description | Body never read; skill is effectively only its description |

### Leak prevention rules

1. **Description = trigger spec only.** No verbs that describe a process.
   "Covers X" and "Triggers on Y" are safe. "First does X, then Y" is not.
   The same rules apply to `when_to_use` — it is combined with the
   description in the listing and leaks the same way.
2. **The test:** read only the description. Could a model execute the skill
   from the description alone? If yes, the description is leaking.
3. **All procedures go in the body.** Reference files are acceptable for
   long procedures. The description is never the right location.
4. **User-only skills cannot leak.** `disable-model-invocation: true`
   removes the description from context entirely (and blocks preloading
   into subagents) — the right setting for command-style skills whose
   description would otherwise read like a procedure.

---

## 3. Injection — adversarial content in skill body

### Mechanism

A SKILL.md body is injected verbatim into the system prompt. Anything that
flows from an external source into the body text is processed as trusted
content. Adversaries exploit this by planting instructions in:

- File paths specified by the user (if a skill reads a file and embeds the
  content in its body template or reference-map).
- URLs fetched at skill load time (a skill that curls a remote manifest and
  embeds the result).
- Environment variables expanded in skill body at load time.
- `references/` files that are generated from user input rather than static
  content.

### Confirmed injection vectors

From the Snyk ToxicSkills 2025 audit (36% of audited community skills were
vulnerable):

| Vector | How it appears | Severity |
|---|---|---|
| User-controlled file path in body | Skill body includes `$PROJECT_ROOT/config.yaml` | Critical |
| Remote URL fetched and inlined | `curl https://user-specified-host/skill-ext.md` embedded | Critical |
| Dynamic-context block over untrusted input | `` !`cat $USER_FILE` `` or a ```` ```! ```` block whose command touches user-controlled data | Critical |
| Env-var expansion in frontmatter | `description: "Covers $SKILL_DOMAIN files..."` | High |
| Shared `references/` written by hook | Hook writes `references/context.md` from user input | High |
| Skill calls another skill that embeds input | Chained skill passes user string into body slot | Medium |

### Injection prevention rules

1. **Skill body is static text** — with one sanctioned exception: dynamic
   context via inline `` !`command` `` and fenced ```` ```! ```` blocks
   (v2.1.x). These execute at invocation (interpreter per `shell:`) and
   splice output into context as trusted text. Keep their commands fixed
   strings over trusted inputs only; orgs can disable them entirely with
   the `disableSkillShellExecution` setting. No other fetched content, no
   runtime file inclusion.
2. **Never embed user-controlled strings** — even partially. An adversary
   controls the part they can influence.
3. **`references/` files must be committed, not generated.** A hook that writes
   a references file from user input creates a writable injection point.
4. **Scripts in `scripts/` are separate processes.** Script *output* should be
   treated as untrusted when it flows back into model context. Pass output
   as tool output, not as injected body text.
5. **Env vars are resolved at session start.** Any env var that can be set by
   user input or a `.env` file is a potential injection carrier. Do not expand
   env vars in skill body or description.

---

## 4. Leak audit checklist

Run this checklist against any SKILL.md before shipping.

**Description field:**

- [ ] No ordered steps ("First...", "Then...", "Finally...").
- [ ] No phase labels ("Phase 1:", "Step 2:").
- [ ] No imperative verbs describing a process ("Parse X", "Run Y on Z",
      "Output a report with...").
- [ ] No checklists (no `- [ ]` or numbered lists).
- [ ] No "will" or "does" followed by a process description ("This skill will
      parse...").
- [ ] Passes the isolation test: reading the description alone gives no
      actionable workflow.

**Body field:**

- [ ] First paragraph does not restate the description.
- [ ] Procedure is present in body (not description) — body contains the
      actual workflow, decision trees, code patterns.
- [ ] Reference map present if `references/` contains files.

**Functional test:**

- [ ] Trigger the skill on a representative task. Does output match the body's
      logic or the description's wording? If the latter, the description is
      leaking.
- [ ] Remove all procedure from the description. Does behavior change? If yes,
      confirms the skill was running from description, not body.

---

## 5. Injection audit checklist

**Description field:**

- [ ] No `$VAR` expansions.
- [ ] No user-controlled strings (paths, URLs, names that come from user input).
- [ ] No content fetched at runtime.

**Body:**

- [ ] No `$VAR` expansions that could be influenced by user or environment.
- [ ] No `curl`/`wget`/`fetch` calls whose output is embedded in the body.
- [ ] No `cat $FILE` or `< $FILE` where `$FILE` is user-controlled.
- [ ] Dynamic-context blocks (`` !`cmd` ``, ```` ```! ````) run only fixed
      commands over trusted inputs — no user-controlled substitutions inside.
- [ ] No template slots filled at runtime from external input.

**`references/` directory:**

- [ ] All files are committed static content.
- [ ] No file in `references/` is written by a hook or script at session time
      from user-supplied input.
- [ ] File names are hardcoded, not derived from user input.

**`scripts/` directory:**

- [ ] Scripts do not write back into `references/` from user input.
- [ ] Script output that flows to model context is clearly labeled as tool
      output, not injected as trusted body text.

**Supply chain:**

- [ ] Skill does not fetch and execute remote `SKILL.md` content.
- [ ] No skill extends another skill by downloading a remote body.
- [ ] Plugin source is pinned — no `latest` channel that could deliver a
      modified skill body.

---

## 6. Screening tools

### Repello SkillCheck

Pre-flight scanner for Claude Code skill security.
Source: https://repello.ai/blog/claude-code-skill-security

Checks for:
- Leak patterns in descriptions (procedural content detection).
- Known injection vectors in body text.
- Env-var expansion risks.
- Remote fetch patterns.

Run before publishing any skill to a marketplace or shared plugin repo.

### Manual description isolation test

1. Copy only the `description:` field value.
2. Ask a fresh model session: "Given this description, what would you do on
   a task that triggers this skill?"
3. If the answer contains a complete procedure, the description is leaking.

### Character count (catch over-length descriptions)

```bash
python3 - "$1" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r'^description:\s*["\']?(.*?)["\']?\s*$', text, re.MULTILINE | re.DOTALL)
if m:
    desc = m.group(1).strip().strip('"').strip("'")
    n = len(desc)
    flag = ' OVER LIMIT' if n > 1024 else ''
    print(f'{n} chars{flag}')
PY
```

Note: the 1024 figure is this repo's stricter cap; Claude Code itself
truncates the combined `description` + `when_to_use` listing entry at
1,536 chars.

### grep patterns for common injection markers

```bash
# Env-var expansion in description or body
grep -n '\$[A-Z_][A-Z0-9_]*' SKILL.md

# Remote fetch in body
grep -n 'curl\|wget\|fetch\|http://' SKILL.md

# File cat patterns
grep -n 'cat \$\|< \$\|open(\$' SKILL.md

# Dynamic-context shell blocks (review each hit by hand)
grep -n '!`\|^```!' SKILL.md

# Phase/step labels (leak risk in descriptions)
grep -in 'phase [0-9]\|step [0-9]\|first,\|then,\|finally,' SKILL.md
```

---

## 7. Required reading

**Snyk ToxicSkills 2025**
https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub

Key findings:
- 36% of audited community skills contained at least one injection vector.
- Most common vector: user-controlled file paths embedded in skill body
  templates.
- Second most common: skills that fetched remote content and inlined it
  without sanitization.
- ClaWHub (the community skill marketplace at the time) had no pre-upload
  scanning. Skills were installed by thousands of users before the audit.

**Repello SkillCheck**
https://repello.ai/blog/claude-code-skill-security

Describes the SkillCheck scanner architecture and the categories it detects.
Covers leak detection, injection detection, and supply-chain risks.

**Vault: [[Claude Code Skill Description Leak]]**
Internal incident record. Audit of 17 skill descriptions found 9 definitively
leaky and 8 borderline. All were rewritten to trigger-only form. Documents
the mechanism in detail and the before/after for a real production skill.

**Anthropic best practices**
https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices

Covers the 500-line body limit, description trigger-spec guidance, and
`allowed-tools` usage.
