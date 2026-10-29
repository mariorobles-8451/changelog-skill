# changelog-skill

A Claude Code plugin that generates a changelog of what changed in a GitHub repo/service between two versions.

```
/github-changelog:changelog 0.0.1 0.0.9 my-org/my-service
```

Or just ask Claude: *"What changed in my-org/my-service between 0.0.1 and 0.0.9?"*

> This plugin is also proposed for the 84.51° enterprise marketplace ([PR #69](https://github.com/8451LLC/effo-claude-code-marketplace/pull/69)). Once it's merged, prefer installing it from there.

## Install

In Claude Code:

```
/plugin marketplace add mariorobles-8451/changelog-skill
/plugin install github-changelog@changelog-skill
```

Or try it for one session without installing:

```bash
git clone https://github.com/mariorobles-8451/changelog-skill
claude --plugin-dir ./changelog-skill/github-changelog
```

## Requirements

- [`gh`](https://cli.github.com/) authenticated (`gh auth login`) with access to the target repo
- `jq`
- bash (macOS / Linux)

See [`github-changelog/README.md`](github-changelog/README.md) for inputs, output format, external effects and testing.
