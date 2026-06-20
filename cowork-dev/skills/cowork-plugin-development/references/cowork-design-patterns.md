# Cowork design patterns

Patterns specific to Cowork plugin authoring that don't show up (or apply differently) in Code-targeted plugins. Each is grounded in either platform behavior, observed user friction, or established design research — sources at the end.

## Multilingual triggering

Cowork's user base is global and chat-shaped — users write to skills in their own language, often code-switching mid-conversation. A skill's `description` field needs to fire on natural-language phrasings in any language.

### Pattern

The `description` field is the primary triggering surface. Approach:

1. Lead with a one-sentence purpose in English.
2. Follow with **trigger semantics, not literal matching** — explicitly tell Claude this list is "trigger semantics, treat as semantics not literal".
3. List 4-5 high-coverage languages with 3-5 example phrasings each. English, Russian, Spanish, German, French, Mandarin tend to cover most users; add the user's specific languages on top of those.
4. Move the exhaustive list (every language you can think of, with 8+ phrasings each) into the SKILL.md body under a "Triggers" section.
5. Keep the description **under ~800 characters total** to avoid UI truncation when many skills are loaded in the marketplace.

### Anti-pattern

Loading the description with 1500 characters and 12 languages: it gets truncated in Cowork's plugin browser, the truncated portion may include the trigger semantics line, and Claude's matching becomes unreliable.

### Example

```yaml
---
name: marketplace-tour
description: Use to give a calm two-minute read-only map of the basic-harness marketplace — what it is, the four personas, the install flow. Triggers on first-time-user-style natural language in any language — "show me what you do", "what can you do", "what is this", "introduce yourself", "give me a tour", "where do I start", "что ты умеешь", "с чего начать", "qué haces", "preséntate", "was kannst du", "qu'est-ce que tu fais", and equivalents in any language not listed. Treat these as trigger semantics, not literal matching — the full trigger list is in the body.
---
```

The body of that SKILL.md then has a `## Triggers` section with a table covering 8+ languages.

## Connector-aware enrichment

Connectors (Gmail / Calendar / Drive / DocuSign / Slack) are Cowork's MCP layer — MCP via Anthropic's cloud, opt-in per user. Local stdio MCP servers are not supported in Cowork, and custom connectors must be reachable from the public internet via Anthropic's IP ranges, so connectors are the *only* external-data path your skill can count on being offered — and even then, only if the user granted them. Skills that gain capability when a connector is available shouldn't gate on it.

### Pattern

In the SKILL.md body, add a section: `## In Cowork (connector-aware enrichment)`. The section enumerates connectors that enrich the skill and what each one adds. Frame it as **soft enrichment, never required**.

```markdown
## In Cowork (connector-aware enrichment)

When this skill runs in Claude Cowork and the user has granted connectors, it can enrich its inputs without changing the core flow. Connectors are **optional** — never gate the skill on them.

- **Google Calendar** — when the user mentions "I have a meeting with X tomorrow", verify the stakeholder's name against actual calendar events before adding to the Stakeholders section.
- **Gmail** — for partnership / customer / hiring decisions, the skill can ask whether to read the relevant email thread before opening the framework. Read-only and on user request.
- **Slack** — generally avoid; team chat is too noisy to ground a strategic decision against.

In Code (no connectors), all of the above happen via the user typing the answer. The output file is identical either way.
```

### Anti-pattern

A skill that says "this won't work without a Gmail connector" or that silently fails when no connector is granted. Cowork users see connectors as optional integrations; making them required feels presumptuous.

### Decision rule

For each connector your skill might benefit from, ask: **what does the user have to say or paste if the connector isn't there?** If the answer is "nothing reasonable" — they have no fallback — the skill probably shouldn't depend on that connector at all.

## Privacy posture for Routines

Routines run in Anthropic's cloud. Plugin authors must be honest with users about what data crosses that boundary during execution.

### Pattern

Each Routine template ships with a **privacy header**:

