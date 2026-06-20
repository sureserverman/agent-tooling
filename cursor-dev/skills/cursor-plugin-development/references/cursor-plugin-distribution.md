# Cursor plugin distribution (verified 2026-06-09, Cursor 3.7)

Three channels exist as of June 2026: the public marketplace, Team
Marketplaces (2.6+), and local installs. There is no slash-command install
flow — distribution is UI- and dashboard-driven.

## 1. Public marketplace

**User side.** Browse and install from the in-editor **Marketplace panel** or
from [cursor.com/marketplace](https://cursor.com/marketplace). At install time
the user picks **project-scoped** (this workspace) or **user-scoped** (all
workspaces).

**Author side.** Submit at
[cursor.com/marketplace/publish](https://cursor.com/marketplace/publish).
Two facts dominate the publishing decision:

- **Manual review.** Every submission is reviewed by a human before listing.
  Budget days, not minutes; incomplete manifests (no description/author/
  license/repo) slow it down.
- **All marketplace plugins must be open source.** Hard requirement. The
  source repo is part of the listing. If the code can't be public, this
  channel is closed — use a Team Marketplace or local install.

The official reference set: Cursor maintains **~13 official plugins** in the
monorepo [github.com/cursor/plugins](https://github.com/cursor/plugins), all
MIT-licensed. When in doubt about layout, manifest fields, or component
conventions, read those before improvising.

## 2. Team Marketplaces (2.6, Teams/Enterprise plans)

Shipped in Cursor 2.6 (Mar 3, 2026). Private plugin distribution for orgs:

- Admins register **private GitHub repos** in the Cursor dashboard as plugin
  sources. The repo can be a single plugin or a `marketplace.json` multi-plugin
  bundle.
- Access runs through the **Cursor GitHub App** — install it on the org/repo;
  no deploy keys or PATs to manage.
- Each plugin can be marked **required or optional per SCIM group** — required
  plugins are pushed to members of the group; optional ones appear in their
  marketplace panel for self-serve install.
- **Auto-refresh ≤10 minutes:** when the source repo updates, installed copies
  refresh within about ten minutes. Consequence for authors: the default
  branch of a registered repo is effectively *production*. Develop on
  branches; merge = deploy.

Constraints to state plainly in plans: Teams/Enterprise plans only; GitHub
repos only (no GitLab/Bitbucket as of 3.7); required-plugin targeting needs
SCIM groups configured.

## 3. Local installs (the dev loop)

Drop — or better, **symlink** — a plugin directory into:

```
~/.cursor/plugins/local/<plugin-name>
```

then run **Reload Window**. Symlinking your working tree means edit → reload →
test with no copy step:

```bash
ln -s ~/dev/my-plugin ~/.cursor/plugins/local/my-plugin
```

Programmatic alternative: a hook on the **`workspaceOpen`** event can return
`{"pluginPaths": ["/abs/path/to/plugin", …]}` to inject plugin directories
when a workspace opens — useful for monorepos that carry their own plugins, or
for machine-provisioning setups. (Hook mechanics: `cursor-hooks-and-agents`.)

## Choosing a channel

| Situation | Channel |
|---|---|
| General-purpose, code can be public | Public marketplace (and keep the repo installable as a reference) |
| Org-internal, Teams/Enterprise, GitHub | Team Marketplace; mark truly load-bearing plugins required per group |
| Personal tooling, experiments, development | `~/.cursor/plugins/local/` symlink |
| Monorepo that should self-provision | `workspaceOpen` hook returning `pluginPaths` |

## Release hygiene for Team Marketplace authors

Because merges deploy within ~10 minutes:

1. Protect the default branch; require PR review.
2. Bump the manifest `version` in every release PR.
3. Run cursor-dev's `scripts/validate.sh` in CI on the plugin directory — a
   broken `.mdc` or unknown hook event ships to the whole SCIM group
   otherwise.
4. Keep a CHANGELOG; admins and users have no other diff surface.

Sources: [cursor.com/docs/plugins](https://cursor.com/docs/plugins),
[cursor.com/changelog](https://cursor.com/changelog) (2.5, 2.6),
[github.com/cursor/plugins](https://github.com/cursor/plugins). Verified
2026-06-09.
