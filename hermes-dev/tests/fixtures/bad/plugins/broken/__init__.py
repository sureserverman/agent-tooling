# Bad fixture: the register(ctx) entry point is absent entirely — the
# package is silently not a plugin without it.
import json


def get_weather(args: dict) -> str:
    return json.dumps({"temp_c": 21})