```markdown
# Routine: <Workflow Name>

**Trigger:** <schedule | webhook | github event>
**Connectors required:** <list, or "none">
**Privacy:** <one-sentence assessment>
```

The privacy assessment is one of:

- **Acceptable** — the workflow processes only public data or data the user is OK with cloud-routing (e.g., news search queries).
- **Moderate** — local-file content transits Anthropic's cloud during execution; flag the tradeoff.
- **High** — sensitive data (contracts under NDA, reflection content, medical / financial / legal personal data). Mark the routine as **not recommended** with explicit warnings.

Some workflows should not have Routine templates at all — reflection skills, profile-edit skills, anything where the cost of cloud transit is asymmetric. Make that explicit in the plugin's `routines/README.md` ("X and Y are deliberately not Routine-able because…").

### Decision rule

Before shipping a Routine template, ask: **if this workflow ran on Anthropic's cloud and the prompt + connector data + output were logged, would the user mind?** If yes for some users and no for others, the privacy header forces a deliberate read; if yes for all users, don't ship the template.

## Refuse-without-prerequisites

Skills that depend on configuration (preferences files, profiles, schemas) should refuse to run when the prerequisite is missing. The refusal should be **clear, redirective, and non-shaming** — point the user at the right precursor skill.

### Pattern

```markdown
<HARD-GATE>
Refuse to run if the news-preferences file has not been initialized. Tell the user: "I don't have your news preferences yet — run the `news-preferences` skill first to tell me what you actually want to track. Generic headlines aren't useful and I won't fake them." Hand off to that skill.
</HARD-GATE>
```

Why a hard refusal beats a degrade-gracefully default: the degraded version is almost always worse than nothing, and shipping it teaches the user that the skill is low-quality. Refusing forces a deliberate setup that produces a real artifact.

### Anti-pattern

A news digest skill that, when no preferences exist, falls back to "top headlines from generic sources." The user gets a low-value artifact, internalizes that the plugin produces noise, and stops using it. A refusal saying "set this up first, here's the path" leads to a useful artifact next time.

### Decision rule

For each skill with a meaningful precursor, ask: **is the no-precursor fallback genuinely useful, or is it a substitute that hides the problem?** If the latter, refuse and redirect.

## Save-and-resume between phases

Long onboarding flows or multi-phase workflows must save state at every phase boundary, so the user can stop and resume without redoing work.

### Pattern

In a 5-phase onboarding skill:

- Phase 2 (profile bootstrap) — save the profile-draft on phase complete.
- Phase 3 (aha moment) — save the artifact (journal entry / decision / preferences file).
- Phase 4 (automation setup) — save the schedule choice.
- Phase 5 (wrap-up) — log the completion to a `~/.claude/<plugin>.local.md` history file.

The next session reads the local file, sees partial state, and offers "pick up where we stopped / start fresh / skip" before proceeding.

### Why

Cowork users are interruption-prone. The chat surface is mixed with other work — they answer Phase 2's question, get pulled into a meeting, come back two days later. A flow that requires them to start over from scratch is a flow they abandon.

### Anti-pattern

A skill that holds all state in working memory and forgets it when the session ends. By Phase 4 the user has answered eight questions and has nothing to show for it.

## "In Cowork" skill convention

A skill that has Cowork-specific behavior (connectors, scheduled-task framing, file uploads in chat) signals it via a body section:

```markdown
## In Cowork (connector-aware enrichment)

<what changes when running in Cowork with connectors granted>
```

The section sits near the end of the SKILL.md body, before "Sources and rationale". Format is consistent across all skills in the plugin: H2 heading, a one-paragraph framing that "connectors are optional", a bullet list of relevant connectors, a closing line about behavior in Code or Cowork-without-connectors.

This convention keeps the SKILL.md readable by both Code and Cowork users — the core skill description doesn't fragment into "if Code do X if Cowork do Y" branches.

## Skill description discipline

