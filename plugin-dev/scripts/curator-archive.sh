#!/usr/bin/env bash
# curator-archive.sh <snapshot|archive|restore|list> [slug] [options]
# The curator's ONLY mutating script. It moves skills; it never removes them.
# The worst case for any skill is a move into the archive, fully reversible.
#
#   snapshot            tar.gz the whole skills root into <archive>/snapshots/
#   archive  <slug>     move <skills-root>/<slug>/ -> <archive>/<slug>/
#   restore  <slug>     move <archive>/<slug>/ -> <skills-root>/<slug>/
#   list                list currently archived skills
#
# Options:
#   --skills-root <dir>  default ~/.claude/skills (must be an absolute path)
#   --archive <dir>      default <skills-root>/.archive (absolute if given)
#   --label <name>       snapshot filename label (default: UTC timestamp)
#
# Enforced in code (not just documented):
#   - no "delete"/"purge" verb — recovery is always a restore/untar away;
#   - a slug is a kebab skill name only (^[a-z0-9][a-z0-9-]*$) — no path
#     traversal, no absolute paths, no separators;
#   - archive refuses a pinned skill (reads .curator-pins directly), so a single
#     bad call can't violate the pin rule even under caller error;
#   - archive/restore/snapshot never overwrite an existing target (symlinks
#     included);
#   - moves must be same-filesystem so the rename is atomic and reversible.
# Origin (plugin vs personal) is NOT re-derived here — the calling skill is
# responsible for only ever archiving personal skills (see SKILL.md).
set -eu

ROOT="$HOME/.claude/skills"; ARCHIVE=""; LABEL=""
CMD="${1:-}"; shift || true
SLUG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --skills-root) ROOT="$2"; shift 2 ;;
    --archive) ARCHIVE="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    -*) echo "error: unknown option: $1" >&2; exit 2 ;;
    *) SLUG="$1"; shift ;;
  esac
done
[ -n "$ARCHIVE" ] || ARCHIVE="$ROOT/.archive"
SNAPDIR="$ARCHIVE/snapshots"

# ROOT/ARCHIVE must be absolute — an empty or relative root turns "$ROOT/$SLUG"
# into "/$SLUG" or a cwd-relative path, operating far outside the estate.
case "$ROOT" in    /*) ;; *) echo "error: --skills-root must be a non-empty absolute path" >&2; exit 2 ;; esac
case "$ARCHIVE" in /*) ;; *) echo "error: --archive must be an absolute path" >&2; exit 2 ;; esac

need_slug() {
  [ -n "$SLUG" ] || { echo "error: '$CMD' needs a skill slug" >&2; exit 2; }
  # A slug is a bare kebab skill name — never a path. This is the code backstop
  # against traversal ('../x'), absolute paths, and separators.
  printf '%s' "$SLUG" | grep -qE '^[a-z0-9][a-z0-9-]*$' \
    || { echo "error: invalid skill slug '$SLUG' (must match ^[a-z0-9][a-z0-9-]*\$)" >&2; exit 2; }
}

# taken (no-follow): true if a real entry or a (possibly dangling) symlink exists.
taken() { [ -e "$1" ] || [ -L "$1" ]; }

# same_device <a> <b> — both must exist; true iff on the same filesystem.
# GNU `stat -c %d` then BSD/macOS `stat -f %d` (same dual-stat fallback as
# curator-inventory.sh) so this works on both platforms; distinct sentinels
# would falsely report "different device" if both stat forms failed.
same_device() {
  local da db
  da=$(stat -c %d "$1" 2>/dev/null || stat -f %d "$1" 2>/dev/null || echo x)
  db=$(stat -c %d "$2" 2>/dev/null || stat -f %d "$2" 2>/dev/null || echo x)
  [ "$da" = "$db" ]
}

is_pinned() {
  local pins="$ROOT/.curator-pins"
  [ -f "$pins" ] || return 1
  grep -vE '^\s*(version:|#|$)' "$pins" | tr -d ' ' | grep -qxF "$1"
}

case "$CMD" in
  snapshot)
    mkdir -p "$SNAPDIR"
    [ -n "$LABEL" ] || LABEL="$(date -u +%Y%m%dT%H%M%SZ)"
    OUT="$SNAPDIR/snapshot-$LABEL.tar.gz"
    taken "$OUT" && { echo "error: snapshot already exists: $OUT" >&2; exit 1; }
    # Archive the whole skills root EXCEPT the archive dir itself (no nesting).
    tar -czf "$OUT" -C "$ROOT" --exclude=".archive" . 2>/dev/null
    echo "$OUT"
    ;;
  archive)
    need_slug
    is_pinned "$SLUG" && { echo "error: '$SLUG' is pinned — pins are exempt from archival" >&2; exit 1; }
    SRC="$ROOT/$SLUG"
    [ -d "$SRC" ] || { echo "error: no such skill to archive: $SLUG (looked in $ROOT)" >&2; exit 1; }
    DEST="$ARCHIVE/$SLUG"
    taken "$DEST" && { echo "error: already archived: $SLUG" >&2; exit 1; }
    mkdir -p "$ARCHIVE"
    same_device "$SRC" "$ARCHIVE" || { echo "error: $ROOT and $ARCHIVE are on different filesystems — move would not be atomic" >&2; exit 1; }
    mv "$SRC" "$DEST"
    echo "archived: $SLUG -> $DEST"
    ;;
  restore)
    need_slug
    [ -d "$ROOT" ] || { echo "error: skills root does not exist: $ROOT" >&2; exit 1; }
    SRC="$ARCHIVE/$SLUG"
    [ -d "$SRC" ] || { echo "error: not archived: $SLUG (looked in $ARCHIVE)" >&2; exit 1; }
    DEST="$ROOT/$SLUG"
    taken "$DEST" && { echo "error: a live skill already occupies $DEST — will not overwrite" >&2; exit 1; }
    same_device "$SRC" "$ROOT" || { echo "error: $ARCHIVE and $ROOT are on different filesystems — move would not be atomic" >&2; exit 1; }
    mv "$SRC" "$DEST"
    echo "restored: $SLUG -> $DEST"
    ;;
  list)
    if [ -d "$ARCHIVE" ]; then
      find "$ARCHIVE" -mindepth 1 -maxdepth 1 -type d -not -name snapshots -printf '%f\n' 2>/dev/null | sort || true
    fi
    ;;
  *)
    echo "usage: $0 <snapshot|archive|restore|list> [slug] [--skills-root d] [--archive d] [--label l]" >&2
    exit 2 ;;
esac
