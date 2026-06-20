# The register(ctx) API: tools, hooks, commands, handler contract

Facts verified 2026-06-09 against hermes-agent.nousresearch.com/docs and
github.com/NousResearch/hermes-agent, Hermes Agent v0.16.0 "The Surface
Release" (June 5, 2026). The plugin API is younger than the skills surface
and Hermes ships multiple minor releases per month — pin against the docs
version and re-verify before shipping.

## Entry point

```python
# __init__.py
def register(ctx):
    ...
```

Hermes calls `register(ctx)` once at load for every enabled plugin. All
capabilities are attached through `ctx`.

## ctx methods

| Method | Registers | Notes |
|---|---|---|
| `ctx.register_tool(name, handler, schema, override=False)` | a model-callable tool | `schema` describes the args dict; `override=True` replaces a built-in of the same name |
| `ctx.register_hook(event, fn)` | a lifecycle hook | events below |
| `ctx.register_command(name, fn, ...)` | a slash command in chat surfaces | |
| `ctx.register_cli_command(name, fn, ...)` | a `hermes <subcommand>` | |
| `ctx.register_skill(path_or_def)` | a skill bundled with the plugin | joins the same catalog as filesystem skills |
| `ctx.dispatch_tool(name, args)` | — | call another registered tool from inside a handler |

Memory providers and context-compression engines are also registered through
`ctx` (provider-registration calls in the docs' plugin-types section); they
follow the same packaging, with the provider object implementing the
documented interface.

## Hook lifecycle events

| Event | Fires | Can |
|---|---|---|
| `on_session_start` | new session begins | seed state, register session context |
| `pre_llm_call` | before each LLM request | **inject context** into the prompt, mutate the pending request |
| `pre_tool_call` | before a tool executes | inspect/modify args, veto |
| `post_tool_call` | after a tool returns | inspect/transform results, audit |

```python
def register(ctx):
    ctx.register_hook("pre_llm_call", inject_team_glossary)
    ctx.register_hook("pre_tool_call", audit_shell_commands)
```

## Handler contract — the rule that matters

Tool handlers:

1. **Take `args: dict`** — already validated against the registered schema.
2. **Return a JSON string** — `json.dumps(...)`, not a dict, not None.
3. **NEVER raise** — catch everything; return an error JSON object instead.

```python
import json

def get_weather(args: dict) -> str:
    try:
        data = lookup(args["city"])
        return json.dumps({"temp_c": data.temp, "summary": data.text})
    except KeyError:
        return json.dumps({"error": "missing required arg: city"})
    except Exception as e:
        return json.dumps({"error": f"lookup failed: {e}"})
```

Why: the result string is fed verbatim into the model's context; a raised
exception aborts the tool call path instead of giving the model a recoverable
error message to act on.

## override=True

Passing `override=True` to a registration call replaces the built-in of the
same name (e.g. wrap the stock shell tool with a policy filter). Without it,
a name collision with a built-in is a load error. Override sparingly and
re-test on every Hermes minor — built-in names and schemas move.

## Minimal complete plugin

```python
# ~/.hermes/plugins/weather/__init__.py
import json, os, urllib.request

SCHEMA = {
    "type": "object",
    "properties": {"city": {"type": "string"}},
    "required": ["city"],
}

def get_weather(args: dict) -> str:
    try:
        key = os.environ["WEATHER_API_KEY"]
        with urllib.request.urlopen(_url(args["city"], key), timeout=10) as r:
            return json.dumps(json.load(r))
    except Exception as e:
        return json.dumps({"error": str(e)})

def register(ctx):
    ctx.register_tool("get_weather", handler=get_weather, schema=SCHEMA)
```

Plus the `plugin.yaml` from `plugin-format.md`. Worked, current examples:
[github.com/NousResearch/hermes-example-plugins](https://github.com/NousResearch/hermes-example-plugins).

Verified 2026-06-09 — hermes-agent.nousresearch.com/docs (plugins, hooks),
github.com/NousResearch/hermes-agent, v0.16.0.