All standard skill-description rules from the `skill-development` and `skill-description-leak-audit` skills apply, plus three Cowork-specific tightenings:

1. **Length under 800 characters.** Cowork's plugin browser truncates long descriptions and the trigger semantics may get cut. Move the long trigger list to the SKILL.md body under "## Triggers".
2. **No first-person.** First-person descriptions ("I help you …") feel salesy in chat. Use third-person operational descriptions ("Use to … Triggers on …").
3. **Trigger semantics, not literal matching.** Explicitly tell Claude that the example phrasings are semantic anchors so it generalizes to unseen phrasings (especially across languages).

The leak-audit pass from `skill-description-leak-audit` still applies — descriptions must not contain procedural content that should live in the body.

## Setup commands for recurring rhythms

Plugins that produce daily / weekly artifacts (briefings, digests, scans) should ship a `setup-<rhythm>.md` slash command that walks the user through Cowork's `/schedule` UI rather than auto-creating the schedule.

### Pattern

`/personal-coach:setup-morning-briefing` does the following:

1. Asks 2-3 questions about cadence (time, days).
2. Builds a scheduled-task prompt (the actual prompt that will run when the task fires).
3. Tells the user verbatim: "Open Cowork → Scheduled → + New task → paste the prompt → set time / days → save."
4. Logs the choice to `~/.claude/<plugin>.local.md`.
5. Hands off, telling the user the first scheduled run is the test.

The command **does not** invoke `/schedule` directly. The scheduled-task UI is an authorization surface the user owns; auto-invoking would feel intrusive and might fail silently if the user denies permission.

### Anti-pattern

A setup command that calls `/schedule` programmatically, or that requires the user to manually edit a YAML file. Cowork users expect a guided UI flow; bypassing it feels Code-flavored.

## Closing-block discipline (Stop-hook independence)

In Code, plugins use Stop hooks for end-of-session cleanup. Cowork supports hooks (Cowork sessions only), but **Anthropic publishes no list of which events Cowork fires** — Stop may or may not be among them — and plugin skills also surface in Claude web chat and the Desktop Chat tab, where hooks are grayed out entirely (see `cowork-platform.md`). So the closing-block discipline lives inside skills, and any Stop hook you ship is a tested enrichment on top, never the contract.

### Pattern

Every long-running skill ends with a clear closing phase:

- Save anything that needs saving.
- Log to the plugin's local history file.
- Tell the user one sentence about what's next.
- Stop.

Example from a personal-coach onboarding skill's Phase 5:

> "You're set up. Files are at `<paths>`. Three next steps when you want them: (a) just talk to me, (b) `/personal-coach:setup-morning-briefing`, (c) `/welcome:tour` for the wider map. We can stop here."

The discipline is "explicit closing, not silent end-of-message." Cowork's chat UX makes silent ends feel like the assistant got stuck or lost the thread.

## Sources

- Multilingual triggering — observed friction in cross-language Cowork sessions; design rule from this plugin's `skill-development` and `skill-description-leak-audit` skills.
- Connector-aware enrichment — Cowork connector documentation ([support.claude.com](https://support.claude.com/en/articles/13837440-use-plugins-in-claude-cowork)) plus pattern observed across well-designed Cowork plugins.
- Privacy posture for Routines — *Automate work with routines* ([code.claude.com](https://code.claude.com/docs/en/web-scheduled-tasks)) plus general data-handling discipline.
- Refuse-without-prerequisites — Cal Newport, *Digital Minimalism* (2019); Yifrah, *Microcopy: The Complete Guide* (2017).
- Save-and-resume — Nielsen, *10 Usability Heuristics* (1994), heuristic 3 (User control and freedom).
- Skill description discipline — this plugin's `skill-description-leak-audit` skill (Snyk ToxicSkills 2025, Repello SkillCheck) plus Cowork's UI truncation observed at ~800-char threshold.
- Closing-block discipline — Yifrah, *Microcopy: The Complete Guide* (2017); chat-UX convention.
