#!/usr/bin/env bash
# Generate a raw changelog between two versions (tags or refs) of a GitHub repo.
#
# Usage: changelog.sh <from-version> <to-version> [owner/repo] [tag-prefix]
#   from-version / to-version : e.g. 0.0.1, v0.0.1, a tag, a branch or a SHA
#   owner/repo                : defaults to the repo of the current directory
#   tag-prefix                : for monorepos, e.g. "my-service/" or "my-service@"
#
# Output: Markdown on stdout, grouped by Conventional Commit type.
set -euo pipefail

FROM="${1:?from-version required}"
TO="${2:?to-version required}"
REPO="${3:-}"
PREFIX="${4:-}"

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || {
    echo "ERROR: no owner/repo given and current directory is not a GitHub repo" >&2
    exit 2
  }
fi

# Resolve a version string to an existing ref, trying common tag conventions.
resolve_ref() {
  local v="$1" bare="${1#v}" candidate
  for candidate in \
    "${PREFIX}${v}" "${PREFIX}v${bare}" "${PREFIX}${bare}" \
    "${v}" "v${bare}" "${bare}"; do
    if gh api "repos/${REPO}/git/ref/tags/${candidate}" --silent 2>/dev/null; then
      echo "$candidate"; return 0
    fi
  done
  # Fall back to any ref GitHub understands (branch, SHA, ...).
  if gh api "repos/${REPO}/commits/${v}" --silent 2>/dev/null; then
    echo "$v"; return 0
  fi
  echo "ERROR: could not resolve '${v}' in ${REPO}. Tags that look similar:" >&2
  gh api "repos/${REPO}/tags" --paginate -q '.[].name' 2>/dev/null \
    | grep -F -- "${bare%.*}" | head -20 >&2 || true
  return 1
}

BASE="$(resolve_ref "$FROM")"
HEAD="$(resolve_ref "$TO")"

# Compare API: paginate so ranges with more than 250 commits are complete.
COMPARE_JSON="$(gh api "repos/${REPO}/compare/${BASE}...${HEAD}?per_page=100" --paginate \
  | jq -s '{
      status: .[0].status,
      ahead_by: .[0].ahead_by,
      behind_by: .[0].behind_by,
      html_url: .[0].html_url,
      files: (.[0].files // [] | length),
      commits: (map(.commits) | add // [])
    }')"

STATUS="$(jq -r .status <<<"$COMPARE_JSON")"
AHEAD="$(jq -r .ahead_by <<<"$COMPARE_JSON")"
BEHIND="$(jq -r .behind_by <<<"$COMPARE_JSON")"
URL="$(jq -r .html_url <<<"$COMPARE_JSON")"
FILES="$(jq -r .files <<<"$COMPARE_JSON")"

# One line per commit, fields separated by \x1f (a non-whitespace IFS keeps empty fields):
# type, scope, breaking, subject, pr, author, short-sha
ROWS="$(jq -r '
  .commits[]
  | (.commit.message | split("\n")) as $lines
  | $lines[0] as $subject
  | ($subject | capture("^(?<type>[a-zA-Z]+)(\\((?<scope>[^)]*)\\))?(?<bang>!)?:\\s*(?<desc>.*)$") // null) as $cc
  | (($subject | capture("\\(#(?<n>[0-9]+)\\)\\s*$") // ($subject | capture("^Merge pull request #(?<n>[0-9]+)")) // {n:""}).n) as $pr
  | [
      ($cc.type // "other" | ascii_downcase),
      ($cc.scope // ""),
      (if ($cc.bang // "") == "!" or ((.commit.message | test("BREAKING CHANGE"))) then "yes" else "" end),
      (if $cc then $cc.desc else $subject end | sub("\\s*\\(#[0-9]+\\)\\s*$"; "")),
      $pr,
      (.author.login // .commit.author.name),
      .sha[0:7]
    ]
  | join("\u001f")' <<<"$COMPARE_JSON")"
SEP=$'\x1f'

section_title() {
  case "$1" in
    feat) echo "Features" ;;
    fix) echo "Bug Fixes" ;;
    perf) echo "Performance" ;;
    refactor) echo "Refactoring" ;;
    docs) echo "Documentation" ;;
    test) echo "Tests" ;;
    build|ci) echo "Build & CI" ;;
    chore) echo "Chores" ;;
    revert) echo "Reverts" ;;
    *) echo "Other Changes" ;;
  esac
}

format_row() {
  local scope="$2" desc="$4" pr="$5" author="$6" sha="$7" line="- "
  [[ -n "$scope" ]] && line+="**${scope}:** "
  line+="${desc}"
  if [[ -n "$pr" ]]; then
    line+=" ([#${pr}](https://github.com/${REPO}/pull/${pr}))"
  else
    line+=" ([${sha}](https://github.com/${REPO}/commit/${sha}))"
  fi
  line+=" — @${author}"
  echo "$line"
}

echo "# Changelog: ${REPO} ${BASE} → ${HEAD}"
echo
echo "- **Commits:** ${AHEAD}  |  **Files changed:** ${FILES}  |  **Compare:** ${URL}"
if [[ "$STATUS" == "diverged" || "$STATUS" == "behind" ]]; then
  echo "- **Warning:** compare status is \`${STATUS}\` (${BEHIND} commits in ${BASE} are not in ${HEAD}). Check the version order."
fi
if [[ "$FILES" == "300" ]]; then
  echo "- **Note:** GitHub caps the file list at 300; the real count may be higher."
fi
echo

if [[ -z "$ROWS" ]]; then
  echo "_No commits between ${BASE} and ${HEAD}._"
  exit 0
fi

BREAKING="$(awk -F"$SEP" '$3=="yes"' <<<"$ROWS")"
if [[ -n "$BREAKING" ]]; then
  echo "## ⚠️ Breaking Changes"
  while IFS="$SEP" read -r t s b d p a h; do
    format_row "$t" "$s" "$b" "$d" "$p" "$a" "$h"
  done <<<"$BREAKING"
  echo
fi

for type in feat fix perf refactor revert docs test build ci chore other; do
  if [[ "$type" == "other" ]]; then
    SECTION="$(awk -F"$SEP" '$1!~/^(feat|fix|perf|refactor|revert|docs|test|build|ci|chore)$/' <<<"$ROWS")"
  else
    SECTION="$(awk -F"$SEP" -v t="$type" '$1==t' <<<"$ROWS")"
  fi
  [[ -z "$SECTION" ]] && continue
  # build and ci share a heading; print it once.
  [[ "$type" == "ci" && -n "$(awk -F"$SEP" '$1=="build"' <<<"$ROWS")" ]] || {
    echo "## $(section_title "$type")"
  }
  while IFS="$SEP" read -r t s b d p a h; do
    format_row "$t" "$s" "$b" "$d" "$p" "$a" "$h"
  done <<<"$SECTION"
  [[ "$type" == "build" && -n "$(awk -F"$SEP" '$1=="ci"' <<<"$ROWS")" ]] || echo
done

echo "## Contributors"
cut -d"$SEP" -f6 <<<"$ROWS" | sort -u | sed 's/^/- @/'
