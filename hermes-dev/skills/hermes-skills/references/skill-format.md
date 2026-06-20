# Hermes skill format

Facts verified 2026-06-09 against hermes-agent.nousresearch.com/docs and
github.com/NousResearch/hermes-agent, Hermes Agent v0.16.0 "The Surface
Release" (June 5, 2026). Hermes ships multiple minor releases per month —
re-verify before shipping.

## Discovery paths

| Priority | Path | Notes |
|---|---|---|
| 1 | `~/.hermes/skills/<category>/<skill-name>/SKILL.md` | Primary. **Two levels**: category, then skill. A skill placed directly under `~/.hermes/skills/` is not indexed. |
| 2 | `<project-root>/skills/` | Repo-shared; flat (no category level required here). |
| 3 | dirs listed in `skills.external_dirs` (config.yaml) | Extra trees, scanned as-is. |

`skills.external_dirs` is the cross-tool sharing trick — point Hermes at a
shared tree that other agentskills.io hosts also read:

```yaml
# ~/.hermes/config.yaml
skills:
  external_dirs:
    - ~/.agents/skills      # one canonical copy for Hermes + Codex + others
```

Categories are plain directories (`engineering/`, `research/`, `writing/`, …).
Hermes also surfaces a category from `metadata.hermes.category`; keep the
directory and the metadata value consistent.

## Directory layout

```
<skill-name>/
├── SKILL.md            # required
├── references/         # optional: depth, loaded only when the skill runs
├── templates/          # optional: files the skill instantiates
├── scripts/            # optional: executables the skill invokes
└── assets/             # optional: images, data
```

## Frontmatter

Required:

| Field | Notes |
|---|---|
| `name` | kebab-case, matches the directory name |
| `description` | third-person, trigger-phrase-rich — the selection surface |
| `version` | **Hermes-specific requirement** (semver string). Other agentskills.io hosts (Claude Code, Cursor, Codex) don't need it — ported skills routinely miss it. Drives update flows and `skill_manage` versioning. |

Optional, Hermes-recognized:

| Field | Notes |
|---|---|
| `metadata.hermes.tags` | list of tags for catalog filtering |
| `metadata.hermes.category` | category string (mirror the directory) |
| `metadata.hermes.config` | skill-specific config mapping |
| `platforms` | e.g. `[linux, macos, windows]` — skill hidden elsewhere |
| `required_environment_variables` | listed env vars must be set or the skill reports itself unavailable |
| `requires_toolsets` | toolsets that must be enabled for the skill to load |
| `fallback_for_toolsets` | skill activates as a fallback when these toolsets are absent |

Everything Hermes-specific that isn't one of the standalone keys above goes
under `metadata.hermes.*` — a mapping (the validator errors with
`hermes-skill-metadata` if it isn't one). Other hosts ignore the whole
`metadata` block, so the skill stays portable.

```yaml
---
name: deploy-checklist
description: Use when deploying the service. Triggers on "deploy", "ship to prod".
version: 0.3.1
metadata:
  hermes:
    tags: [ops, deploy]
    category: engineering
    config:
      default_env: staging
platforms: [linux]
required_environment_variables: [DEPLOY_TOKEN]
requires_toolsets: [shell]
---
```

## Activation model

Progressive disclosure, two stages:

1. `skills_list()` — the model sees only catalog metadata (name, description,
   version, tags) for every installed skill; ~3k tokens total.
2. `skill_view()` — the full SKILL.md body is loaded on demand when Hermes
   decides (or is told) to use the skill.

Triggers:

- **Description match** — Hermes selects the skill when the conversation
  matches the description. Write descriptions in third person with literal
  trigger phrases.
- **Slash command** — `/skill-name` invokes it explicitly.

References/templates/scripts under the skill directory are loaded or executed
only when the body asks for them — keep SKILL.md lean and push depth down.

## Machine edits: skill_manage

Hermes autonomously **creates and patches its own skills** after completing
complex tasks, via the built-in `skill_manage` tool. Consequences for authors:

- Expect machine edits to installed copies; keep the canonical source in git
  and treat the installed tree as a working copy.
- Keep `version` meaningful — `skill_manage` bumps it on edit, and update
  flows compare versions.
- Don't encode invariants only in formatting/comments; Hermes may rewrite
  the body while preserving frontmatter semantics.

Verified 2026-06-09 — hermes-agent.nousresearch.com/docs (skills),
github.com/NousResearch/hermes-agent, v0.16.0.
