#!/usr/bin/env bash
# Repository hygiene guard. Runs in CI (.github/workflows/guards.yml) and locally:
#   bash scripts/guards/repo-hygiene.sh
# Its own tests: bash scripts/guards/test-repo-hygiene.sh
#
# Each check here encodes a rule from AGENTS.md as code, because a rule that only lives in prose
# gets forgotten. Every check collects its own failures and the script exits non-zero at the end
# if any check failed, so one problem never hides another.
#
# It scans files tracked by git (git ls-files), not the working tree, because only tracked files
# reach the public repo. Run it from anywhere inside the repository.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

failures=0
fail() {
  echo "FAIL: $*"
  failures=$((failures + 1))
}

# The file list is written to a temporary file first, so that set -e stops the script if git
# fails. Written as `while read ...; done < <(git ls-files)`, a git failure would be swallowed by
# the process substitution and the guard would scan an empty list and pass: a check that silently
# stops checking.
#
# -z separates paths with NUL bytes and prints them unquoted. Without it, git wraps any path with
# non-ASCII or special characters in quotes ("\303\251/.env"), and a check that compares the file
# name would never match it.
list="$(mktemp)"
trap 'rm -f "$list"' EXIT
git ls-files -z > "$list"

files=()
while IFS= read -r -d '' path; do
  files+=("$path")
done < "$list"

if [ "${#files[@]}" -eq 0 ]; then
  fail "git ls-files returned no files; the guard has nothing to check"
fi

workflows=()
found_own_workflow=false
# "${array[@]+...}" keeps an empty array from tripping set -u on older bash (macOS ships 3.2).
for path in "${files[@]+"${files[@]}"}"; do
  name="${path##*/}"

  # 1. No environment files. .env.example (placeholders only) is the one allowed exception.
  case "$name" in
    .env.example) ;;
    .env | .env.*) fail "environment file is tracked: $path (secrets belong in a gitignored .env)" ;;
  esac

  # 2. No macOS metadata files.
  if [ "$name" = ".DS_Store" ]; then
    fail ".DS_Store is tracked: $path"
  fi

  # Checks 3 and 4 only look at workflow files. A glob, not a regex, so the dots are literal.
  case "$path" in
    .github/workflows/*.yml | .github/workflows/*.yaml) workflows+=("$path") ;;
  esac
  if [ "$path" = ".github/workflows/guards.yml" ]; then
    found_own_workflow=true
  fi
done

# The guard must find its own workflow. If the workflow filter above ever broke, every workflow
# check below would pass on an empty list.
if [ "$found_own_workflow" != true ]; then
  fail "could not find .github/workflows/guards.yml; the workflow checks would check nothing"
fi

for wf in "${workflows[@]+"${workflows[@]}"}"; do
  # YAML comments are removed before checks 3 and 4, so a comment may explain a rule (the header
  # of guards.yml names the banned trigger) without tripping it. A YAML comment starts with # at
  # the start of a line or after whitespace; a # inside a value, as in a URL fragment, is kept.
  code="$(sed -E 's/(^|[[:space:]])#.*$//' "$wf")"

  # 3. pull_request_target runs with the base repo's secrets and write token while able to check
  #    out fork code. Banned outright (AGENTS.md, "This repository is public").
  if printf '%s\n' "$code" | grep -q 'pull_request_target'; then
    fail "$wf uses pull_request_target"
  fi

  # 4. Third-party actions and reusable workflows must be pinned to a full 40-character commit
  #    SHA. A tag like @v4 can be moved by whoever controls the action's repo; a SHA can't.
  #    Every `uses:` on a line is found, wherever it sits, so block style (- uses: x) and inline
  #    style (- {name: a, uses: x}) are both checked. Example of one extracted reference:
  #      `- uses: "actions/checkout@<sha>"`  ->  actions/checkout@<sha>
  #    Local actions (./path) and docker:// images are exempt here.
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    case "$ref" in
      ./* | docker://*) continue ;;
    esac
    if ! printf '%s' "$ref" | grep -qE '^[^@[:space:]]+@[0-9a-f]{40}$'; then
      fail "$wf: action not pinned to a commit SHA: $ref"
    fi
  done < <(printf '%s\n' "$code" \
    | grep -oE "(^|[^[:alnum:]_-])uses:[[:space:]]*[^[:space:],}]+" \
    | sed -E "s/^.*uses:[[:space:]]*//; s/^[\"']//; s/[\"']$//" \
    || true)
done

if [ "$failures" -gt 0 ]; then
  echo
  echo "repo-hygiene: $failures problem(s) found."
  exit 1
fi

echo "repo-hygiene: all checks passed."
