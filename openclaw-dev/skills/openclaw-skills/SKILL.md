---
name: openclaw-skills
description: Use when authoring, gating, debugging, or distributing skills for OpenClaw. Triggers on "OpenClaw skill", "openclaw metadata frontmatter", "skill not loading in OpenClaw", "ClawHub skill", "OpenClaw workspace skills", "publish to ClawHub".
---

# openclaw-skills

OpenClaw — Peter Steinberger's open-source personal AI assistant (renamed Clawdbot → Moltbot → OpenClaw in January 2026; CalVer releases, current 2026.6.5) — reads AgentSkills-format `SKILL.md` skills, the same base format as Claude Code and Codex. What's OpenClaw-specific is exactly where skills break:

- The `metadata` frontmatter block must be **single-line JSON**, not nested YAML — the signature OpenClaw formatting trap.
- A **six-level precedence** where a same-name skill **silently shadows** lower levels — there is NO merging.
- **Gating at load time** (`requires.bins` / `anyBins` / `env` / `config`, `os`) — a skill that fails its gate simply never appears.
- Skills are **snapshotted at session start** — editing a skill mid-session does nothing without the watcher.
- Distribution runs through **ClawHub** (clawhub.ai, 13k+ skills — "npm for AI agents").

All facts verified 2026-06-09 against docs.openclaw.ai (tools/skills, tools/creating-skills, tools/skill-workshop, clawhub), OpenClaw 2026.6.5.

## Reference map

| When you need… | Read first |
|---|---|
| Frontmatter fields, the metadata JSON schema, precedence, gating semantics, per-skill config, snapshot/watcher behavior, Skill Workshop | `references/skill-format.md` |
| ClawHub search/install/update, the `clawhub` CLI, publishing gates, lockfile, commit pinning, telemetry opt-out | `references/clawhub-distribution.md` |

## The shape in 30 seconds

A skill is a directory with `SKILL.md`. Identity comes from the frontmatter `name` (directory name is only the fallback):

```yaml
---
name: release-notes
description: Use when the user asks to draft release notes from recent commits.
homepage: https://example.com/release-notes
user-invocable: true
metadata: {"openclaw": {"emoji": "📝", "os": "darwin", "requires": {"bins": ["git"]}, "install": [{"id": "git", "kind": "brew", "formula": "git", "bins": ["git"], "label": "Git"}]}}
---
```

The `metadata` value is **one line of JSON**. A nested YAML block under `metadata:` parses as YAML but OpenClaw will not read it the same way — keep it single-line JSON (the deterministic lane errors on anything else: `openclaw-skill-metadata-json`). Legacy `metadata.clawdbot` keys are still accepted.

## Decision rules

### Where should the skill live?

Precedence, highest wins — and a same-name skill at a higher level **silently shadows** all lower ones, no merge, no warning:

1. `<workspace>/skills` — workspace
2. `.agents/skills` — project
3. `~/.agents/skills` — personal
4. `~/.openclaw/skills` — managed (ClawHub installs)
5. Bundled skills
6. `skills.load.extraDirs` + plugin-provided skills

Debugging "my edit does nothing": check whether a higher level carries the same `name`. Shared-with-the-repo skills go in `.agents/skills`; yours-everywhere in `~/.agents/skills`; leave `~/.openclaw/skills` to the installer.

### Why isn't my skill loading at all?

Gating is evaluated at load: every `requires.bins` entry must be on PATH, `anyBins` needs at least one, `env` vars must be set, `config` paths must be truthy in `openclaw.json`; `os` restricts platform. A failed gate hides the skill with no error. `always: true` bypasses gating — reserve it for skills that genuinely must always load. Full semantics in `references/skill-format.md`.

### Why doesn't my edit show up mid-session?

Skills are **snapshotted at session start** and injected as compact XML. Mid-session refresh happens only via the file watcher (`skills.load.watch`, debounced by `watchDebounceMs`) or when a new remote node joins. Otherwise: start a new session after every skill change — this is the first thing to check before debugging anything else.

### How do users configure or restrict the skill?

Per-skill config lives in `skills.entries.<name>`: `enabled`, `apiKey` (a SecretRef paired with the skill's `primaryEnv`), `env`, `config`. **Gotcha:** `skills.entries` env/apiKey inject into the HOST agent run only — inside a sandbox they do not pass through unless explicitly forwarded. Per-agent allowlists: `agents.defaults.skills` and `agents.list[].skills` (an empty array means zero skills for that agent).

### Should the agent edit skills itself?

Route agent-drafted changes through the **Skill Workshop** (docs.openclaw.ai/tools/skill-workshop): a proposal queue where the agent drafts skill changes and a human approves before they land. Don't have the agent write directly into live skill directories.

### How do I ship it?

ClawHub. `openclaw skills search/install/update --all` for consumers, or the standalone CLI (`npm i -g clawhub`): `clawhub login`, `clawhub install <slug>` (writes `./skills` + `.clawhub/lock.json`), `clawhub sync --all`, `clawhub skill publish --slug … --version … --changelog … --tags …`. Publishing gate: GitHub account ≥1 week old. Since 2026.6.5, installs are pinned to GitHub commits and validated by install-policy. Telemetry: `CLAWHUB_DISABLE_TELEMETRY=1`. Details in `references/clawhub-distribution.md`.

## Deterministic gate

```bash
bash scripts/validate.sh path/to/artifact --json | jq .
```

Errors on missing/empty `name`+`description` frontmatter (`openclaw-skill-frontmatter`) and on any `metadata` value that is not single-line jq-parseable JSON (`openclaw-skill-metadata-json`). Fix errors before shipping.

## Anti-patterns this skill catches

- `metadata:` written as an indented YAML block — valid YAML, wrong for OpenClaw; it must be single-line JSON.
- Same-name skill at two precedence levels and the author expects a merge — the higher one silently wins wholesale.
- Editing a skill mid-session and concluding it's broken — snapshot staleness; new session or `skills.load.watch`.
- `always: true` slapped on to "fix" a gating problem — fix the `requires` block instead.
- A sandboxed agent expected to see `skills.entries` env/apiKey — host-run only; forward explicitly.
- Hand-editing `~/.openclaw/skills` — that's the managed tree; ClawHub updates will fight you.
- Publishing under a fresh GitHub account — ClawHub requires the account to be ≥1 week old.

## Sources

- OpenClaw, *Skills* — format, precedence, gating, snapshot/watcher, per-skill config ([docs.openclaw.ai/tools/skills](https://docs.openclaw.ai/tools/skills)). Verified 2026-06-09 (OpenClaw 2026.6.5).
- OpenClaw, *Creating skills* — frontmatter fields, metadata JSON, install specs ([docs.openclaw.ai/tools/creating-skills](https://docs.openclaw.ai/tools/creating-skills)). Verified 2026-06-09.
- OpenClaw, *Skill Workshop* — proposal queue ([docs.openclaw.ai/tools/skill-workshop](https://docs.openclaw.ai/tools/skill-workshop)). Verified 2026-06-09.
- OpenClaw, *ClawHub* — registry, CLI, publishing gates, 2026.6.5 commit pinning ([docs.openclaw.ai/clawhub](https://docs.openclaw.ai/clawhub)). Verified 2026-06-09.

When upstream behavior changes, update the references — not this SKILL.md.
