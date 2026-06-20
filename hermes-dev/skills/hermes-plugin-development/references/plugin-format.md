# Hermes plugin format: locations, plugin.yaml, packaging

Facts verified 2026-06-09 against hermes-agent.nousresearch.com/docs and
github.com/NousResearch/hermes-agent, Hermes Agent v0.16.0 "The Surface
Release" (June 5, 2026). The plugin API is younger than the skills surface
and Hermes ships multiple minor releases per month — pin against the docs
version and re-verify before shipping.

## Locations

| Kind | Path |
|---|---|
| User plugin | `~/.hermes/plugins/<name>/` |
| Bundled plugin (in a Hermes checkout/distribution) | `plugins/<category>/<name>/` |
| pip-installed | anywhere on `sys.path`, discovered via entry points |

## Package structure

```
<name>/
├── plugin.yaml      # manifest — required
├── __init__.py      # def register(ctx) — required
├── schemas.py       # convention: tool argument schemas
└── tools.py         # convention: handler implementations
```

`plugin.yaml` and `__init__.py` are the contract; `schemas.py`/`tools.py` are
convention (any module layout works as long as `register` imports it).

## plugin.yaml

| Field | Required | Type | Notes |
|---|---|---|---|
| `name` | yes | string | matches the directory / distribution name |
| `version` | yes | string | semver |
| `description` | yes | string | shown by `hermes plugins list` |
| `provides_tools` | no | **list** of strings | tool names the plugin registers |
| `provides_hooks` | no | **list** of strings | hook events the plugin attaches to |
| `requires_env` | no | list of strings | env vars the plugin needs; Hermes warns when unset |

`provides_tools` / `provides_hooks` must be YAML lists, not comma-joined
strings — the deterministic validator errors with `hermes-plugin-yaml-types`.

```yaml
name: weather
version: 0.1.0
description: Weather lookup tool plus a pre-call audit hook.
provides_tools:
  - get_weather
provides_hooks:
  - pre_tool_call
requires_env:
  - WEATHER_API_KEY
```

## pip distribution

Declare the entry point group `hermes_agent.plugins`:

```toml
# pyproject.toml
[project]
name = "hermes-weather"
version = "0.1.0"

[project.entry-points."hermes_agent.plugins"]
weather = "hermes_weather"        # module exposing register(ctx)
```

`pip install hermes-weather` makes the plugin discoverable without touching
`~/.hermes/plugins/`. Ship `plugin.yaml` inside the package data so the
manifest metadata travels with the wheel.

## Management CLI

```bash
hermes plugins list                 # discovered plugins + enabled state
hermes plugins install <source>     # directory, pip name, or URL
hermes plugins update [name]
hermes plugins enable <name>
hermes plugins disable <name>
```

Disabled plugins stay on disk but never get `register(ctx)` called.

## Plugin types beyond tools

Two additional first-class plugin types use the same packaging:

- **Memory providers** — replace/extend the persistence backend behind
  MEMORY.md-style durable facts (vector stores, SQL, custom).
- **Context-compression engines** — replace the summarizer that compacts
  conversation context when it approaches the window limit.

Both are registered from `register(ctx)`; see `register-api.md` and the
official examples at github.com/NousResearch/hermes-example-plugins.

Verified 2026-06-09 — hermes-agent.nousresearch.com/docs (plugins),
github.com/NousResearch/hermes-agent, v0.16.0.
