# Skill → agent: when to carve work out of a skill

The determinism boundary splits mechanical from judgment. Judgment itself then
splits again by **where it must run**: some judgment has to stay in the main
conversation loop, and some is better handed to a dispatched subagent. This is
the third lane — the reason the boundary is three-way, not two-way:

| Lane | Owns | Lives in |
|---|---|---|
| **mechanical** | decidable checks, scaffolding | a deterministic script |
| **judgment-interactive** | anything needing the user or the conversation | a skill / command (main loop) |
| **judgment-batch-isolated** | heavy, self-contained judgment work | a dispatched agent |

A skill that does everything inline — interviews the user *and* reads forty files
*and* writes the report — is carrying agent work in the main loop. Carving that
batch work into an agent is the same altitude decision as pushing a check into a
script: put the work where its constraints are cheapest.

## Move it to an agent when — and only when — there is a concrete benefit

Extraction earns its keep on at least one of these. If none apply, it stays in
the skill; possibility is not a reason (the artifact-level echo of "don't invent
checks just to install a kit").

- **Context isolation pays.** The work reads dozens of files or web sources and
  the main conversation needs only the conclusion. Inline, that flood lands in
  the orchestrating context and degrades everything after it; an agent returns
  just the verdict.
- **It fans out.** One unit of work per competitor / file / project, runnable in
  parallel. A skill can't parallelize itself; agents dispatched from a skill can.
- **Model pinning saves money.** Mechanical scanning or rewriting runs fine on a
  cheap tier (Haiku) while the orchestrator stays on the smart one. The pin lives
  on the agent, not the skill. (stingy-agents is this rationale as a whole
  plugin: `readonly-scanner`, `skill-rewriter` pinned small.)
- **Tool scoping is a safety win.** An agent can be handed Read/Edit only, scoped
  to caller-named paths — a guarantee a skill body running with the full tool set
  cannot make about itself.
- **Reuse across skills.** Two skills need the same batch capability. Extract it
  once as an agent both dispatch, instead of duplicating the logic in two
  SKILL.md files.

## Keep it in the skill when

These are hard constraints, not preferences — the first is the load-bearing one.

- **It's interactive.** *Subagents cannot run `AskUserQuestion`.* Anything with a
  depth-tier interview, a confirm-before-assume step, or an approval gate **must**
  stay in the main loop. This is the sharpest edge of the whole rule: the moment a
  step needs to ask the user something, it is not extractable. Interview in the
  skill; hand the *answers* to the agent.
- **It needs conversation context.** An agent receives only the prompt you write
  for it. If the step depends on what the user said three turns ago, or on state
  the session accumulated, reconstructing that in the prompt costs more than the
  handoff saves.
- **It's short.** Dispatch has real overhead — spawn, context transfer, result
  relay. A quick single-file edit or a two-minute check gains nothing from an
  agent and just adds a boundary.
- **The main loop needs incremental state.** If later skill steps branch on
  intermediate results the step produces as it goes, an opaque agent boundary
  hides exactly what the orchestrator needs to see.

## Worked example: business market-research

The canonical split. `business/skills/market-research/SKILL.md` **keeps in the
skill**: the depth-tier question (`triage|brief|standard|deep`), the
confirm-scope step ("research against *this* audience — yes?"), and the final
verdict write. It **dispatches to** `business/agents/market-researcher.md`: the
actual evidence-gathering across competitors and sources — output-heavy,
fan-out-shaped, and needing none of the conversation. The chosen tier crosses the
boundary as the agent's `depth:` dispatch parameter. Interactive part in the main
loop; batch part in the agent; the tier is the handoff token between them.

Note what did *not* get extracted: the interview. That is the rule working — the
part that talks to the user stayed where the user is.

## Refactor vs. greenfield

- **Refactoring** an existing plugin: in the survey, tag each action of each skill
  mechanical / judgment-interactive / judgment-batch-isolated. Only the third tag
  is an extraction candidate, and only if it clears the concrete-benefit bar
  above. Don't push a working, coupled skill into an agent for tidiness.
- **Greenfield**: when a new skill is described as doing heavy non-interactive
  evidence-gathering, plan it as skill-orchestrator + dispatched agent from the
  start, the agent pinned to the smallest model that can do the job.

## Anti-patterns

- Extracting an interactive step into an agent — it cannot ask the user; the
  extraction is simply broken.
- Extracting for elegance with no context / fan-out / cost / scoping / reuse
  benefit — overhead with no payoff.
- Duplicating a batch capability inline in two skills instead of sharing one
  agent.
- Leaving a forty-file read inline in the orchestrator "because it works" — it
  works and it poisons the context the rest of the session depends on.
