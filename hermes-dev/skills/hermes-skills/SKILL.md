---
name: hermes-skills
description: Use when authoring, porting, or distributing skills for Hermes Agent (Nous Research's agent harness). Triggers on "Hermes skill", "write a skill for Hermes", "hermes skills install", "skill bundle", "Hermes skill tap", "port this skill to Hermes", "skills.external_dirs".
---

# hermes-skills

Hermes Agent (the open-source agent harness by Nous Research — **not** the Hermes model family) reads **agentskills.io-standard SKILL.md** — the same format as Claude Code, Cursor, and Codex, so existing skills largely port as-is. What's Hermes-specific: a **required `version` frontmatter field**, a **category level** in the skills tree, `metadata.hermes.*` extras, skill bundles, a tap-based distribution system with an install-time security scan, and the fact that **Hermes edits its own skills** (the autonomous `skill_manage` tool patches them after complex tasks).

All facts verified 2026-06-09 against hermes-agent.nousresearch.com/docs and github.com/NousResearch/hermes-agent, Hermes Agent v0.16.0 "The Surface Release" (June 5, 2026). **Hermes ships multiple minor releases per month** (v0.14→v0.16 within May–June 2026) — re-verify specifics against current docs before shipping.

## Reference map

| When you need… | Read first |
|---|---|
| Skill paths + the category level, directory layout, frontmatter fields, metadata.hermes.*, activation + progressive disclosure | `references/skill-format.md` |
| `hermes skills install` sources, GitHub taps, /.well-known endpoints, the security scan, skill bundles, skill_manage machine edits | `references/distribution.md` |

## The shape in 30 seconds

```
~/.hermes/skills/<category>/<skill-name>/   # note the CATEGORY level — Hermes-only
├── SKILL.md            # required: frontmatter (name, description, version) + body
├── references/         # optional: depth loaded on demand
├── templates/          # optional
├── scripts/            # optional: executables the skill calls
└── assets/             # optional
```

```yaml
---
name: release-helper
description: Use when cutting a release. Triggers on "cut a release", "tag and ship".
version: 1.2.0            # REQUIRED by Hermes — other hosts don't need it
metadata:
  hermes:                 # Hermes-only extras; other agentskills.io hosts ignore them
    tags: [release, git]
    category: engineering
platforms: [linux, macos] # optional
required_environment_variables: [GH_TOKEN]   # optional
requires_toolsets: [shell]                   # optional; also fallback_for_toolsets
---
```

## Decision rules

### Where does the skill live?

| Scope | Path |
|---|---|
| Personal, all projects | `~/.hermes/skills/<category>/<skill-name>/SKILL.md` — primary; **don't forget the category directory** |
| Repo-shared | `<project-root>/skills/` |
| Cross-tool shared | any dir listed under `skills.external_dirs` in `config.yaml` — point it at a shared tree like `~/.agents/skills` and one canonical copy serves Hermes, Codex, and friends |

### Porting from Claude Code / Cursor / Codex

1. Copy the skill directory as-is — the SKILL.md body needs no changes.
2. Add `version:` to the frontmatter (missing version = the skill still loads on most builds, but `skill_manage` versioning and update flows expect it — the deterministic validator warns as `hermes-skill-no-version`).
3. Place it under a category directory, or add the existing tree to `skills.external_dirs`.
4. Put any Hermes-specific knobs under `metadata.hermes.*` so other hosts keep ignoring them.

### Activation

Progressive disclosure: `skills_list()` exposes only metadata (~3k tokens for the whole catalog) → Hermes calls `skill_view()` on demand. A skill fires on **description match** or explicitly via the `/skill-name` slash command — the description is the selection surface, so make it third-person and trigger-phrase-rich.

### Bundles

A YAML file in `~/.hermes/skill-bundles/` groups several skills under one slash command and prepends an extra instruction block — use a bundle when a workflow always needs the same set of skills together. Shape in `references/distribution.md`.

## Anti-patterns this skill catches

- A skill dropped at `~/.hermes/skills/<skill-name>/` — missing the **category** level; Hermes won't index it.
- Frontmatter without `version` — breaks Hermes's update/`skill_manage` flows; only host that requires it, so ports routinely miss it.
- Hermes-specific config in top-level frontmatter keys — put it under `metadata.hermes.*` to stay portable.
- Hand-maintaining duplicate copies per tool — use `skills.external_dirs` pointing at one shared tree.
- Assuming your skill file is frozen — Hermes **autonomously creates and patches skills** via `skill_manage` after complex tasks; expect machine edits, keep `version` meaningful, and keep the canonical copy in git.
- Shipping an install source that fails the security scan (injection/exfiltration/destructive-command patterns) and telling users to `--force` — fix the skill instead.

## Deterministic gate

```bash
bash scripts/validate.sh path/to/artifact --json | jq .
```

Flags missing/unparseable frontmatter, missing `name`/`description`, missing `version` (warning `hermes-skill-no-version`), and a `metadata.hermes` that isn't a mapping (error `hermes-skill-metadata`).

## Sources

- Nous Research, *Hermes Agent docs — Skills* (paths, category tree, frontmatter, external_dirs, activation, bundles) — [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs). Verified 2026-06-09, v0.16.0.
- Nous Research, *Hermes Agent docs — Skill distribution* (`hermes skills install`, taps, well-known endpoints, security scan) — [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs). Verified 2026-06-09.
- [github.com/NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) — v0.16.0 "The Surface Release" (June 5, 2026), `skill_manage` behavior. Verified 2026-06-09.
- [agentskills.io](https://agentskills.io) — the cross-host SKILL.md standard. Verified 2026-06-09.

When upstream behavior changes (it does, monthly), update the references — not this SKILL.md.
