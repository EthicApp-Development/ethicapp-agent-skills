#!/usr/bin/env bash
# Report what a release would contain: the pull requests merged on the first
# parent line between two refs, with the issues they close, direct commits,
# migrations added, environment contract variables added or removed, and the
# changed top-level paths.
#
# Usage: release-scope.sh PREVIOUS_REF TARGET_REF [MIGRATIONS_DIR] [CONTRACT_FILE]
#   Run from the repository root. Needs git; uses gh for the closing issues
#   when it is available and authenticated (otherwise prints titles only).
# Exit codes: 0 report printed, 1 usage or git error.
set -euo pipefail

if [ $# -lt 2 ]; then
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

prev="$1"
target="$2"
migrations="${3:-}"
contract="${4:-}"
range="$prev..$target"

git rev-parse --verify --quiet "$prev^{commit}" >/dev/null || { echo "unknown ref: $prev" >&2; exit 1; }
git rev-parse --verify --quiet "$target^{commit}" >/dev/null || { echo "unknown ref: $target" >&2; exit 1; }

use_gh=false
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  use_gh=true
fi

echo "# Release scope $range"
echo
echo "- target commit: $(git rev-parse "$target^{commit}")"
echo "- commits (non-merge): $(git rev-list --count --no-merges "$range")"
echo

echo "## Merged pull requests"
echo
found=false
while IFS= read -r line; do
  [ -n "$line" ] || continue
  number="$(printf '%s\n' "$line" | sed -n 's/.*Merge pull request #\([0-9][0-9]*\).*/\1/p')"
  [ -n "$number" ] || continue
  found=true
  if $use_gh; then
    gh pr view "$number" --json number,title,closingIssuesReferences \
      --jq '"- #\(.number) \(.title)" + (if (.closingIssuesReferences | length) > 0 then " (closes " + ([.closingIssuesReferences[] | "#\(.number)"] | join(", ")) + ")" else "" end)' \
      || echo "- #$number (gh lookup failed)"
  else
    echo "- #$number $(git log -1 --format=%b "$(printf '%s' "$line" | cut -d' ' -f1)" | head -1)"
  fi
done < <(git log --first-parent --merges --format='%H %s' "$range")
$found || echo "none"
echo

echo "## Direct commits on the first parent line"
echo
git log --first-parent --no-merges --format='- %h %s' "$range" | sed -n '1,60p'
[ -n "$(git log --first-parent --no-merges --format=%h "$range")" ] || echo "none"
echo

if [ -n "$migrations" ]; then
  echo "## Migrations added ($migrations)"
  echo
  added="$(git diff --name-only --diff-filter=A "$prev...$target" -- "$migrations" | sed 's#.*/##')"
  if [ -n "$added" ]; then printf '%s\n' "$added" | sed 's/^/- /'; else echo "none"; fi
  modified="$(git diff --name-only --diff-filter=MRD "$prev...$target" -- "$migrations")"
  if [ -n "$modified" ]; then
    echo
    echo "WARNING: existing migrations modified, renamed or deleted:"
    printf '%s\n' "$modified" | sed 's/^/- /'
  fi
  echo
fi

if [ -n "$contract" ]; then
  echo "## Environment contract ($contract)"
  echo
  vars() {
    git show "$1:$contract" 2>/dev/null \
      | grep -E '^[[:space:]]{2,6}-?[[:space:]]*name:[[:space:]]*[A-Z][A-Z0-9_]+|^[[:space:]]{2,4}[A-Z][A-Z0-9_]{2,}:[[:space:]]*$' \
      | sed -E 's/.*name:[[:space:]]*//; s/^[[:space:]]+//; s/:[[:space:]]*$//' | sort -u
  }
  before="$(vars "$prev")"
  after="$(vars "$target")"
  added_vars="$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^$/d')"
  removed_vars="$(comm -23 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^$/d')"
  if git diff --quiet "$prev" "$target" -- "$contract"; then
    echo "unchanged"
  else
    echo "- added: $(printf '%s' "$added_vars" | tr '\n' ' ' | sed 's/ $//')"
    echo "- removed: $(printf '%s' "$removed_vars" | tr '\n' ' ' | sed 's/ $//')"
    echo "- the file changed: read \`git diff $range -- $contract\` for defaults, descriptions and required flags"
  fi
  echo
fi

echo "## Changed paths (top two levels, files changed)"
echo
git diff --name-only "$prev...$target" | awk -F/ '{ if (NF > 2) print $1 "/" $2; else print $1 }' | sort | uniq -c | sort -rn | sed -n '1,40p'
