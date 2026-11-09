#!/usr/bin/env bash
# Runs every guard and every guard's tests, the same way CI does. Run it before a PR leaves draft:
#   bash scripts/guards/run-all.sh
#
# The tests are found by name (scripts/guards/test-*), so a new guard's tests run without anyone
# remembering to list them. Finding no tests is a failure: an empty run would prove nothing.
# The PR description check isn't run here, because it needs a PR; to check a description locally:
#   node scripts/guards/pr-description.mjs path/to/description.md

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

bash scripts/guards/repo-hygiene.sh

shopt -s nullglob
tests=(scripts/guards/test-*)
if [ "${#tests[@]}" -eq 0 ]; then
  echo "run-all: no scripts/guards/test-* files found; the guards are untested."
  exit 1
fi

for t in "${tests[@]}"; do
  case "$t" in
    *.sh) bash "$t" ;;
    *.mjs) node "$t" ;;
    *)
      echo "run-all: don't know how to run $t (expected .sh or .mjs)."
      exit 1
      ;;
  esac
done

echo "run-all: ${#tests[@]} test file(s) and the repo-hygiene guard passed."
