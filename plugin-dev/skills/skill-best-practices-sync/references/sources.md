# Research sources for skill-best-practices-sync

Use this list when dispatching Phase-2 research agents. Group sources into clusters and spawn one agent per cluster, in parallel.

## Cluster A — Anthropic primary sources (highest weight)

- `https://docs.claude.com/` — skill-authoring docs, plugin docs, Claude Code docs
- `https://docs.anthropic.com/` — Agent SDK, tool use, prompting
- `https://www.anthropic.com/engineering` — engineering blog posts
- GitHub: `anthropics/skills`, `anthropics/claude-code`, `anthropics/anthropic-cookbook`
- Anthropic's applied-AI guides (prompt engineering, tool use)

Queries to run:
- `site:docs.claude.com skills`
- `site:anthropic.com skill authoring`
- `"SKILL.md" best practices`
- `progressive disclosure skill claude`

## Cluster B — Named practitioners

- Simon Willison: `simonwillison.net` — tagged `#claude`, `#llms`, `#ai-agents`, `#skills`
- Andrej Karpathy: `karpathy.ai`, plus his long-form X threads that get mirrored to blogs
- Ethan Mollick: `oneusefulthing.org`
- swyx / Latent Space: `latent.space`, `swyx.io`
- Shopify engineering blog (they publish on agent patterns)
- Geoffrey Huntley: `ghuntley.com` — posts on Claude Code skills and agent engineering

Queries to run:
- `skills claude code <author>`
- `<author> agent skill authoring`
- Search within their RSS feeds for the last 6 months

## Cluster C — GitHub community repos

Look for repositories that:
- Explicitly curate or review skills (not just store them)
- Have been updated in the last 3 months
- Have >50 stars OR a clear author reputation
- Cite their sources (a sign of a serious maintainer)

Queries to run:
- `"awesome-claude" skills`
- `"claude-skills"` or `"claude-code-skills"` sorted by recently updated
- `SKILL.md` in-file search sorted by most starred

Red flags — skip repos that:
- Were last updated > 6 months ago
- Are pure dumps of SKILL.md files with no editorial commentary
- Have SKILL.md descriptions that obviously leak workflow (they'd be importing bad patterns)

## Cluster D — Talks, papers, conference writeups

- Anthropic's Dev Day / Code with Claude talks (YouTube + any written recaps)
- Agent-building conference talks from AI Engineer Summit
- Any Anthropic-published model cards / system prompts that mention skills

These are lower priority — only pull if Cluster A-C produced little.

## Agent prompt template

When you dispatch a Phase-2 research agent, give it roughly this:

```
Research current best practices for authoring Claude Code skills (SKILL.md files).
Focus on material dated within the last ~6 months. Check these sources:
<paste the relevant cluster>

For each useful finding, return:
- URL
- Publication date (or "unknown")
- Author
- The pattern/rule in one sentence
- Why it improves skill quality in one sentence

Do NOT return quotes longer than a few sentences. Do NOT return a link dump
without synthesis. If a source turns out to be low-signal, drop it. Return
3–8 findings max.
```

## What counts as a "pattern"

Useful, concrete, actionable:

- "Trigger descriptions should contain user phrases, not workflow steps." (testable)
- "Body > 500 lines should split into `references/` with pointers." (testable)
- "Avoid `MUST`/`ALWAYS` caps in favor of explaining the *why*." (testable)

Not useful — too vague to apply:

- "Skills should be high quality."
- "Write clearly."
- "Use the right tool for the job."

Drop the vague ones. They waste the user's attention in Phase 4.
