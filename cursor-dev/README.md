# cursor-dev

Authoring kit for **Cursor (the AI editor)** extensions. Part of the [`coder-plugins`](..) marketplace.

## Why a separate cursor-dev?

Cursor's extension surfaces rhyme with Claude Code's, and the rhyme is exactly where things break. As of June 2026 (Cursor 3.7):

- **Plugins** use `.cursor-plugin/plugin.json` (not `.claude-plugin/`), publish through cursor.com/marketplace with manual review and a **hard open-source requirement**, and reach orgs via Team Marketplaces (private GitHub repos, 2.6+).
- **Rules must be `.mdc`** — a plain `.md` in `.cursor/rules/` is silently ignored, the single most common "my rule doesn't work" cause. Four application types; `alwaysApply: false` with no description/globs is an accidental manual-only rule.
- **Hooks are a different schema** — ~22 **camelCase** events, a required integer `version`, `permission` (not `permissionDecision`), built-in `loop_limit`, prompt-type LLM hooks. A Claude Code hooks.json ported verbatim fails silently.
- **Subagents have no `tools` field** — `readonly: true` is the only restriction lever; Cursor compat-reads `.claude/agents/` and `.codex/agents/`.
- **MCP** lives in `.cursor/mcp.json` with its own interpolation set (`${env:NAME}`, `${workspaceFolder}`, …), OAuth auto-discovery, `permissions.json` (3.6+), and install deeplinks.

[`plugin-dev`](../plugin-dev) owns Claude Code plugin *structure*; **cursor-dev owns the Cursor platform**. All platform facts are sourced and dated (verified 2026-06-09).

## Skills

| Skill | Covers |
|---|---|
| `cursor-plugin-development` | Manifest, layout, marketplace.json, publishing, Team Marketplaces, local dev loop, version timeline 2.4→3.7 |
| `cursor-rules-and-skills` | `.mdc` rules (four types, precedence), skills (agentskills.io standard, discovery + compat paths, commands migration) |
| `cursor-hooks-and-agents` | hooks.json (events, protocol, prompt hooks), subagents, MCP (transports, OAuth, deeplinks) |

## Balanced by design — the determinism boundary

Like every plugin in this marketplace, cursor-dev keeps mechanical checks out of the LLM's hands:

- **Deterministic lane → `scripts/`.** `validate-cursor-artifact.sh` checks a Cursor-bound artifact directory: manifest presence/parse/name, `.mdc` frontmatter parse and the manual-only rule trap, plain-`.md` rules Cursor silently ignores, skill `name`↔directory mismatches, and hooks.json version + unknown (e.g. PascalCase) event names — on the shared JSON finding contract from plugin-dev's determinism kit.
- **Semantic lane → the skills.** Platform decisions (plugin vs in-repo `.cursor/`, rule vs skill vs hook, prompt-hook phrasing, subagent descriptions, MCP scoping) stay with the skills, which consume the script output rather than re-deriving the rules.

```bash
# gate an artifact before shipping it to Cursor
bash scripts/validate.sh path/to/cursor-plugin --json | jq .
# self-test against the bundled fixtures
bash scripts/validate.sh tests/fixtures/good   # passes
bash scripts/validate.sh tests/fixtures/bad    # fails: ignored .md rule, broken .mdc, skill name mismatch, hooks version + PascalCase event
```

Rule-id table in [`scripts/README.md`](scripts/README.md).

## Install

From the `coder-plugins` marketplace root, register the marketplace in Claude Code, then `/plugin install cursor-dev`.

## License

MIT — see [LICENSE](LICENSE).
