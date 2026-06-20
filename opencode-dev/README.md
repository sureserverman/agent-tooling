# opencode-dev

Authoring kit for **OpenCode (the opencode.ai terminal agent)** extensions. Part of the [`coder-plugins`](..) marketplace.

## Why a separate opencode-dev?

OpenCode's extension surfaces rhyme with Claude Code's, and the rhyme is exactly where things break. As of June 2026 (OpenCode v1.16; canonical source **github.com/anomalyco/opencode** after the SST→Anomaly rebrand — open-code.ai and opencodedocs.com are NOT canonical):

- **Plugins are JS/TS modules**, not hooks.json — `.opencode/plugins/*.{js,ts}`, TypeScript-native (Bun, no build step), exporting an async function that returns a hook map (`{project, client, $, directory, worktree}` context). v1.15.0 rebuilt event delivery on an Effect core; pre-1.15 tutorials describe a different runtime.
- **Plural directories are canonical** (`agents/`, `commands/`, `plugins/`, `tools/`, `skills/`, `themes/`); legacy singular spellings have silent-ignore bug history (issue #14410: `opencode agent create` wrote `agent/` while the loader expected `agents/`).
- **Agents' `tools` boolean map is deprecated** — `permission` with `ask`/`allow`/`deny` and bash glob maps replaces it; agents were "modes" in 0.x.
- **Config merges across 8 layers** (remote `.well-known` → global → env → project → managed → MDM), with `{env:}`/`{file:}` substitution and `share` replacing the deprecated `autoshare`. Unknown top-level keys are silently ignored.
- **Skills are native** (`.opencode/skills/` plus `.claude/skills/` Claude Code compat); skill-loader plugins are obsolete. Rules: AGENTS.md canonical, CLAUDE.md fallback, `instructions` array with globs and remote URLs.
- **MCP tool definitions consume context on every turn** — the docs flag it; disable fat servers globally, re-enable per agent.

[`plugin-dev`](../plugin-dev) owns Claude Code plugin *structure*; **opencode-dev owns the OpenCode platform**. All platform facts are sourced and dated (verified 2026-06-09).

## Skills

| Skill | Covers |
|---|---|
| `opencode-plugin-development` | Plugin API and loading paths, the ~30 hook events, npm distribution, custom tools (`tool()` from `@opencode-ai/plugin`, shadowing), the plural-dirs gotcha |
| `opencode-agents-and-commands` | Agents (modes, frontmatter, built-in overrides, the `tools`→`permission` migration), commands (`$ARGUMENTS`, `` !`cmd` `` injection, `@file`, `subtask`) |
| `opencode-config-and-skills` | `opencode.json` (merge order, substitution, key catalog), native Agent Skills, AGENTS.md/instructions rules, MCP (OAuth/DCR, context bloat), themes |

## Balanced by design — the determinism boundary

Like every plugin in this marketplace, opencode-dev keeps mechanical checks out of the LLM's hands:

- **Deterministic lane → `scripts/`.** `validate-opencode-artifact.sh` checks an OpenCode-bound artifact directory: agent/command frontmatter parse, the deprecated `tools:` map, legacy singular dirs, `opencode.json` parse/unknown keys/`autoshare`, export-less plugin files, and skill frontmatter validity — on the shared JSON finding contract from plugin-dev's determinism kit.
- **Semantic lane → the skills.** Platform decisions (plugin vs tool vs agent vs skill, permission policy, MCP scoping, prompt wording) stay with the skills, which consume the script output rather than re-deriving the rules.

```bash
# gate an artifact before shipping it to OpenCode
bash scripts/validate.sh path/to/artifact --json | jq .
# self-test against the bundled fixtures
bash scripts/validate.sh tests/fixtures/good   # passes
bash scripts/validate.sh tests/fixtures/bad    # fails: deprecated tools: map, broken frontmatter, singular agent/ dir, autoshare + unknown key, export-less plugin
```

Rule-id table in [`scripts/README.md`](scripts/README.md).

## Install

From the `coder-plugins` marketplace root, register the marketplace in Claude Code, then `/plugin install opencode-dev`.

## License

MIT — see [LICENSE](LICENSE).
