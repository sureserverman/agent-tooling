# Cowork distribution reference

How to ship a plugin to Cowork users as of June 2026. Four install paths exist; pick per audience, and always keep direct ZIP upload working as the universal fallback. Facts verified against Anthropic's docs 2026-06-09.

## The four install paths

| Path | Audience | Plan requirement | Author effort |
|---|---|---|---|
| **Official Anthropic catalog** (Customize → Plugins → Browse) | Everyone | Any paid plan | You don't control inclusion — Anthropic curates |
| **Direct ZIP upload** (Plugins page) | Any individual user | Any paid plan | Attach ZIPs to GitHub releases; user uploads |
| **Marketplace by URL** | Users who can paste a URL | Any paid plan | Public repo + valid marketplace.json |
| **Org private marketplace** | Whole organizations | Team/Enterprise (owners set up; requires Cowork + Skills enabled) | Manual ZIP uploads or GitHub-synced repo |

For an independent plugin author the practical default is: **public GitHub repo with a marketplace.json** (covers path 3) **plus release ZIPs** (covers path 2). Org private marketplaces are something your enterprise users set up on their side; your job is to make the repo sync-compatible (see below).

### Marketplace by URL — what users can paste

- GitHub **`owner/repo` shorthand** (public github.com repos).
- **GitHub Enterprise** — works **target-side only** (the marketplace repo can live on GHE; the feature isn't otherwise available through GHE).
- **Public GitLab** repos.
- **Bitbucket** repos.

Users can add at most **25 marketplaces**, and a marketplace archive is capped at **512 MB** — keep the repo lean.

## Org private marketplaces (Team/Enterprise)

Two publishing modes, with different limits:

### Manual ZIP upload

- Per-ZIP limit: **50 MB**.
- Up to **100 plugins per marketplace**.
- Uploading a plugin with the same name **overwrites** the existing one (that's your update path).

### GitHub sync

- **Private repos on github.com ONLY** — GitHub Enterprise Server is unsupported for sync.
- **Auto-syncs on merged PRs**; sync has a **30-minute timeout**.
- Up to **500 plugins**.
- **Relative-path sources are fully supported** — `"source": "./my-plugin"` is the safe default.
- External `github` / `url` / git-subdir sources work **only if the target repo is public**.
- **npm and pip sources are unsupported.** A marketplace.json with `{"source": "npm", ...}` or pip sources will not deliver those plugins to Cowork.
- **Failed syncs can temporarily remove plugins** from the marketplace — keep the manifest valid and small; a broken marketplace.json on main is an org-wide outage for your plugins.

Author checklist for sync-compatible repos:

1. Every plugin under a relative-path source.
2. No npm/pip sources anywhere in marketplace.json.
3. Validate marketplace.json in CI before merge (a merged broken PR = sync failure = plugins disappear until fixed).
4. Keep individual plugins under the package limits (next section) — oversized plugins fail to deliver.

## Package limits (all paths)

| Limit | Value |
|---|---|
| Uncompressed plugin size | **200 MB** |
| Files per plugin | **5,000** |
| Plugin name | lowercase-hyphen, **≤64 chars** |
| Reserved names | `claude-code-marketplace`, `anthropic-plugins`, `agent-skills`, among others — enforced at upload |

Run `bash scripts/validate.sh <package-dir>` (this plugin's deterministic lane) before tagging a release — it checks all of the above mechanically and warns at 80% of the size/file caps.

## Org distribution states

Once a plugin is in an org marketplace, owners assign it a state:

**Required** > **Installed by default** > **Available for install** > **Not available**

Most-permissive wins across Enterprise groups. Required plugins are non-removable by users, and locally edited plugin files trigger update warnings. If your plugin is a candidate for Required deployment, tune skill triggering conservatively and never ask users to edit installed plugin files.

## The ZIP-upload UX, what users actually do

1. User downloads a release artifact from your GitHub releases page.
2. User unzips locally (if you ship one all-in-one zip; skip this step if you ship per-plugin zips directly).
3. User opens Cowork → **Plugins** page (Customize → Plugins) → upload plugin file.
4. User selects the zip(s).
5. User invokes a skill via natural language or a slash command (restart the app if skills don't register).

Each step is a friction point. Document the path in the README clearly enough that the user only reads it once.

## All-in-one zip vs per-plugin zips

You'll choose between two release-artifact shapes:

**Per-plugin zips** — one zip per plugin attached as a separate release asset. Five plugins = five assets per release.

- Pro: user downloads only the plugins they want; each inner zip stays under the 50 MB org-upload cap more easily.
- Con: user has to read filenames and pick. More cognitive friction.

**Single all-in-one zip wrapping per-plugin zips** — one outer zip per release, containing N inner zips at the root.

- Pro: one download, simpler release page.
- Con: user has to unzip locally before uploading; the outer zip counts against nothing, but each inner zip must individually respect plugin limits.

**Recommendation:** for a multi-plugin marketplace shipping ≤6 plugins per release, ship the single all-in-one zip. For larger bundles or cases where users typically install one plugin in isolation, ship per-plugin zips.

Either way, name zips with the version: `<plugin-name>-<version>.zip` for per-plugin, `<bundle-name>-<version>.zip` for all-in-one. Including the version in the filename makes it unambiguous which release the user has installed.

## GitHub Actions release workflow shape

The mechanical pattern: tag → build zip(s) → create release → attach assets. Use [`softprops/action-gh-release@v2`](https://github.com/softprops/action-gh-release) (canonical for releases as of 2026).

Trigger: tag push matching `v*` (so `v0.3.0`, `v1.0.0`, but not random branch pushes).

Permissions needed: `contents: write` on the workflow's GITHUB_TOKEN. If your org has stricter Actions permissions defaults, the user enables "Read and write permissions" under Settings → Actions → General → Workflow permissions.

Concurrency: lock per ref (`group: release-${{ github.ref }}`) to prevent double-runs if a tag is force-pushed.

Verification step: count built zips before creating the release, and check each against the plugin limits (200 MB uncompressed / 5,000 files). Fail the workflow if zero zips or any oversize, so a misconfigured layout doesn't silently produce a broken release.

Release body: include the install steps **in the release body**, not just in the README. Users reaching the release page from a notification or RSS feed shouldn't have to navigate to find install instructions.

A complete copy-paste workflow lives at `examples/release-workflow.yml`.

## marketplace.json — when it matters

A `marketplace.json` (at `.claude-plugin/marketplace.json` of the repo) describes the marketplace structure (plugins, sources, descriptions). It's read by:

- Claude **Code's** `/plugin marketplace add owner/repo` command.
- Cowork's **marketplace-by-URL** path (any paid-plan user pasting your repo).
- Cowork's **org GitHub sync** (Team/Enterprise admins syncing from your repo).

Only users on the pure ZIP-upload path never see it. As of June 2026 it is **load-bearing for Cowork distribution**, not just a Code-side convenience:

- Every `source` path must resolve to an actual plugin directory (prefer relative paths — fully supported in org sync).
- No npm/pip sources (unsupported in Cowork org marketplaces).
- External github/url sources only if the referenced repo is public.
- Version metadata should match the latest release.

## README install section

The Cowork install section in your README should look roughly like:

```markdown
## Install

**In Cowork — marketplace by URL (recommended):**
Customize → Plugins → add marketplace → paste `<org>/<repo>`. Pick the plugins you want.

**In Cowork — ZIP upload:**
1. Open the [latest release](https://github.com/<org>/<repo>/releases/latest).
2. Download the zip (unzip locally first if it's an all-in-one bundle).
3. Plugins page → upload plugin file → select the zip.

**In Code:** `/plugin marketplace add <org>/<repo>` then `/plugin install <plugin>@<marketplace>`.

**For org admins (Team/Enterprise):** sync this repo into your private marketplace
(Settings → Plugins). All sources are relative paths, so GitHub sync works as-is.
```

Things to avoid in the README:

- Presenting `/plugin marketplace add ...` as the only install path — it's Code's flow; Cowork users need the UI paths.
- "git clone and copy to ~/.claude/plugins/" — works in Code but not Cowork; Cowork's plugin storage is managed by the app.
- Links to Anthropic's curated catalog if your plugin isn't actually there.

## Versioning

Standard semver. Every plugin in a multi-plugin bundle bumps version when its contents change; the bundle metadata version (in `marketplace.json`) bumps when the catalog or any plugin changes.

Tag the repo with `v<bundle-version>`. The release workflow uses the tag name verbatim as the release title and as the version suffix in zip filenames.

Breaking changes (install path changes, hard-removed skills, schema migrations in saved-state files) deserve a major bump. Cowork-only refactors that purge Code paths are breaking changes — bump major.

Org-sync note: because sync fires on merged PRs, a version bump merged to main **is** the deployment for synced orgs. Treat main as a release branch once any org syncs you.

## CHANGELOG

Optional. The release workflow auto-generates release notes from commits since the previous tag, which is usually enough.

If you want a hand-curated changelog, ship `CHANGELOG.md` and reference the latest section in the release body. Don't ship a stale CHANGELOG — that's worse than not shipping one.

## Sources

- *Plugins in Claude Cowork* — [claude.com/docs/cowork/guide/plugins](https://claude.com/docs/cowork/guide/plugins). Verified 2026-06-09.
- *Use plugins in Claude Cowork* — [support.claude.com article 13837440](https://support.claude.com/en/articles/13837440). Verified 2026-06-09.
- *Manage Claude Cowork plugins for your organization* — [support.claude.com article 13837433](https://support.claude.com/en/articles/13837433). Verified 2026-06-09.
