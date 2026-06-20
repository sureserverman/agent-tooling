# ClawHub distribution reference

How OpenClaw skills are published and consumed through ClawHub. All facts verified 2026-06-09 against docs.openclaw.ai/clawhub, OpenClaw 2026.6.5.

## What ClawHub is

ClawHub ([clawhub.ai](https://clawhub.ai)) is the public registry for OpenClaw skills — 13k+ skills as of June 2026, positioned as "npm for AI agents". Skills are published from GitHub repositories; since OpenClaw 2026.6.5, installs are **pinned to GitHub commits** and validated by install-policy before anything lands on disk.

## Consuming skills

Two equivalent surfaces:

### Inside OpenClaw

```bash
openclaw skills search <query>
openclaw skills install <slug>
openclaw skills update --all
```

Installs land in the **managed tree** `~/.openclaw/skills` — precedence level 4. A same-name skill in `~/.agents/skills` or the project/workspace trees will shadow the managed copy entirely (see `skill-format.md`).

### The standalone clawhub CLI

```bash
npm i -g clawhub
clawhub login                      # GitHub auth
clawhub install <slug>            # installs into ./skills + writes .clawhub/lock.json
clawhub sync --all                # bring everything to the locked/pinned state
```

`clawhub install` is project-oriented: it writes into `./skills` and records the pin in `.clawhub/lock.json`, so a repo can check in its skill set reproducibly — commit the lockfile.

## Publishing

```bash
clawhub skill publish --slug my-skill --version 1.2.0 --changelog "fix gating" --tags "git,release"
```

- **Publishing gate:** the authenticated GitHub account must be **≥1 week old**. Fresh accounts are rejected — plan for this when automating publishes from CI service accounts.
- Versions are yours to choose (`--version`); the registry tracks the GitHub commit each version points at.
- `--changelog` and `--tags` populate the registry listing; tags drive search.

## 2026.6.5 hardening

Two changes shipped in OpenClaw 2026.6.5 that affect distribution:

1. **Commit pinning** — installs resolve to a specific GitHub commit, not a floating branch. `clawhub sync --all` reconciles local state to the pins in `.clawhub/lock.json`.
2. **Install-policy validation** — every install is validated against the configured install policy before files are written. A skill that fails policy does not install; surface the policy error rather than retrying.

## Telemetry

The clawhub CLI emits telemetry by default. Opt out with:

```bash
export CLAWHUB_DISABLE_TELEMETRY=1
```

Set it in CI and in privacy-sensitive environments; document it in your skill's README if your users care.

## Publishing checklist

1. `bash scripts/validate.sh <skill-dir>` — frontmatter and metadata JSON clean (`openclaw-skill-frontmatter`, `openclaw-skill-metadata-json`).
2. Gates honest: `requires` lists every binary/env the skill actually shells out to; `install` specs offered for anything brew/node/uv/go/download can provide.
3. `description` is third-person and trigger-dense; no workflow leak.
4. Test from a clean install: `clawhub install <slug>` into a scratch project, new session, fire the skill.
5. Publish with a real `--changelog`; bump `--version` every time — pinned installs mean silent republish of the same version helps nobody.

## Sources

- [docs.openclaw.ai/clawhub](https://docs.openclaw.ai/clawhub) — registry, CLI commands, publishing gate, pinning, telemetry. Verified 2026-06-09 (OpenClaw 2026.6.5).
- [clawhub.ai](https://clawhub.ai) — registry scale (13k+ skills). Verified 2026-06-09.
