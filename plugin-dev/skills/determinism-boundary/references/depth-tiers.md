# Depth tiers for expensive skills

Some skills do work whose cost scales enormously with scope: a market-research
pass can be a five-minute sanity check or a multi-hour cited report; a plan can
be two tested edits or a master plan of sub-plans. Running such a skill at one
fixed weight is wrong in both directions — it over-invests on small jobs and
under-delivers on large ones. **Depth tiers let one skill scale to the size of
the job**, chosen up front rather than discovered halfway through.

## When this applies (the gate)

**Only when a skill's effort can vary by roughly an order of magnitude with
scope.** If the cheapest and most expensive reasonable runs of a skill are within
~2–3x of each other, a tier menu is ceremony — the skill should just do the one
sensible thing. Reserve tiers for the genuinely elastic skills: research, report
generation, portfolio/registry sweeps, planning. A small authoring or review
skill that does one bounded thing does **not** get tiers; forcing them on it is
overfitting to what an elastic skill happened to need.

## The pattern

### Ask first

Make the tier the **first** decision, before any expensive work. The skill asks
the operator how deep to go (one `AskUserQuestion` — and note this is exactly why
the asking stays in the skill, never in a dispatched agent; see
`skill-to-agent.md`). Offer a small, named ladder with a one-line cost/output
description each, so the choice is informed.

Precedent vocabularies to reuse rather than reinvent:

- **business** — `triage | brief | standard | deep` (a market-research pass, from
  a quick viability sniff to a fully cited TAM/SAM/SOM report).
- **planning** — `Direct | Light | Standard | Master` (the downward-and-upward
  format ladder: from "just do it, no plan file" to a master plan plus sub-plans).

A skill's ladder should have 3–4 rungs. Two is usually a boolean in disguise;
five is a menu no one reads.

### Confirm scope before assuming

Depth answers *how much*; it does not answer *about what*. After the tier is
chosen, **confirm the scope before committing to it** — the audience, the target,
the subject the expensive pass will run against. Ground it from context, state
the assumption, and get a yes before dispatching. Silently researching against an
assumed audience burns the whole tier on the wrong question; the confirm step is
cheap insurance against an expensive miss.

### Record the tier, then pass it down

The chosen tier is not just a runtime branch — it is **data**:

- **Record it in the artifact.** The persisted output stamps the depth it was
  produced at, so a reader (and a scanner — see `tiered-artifacts.md`, whose
  per-artifact ceilings are keyed to exactly this field) knows what weight of
  evidence it is looking at.
- **Pass it as the dispatch parameter.** When the skill hands batch work to an
  agent (see `skill-to-agent.md`), the tier crosses the boundary as the agent's
  `depth:` argument — the agent scales its effort to the tier the user picked. The
  interview stayed in the skill; the tier is the token it hands off.

## Interaction with the other two lanes

Depth tiers sit at the seam of the whole boundary. The **interview** that picks
the tier is judgment-interactive (skill, main loop). The **artifact** the tier is
stamped into is schema'd and scanner-checked with tier-keyed ceilings
(deterministic lane, `tiered-artifacts.md`). The **batch work** the tier scales
is the dispatched agent (`skill-to-agent.md`). A well-built elastic skill uses all
three references at once.

## Anti-patterns

- A depth menu on a skill whose effort barely varies — ceremony; drop it.
- Asking the tier *after* doing expensive work — the whole point is to choose
  before spending.
- Choosing depth but skipping scope confirmation — right weight, wrong target.
- A tier that lives only as a runtime branch and never reaches the artifact or
  the agent — then the scanner can't check it and the agent can't scale to it.
- Inventing a fresh tier vocabulary when `triage|brief|standard|deep` or
  `Direct|Light|Standard|Master` already fits.
