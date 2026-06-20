#!/usr/bin/env bash
# agent-tooling bootstrap
#
# Registers the agent-tooling marketplace and enables the AI-tool authoring
# family (plugin-dev + six platform siblings) in ~/.claude/settings.json.
# Idempotent: user values always win over the defaults this script provides, so
# re-running it after you customize settings does not clobber your choices.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/sureserverman/agent-tooling/main/bootstrap.sh)
# or locally:
#   ./bootstrap.sh

set -euo pipefail

SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
SETTINGS_DIR="$(dirname "$SETTINGS")"

die() { echo "bootstrap: $*" >&2; exit 1; }
info() { echo "bootstrap: $*"; }

# --- preflight ---------------------------------------------------------------

command -v jq  >/dev/null || die "jq is required (apt install jq / brew install jq)"

mkdir -p "$SETTINGS_DIR"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

# Sanity: settings.json must be valid JSON or we refuse to touch it
jq -e . "$SETTINGS" >/dev/null || die "$SETTINGS is not valid JSON; refusing to modify"

# --- recommended defaults ----------------------------------------------------
#
# These are merged with `$defaults * $current` semantics in jq: every key the
# user already has wins. Adding a key here makes it the default for fresh
# installs; existing machines keep whatever the user already set.

DEFAULTS=$(cat <<'JSON'
{
  "extraKnownMarketplaces": {
    "agent-tooling": {
      "source": { "source": "github", "repo": "sureserverman/agent-tooling" }
    }
  },
  "enabledPlugins": {
    "plugin-dev@agent-tooling": true,
    "cowork-dev@agent-tooling": true,
    "cursor-dev@agent-tooling": true,
    "codex-dev@agent-tooling": true,
    "opencode-dev@agent-tooling": true,
    "hermes-dev@agent-tooling": true,
    "openclaw-dev@agent-tooling": true
  }
}
JSON
)

# --- backup ------------------------------------------------------------------

BACKUP="$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS" "$BACKUP"
info "backup written to $BACKUP"

# --- merge -------------------------------------------------------------------
#
# jq's `*` operator does a recursive deep merge with the right-hand side
# winning. So `$defaults * $current` keeps every value the user has already
# set and only fills in gaps from $defaults.

jq --argjson defaults "$DEFAULTS" '$defaults * .' "$SETTINGS" > "$SETTINGS.tmp"
mv "$SETTINGS.tmp" "$SETTINGS"

info "merged recommended defaults into $SETTINGS"
info ""
info "Defaults applied for keys you did not already have:"
info "  - agent-tooling marketplace registered"
info "  - 7 plugins enabled (plugin-dev, cowork-dev, cursor-dev, codex-dev,"
info "    opencode-dev, hermes-dev, openclaw-dev)"
info ""
info "Tip: enable only the platforms you target — flip the rest off per-machine"
info "with /plugin or per-project with /loadout (plugin-authoring task profile)."
info ""
info "Restart Claude Code (or /reload-plugins in an active session) to apply."
