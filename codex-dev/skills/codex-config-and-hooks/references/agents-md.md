# AGENTS.md discovery in Codex

Facts verified 2026-06-09 against [developers.openai.com/codex/guides/agents-md](https://developers.openai.com/codex/guides/agents-md), Codex CLI v0.139.0.

## Discovery order

The agent briefing is assembled fresh **per run** (no caching across runs) from two scopes:

**1. Global** — exactly one file:

| Checked first | Fallback |
|---|---|
| `~/.codex/AGENTS.override.md` | `~/.codex/AGENTS.md` |

The override file, when present, **replaces** (not appends to) the global AGENTS.md — use it for temporary experiments without touching your canonical file. `CODEX_HOME` relocates both (they live under `$CODEX_HOME`, default `~/.codex`).

**2. Project** — Codex walks every directory from the **git root down to the cwd**, and in each directory takes the first match of:

1. `AGENTS.override.md`
2. `AGENTS.md`
3. any name listed in `project_doc_fallback_filenames` (config.toml), in order

So a monorepo can layer: root `AGENTS.md` (org conventions) + `services/api/AGENTS.md` (service specifics) — both load when you run from `services/api/`, root first. Directories *above* the git root and *below* the cwd are never read.

## Byte budget

| Key | Default | Behavior |
|---|---|---|
| `project_doc_max_bytes` | **32 KiB** | Cap on the **combined** project docs; content beyond it is **silently truncated** |

A deep monorepo walk that collects several large AGENTS.md files blows the budget without any error — the bottom of the stack just vanishes. Fixes: trim the files, or raise `project_doc_max_bytes` in config.toml (user layer).

## Interop notes

- `project_doc_fallback_filenames` is how you keep a single source of truth with other tools — e.g. `["CLAUDE.md"]` lets Codex read a Claude Code project file in directories that lack an AGENTS.md. Per-directory, a real AGENTS.md still wins.
- AGENTS.md is instructions-only context; it is not a skill catalog and does not affect skill discovery (see the codex-skills-and-agents skill).

## Debug checklist

| Symptom | Check |
|---|---|
| Global instructions ignored | Is an `AGENTS.override.md` shadowing `~/.codex/AGENTS.md`? Is `CODEX_HOME` set somewhere unexpected? |
| Project file ignored | Is it above the git root or below the cwd? Wrong filename and not in `project_doc_fallback_filenames`? |
| Tail of instructions ignored | Combined size > `project_doc_max_bytes` (32 KiB default) — silent truncation |
| Stale instructions | They aren't — context is rebuilt per run; suspect an override file instead |

## Sources

- OpenAI, *AGENTS.md guide* — discovery walk, override files, fallbacks, byte budget — [developers.openai.com/codex/guides/agents-md](https://developers.openai.com/codex/guides/agents-md). Verified 2026-06-09 (Codex CLI v0.139.0).
- OpenAI, *Config reference* — `project_doc_max_bytes`, `project_doc_fallback_filenames`, `CODEX_HOME` — [developers.openai.com/codex/config-reference](https://developers.openai.com/codex/config-reference). Verified 2026-06-09.
