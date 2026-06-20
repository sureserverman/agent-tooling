---
name: lobster-facts
description: Use when the user asks this fixture plugin for a lobster fact. Triggers on "lobster fact", "tell me about lobsters".
user-invocable: true
metadata: {"openclaw": {"emoji": "🦞", "always": false, "requires": {"bins": ["jq"]}, "install": [{"id": "jq", "kind": "brew", "formula": "jq", "bins": ["jq"], "label": "jq"}]}}
---

# lobster-facts

Reply with one verifiable lobster fact. Valid single-line JSON metadata — the validator must pass this.
