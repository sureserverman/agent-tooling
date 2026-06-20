# cowork-dev

Authoring kit for **Claude Cowork** plugins. Part of the [`coder-plugins`](..) marketplace.

## Why a separate cowork-dev?

Cowork runs the same plugin format as Claude Code, but it is a different platform with different rules — and the differences are exactly where plugins break. As of June 2026:

- **Four install paths, none of them slash commands** — the Anthropic catalog, direct ZIP upload, marketplace by URL (GitHub `owner/repo`, public GitLab, Bitbucket), and org private marketplaces — each with hard limits (200 MB / 5,000 files per plugin, 50 MB manual org ZIPs, npm/pip marketplace sources unsupported, reserved-name list enforced).
- **Hooks and sub-agents run only in Cowork** (grayed out in chat) — and Anthropic publishes no list of which hook events Cowork fires. Skills travel further than the rest of the plugin: they also surface in Claude web chat and the Desktop Chat tab.
- **Local stdio MCP is not supported.** Cowork's MCP story is connectors via Anthropic's cloud; custom connectors must be reachable from the public internet.
- **The chat register dominates.** Multilingual auto-triggering skills, connector-aware enrichment, and privacy-honest Routine templates are the native idioms; terminal idioms feel wrong.

[`plugin-dev`](../plugin-dev) owns plugin *structure* (manifest, frontmatter, layout) for both platforms; **cowork-dev owns the Cowork platform**: what's supported, what the limits are, how distribution actually works, and how to design for chat. All platform facts are sourced and dated (verified 2026-06-09).

## Balanced by design — the determinism boundary

Like every plugin in this marketplace, cowork-dev keeps mechanical checks out of the LLM's hands:

- **Deterministic lane → `scripts/`.** `validate-cowork-artifact.sh` checks a Cowork-bound package against the platform's enforced limits: name shape / length / reserved list, uncompressed size and file count (warns at 80% of the caps), npm/pip marketplace sources, and local stdio MCP servers — on the shared JSON finding contract from plugin-dev's determinism kit.
- **Semantic lane → the skill.** Platform decisions (Code vs Cowork vs both, hooks-as-enrichment design, connector enrichment, Routine privacy posture, multilingual trigger quality) stay with `cowork-plugin-development`, which consumes the script output rather than re-deriving the rules.

```bash
# gate a package before shipping it to Cowork
bash scripts/validate.sh path/to/plugin-package --json | jq .
# self-test against the bundled fixtures
bash scripts/validate.sh tests/fixtures/good   # passes
bash scripts/validate.sh tests/fixtures/bad    # fails: reserved name, stdio MCP, npm source
```

See [`scripts/README.md`](scripts/README.md) for the rule-id table and the contract.

## Installation

```bash
/plugin marketplace add sureserverman/coder-plugins
/plugin install cowork-dev@coder-plugins
```

## Components

### Skills (1)

| Skill | Triggers when you ask |
|---|---|
| `cowork-plugin-development` | "build a Cowork plugin", "Cowork install paths", "private marketplace limits", "Cowork ZIP upload", "which hook events fire in Cowork", "multilingual skill triggers", "connector-aware enrichment", "privacy posture for cloud Routines" |

Depth lives in the skill's `references/` (platform parity + limits, distribution paths, chat-native design patterns) and `examples/` (a copy-paste release workflow, a Cowork-aware sample skill).

### Scripts

| Script | Does |
|---|---|
| `scripts/validate.sh <package-dir> [--json]` | Orchestrator — runs every domain validator, merges findings, prints one verdict. |
| `scripts/validate-cowork-artifact.sh` | The Cowork-bound package checks (limits, names, npm/pip sources, stdio MCP). |

## Anti-patterns this plugin will catch

- A `.mcp.json` with local stdio servers shipped to Cowork (does nothing there — MCP is cloud-connectors only).
- npm/pip sources in a marketplace.json bound for a Cowork org marketplace.
- Reserved, over-long, or non-lowercase-hyphen plugin names (rejected at upload).
- Packages over (or sneaking up on) the 200 MB / 5,000-file limits.
- Load-bearing hooks — Cowork's fired-event list is unpublished, and skills also surface in chat where hooks never run.
- Install docs that only say `/plugin marketplace add` — Cowork users need the UI paths.

## License

MIT
