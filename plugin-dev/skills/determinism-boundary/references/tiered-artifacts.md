# Schema-versioned persisted artifacts

The determinism boundary extends past the plugin's *own* files to the artifacts
it **writes for the user** — a research report, a plan, a business assessment, a
metrics file. If a plugin persists a structured document that later steps (its
own or another plugin's) read back, that document is domain data, and the same
rule applies: **the shape a script can check belongs to a script, not to prose
that hopes the model kept the format.**

This is the artifact analogue of validating structure. `validate-plugin.sh`
proves the *plugin* is well-formed; a domain scanner proves the *artifacts the
plugin emits* are well-formed. Both live in the deterministic lane.

## When this applies (the gate)

**Only when the plugin persists a structured artifact a consumer reads back.**
A plugin whose skills answer inline and write nothing structured — most authoring
and review plugins — has no artifact to schema and should skip this entirely.
Don't invent a persisted format just to have something to scan; that is the
artifact-level version of "don't invent checks just to install a kit."

Signals that this *does* apply:

- A skill writes a file to a known path (`business/BUSINESS.md`, `plans/*.md`,
  `market-research.md`) that another skill, agent, or roll-up later parses.
- The format has required sections, an enum-valued field, or per-section bounds
  that today live only in prose the model is asked to honor.
- Two skills must agree on the format (one writes, one reads) — the contract
  wants to be machine-checked, not restated in both SKILL.md files.

## The three pieces

Give a schema'd artifact all three, in the plugin's own `scripts/` lane.

### 1. A schema version

Stamp the artifact and its format doc with a schema version. The format doc
(e.g. `references/<artifact>-format.md`) is the human spec; the version is the
contract handle. When the format changes shape, bump the version — the scanner
keys its rules off it, and a consumer can refuse an artifact whose schema it
predates. Precedent: coder-plugins business `market-research-format.md` and
`plan-format.md` moved to **schema 2** when depth tiers and new sections landed.

### 2. A deterministic scanner with per-artifact ceilings

Add a `validate-<artifact>.sh` (or a small `<artifact>-scan.py` where the parse
is beyond bash) to the plugin's `scripts/`, on the **shared findings contract** —
source `lib/findings.sh`, emit one `add_finding <severity> <rule-id> <category>
<relpath> <line|0> "<msg>"` per check, end with `render_findings`. It asserts
only decidable facts about a written artifact:

- Required sections present; the schema-version line present and known.
- Enum-valued fields in range (e.g. `depth: triage|brief|standard|deep`).
- **Per-artifact ceilings keyed to the schema/tier** — a `brief` artifact may
  carry fewer sections or a lower size ceiling than a `deep` one; the scanner
  enforces the ceiling for the tier the artifact declares. This is what
  `business-scan.py` does: each artifact type and depth has its own bound.
- Cross-artifact consistency where one file references another.

Same severity discipline as any validator: hard violations `error`, shoulds
`warn`, regex candidates `warn`, nudges `info`. The scanner **reads and reports;
it never edits** the user's artifact.

### 3. Fixture coverage

A check nobody proved fires is a check that silently rots. For each scanner rule,
commit fixtures under the plugin's `scripts/` (or `tests/`) and assert the
scanner's verdict on them:

- **At least one happy fixture** the scanner passes (a well-formed artifact — and
  where tiers exist, one per meaningfully different tier, e.g. a happy `brief`
  and a happy `deep`).
- **At least one deliberately-broken fixture per check** the scanner flags — a
  bad-depth enum value, a missing required section, an over-ceiling artifact — so
  a regression that stops flagging it fails the fixture test.

Fixtures are how the deterministic lane stays honest as the format evolves;
without them a schema bump can quietly disable half the checks.

## Optional: staleness markers

Niche, and only for plugins that maintain a **registry or roll-up** across many
artifacts (a portfolio sweep, a metrics dashboard). Such a plugin can treat *age*
as a decidable field: stamp each artifact with a date, and have the roll-up
scanner flag entries past a threshold (coder-plugins uses **>90 days → STALE** in
its business and compass roll-ups). This is a deterministic check like any other
— a date compared to a bound — but it earns its place only when there is a
roll-up whose job is to notice neglected entries. A single-artifact plugin has
nothing to go stale against; skip it.

## Anti-patterns

- A SKILL.md that lists "the report must contain sections X, Y, Z" in prose and
  trusts the model to comply — that list is a scanner's job.
- A scanner that judges whether the report is *good* (insightful, well-argued) —
  wrong lane; quality stays with the LLM.
- Schema checks with no broken fixture — you don't know they fire.
- A scanner that rewrites or "fixes" the user's artifact — scanners never edit.
- Adding a schema + scanner to a plugin that persists nothing structured — the
  gate above said skip; skipping is the correct outcome, not a gap.
