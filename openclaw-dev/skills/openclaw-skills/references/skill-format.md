# OpenClaw skill format reference

The AgentSkills `SKILL.md` format as OpenClaw 2026.6.5 reads it: frontmatter fields, the `metadata` JSON schema, load precedence, gating, per-skill config, snapshot behavior, and the Skill Workshop. All facts verified 2026-06-09 against docs.openclaw.ai/tools/skills and docs.openclaw.ai/tools/creating-skills.

## Identity and layout

A skill is a directory containing `SKILL.md` (plus whatever scripts/assets it needs). The skill's identity is the frontmatter `name`; the directory name is only a fallback when `name` is absent. Two directories with the same frontmatter `name` are the *same skill* for precedence purposes — the higher-precedence one shadows the other completely.

## Frontmatter fields

| Field | Required | Meaning |
|---|---|---|
| `name` | ✅ | Skill identity. Shadows same-name skills at lower precedence levels. |
| `description` | ✅ | Third-person trigger description; what the model sees in the catalog. |
| `homepage` | — | URL surfaced in listings. |
| `user-invocable` | — | Default `true` — the skill is exposed as a slash command. Set `false` to hide it from the command list. |
| `disable-model-invocation` | — | Prevents the model from auto-firing the skill; it remains user-invocable. |
| `command-dispatch` | — | `"tool"` routes the slash command straight to a tool — pair with `command-tool` (which tool) and `command-arg-mode: "raw"` (pass the argument string through unparsed). |
| `metadata` | — | **Single-line JSON** (see below). |

## The metadata block — single-line JSON

The single most OpenClaw-specific rule: `metadata` must be one line of JSON, parseable by `jq`. The current key is `"openclaw"`; legacy `"clawdbot"` is still accepted.

```yaml
metadata: {"openclaw": {"emoji": "🦞", "os": "darwin", "always": false, "requires": {"bins": ["ffmpeg"], "anyBins": ["uv", "pip"], "env": ["OPENAI_API_KEY"], "config": ["browser.enabled"]}, "primaryEnv": "OPENAI_API_KEY", "skillKey": "video-tools", "install": [{"id": "ffmpeg", "kind": "brew", "formula": "ffmpeg", "bins": ["ffmpeg"], "label": "FFmpeg"}]}}
```

Schema of `metadata.openclaw`:

| Key | Type | Meaning |
|---|---|---|
| `emoji` | string | Display emoji in listings. |
| `os` | string | Restrict to a platform (e.g. `"darwin"`). Skill is hidden elsewhere. |
| `always` | bool | `true` bypasses all gating — the skill always loads. Default `false`. |
| `requires.bins` | string[] | **All** must be on PATH at load. |
| `requires.anyBins` | string[] | **At least one** must be on PATH. |
| `requires.env` | string[] | All env vars must be set. |
| `requires.config` | string[] | All `openclaw.json` paths must be truthy. |
| `primaryEnv` | string | The env var a configured `skills.entries.<name>.apiKey` SecretRef pairs with. |
| `skillKey` | string | Override the config key used under `skills.entries`. |
| `install` | object[] | Installer specs: `{id, kind, formula, bins, label}` with `kind` one of `brew` \| `node` \| `uv` \| `go` \| `download`. Lets OpenClaw offer to install missing dependencies. |

**Anti-example** — valid YAML, broken in OpenClaw, and what the deterministic lane flags as `openclaw-skill-metadata-json`:

```yaml
metadata:
  openclaw:
    emoji: 🦞
    requires:
      bins: [ffmpeg]
```

## Load precedence

Highest wins; same-`name` skills at lower levels are **silently shadowed** (no merging, no diagnostics):

1. `<workspace>/skills` — workspace skills
2. `.agents/skills` — project skills (checked into the repo)
3. `~/.agents/skills` — personal, cross-project
4. `~/.openclaw/skills` — managed tree (ClawHub installs land here)
5. Bundled skills (ship with OpenClaw)
6. `skills.load.extraDirs` (config-declared extra directories) and plugin-provided skills

Implications:

- To override a bundled or managed skill deliberately, reuse its `name` at a higher level.
- A stale personal copy in `~/.agents/skills` will mask every ClawHub update of the managed copy — the classic "update didn't take" report.
- Plugin-provided skills sit at the bottom: any user/project skill with the same name replaces them.

## Gating semantics

Evaluated once at load, per skill:

- `requires.bins`: every binary resolvable on PATH.
- `requires.anyBins`: at least one resolvable.
- `requires.env`: every variable set (non-empty).
- `requires.config`: every dotted path truthy in `openclaw.json`.
- `os`: current platform must match.
- `always: true`: bypasses all of the above.

A failed gate hides the skill silently — there is no load error to find. When a skill "doesn't exist", check gates first, precedence shadowing second, snapshot staleness third.

## Per-skill configuration

```json5
// openclaw.json
{
  skills: {
    entries: {
      "video-tools": {
        enabled: true,
        apiKey: { secret: "openai-key" },   // SecretRef; injected as the skill's primaryEnv
        env: { FFMPEG_THREADS: "4" },
        config: { maxClipSeconds: 90 },
      },
    },
  },
}
```

- `enabled: false` is the supported way to switch a skill off without deleting it.
- `apiKey` pairs with the skill's `metadata.openclaw.primaryEnv` — OpenClaw injects the secret as that env var.
- **Sandbox gotcha:** `skills.entries` `env`/`apiKey` inject into the **host** agent run only. A sandboxed run (docker) does not receive them unless explicitly passed through. Skills that must work sandboxed should read config another way or document the forwarding step.

Per-agent allowlists: `agents.defaults.skills` (array of skill names every agent gets) and `agents.list[].skills` per agent. An **empty array means zero skills** — a common surprise when someone sets `skills: []` intending "defaults".

## Snapshot at session start

The skill catalog is snapshotted when a session starts and injected into context as compact XML. Mid-session changes are picked up only when:

- the watcher is enabled — `skills.load.watch: true` (debounce via `skills.load.watchDebounceMs`), or
- a new remote node joins the session.

Otherwise every skill edit requires a **new session** to be visible. Debug ritual: edit → new session → test; or enable the watcher during development.

## Skill Workshop

The Skill Workshop (docs.openclaw.ai/tools/skill-workshop) is a proposal queue for agent-authored skill changes: the agent drafts a new skill or an edit, the proposal is queued, and a human approves or rejects it before anything lands in a live skill directory. Use it whenever the agent is asked to "improve its own skills" — direct writes into live skill trees bypass review and can shadow or break managed copies.

## Sources

- [docs.openclaw.ai/tools/skills](https://docs.openclaw.ai/tools/skills) — precedence, gating, snapshot, config. Verified 2026-06-09 (OpenClaw 2026.6.5).
- [docs.openclaw.ai/tools/creating-skills](https://docs.openclaw.ai/tools/creating-skills) — frontmatter, metadata schema, install specs. Verified 2026-06-09.
- [docs.openclaw.ai/tools/skill-workshop](https://docs.openclaw.ai/tools/skill-workshop) — proposal queue. Verified 2026-06-09.
