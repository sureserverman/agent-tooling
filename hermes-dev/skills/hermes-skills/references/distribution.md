# Hermes skill distribution: install sources, taps, bundles, security scan

Facts verified 2026-06-09 against hermes-agent.nousresearch.com/docs and
github.com/NousResearch/hermes-agent, Hermes Agent v0.16.0 "The Surface
Release" (June 5, 2026). Hermes ships multiple minor releases per month —
re-verify before shipping.

## hermes skills install

```bash
hermes skills install <source>
```

Accepted sources:

| Source | Example |
|---|---|
| Official catalog name | `hermes skills install pdf-tools` |
| skills.sh | `hermes skills install skills.sh/<author>/<skill>` |
| Direct SKILL.md URL | `hermes skills install https://example.com/skills/foo/SKILL.md` |
| ClawHub / LobeHub | registry identifiers from either hub |
| GitHub tap | any skill from a tapped repo (see below) |
| Well-known endpoint | a site's `/.well-known/skills/index.json` |

Installed skills land under `~/.hermes/skills/<category>/<name>/`, category
taken from the skill's metadata.

## GitHub taps

Homebrew-style:

```bash
hermes skills tap add myorg/skills-repo     # register a repo as a tap
hermes skills tap list
hermes skills tap remove myorg/skills-repo
```

Default taps ship enabled, including **openai**, **anthropics**,
**huggingface**, and **NVIDIA** skill repos — `hermes skills install <name>`
resolves against the official catalog plus all taps.

Publishing via tap = keep a repo of skill directories (each with a
versioned SKILL.md); consumers tap it once and install/update by name.

## /.well-known/skills/index.json

A site can self-host its skills by serving an index at
`/.well-known/skills/index.json` listing skill names → SKILL.md URLs.
`hermes skills install <domain>` discovers and installs from it. Useful for
product-docs sites shipping a "use our API" skill.

## Security scan

Every install passes a static security scan before activation:

- **Prompt-injection patterns** in the body (e.g. instructions to exfiltrate
  context or override system behavior).
- **Exfiltration** — bodies/scripts that send local data to remote endpoints.
- **Destructive commands** — `rm -rf`, credential harvesting, etc. in
  embedded scripts.

A failed scan blocks the install; `--force` overrides. As an author: never
tell users to `--force` — fix the finding. Test your own skill with a local
install before publishing.

## Skill bundles

A bundle is a YAML file in `~/.hermes/skill-bundles/` that groups several
skills under **one slash command** with an extra instruction block:

```yaml
# ~/.hermes/skill-bundles/release.yaml
name: release
description: Everything needed to cut and announce a release.
skills:
  - engineering/release-helper
  - engineering/changelog-writer
  - writing/announcement-drafter
instructions: |
  Run the release flow end-to-end: tag, changelog, then announcement.
  Ask before pushing tags.
```

`/release` then loads all three skills plus the instruction block. Use a
bundle when a workflow always needs the same skills together; keep individual
skills single-purpose.

## Updating and machine churn

- `hermes skills update [name]` re-resolves against the install source and
  compares `version` — another reason the field is required.
- Local machine edits by `skill_manage` (Hermes's autonomous skill author)
  bump the local version; an update that would clobber local edits prompts.
- Keep canonical sources in git; treat `~/.hermes/skills/` as a managed
  working copy, not the source of truth.

Verified 2026-06-09 — hermes-agent.nousresearch.com/docs (skills,
distribution), github.com/NousResearch/hermes-agent, v0.16.0.
