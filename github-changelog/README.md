# github-changelog

Generate a changelog of what changed in a GitHub repo/service between two versions.

```
/github-changelog:changelog 0.0.1 0.0.9 my-org/my-service
```

Or just ask: *"What changed in my-org/my-service between 0.0.1 and 0.0.9?"*

## What you get

- Summary: commit count, files changed, link to the GitHub compare view
- **Breaking Changes** (from `!` or `BREAKING CHANGE` in commit messages)
- Sections by Conventional Commit type: Features, Bug Fixes, Performance, Refactoring, ...
- Each entry linked to its PR (or commit when there is no PR) and its author
- Contributors list
- A short human-readable summary on top, written by Claude

Commits that don't follow Conventional Commits are re-grouped by Claude from their subjects and PR titles.

## Inputs

| Input | Required | Notes |
|---|---|---|
| From / to version | Yes | `0.0.1`, `v0.0.1`, any tag, branch or SHA. `v` / no-`v` variants are resolved automatically. |
| Repo (`owner/repo`) | No | Defaults to the GitHub repo of the current directory. |
| Tag prefix | No | Monorepos only, e.g. `my-service/` or `my-service@`. |

If a version can't be resolved, the plugin lists similar existing tags.

## Requirements

- [`gh`](https://cli.github.com/) authenticated (`gh auth login`) with access to the target repo
- `jq`
- bash (macOS / Linux)

No clone is needed: everything goes through the GitHub compare API.

## Skills

| Skill | Purpose | Triggers when |
|---|---|---|
| `changelog` | Builds a changelog between two versions of a GitHub repo | You ask for a changelog, release notes, or what changed / shipped between two versions, tags or releases |

## External effects

- **Network:** read-only calls to the GitHub REST API through `gh` (`repos/{repo}/git/ref/tags/*`, `repos/{repo}/commits/*`, `repos/{repo}/compare/*`, `repos/{repo}/tags`), and optionally `gh pr view` to read PR titles.
- **Local files:** none, unless you ask to save the changelog; then it writes `CHANGELOG-<repo>-<from>-to-<to>.md` in the current directory.
- **Configuration / PATH:** nothing is changed.

## Testing

1. Load the plugin locally: `claude --plugin-dir ./github-changelog`
2. Ask: *"What changed in axios/axios between 1.7.0 and 1.7.2?"* — expect a summary plus Bug Fixes (#6410, #6413) and Chores sections.
3. Ask with a version that doesn't exist (e.g. `1.7.99`) — expect an error listing similar tags (`v1.7.9`, `v1.7.8`, ...).
4. Overeagerness: ask unrelated things (e.g. *"show me the git log of this repo"*, *"write a CHANGELOG.md entry for my change"*) — the skill should not be invoked.

## Support

Maintainer: Mario Robles (m297369@8451.com). If the script fails for reasons other than input or `gh` auth, please report it.

## Running the script directly

```bash
skills/changelog/scripts/changelog.sh <from> <to> [owner/repo] [tag-prefix]
```
