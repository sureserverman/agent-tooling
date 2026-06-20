# Example: a Cowork-aware skill

A reference skill demonstrating the four Cowork-specific patterns:

1. Multilingual triggers in the description, with body-level "## Triggers" expansion.
2. Connector-aware enrichment as an additive `## In Cowork` section.
3. Closing-block discipline (no Stop hook — discipline lives in the skill).
4. Refuse-without-prerequisites pattern (illustrative — adapt or remove for your skill).

This is illustrative, not literally a working skill — adapt the body for your domain. The structure is what matters.

---

```markdown
---
name: weekly-summary
description: Use to produce a calm one-page summary of the user's week — what got done, what didn't, what's on tap. Reads from a recent-work log file the user maintains. Triggers on first-message-of-week-style natural language in any language — "summarize my week", "what did I do", "weekly recap", "что я делал на этой неделе", "resumen de la semana", "wochenrückblick", "résumé hebdomadaire", and equivalents in any language not listed. Treat these as trigger semantics, not literal matching — the full trigger list is in the body. Refuses to fabricate; if the log file is empty, says so. Read-only by default; writes the summary only on explicit user save.
---

# Weekly Summary

A calm one-page weekly recap. Reads from a user-maintained log, surfaces what got done, names what didn't, points at what's on tap. Refuses to make things up.

**Announce at start, in the user's language:** something equivalent to "Looking at your log for the week — give me a moment."

<HARD-GATE>
Refuse to run if the user has no work log. Tell the user: "I don't have your work log yet — point me at one (path or URL), or run the `setup-work-log` skill first to create the format I expect. I won't fabricate a summary." Hand off.
</HARD-GATE>

## Triggers (full list, for language detection)

The skill fires on weekly-recap-style natural language in any language. Below is non-exhaustive; Claude generalizes to phrasings not on the list. Use these as trigger semantics.

| Language | Phrases |
|---|---|
| English | summarize my week · what did I do this week · weekly recap · how was my week · weekly summary |
| Russian | что я делал на этой неделе · подведи итоги недели · недельный обзор |
| Spanish | resumen de la semana · qué hice esta semana · recapitulación semanal |
| German | wochenrückblick · was habe ich diese woche gemacht |
| French | résumé hebdomadaire · qu'ai-je fait cette semaine |
| Mandarin | 总结这一周 · 本周回顾 |

If the user writes in another language, the skill still fires — run the flow in that language.

## Phase 1 — Read

Read from the user's work log. Default location: `~/.claude/work-log.md` if present, otherwise the path the user gives. Look at entries from the last 7 days only.

If the log is empty for the week, **say so explicitly**:

> Your log is empty for the last 7 days. Either nothing got logged (in which case the recap is "no logged work this week, here's what you can do next time"), or the log is at a different path. Which is it?

Don't fabricate entries. An empty week is a real signal.

## Phase 2 — Categorize

Group entries into:

- **Shipped** — work that crossed a finish line.
- **In flight** — work that's mid-stream.
- **Stuck / blocked** — work that didn't move because of something else.
- **Started** — work begun this week, regardless of state.

If an entry doesn't fit, leave it uncategorized — better than miscategorizing.

## Phase 3 — Surface what didn't happen

Cross-reference the log against the user's stated goals (in their personal profile, if available). What was a goal at the start of the week and didn't appear in the log?

Surface this carefully — neutrally, not accusatorially. The point is signal, not blame.

## Phase 4 — Render

Produce a one-page summary, in the user's language:

```
Week of <YYYY-MM-DD>

Shipped (N items):
- <title> — <one-sentence why-it-mattered>

In flight (N items):
- <title> — <where-it-stands>

Stuck (N items):
- <title> — <what's-blocking>

Quiet on:
- <goal-from-profile-with-no-log-entries-this-week>

For next week:
- <one-line suggestion grounded in the gaps above>
```

Cap each section at 5 items. If there are more, say "+ N more in your log."

## Phase 5 — Save (or not)

Ask:

> Want me to save this as `<vault-or-claude-dir>/Reviews/YYYY-week-NN.md`? (yes / no / edit)

On yes, write. On no, the recap still happened verbally; nothing on disk. On edit, let the user redact before save.

## Phase 6 — Closing

> That's the week. The log is at `<path>` whenever you want to update it during the week instead of relying on memory. We can stop here.

Stop. Do not chain.

## In Cowork (connector-aware enrichment)

When this skill runs in Claude Cowork and the user has granted connectors, it can enrich the recap without changing the core flow. Connectors are **optional** — the skill works the same without them.

- **Google Calendar** — read the week's events to ground "what got done" against actual meetings. Surface meetings that ran that aren't in the log (often a sign of work the user did but didn't capture).
- **GitHub** — read the user's commits / PRs from the past 7 days, against repos the user has named in their profile. Useful for grounding the Shipped section against actual ship events.
- **Slack** — generally avoid. Slack history is too noisy to ground a weekly recap against.
- **Linear / Jira** — read tickets that closed this week, in projects the user has named. Cross-check against the log's Shipped section.

In Code (no connectors), all the above grounding happens via what's in the log file. The output is identical when the log is comprehensive; less complete when it isn't.

## Hard rules

- **No fabrication.** If the log is sparse, the recap is sparse. Better than fake completeness.
- **No silent saves.** Always ask before writing.
- **No accusation.** "Quiet on X" is descriptive, not corrective.
- **No comparison to past weeks.** Comparisons are easy to render, hard to interpret well; out of scope.

## What this skill is NOT

- Not a productivity-tracking app. It reads what the user logs; it doesn't track anything itself.
- Not a goal-grading skill — that's a different skill (e.g., `decision-grading`).
- Not a journaling prompt — that's `reflection-session`.

## Sources and rationale

- **Refuse-without-prerequisites** — Cal Newport, *Digital Minimalism* (2019); empty-bucket explicit-negative pattern from intelligence analysis (Heuer, *Psychology of Intelligence Analysis*, 1999).
- **Connector-aware enrichment** — Cowork connector design rule from this plugin's `cowork-design-patterns.md`.
- **No fabrication** — anti-hallucination discipline; cited every-item rule from RAG practice.
- **Closing-block discipline** — Yifrah, *Microcopy: The Complete Guide* (2017).
```

---

## What to notice in the example

1. **Description length** — the description above is around 700 characters, well under the 800-char Cowork truncation threshold. Triggers are listed in five languages plus a "treat as semantics" anchor; the body has the full table.
2. **Hard-gate refuse-without-prereq** — illustrative pattern. Adapt if your skill doesn't have a meaningful precursor; remove the gate entirely if the skill works standalone.
3. **`## In Cowork` section** — sits near the end, before "Sources and rationale". Frames connectors as optional enrichment.
4. **`## Triggers` body table** — moves the long multilingual list out of the description and into the body, where Claude reads it as part of language detection.
5. **Closing-block discipline** — Phase 6 explicitly closes the flow ("We can stop here"). No Stop hook needed.
6. **Sources section** — cites primary sources, treats methodology as defensible.

Adapt the structure; don't copy the content.
