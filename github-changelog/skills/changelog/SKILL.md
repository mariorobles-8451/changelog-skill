---
name: changelog
description: Generate a changelog of what changed in a GitHub repo/service between two versions (tags, releases, branches or SHAs), e.g. "what changed between 0.0.1 and 0.0.9". Use when someone asks for a changelog, release notes, a diff between versions/releases/tags, or "what shipped since X".
---

# Changelog between two versions

Produces a readable changelog of everything that landed in a GitHub repo between two versions, using the `gh` CLI (no clone needed).

## Inputs

- **From version** and **to version** (required). Accepts `0.0.1`, `v0.0.1`, any tag, branch or SHA. The script tries `v`/no-`v` variants automatically.
- **Repo** as `owner/repo`. If not given: use the current directory's repo if it is a GitHub repo; otherwise ask the user. Don't guess the repo from the service name.
- **Tag prefix** (optional, monorepos only), e.g. `my-service/` or `my-service@`. If the version doesn't resolve, the script prints similar-looking tags: use them to infer the prefix.

If the user gives versions in the wrong order (e.g. `0.0.9 0.0.1`), swap them.

## Steps

1. **Check auth:** `gh auth status`. If not logged in, ask the user to run `! gh auth login`.

2. **Generate the raw changelog:**
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/skills/changelog/scripts/changelog.sh" <from> <to> [owner/repo] [tag-prefix]
   ```
   It outputs Markdown: summary line (commit count, files changed, compare URL), Breaking Changes, then sections by Conventional Commit type (Features, Bug Fixes, ...), and Contributors. Each entry links to its PR, or to the commit if there is no PR.

   If it fails to resolve a version, show the user the similar tags it printed and ask which one they meant (or retry with the inferred prefix).

3. **Polish (only when commits don't follow Conventional Commits).** If most entries land in "Other Changes", re-group them yourself into Features / Fixes / Internal by reading the subjects. For ambiguous items, fetch the PR title/body with `gh pr view <n> -R owner/repo --json title,body,labels`. Never invent changes that aren't in the output.

4. **Add a short summary** (2–4 bullets) on top: the most relevant user-facing changes and any breaking change. Keep the generated sections below it.

5. **Deliver.** Show the changelog in the conversation. If the user wants a file, save it as `CHANGELOG-<repo>-<from>-to-<to>.md` in the current directory. Write the changelog in English unless asked otherwise.

## Notes

- Range semantics: commits reachable from `<to>` but not from `<from>` (GitHub's three-dot compare). If the script warns the status is `diverged`, the versions are on different branches; mention it.
- Bot commits (release bumps, dependabot) are kept; collapse them into one line in step 4 if they add noise.
- Private repos work as long as the `gh` account has access.

## Errors and support

- `gh` not installed or not authenticated, or no access to the repo: tell the user to install `gh` / run `! gh auth login`, and confirm their account can see the repo.
- If the script itself crashes or produces malformed output (not a user input problem), say it's a bug in this plugin and point the user to the maintainer: Mario Robles (m297369@8451.com).
