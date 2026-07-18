---
name: skill-curator
description: Use to review and maintain the personal skills estate — surface stale or unused skills and archive, consolidate, or patch them safely. Triggers on "curate my skills", "which skills are stale", "clean up my skills", "skill maintenance", "archive unused skills", "skill decay".
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Grep, Glob, AskUserQuestion, Task
---

# Skill Curator

Maintain the personal skills estate the way Hermes Agent's Curator does: a
deterministic staleness scan, then a per-skill judgment pass that keeps,
patches, consolidates, or archives — never deletes. Skills are procedural
memory; left unmaintained they proliferate into overlapping, token-expensive
clutter. This skill is the decay half of the lifecycle (the birth half is
`skill-workshop`).

Scripts live at `${CLAUDE_PLUGIN_ROOT}/scripts/`. All scanning is read-only;
the single mutating script (`curator-archive.sh`) only ever moves files.

## Hard safety rules — read before acting

These are invariants, not defaults. They hold for every run:

1. **Plugin/marketplace skills are report-only.** Any skill whose `origin` is
   `plugin` is git-managed and lives in someone's repo. Surface it in the report
   so the user knows it exists, but never archive, patch, or edit it here. Only
   `origin: personal` skills (under `~/.claude/skills`) are actionable.
2. **Nothing is ever deleted.** The worst thing that happens to a skill is a
   move into `~/.claude/skills/.archive/`, reversible with one `restore`.
3. **Pinned skills are never offered for archival.** A skill in state `pinned`
   may be patched if the user asks, but is never presented as an archive
   candidate regardless of age.
4. **Snapshot before the first mutation of a session.** Run
   `curator-archive.sh snapshot` once, before any archive or patch, so the whole
   estate can be rolled back from a tar.gz.
5. **Confirm before acting.** Archiving and patching happen only on an explicit
   per-skill choice via AskUserQuestion. Never batch-archive without asking.

## Step 1 — Scan the estate

Run the deterministic state machine over the personal dir plus any marketplace
repos the user wants surfaced (report-only). Capture the JSON:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/curator-scan.sh" \
  "$HOME/.claude/skills" \
  <marketplace-repo-roots…> \
  --json > /tmp/curator-scan.json
```

`curator-scan.sh` classifies each skill: `fresh` (<30d), `stale` (30–90d),
`archive-candidate` (≥90d), `pinned`, or `report-only` (plugin origin). Age is
the last Skill-tool invocation from session history, or the file mtime when
history has none (`basis: mtime` — session history is pruned, so absence is not
proof of disuse; treat mtime-based staleness as weaker evidence when presenting).

## Step 2 — Present the report

Read `/tmp/curator-scan.json` and present a grouped summary the user can act on:

- **Archive candidates** (personal, ≥90d) — the primary action list.
- **Stale** (personal, 30–90d) — watch list; usually keep.
- **Pinned** — shown for awareness; archival not offered.
- **Report-only** (plugin) — a count and names; no actions.

For each actionable skill show: name, state, age in days, and `basis`
(`usage` vs `mtime` — call out mtime-based ones as lower-confidence).

## Step 3 — Decide per skill

For each **personal** `archive-candidate` (and any `stale` skill the user wants
to act on), use AskUserQuestion to get one choice:

- **Keep** — no change (optionally offer to pin it; see Step 6).
- **Patch** — a targeted fix (rename, tighten description, fix a step). Gather
  what to change.
- **Consolidate into X** — fold this skill into a named sibling, then archive
  this one.
- **Archive** — move it out of the active set.

Do not present pinned or report-only skills as archivable. Batch the questions
so the user answers the actionable set in one pass rather than one prompt at a
time where the UI allows.

## Step 4 — Snapshot, then execute

Before the first archive or patch, snapshot once:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/curator-archive.sh" snapshot
```

Then apply each chosen action:

- **Patch:** where the `stingy-agents:skill-rewriter` agent is available,
  dispatch it (via the Task tool) with the exact edit spec and the skill path;
  it does Read/Edit only. When that plugin is not enabled, apply the edit inline
  with the Edit tool. Either way, re-run
  `bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-skill.sh" <skill-dir>` after and
  confirm it is clean.
- **Consolidate:** apply the merge into the target skill (rewriter or inline),
  validate the target, then archive the now-redundant source (below).
- **Archive:**

  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/curator-archive.sh" archive <slug>
  ```

## Step 5 — Re-propagate reminder

The personal skills are mirrored to other IDE/tool skill dirs by the
`propagate-skill-across-ide-repos` skill. After any archive or patch, remind the
user to re-run that propagation so the cross-IDE copies do not resurrect an
archived skill or drift from a patched one. This skill does not touch the
mirrors itself.

## Step 6 — Pin management (sub-flow)

Pins live in `~/.claude/skills/.curator-pins` — a `version: 1` header followed by
one skill slug per line. A pinned skill is exempt from archival but still
patch-eligible. To pin or unpin, edit that file (create it with the `version: 1`
header if absent). Offer pinning for any skill the user chooses to **Keep** that
keeps resurfacing as an archive candidate — pinning stops the noise without
losing the skill.

## What this skill never does

- Never edits a `plugin`-origin skill or anything under a marketplace repo.
- Never deletes; archival is the floor.
- Never archives without an explicit per-skill choice.
- Never touches the cross-IDE mirrors — it reminds; the user propagates.
