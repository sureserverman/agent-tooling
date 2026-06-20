# Valid Hermes plugin entry point: def register(ctx) present, handlers follow
# the args-dict-in / JSON-string-out / never-raise contract.
import json


def get_weather(args: dict) -> str:
    try:
        return json.dumps({"city": args["city"], "temp_c": 21})
    except Exception as e:  # NEVER raise from a handler
        return json.dumps({"error": str(e)})


def audit(event: dict) -> str:
    return json.dumps({"ok": True})


def register(ctx):
    ctx.register_tool("get_weather", handler=get_weather, schema={
        "type": "object",
        "properties": {"city": {"type": "string"}},
        "required": ["city"],
    })
    ctx.register_hook("pre_tool_call", audit)
