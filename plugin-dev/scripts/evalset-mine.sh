#!/usr/bin/env bash
# evalset-mine.sh <skill-name> [--sessions <dir>] [--limit N]
# Drafts `source: session` eval cases from real session history: finds sessions
# where the target skill actually fired and lifts the triggering user message
# into a case, with a session_ref and a TODO rubric stub for the author to
# finish. Prints a draft cases.yaml to stdout.
#
# Usage signal comes from curator-usage.sh (consumed as-is, NOT forked): if the
# skill has no history, there is nothing to mine and we say so. The prompt-
# context extraction below is a DIFFERENT concern from usage-timestamp
# aggregation, so it does not duplicate curator-usage.sh's logic.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILL=""; SESSDIR="$HOME/.claude/projects"; LIMIT=5
while [ $# -gt 0 ]; do
  case "$1" in
    --sessions) SESSDIR="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    -*) echo "error: unknown option: $1" >&2; exit 2 ;;
    *) SKILL="$1"; shift ;;
  esac
done
[ -n "$SKILL" ] || { echo "usage: $0 <skill-name> [--sessions <dir>] [--limit N]" >&2; exit 2; }

# Usage-signal gate via curator-usage.sh (single source of truth for "did it fire").
USAGE=$(bash "$DIR/curator-usage.sh" --sessions "$SESSDIR" --json "$SKILL")
COUNT=$(printf '%s' "$USAGE" | jq -r --arg s "$SKILL" '[.usage[]|select(.skill==$s)|.count][0] // 0')
if [ "$COUNT" = 0 ]; then
  echo "# no session usage for '$SKILL' — nothing to mine (author synthetic/golden cases instead)" >&2
  exit 1
fi

# Prompt-context extraction: the nearest preceding user message before each Skill
# invocation of this skill, up to --limit occurrences.
python3 - "$SKILL" "$SESSDIR" "$LIMIT" <<'PY'
import sys, os, json, glob
skill, sessdir, limit = sys.argv[1], sys.argv[2], int(sys.argv[3])

def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(b.get("text","") for b in content
                         if isinstance(b, dict) and b.get("type")=="text").strip()
    return ""

cases = []
for f in sorted(glob.glob(os.path.join(sessdir, "**", "*.jsonl"), recursive=True)):
    last_user = None
    try:
        fh = open(f, encoding="utf-8")
    except OSError:
        continue
    for line in fh:
        try:
            o = json.loads(line)
        except Exception:
            continue                      # one bad line loses only itself
        t = o.get("type")
        msg = o.get("message") or {}
        if t == "user":
            txt = text_of(msg.get("content"))
            if txt:
                last_user = (txt, o.get("timestamp"))
        elif t == "assistant":
            for b in (msg.get("content") or []) if isinstance(msg.get("content"), list) else []:
                if isinstance(b, dict) and b.get("type")=="tool_use" and b.get("name")=="Skill":
                    inv = (b.get("input") or {}).get("skill","")
                    if inv.split(":")[-1] == skill and last_user:
                        cases.append({
                            "prompt": last_user[0],
                            "ref": f"{os.path.basename(f)}@{o.get('timestamp')}",
                        })
        if len(cases) >= limit:
            break
    fh.close()
    if len(cases) >= limit:
        break

# Emit a draft cases.yaml (rubric stubs = TODO; validate with --draft).
def block(s, indent):
    pad = " " * indent
    return "\n".join(pad + ln for ln in s.splitlines()) or (pad + "")

print("version: 1")
print(f"skill: {skill}")
print("thresholds:")
print("  min_case_score: 3.0")
print("  pass_fraction: 1.0")
print("cases:")
for i, c in enumerate(cases, 1):
    print(f"  - id: session-{i}")
    print(f"    source: session")
    print(f"    prompt: |")
    print(block(c["prompt"], 6))
    print(f"    session_ref: {json.dumps(c['ref'])}")  # json string == valid YAML scalar; escapes safely
    print(f"    rubric: TODO   # fill in: list of {{criterion, weight}}")
PY
