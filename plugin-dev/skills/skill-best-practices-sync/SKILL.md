---
name: skill-best-practices-sync
description: Use when syncing skills to current best practices. Triggers on "sync skills with best practices", "update skills based on Anthropic guidance", "refresh skills from Karpathy/community advice".
---

# Skill Best Practices Sync

Keep locally installed skills aligned with the current state of the art in skill authoring. Research external sources, synthesize what actually applies, analyze installed skills, propose targeted improvements with clear rationale, then apply only what the user approves.

## Why this exists

Skill-authoring best practices evolve quickly. Guidance from Anthropic's docs, engineers like Andrej Karpathy and Simon Willison, and reputable community repos shifts as model capabilities and the harness change. Skills written six months ago may use patterns now known to undertrigger, leak workflow into descriptions, over-specify with `MUST`/`ALWAYS`, or ignore progressive disclosure.

This skill closes that gap — on demand, not automatically. It brings fresh external wisdom to bear on the user's actual installed skills and produces a concrete, reviewable change proposal.

## Operating principles

1. **Benefits before diffs.** Never edit a skill before the user has seen, in writing, *what* would change and *why it helps*. The user approves each change explicitly. This overrides the natural tendency to jump to implementation.
2. **Cite the source.** Every recommendation names where it came from — a URL, an author, a post date. The user should be able to audit your reasoning.
3. **Respect scope.** Make only the changes the user approves. Do not refactor surrounding content, reformat unrelated sections, or rename skills without explicit request.
4. **Freshness matters.** Training data goes stale. Prefer material dated within the last ~6 months over older posts, unless the older source is canonical (e.g., Anthropic's own skill-authoring doc).
5. **Cache research for a week, and merge — never overwrite.** External findings live at `~/.claude/cache/skill-best-practices-sync/findings.md` and are reused for 7 days from their `updated_at` date. When re-researching, **merge** new findings into the existing cache: add new patterns, update entries with fresher sources, remove only entries actively contradicted by new evidence. Preserve curated wisdom across runs.

## Workflow

Run these phases in order. Do not skip ahead to editing.

### Phase 1 — Scope the request

Ask the user (if not already clear):

- Which skill directories to analyze? Default candidates, in order:
  - The current project's `skills/` directory
  - `~/.claude/skills/`
  - `~/.claude/plugins/` (plugin-bundled skills)
- Any topic focus? (e.g., "just trigger descriptions", "just progressive disclosure", or "full audit")
- Any skills to exclude?

If the user gives a vague "just improve my skills" — default to a full audit across the current project's `skills/` and confirm before expanding.

### Phase 2 — Research fresh best-practice material

**Check the cache first.** External best-practice material does not change fast enough to justify re-researching on every run. Before spawning any research agents, check for a cached findings file at:

```
~/.claude/cache/skill-best-practices-sync/findings.md
```

The file carries YAML frontmatter with an `updated_at: YYYY-MM-DD` field. Compute `today - updated_at`:

- **< 7 days old** → reuse the cached findings verbatim as the Phase 2 output. Tell the user: `Using cached findings from <updated_at> (next refresh available <updated_at + 7 days>).` Then jump to Phase 3. Do **not** re-research, and do **not** touch the cache file.
- **≥ 7 days old, missing, or unreadable** → proceed with fresh research below, then **merge** the results into the cache (see "Merge the cache" below).

Bypass the 7-day gate only when the user explicitly asks ("force refresh", "ignore cache", "re-research now", "refresh best practices"). Even on a forced refresh, the cache is **merged, not overwritten** — the goal is to evolve a single curated list over time, not to wipe it every week.

**Fresh research path.** Spawn parallel research agents (via the Agent tool with `subagent_type: general-purpose`) — one per source cluster — so fetching doesn't serialize. See `references/sources.md` for the canonical source list and search queries. Summarize each agent's return into **cited, dated findings** (url + date + one-line takeaway).

Guidelines:

- Prefer primary sources: Anthropic docs (`docs.claude.com`, `docs.anthropic.com`, the `anthropics/skills` GitHub repo) first.
- Then named practitioners: Simon Willison (`simonwillison.net`), Andrej Karpathy (`karpathy.ai`, his X/Twitter essays reposted to blogs), Ethan Mollick, Shopify engineering, Latent Space, swyx.
- Then community GitHub repos with real traction: look for repositories that explicitly document skill-authoring lessons learned — check stars, recent commits, and whether the README cites sources.
- Skip social-only sources you cannot verify (random tweets without follow-up write-ups, unsourced Reddit comments).

Produce a synthesized list of **actionable patterns**, not a link dump. Each pattern needs: the rule, the source, and one sentence on why it improves skill quality.

**Merge the cache.** After synthesis (only when you ran fresh research), reconcile the new findings with the existing cache at `~/.claude/cache/skill-best-practices-sync/findings.md` instead of overwriting it. Create the parent directory and file if they do not exist (`mkdir -p`).

Reconciliation rules — work bullet-by-bullet, not by blind replacement:

1. **Add** any new pattern from this run that has no matching entry in the cache. Match on the rule itself (semantic equivalence), not just URL. Append to the list with its source and date.
2. **Update** an existing cache entry when the new research confirms the same rule but from a fresher source or with a clearer one-liner. Replace the citation and date; keep the entry.
3. **Remove** a cache entry only when the current research explicitly contradicts it (e.g., Anthropic now recommends the opposite) or when its source has been retracted/deleted. Do **not** remove an entry just because this run did not rediscover it — absence of evidence is not evidence of absence.
4. **Leave untouched** any entry the new research neither confirms nor contradicts. Older curated wisdom stays in the cache until something actively invalidates it.

Before writing, show the user a short change summary: `+N added, ~M updated, -K removed` with a one-line reason per removal. The user may veto any line of the merge.

File shape after merge:

```markdown
---
updated_at: YYYY-MM-DD          # today's date — set on every successful merge
last_full_research: YYYY-MM-DD  # date of the most recent fresh-research pass
---

## External findings (what's current)
- [source, date] pattern → one-line why
- ...
```

The `updated_at` field still drives the 7-day TTL on the next run. Bump it whenever any line of the cache changes.

### Phase 3 — Analyze installed skills

For each target skill directory, enumerate `SKILL.md` files and read each. Record for every skill:

- Current description (copy it verbatim)
- Approximate body length in lines
- Presence of `references/`, `scripts/`, `assets/`
- Any red flags against the Phase 2 patterns (e.g., workflow leak in the description, heavy `MUST`/`ALWAYS` usage, missing trigger phrases, body > 500 lines without hierarchy, no progressive disclosure for large content)
- **Harness-assumption scaffolding**: components that encode a "the model can't X on its own" assumption — rigid retry/cycle caps, mandatory step-by-step decomposition the model may no longer need, model-tier pinning, hand-holding sequences for once-weak capabilities. "Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing" as models improve (Anthropic Engineering, https://www.anthropic.com/engineering/harness-design-long-running-apps). Flag these for re-testing against the current model generation — they are candidates, not defects.

Do not edit anything in this phase.

### Phase 4 — Draft the improvement proposal

Produce a single **proposal report** shown to the user before any edits. Structure:

```
## External findings (what's current)
- [source, date] pattern → one-line why

## Per-skill recommendations
### <skill-name>
- Finding: <what is suboptimal, with quoted evidence from the skill>
- Source: <which Phase-2 pattern(s) this maps to>
- Proposed change: <concrete before → after>
- Benefit: <why this helps triggering / execution / clarity>
- Effort: trivial / small / medium
```

Rules for the proposal:

- Keep one recommendation per bullet — bundling unrelated changes makes it hard for the user to accept some and reject others.
- Show before/after snippets for anything you'd edit, not prose descriptions of changes — the user should be able to see the exact diff they're approving.
- If a skill is already well-aligned with current practice, say so and list no changes for it. Padded reports erode trust; the user should be able to assume every bullet is load-bearing.
- Flag uncertain recommendations with `CONFIDENCE: low` so the user can weight them against the high-confidence ones.
- Prefix harness-assumption findings with `ASSUMPTION:` and propose an **experiment**, not a blind edit — e.g. "relax the 3-cycle cap on a branch and compare outcomes on the next two runs". Scaffolding that still earns its keep stays; the proposal is to test it, never to strip it on faith.

### Phase 5 — Confirm and apply

Ask the user which recommendations to apply. Offer these options via AskUserQuestion:

- Apply all
- Apply only trivial/small effort items
- Let me pick (present a numbered list, user names numbers)
- Skip for now

For every approved change:

1. Use the Edit tool against the target SKILL.md. Change only the lines in scope.
2. Do not touch unrelated frontmatter fields or body sections.
3. Re-read the file afterward and verify YAML still parses and the body is intact.

If a skill lives inside a plugin (its directory sits under a `plugins/<plugin>/skills/` tree with a sibling `plugin.json`), **bump the `version` field in that `plugin.json`** as part of the same change. This matches the user's standing rule that every plugin modification bumps the plugin version.

### Phase 6 — Report

Summarize:

- Files changed with line counts
- Recommendations the user declined (kept as a record — useful next sync)
- Sources cited (so the user can follow up)
- Any follow-up work that's out of scope for this pass (e.g., "skill X's body is 800 lines; splitting into `references/` is worth its own session")

## Defaults and guardrails

- **Never apply changes in Phase 2 or Phase 3.** Research and analysis are read-only.
- **Never rewrite a skill wholesale in one pass.** If a skill needs structural surgery (e.g., progressive disclosure refactor), propose it as a separate follow-up rather than folding it into this sync.
- **Never add `ALWAYS`/`MUST` language** to compensate for weak triggering. Phase-2 findings should push you toward more concrete trigger phrases, not heavier imperatives.
- **Don't import patterns you can't cite.** If you can't find the source after searching, drop the recommendation.
- **Don't delete the user's `references/` or `assets/`** as "cleanup" unless the user asked.
- **Don't bypass the 7-day cache TTL silently.** If the user wants fresh research inside the window, they must ask for it explicitly — otherwise reuse the cache and announce which date it's from.

## Source list and queries

See `references/sources.md` for the up-to-date list of primary sources, search queries to run, and the shape of a useful research agent prompt. Read it before dispatching Phase-2 agents.

## What a good run looks like

- 3–6 external patterns synthesized with dated citations
- A per-skill table with targeted, quoted evidence
- User sees the proposal and picks what they want
- Edits land with minimal surface area and leave the rest untouched
- The user walks away knowing *why* each change was made and *where the idea came from*

## Delegation (Claude Code only)

> **Skip this section unless you are Claude Code.** The Agent tool with
> `subagent_type:` parameters is a Claude Code feature. Codex, Cursor, Gemini,
> OpenCode, and other hosts do not have it — run the full workflow yourself
> instead.

Once the user has approved the per-skill change proposal, applying it is pure
rewrite work. If you are on Opus, delegate the edit phase to the `skill-rewriter`
subagent (model: sonnet) via the Agent tool with `subagent_type: skill-rewriter`.
For each approved change give it:

- the exact skill path,
- the single dimension being aligned (description rewrite, section reorder,
  frontmatter field, etc.),
- the canonical pattern or reference skill,
- the approved change's rationale and any constraints from the proposal.

One invocation per skill, one concern per invocation — so the scope discipline
the rewriter enforces stays tight. Keep Phases 1–4 (scoping, research, proposal
drafting, user approval) in this session. `skill-rewriter` is Read/Edit only —
it cannot create or delete files.
