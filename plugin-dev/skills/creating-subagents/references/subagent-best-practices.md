# Subagent best practices

Drawn from Anthropic's Claude Code subagent docs, OpenAI's Codex subagent guide, the OpenCode agent documentation, Cursor's rules/agents reference, and the proven-in-production `testing-expert` bundle at `/home/user/dev/ai-tools/agents/agents/testing-expert/`.

These principles apply across all four hosts. Host-specific mechanisms differ; the design does not.

## 1. Single responsibility

One agent owns one job. If its description needs "…and also…", split it.

**Why**: routing on every host is description-based. A fuzzy description routes poorly in both directions — it steals work from more-specific agents and gets delegated tasks it handles badly. A crisp description makes the agent a reliable specialist.

**How to test**: write the description first. If you can't fit it in ~400 characters without listing unrelated capabilities, split.

## 2. Description IS the router

Across all four hosts, the first line of routing is the agent's `description` field. Invest in it.

A good description contains:

- **Trigger phrases**: the literal strings users type ("run tests", "flaky", "coverage gap").
- **Domain keywords**: so routing is sharp against adjacent agents.
- **A stance sentence**: "Opinionated: <position>". Helps the router disambiguate similar agents.
- **Use-case scope**: "Use when …" or "Use proactively for …".

Does **not** contain:

- Self-description ("You are an expert …") — that belongs in the system prompt.
- Vague mission statements ("helps with code quality") — helps what, when, how?
- Lists of tools — tool surface is a separate field.

Most Anthropic docs recommend a short description. In practice, the testing-expert-style longer description (200–400 chars with explicit triggers) routes noticeably better at the cost of a few tokens. Worth it.

## 3. Minimum viable tool surface

Grant the smallest set that gets the job done. Reason by the agent's job, not convenience:

- **Researcher / reviewer** → read-only (Read, Grep, Glob, Bash for non-mutating commands, optionally WebFetch).
- **Author** → add Edit, Write.
- **Runner / triager** → add Bash fully, but refuse destructive flags (see safety rails).
- **Coordinator** → add `Agent(...)` or equivalent delegation primitive.

Apply per-host:
- Claude Code: `tools:` allowlist or `disallowedTools:` denylist.
- Codex: `sandbox_mode` (`read-only` / `workspace-write`).
- Cursor: `readonly: true` blanket; file-level restriction via host.
- OpenCode: `permission:` block with `edit`/`bash`/`webfetch` rules.

An agent restricted on one host and wide-open on another is a bug, not a feature.

## 4. Explain the why

A rule with a short justification survives edge cases; a bare MUST does not.

Bad:
> 4. NEVER test private methods.

Better:
> 4. Test observable behavior, not implementation. No private-method tests. (*Fowler "UnitTest"; Beck, TDD by Example*.) Testing implementation pins a specific structure and makes refactoring hurt without catching real regressions.

Modern models are smart enough to generalize from the reasoning. They can't generalize from an absolute they don't understand. When you see yourself writing ALWAYS / NEVER / MUST — reframe as "do X because Y" and you'll get better edge-case handling for the same token count.

## 5. Announce protocols / phases

The testing-expert core uses six named protocols (stack detection, execute & triage, gap analysis, authoring, review, coach). The agent announces which one it's in before acting.

**Why**: the user knows what to expect and can interrupt the wrong entry. The agent's outputs stay schema-consistent within a protocol. Composition across protocols is explicit.

This is not required for every agent, but for agents with >2 distinct modes of work, it prevents drift mid-session.

## 6. Output schemas

If the agent produces reports, diffs, reviews, or any structured artifact — name the schema and show its template in the system prompt.

```
Triage Report:
  Run: <cmd> | Duration: <s> | Seed: <n>
  Totals: <pass>/<fail>/<error>/<skip>/<flaky>
  Failure clusters: [C1] <n> — <symptom> — hypothesis — confidence H/M/L
  Minimal repro: <smallest cmd>
  Next action: fix | quarantine | escalate | gather-more-evidence
```

Schemas give downstream tooling something to parse and humans something consistent to scan.

## 7. Safety rails

Every agent that can mutate state needs explicit safety rails in the system prompt:

- **Read before write.** Announce intent before modifying.
- **Refuse destructive inputs.** Production env indicators, `--force`, `rm` in teardown, DB drop/truncate.
- **Confirm billable operations.** Cloud test farms, paid APIs, load-test runs.
- **Escalate, don't guess.** Define the conditions that mean "stop and ask" — unfamiliar framework, high first-run failure rate, secrets in config, live external services.
- **No silent skips.** Quarantine with owner + expiry is fine; silent skip is not.

Do this in the core, not per-host, so the agent behaves the same everywhere.

## 8. Host affordances belong in the wrapper

If a section mentions `TaskCreate`, `apply_patch`, `.mdc`, globs, `permission:`, or any host-specific affordance — it goes in the host wrapper, not the core.

The core should read identically on Claude Code, Codex, Cursor, and OpenCode. If it references proprietary names, you've leaked abstraction layers.

## 9. Citations over appeals to authority

"Follow the pyramid." is a command. "Follow the pyramid (*Fowler, 'The Practical Test Pyramid'*)." is a justification plus a pointer. Cite for:

- Established testing / architecture / security practices (Beck, Fowler, Meszaros, Google Testing Blog, OWASP).
- Industry standards (ThoughtWorks Radar, WCAG, NIST).
- Tool-specific behavior (Stryker operators, Hypothesis shrinking).

Citations survive model changes. Style advice that can't be traced to a source becomes noise.

## 10. Length discipline

Guideline budgets (not hard limits, but good targets):

- **Core file**: 80–200 lines of actual content.
- **Per-host wrapper**: 10–30 lines of host affordances + the embedded core.
- **Description**: 150–400 chars.

Aggressively kill filler. "You should be aware that…" "It is important that you…" — delete these. The subagent's entire system prompt is in its context every turn; wasted tokens cost real money across many invocations.

## 11. Restraint is a feature

A great agent refuses work outside its scope. The testing-expert core has a single line:

> Restraint: throwaway scripts, spikes, and one-shot migrations need no tests; say so plainly.

This is the mark of expertise. Agents that try to do something for every request are annoying; agents that say "you don't need this" earn trust.

## 12. Iterate via the real bundle

Once you have a draft:

1. Run `./build.sh` — confirm the core actually embeds.
2. Install to one host (`install -m 0644 claude-code/<name>.md ~/.claude/agents/`) and try it on two real tasks.
3. Rewrite based on what went wrong, not what you imagined would go wrong.
4. Repeat on each host — different routing behavior will reveal different description issues.

A three-iteration bundle beats a first-draft-perfect bundle. The first draft is guessing; iteration is learning.

## References

- Claude Code subagents: https://code.claude.com/docs/en/sub-agents
- Codex subagents: https://developers.openai.com/codex/subagents
- Codex AGENTS.md: https://developers.openai.com/codex/guides/agents-md
- OpenCode agents: https://opencode.ai/docs/agents/
- OpenCode permissions: https://opencode.ai/docs/permissions/
- Cursor docs: https://cursor.com/docs
- Working bundle: `/home/user/dev/ai-tools/agents/agents/testing-expert/`
