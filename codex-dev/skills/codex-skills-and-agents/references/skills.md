# Codex skills

Facts verified 2026-06-09 against [developers.openai.com/codex/skills](https://developers.openai.com/codex/skills) and the changelog, Codex CLI v0.139.0.

## Format

Skills landed in Codex CLI **v0.69.0 (December 10, 2025)** and implement the **agentskills.io** open standard — the same `SKILL.md` that Claude Code and Cursor read. A skill is a directory:

```
my-skill/
├── SKILL.md            # required: YAML frontmatter (name, description) + body
├── scripts/            # optional: executables the skill calls
├── references/         # optional: depth loaded on demand
├── assets/             # optional: templates, images
└── agents/
    └── openai.yaml     # optional, Codex-ONLY sidecar
```

Frontmatter requires `name` (matching the directory) and `description` (third-person, trigger-phrase-rich — it is the selection surface).

## agents/openai.yaml — the Codex sidecar

Codex-specific metadata that other agentskills.io hosts ignore:

```yaml
interface:
  display_name: Release Helper   # UI name
  icon: rocket                   # UI icon
  brand_color: "#0f766e"         # UI accent
policy:
  allow_implicit_invocation: false   # false = explicit-only ($skill-name / /skills); never fires on description match
dependencies:
  tools:
    - type: mcp                  # declare an MCP server the skill depends on
```

| Block | Keys | Effect |
|---|---|---|
| `interface` | `display_name`, `icon`, `brand_color` | How the skill renders in Codex UI |
| `policy` | `allow_implicit_invocation` | `false` disables description-match firing |
| `dependencies` | `tools` (e.g. `type: "mcp"`) | Declares tool/MCP dependencies |

Because the sidecar lives in its own file, the same skill directory stays portable: Claude Code reads SKILL.md and ignores `agents/openai.yaml`.

## Discovery order

First match wins per skill name:

1. `<cwd>/.agents/skills` — working-directory-local
2. `$REPO_ROOT/.agents/skills` — repo-shared
3. `~/.agents/skills` — personal, cross-project. **NOT `~/.claude/skills`** — Codex does not read Claude's tree.
4. `/etc/codex/skills` — admin-managed, machine-wide
5. Bundled system skills at `~/.codex/skills/.system` — e.g. `$skill-creator` (scaffolds new skills), `plan`

**Symlinked skill folders are followed.** The standard multi-tool setup: keep the canonical skill in one place and symlink it into `~/.agents/skills/`.

Plugins add a sixth source: skills bundled in installed plugins join the same catalog.

## Invocation and the catalog budget

- **Explicit**: `$skill-name` inline in a prompt, or the `/skills` picker.
- **Implicit**: Codex matches the request against skill descriptions.

The catalog (all names + descriptions) is **capped at ~2% of the context window — roughly 8,000 characters**. Bodies are NOT in the catalog; a skill's body loads only when the skill is selected. Consequences:

- Keep descriptions short and trigger-dense; every char you spend is taken from sibling skills.
- Never put workflow steps in the description (leak risk + budget waste) — the body is free.
- If you have many skills installed, audit the catalog: skills can silently fall out of the budget.

## Per-skill disable

In config.toml:

```toml
[[skills.config]]
path = "/home/me/.agents/skills/noisy-skill"
enabled = false
```

One `[[skills.config]]` array entry per skill, keyed by `path`.

## Custom prompts — deprecated, migrate to skills

`~/.codex/prompts/*.md` (invoked as `/prompts:name`) are **deprecated** in favor of skills. They still function, with these limits:

- **Top-level files only** — no subdirectories.
- Interpolation: positional `$1`–`$9`, `$ARGUMENTS` (everything after the name), named uppercase `$KEY=value`.
- **Known regression**: issue [#15941](https://github.com/openai/codex/issues/15941) — prompts intermittently vanish from the slash menu.

### Migration recipe

| Prompt feature | Skill equivalent |
|---|---|
| Prompt body | SKILL.md body |
| `/prompts:name` invocation | `$name` or `/skills` |
| `$1`–`$9` / `$ARGUMENTS` | Prose in the body: "the user supplies X in the request" — the model reads arguments from context |
| `$KEY=value` named args | Same — describe expected inputs in the body |
| (no equivalent) | `description` frontmatter enables implicit firing, which prompts never had |

Steps: create `~/.agents/skills/<name>/SKILL.md` → move body → rewrite interpolation as prose → add third-person trigger-rich description → verify in `/skills` → delete the prompt file.

## Authoring checklist

1. `name` in frontmatter == directory name.
2. `description` third-person, trigger phrases quoted, no workflow steps, well under the catalog budget.
3. Depth in body/`references/` (one level), not in the description.
4. Explicit-only? Add `agents/openai.yaml` with `policy.allow_implicit_invocation: false`.
5. MCP dependency? Declare it under `dependencies.tools`.
6. Run `bash scripts/validate.sh <artifact>` — frontmatter checks are deterministic.
