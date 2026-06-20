---
name: skill-description-leak-audit
description: Use when auditing a skill description for workflow leak. Triggers on "check skill description", "this skill runs a shortened version of its workflow", "leak-proof my skill".
---

# Skill Description Leak Audit

Detects and fixes "workflow leak" in a skill's `description` frontmatter — the failure mode where procedural details in the description cause Claude to execute a summarized version of the skill instead of the full workflow in the body.

## Why this exists

Claude Code uses the `description` field to decide whether to trigger a skill. Once triggered, Claude is also expected to read and follow the full workflow in the SKILL.md body.

There's a subtle failure mode: if the description already reads like a workflow summary ("runs unit and integration tests in parallel, then gates E2E, then reports coverage"), Claude may treat the description itself as sufficient instruction and skip the body. The skill then "leaks" a shortened version of its workflow through the description, and the shortened version is what gets executed.

The fix is structural: descriptions should contain **only** trigger material (what the user might say, when to reach for the skill) — never procedural steps. The workflow belongs in the body.

## When to invoke

- User asks to audit a skill description, harden it, or "leak-proof" a skill
- User reports a skill is running a simplified version of its workflow
- User is writing a new skill and wants to avoid leaks up front
- You notice a skill whose description reads like a process summary rather than a list of trigger phrases

## Instructions

When invoked, identify the target skill. If the user specifies a path, use it. If unclear, ask. Run the steps below in order. At the end, report findings and offer to apply the rewrite.

## 1. Read the target SKILL.md

Use the Read tool to load the full file. Parse the YAML frontmatter and isolate the `description` value. Keep the body content in mind for Step 4.

## 2. Classify the description content

Sort every phrase in the description into one of two buckets:

- **Trigger material** — user phrases, keywords, scenarios, contexts in which the skill should activate
- **Workflow material** — ordered steps, tool invocations, procedural verbs, "how it works" narrative

A clean description is 100% trigger material. Any workflow material is a leak.

## 3. Detect leak patterns

Flag the description as leaky if it contains any of the following. Cite the exact offending phrases in your report.

- [ ] **Ordered or sequential steps** — "first X, then Y, then Z", numbered lists inside the description, "after/before" chains
- [ ] **Tool or implementation specifics** — "runs pytest with coverage", "calls the GitHub API via gh", "uses ripgrep to..."
- [ ] **Compound workflow verbs** — "parallel unit/integration tests and gated E2E", "investigation and resolution workflow"
- [ ] **Outcome narratives** — "comprehensive review that covers X, Y, Z and produces a report"
- [ ] **Scope adjectives attached to verbs** — "comprehensive", "full-stack", "end-to-end", "multi-stage" modifying a workflow verb
- [ ] **Multiple distinct actions joined by "and"** — a reliable tell that procedure is bleeding in ("scans X and rewrites Y and validates Z")
- [ ] **Step counts or phase counts** — "5-step process", "three-phase workflow"
- [ ] **"How" language** — any sentence that answers *how* the skill works rather than *when* to use it

If zero patterns match, the description is clean. Report that and stop — no rewrite needed.

## 4. Verify the workflow exists in the body

Before rewriting, confirm that the full workflow is actually present in the SKILL.md body. If the description was the only place the workflow lived, extract it into the body first. Never delete workflow content without preserving it.

This matters because the user may have been relying on the leaked description as the de facto workflow. Moving it to the body is the actual fix — trimming the description alone would silently remove instructions.

## 5. Rewrite the description

Produce a new description containing only:

- A short phrase describing what the skill is **for** (not **how** it works)
- Concrete trigger phrases the user is likely to type, quoted where natural
- Contexts or scenarios in which the skill should activate

Keep it direct. Think of the description as answering "when should Claude reach for this skill?" — nothing more. If you find yourself explaining a procedure, stop and move that text to the body.

### Transform examples

See [references/transform-examples.md](references/transform-examples.md) for three concrete leaky→clean pairs (testing, debug, and review skills). Consult it when you need a template, especially if the original description mixes multiple leak patterns.

## 6. Apply the edit

Use the Edit tool to replace only the `description:` line in the frontmatter. Do not touch the body of SKILL.md during this pass unless Step 4 required moving workflow content there.

After editing, re-read the file and confirm:

- [ ] YAML frontmatter still parses (`name`, `description`, and any other fields intact)
- [ ] The body contains the full workflow
- [ ] The new description matches none of the leak patterns from Step 3

## 7. Report

Tell the user:

- Which leak patterns you found, with the exact offending phrases
- The before/after description, side by side
- Whether any workflow content had to be moved into the body (and what)
- Any trigger coverage concerns — if the original description had unique user phrases you couldn't preserve, call them out

## Testing the fix

The only meaningful test is behavioral: does the skill still trigger on the user phrases it is supposed to catch?

- If the user reports the skill fails to trigger after the rewrite, add **more concrete trigger phrases** — more quoted user utterances, more scenarios. Do **not** re-inject workflow details.
- If the skill triggers reliably, you're done.

Weak trigger coverage is solved by more triggers, never by leaking workflow back into the description. Leaked workflow may improve triggering on the margin, but it costs you correct execution — which is a much worse trade.

## What not to do

- **Don't rewrite the skill body on the same pass.** Scope creep defeats the audit. If the body also needs work, do it in a separate pass with the user's explicit agreement.
- **Don't delete workflow text from the description until you've confirmed it exists in the body.** Preserve first, trim second.
- **Don't add `ALWAYS` or `MUST` language** to compensate. Those don't fix leaks; they just make the description heavier without changing how Claude reads it.
- **Don't rename the skill or change other frontmatter fields** unless the user asks.
- **Don't add workflow back "just to be safe"** if triggering seems weak. The fix is more user-phrase examples, not more procedure.

## Origin

Based on the observation described in the article "Утечка workflow в скилах Claude Code" (blognot.co, 2026): skill descriptions that contain procedural details cause Claude to treat the description as the workflow and skip the SKILL.md body. The concrete case cited was a "code review between tasks" description that produced a single-pass review instead of the multi-stage procedure defined in the skill body.

## Delegation (Claude Code only)

> **Skip this section unless you are Claude Code.** The Agent tool with
> `subagent_type:` parameters is a Claude Code feature. Codex, Cursor, Gemini,
> OpenCode, and other hosts do not have it — run the full workflow yourself
> instead.

Two phases of this skill can move off Opus when the session permits.

**Scan phase (to haiku).** When the user points this skill at a whole skills
tree rather than a single SKILL.md, the collection pass (walking the tree,
reading every `SKILL.md`'s frontmatter, extracting and measuring the
`description` field) is pure bulk I/O. Delegate to the `readonly-scanner`
subagent (model: haiku) via the Agent tool with `subagent_type: readonly-scanner`.
Ask it to return, per skill: `path`, `name`, full `description` text, character
count, and whether the description contains imperative verbs, numbered steps,
or compound "and" actions (flag candidates, not verdicts).

**Rewrite phase (to sonnet).** Once you have classified the leaks in Step 3
and confirmed the workflow lives in the body (Step 4), the mechanical rewrite
of the `description:` field is a tight Sonnet-tier job. Delegate Step 6 to the
`skill-rewriter` subagent (model: sonnet) via the Agent tool with
`subagent_type: skill-rewriter`. Give it:

- the skill path,
- the list of leak patterns you detected with the exact offending phrases,
- the instruction: description-only rewrite, trigger material only, no body
  edits unless Step 4 required moving content there.

Keep the leak classification (Step 3), the workflow-presence check (Step 4),
the final before/after report (Step 7), and any body-moves in this session.
