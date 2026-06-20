---
name: hermes-plugin-development
description: Use when authoring, debugging, or distributing a Python plugin for Hermes Agent. Triggers on "Hermes plugin", "plugin.yaml", "register(ctx)", "Hermes register_tool", "Hermes hook pre_tool_call", "hermes plugins install", "Hermes memory provider".
---

# hermes-plugin-development

Hermes Agent plugins are **Python packages** with a `plugin.yaml` manifest and a `register(ctx)` entry function — nothing like Claude Code's markdown-and-JSON plugins. They can add tools, hooks, slash commands, CLI commands, skills, **memory providers, and context-compression engines**, and they can replace built-ins with `override=True`. The handler contract is strict: take `args: dict`, **return JSON strings, never raise**.

All facts verified 2026-06-09 against hermes-agent.nousresearch.com/docs and github.com/NousResearch/hermes-agent, Hermes Agent v0.16.0 "The Surface Release" (June 5, 2026). **Caveat: the plugin API is Hermes-specific and younger than the skills surface, and Hermes ships multiple minor releases per month (v0.14→v0.16 within May–June 2026) — pin against the docs version and re-verify before shipping.**

## Reference map

| When you need… | Read first |
|---|---|
| Plugin locations, plugin.yaml fields, package layout, pip entry points, management CLI | `references/plugin-format.md` |
| Every `register(ctx)` method, hook lifecycle events, handler contract, override semantics, memory/compression plugin types | `references/register-api.md` |

## The shape in 30 seconds

```
~/.hermes/plugins/<name>/        # user plugins; bundled ones: plugins/<category>/<name>/
├── plugin.yaml                  # manifest: name, version, description, provides_tools, provides_hooks
├── __init__.py                  # def register(ctx): ...
├── schemas.py                   # typically: tool arg schemas
└── tools.py                     # typically: handler implementations
```

```yaml
# plugin.yaml
name: weather
version: 0.1.0
description: Adds a weather lookup tool and a pre-call audit hook.
provides_tools: [get_weather]
provides_hooks: [pre_tool_call]
requires_env: [WEATHER_API_KEY]   # optional
```

```python
# __init__.py
import json

def register(ctx):
    ctx.register_tool("get_weather", handler=get_weather, schema=WEATHER_SCHEMA)
    ctx.register_hook("pre_tool_call", audit)

def get_weather(args: dict) -> str:        # args dict in…
    try:
        return json.dumps({"temp_c": lookup(args["city"])})   # …JSON string out
    except Exception as e:
        return json.dumps({"error": str(e)})                  # NEVER raise
```

## Decision rules

### Skill or plugin?

Prompt-level behavior (instructions, workflows, references) → a **skill** (see `hermes-skills`). New *capabilities* — tools the model can call, lifecycle hooks, slash/CLI commands, memory backends, compression engines — → a **plugin**.

### Which registration call?

| Need | Call |
|---|---|
| A model-callable tool | `ctx.register_tool(name, handler, schema)` |
| Intercept/augment lifecycle | `ctx.register_hook(event, fn)` — `pre_tool_call`, `post_tool_call`, `pre_llm_call` (can inject context), `on_session_start` |
| Slash command in chat | `ctx.register_command(...)` |
| `hermes <subcommand>` | `ctx.register_cli_command(...)` |
| Bundle a skill with the plugin | `ctx.register_skill(...)` |
| Call another tool from yours | `ctx.dispatch_tool(...)` |
| Replace a built-in | same calls with `override=True` |

### Distribution

- **Directory drop**: `~/.hermes/plugins/<name>/` (user) or `plugins/<category>/<name>/` (bundled in a checkout).
- **pip**: declare `[project.entry-points."hermes_agent.plugins"]` in pyproject.toml; `pip install` makes the plugin discoverable.
- Manage with `hermes plugins list / install / update / enable / disable`.
- Worked examples: [github.com/NousResearch/hermes-example-plugins](https://github.com/NousResearch/hermes-example-plugins).

## Anti-patterns this skill catches

- A handler that **raises** — Hermes expects an error JSON string back; an exception kills the tool call ungracefully. Wrap everything.
- A handler returning a dict/object — the contract is a **JSON string** (`json.dumps(...)`), not a Python value.
- `provides_tools`/`provides_hooks` as comma-strings — they're YAML **lists**; the validator errors with `hermes-plugin-yaml-types`.
- `plugin.yaml` without `name`+`version`+`description` — refused at load (`hermes-plugin-yaml-fields`).
- `__init__.py` without `def register(ctx)` — the package is silently not a plugin (`hermes-plugin-register-missing`).
- Secrets hardcoded in tools.py — declare them in `requires_env` and read from the environment.
- Treating the plugin API as stable across minors — it's younger than the skills surface; pin and re-verify.

## Deterministic gate

```bash
bash scripts/validate.sh path/to/plugin --json | jq .
```

Flags unparseable plugin.yaml (`hermes-plugin-yaml-parse`), missing manifest fields, non-list `provides_*`, missing `register(` in `__init__.py`, and Python syntax errors (`hermes-plugin-py-syntax`).

## Sources

- Nous Research, *Hermes Agent docs — Plugins* (plugin.yaml, register(ctx), handler contract, plugin types, management CLI) — [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs). Verified 2026-06-09, v0.16.0.
- [github.com/NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) — plugin loader source, entry-point group `hermes_agent.plugins`. Verified 2026-06-09.
- [github.com/NousResearch/hermes-example-plugins](https://github.com/NousResearch/hermes-example-plugins) — official worked examples. Verified 2026-06-09.

When upstream behavior changes (it does, monthly), update the references — not this SKILL.md.
