#!/usr/bin/env bash
# Tests for scripts/guards/repo-hygiene.sh. Runs in CI (.github/workflows/guards.yml) and locally:
#   bash scripts/guards/test-repo-hygiene.sh
#
# A guard that stops catching what it was written to catch fails silently, so every check in the
# guard has a case here that must fail, alongside cases that must pass. Each case builds a
# throwaway git repository holding the guard, a known-good guards.yml and the files under test,
# stages them (the guard reads the index, so nothing is committed) and runs the guard.

set -euo pipefail

root="$(git rev-parse --show-toplevel)"
guard="$root/scripts/guards/repo-hygiene.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

passed=0
failed=0
n=0

# A guards.yml that passes every check, used as the base of each case.
good_workflow='# This header may mention pull_request_target and uses: x@v1 without failing.
name: Guards
on:
  pull_request:
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@0123456789abcdef0123456789abcdef01234567 # v1.0.0
      - uses: ./local-action
      - uses: docker://alpine@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
'

# new_bare_repo: an empty repository holding only the guard.
new_bare_repo() {
  n=$((n + 1))
  repo="$work/case$n"
  mkdir -p "$repo/scripts/guards"
  git -C "$repo" init -q
  cp "$guard" "$repo/scripts/guards/repo-hygiene.sh"
}

# new_repo: a repository with the guard and the good workflow.
new_repo() {
  new_bare_repo
  mkdir -p "$repo/.github/workflows"
  printf '%s' "$good_workflow" > "$repo/.github/workflows/guards.yml"
}

# put PATH CONTENT: write a file in the current case's repository.
put() {
  mkdir -p "$(dirname "$repo/$1")"
  printf '%s\n' "$2" > "$repo/$1"
}

# run_guard: stage everything in the current case's repository and run the guard there. With
# stage=no set, nothing is staged (for the case where the guard must see no tracked files).
run_guard() {
  if [ "${stage:-yes}" = yes ]; then
    git -C "$repo" add -A -f
  fi
  set +e
  output="$(cd "$repo" && bash scripts/guards/repo-hygiene.sh 2>&1)"
  status=$?
  set -e
}

# expect_pass NAME: the guard must exit 0.
expect_pass() {
  run_guard
  if [ "$status" -eq 0 ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    printf 'NOT OK: %s: expected the guard to pass, got exit %s:\n%s\n\n' "$1" "$status" "$output"
  fi
}

# expect_fail NAME MESSAGE: the guard must exit non-zero and print MESSAGE.
expect_fail() {
  run_guard
  if [ "$status" -ne 0 ] && printf '%s' "$output" | grep -qF -- "$2"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    printf 'NOT OK: %s: expected exit 1 with "%s", got exit %s:\n%s\n\n' "$1" "$2" "$status" "$output"
  fi
}

# step YAML: a workflow whose only step is YAML (indented to sit under steps:).
step() {
  printf 'jobs:\n  a:\n    steps:\n      %s\n' "$1"
}

# --- Cases that must pass ---
new_repo
expect_pass "clean repository"

new_repo; put ".env.example" "API_KEY=placeholder"
expect_pass ".env.example is allowed"

new_repo; put ".github/actions/build/action.yml" "runs:
  using: composite
  steps:
    - uses: actions/checkout@0123456789abcdef0123456789abcdef01234567"
expect_pass "a composite action with a pinned step"

new_repo; put ".github/workflows/notes.yml" "  # pull_request_target is banned; an indented comment may say so
on: [push]
jobs: {}"
expect_pass "pull_request_target mentioned only in a full-line comment"

new_repo; put ".github/workflows/ok.yml" "$(step '- {name: "step #1", uses: actions/checkout@0123456789abcdef0123456789abcdef01234567}')"
expect_pass "a # inside a quoted value next to a pinned action"

# --- Check 1: environment files ---
new_repo; put ".env" "X=1"
expect_fail ".env at the root" "environment file is tracked: .env"

new_repo; put "services/api/.env.local" "X=1"
expect_fail "nested .env.local" "environment file is tracked: services/api/.env.local"

new_repo; put "é/.env" "X=1"
expect_fail ".env under a non-ASCII folder name" "environment file is tracked: é/.env"

new_repo; put "tools/.envrc" "export X=1"
expect_fail ".envrc (direnv)" "environment file is tracked: tools/.envrc"

new_repo; put "config/.ENV" "X=1"
expect_fail ".ENV in capitals" "environment file is tracked: config/.ENV"

new_repo; put "my folder/.env" "X=1"
expect_fail ".env under a folder name with a space" "environment file is tracked: my folder/.env"

# --- Check 2: .DS_Store ---
new_repo; put "docs/.DS_Store" "x"
expect_fail "nested .DS_Store" ".DS_Store is tracked: docs/.DS_Store"

new_repo; put "a/.DS_STORE" "x"
expect_fail ".DS_STORE in capitals" ".DS_Store is tracked: a/.DS_STORE"

new_repo; put "ñ/.DS_Store" "x"
expect_fail ".DS_Store under a non-ASCII folder name" ".DS_Store is tracked: ñ/.DS_Store"

# --- Check 3: pull_request_target ---
new_repo; put ".github/workflows/bad.yml" "on:
  pull_request_target:
jobs: {}"
expect_fail "pull_request_target, block style" ".github/workflows/bad.yml uses pull_request_target"

new_repo; put ".github/workflows/bad.yaml" "on: [push, pull_request_target]
jobs: {}"
expect_fail "pull_request_target, inline list in a .yaml file" ".github/workflows/bad.yaml uses pull_request_target"

new_repo; put ".github/workflows/bad.yml" 'on: {workflow_dispatch: {inputs: {a: {description: "a #"}}}, pull_request_target: {}}
jobs: {}'
expect_fail "pull_request_target after a # inside a quoted value" ".github/workflows/bad.yml uses pull_request_target"

new_repo; put ".github/workflows/bad.yml" "on: [push] # not pull_request_target
jobs: {}"
expect_fail "pull_request_target in a trailing comment fails (the safe way to be wrong)" ".github/workflows/bad.yml uses pull_request_target"

# Over 64 KB, where a pipe into grep -q could lose the match.
new_repo; put ".github/workflows/bad.yml" "on: [pull_request_target]
env:
$(for i in $(seq 1 3000); do printf '  PAD_%s: padding value to make this workflow file large\n' "$i"; done)
jobs: {}"
expect_fail "pull_request_target at the top of a large workflow" ".github/workflows/bad.yml uses pull_request_target"

# --- Check 4: actions pinned to a commit SHA ---
new_repo; put ".github/workflows/bad.yml" "$(step '- uses: actions/checkout@v4')"
expect_fail "tag pin" "action not pinned to a commit SHA: actions/checkout@v4"

new_repo; put ".github/workflows/bad.yml" "$(step "- uses: 'actions/checkout@v4'")"
expect_fail "quoted tag pin" "action not pinned to a commit SHA: actions/checkout@v4"

new_repo; put ".github/workflows/bad.yml" "$(step '- {uses: evil/act@main}')"
expect_fail "inline mapping, uses first" "action not pinned to a commit SHA: evil/act@main"

new_repo; put ".github/workflows/bad.yml" "$(step '- {name: Build, uses: evil/act@main, with: {x: 1}}')"
expect_fail "inline mapping, uses not first" "action not pinned to a commit SHA: evil/act@main"

new_repo; put ".github/workflows/bad.yml" "$(step '- {name: "a #", uses: evil/act@main}')"
expect_fail "uses after a # inside a quoted value" "action not pinned to a commit SHA: evil/act@main"

new_repo; put ".github/workflows/bad.yml" "$(step '- {"uses": "evil/act@main"}')"
expect_fail "quoted uses key" "action not pinned to a commit SHA: evil/act@main"

new_repo; put ".github/workflows/bad.yml" "$(step '- uses : actions/checkout@v4')"
expect_fail "space before the colon" "action not pinned to a commit SHA: actions/checkout@v4"

new_repo; put ".github/workflows/bad.yml" "$(step "- uses$(printf '\t'): actions/checkout@v4")"
expect_fail "tab before the colon" "action not pinned to a commit SHA: actions/checkout@v4"

new_repo; put ".github/workflows/bad.yml" "$(step '- {"uses" : "evil/act@main"}')"
expect_fail "quoted key with a space before the colon" "action not pinned to a commit SHA: evil/act@main"

new_repo; put ".github/workflows/bad.yml" "$(step '- uses: docker://evil/img:latest')"
expect_fail "docker image on a tag" "docker image not pinned to a sha256 digest: docker://evil/img:latest"

new_repo; put ".github/actions/build/action.yaml" "runs:
  using: composite
  steps:
    - uses: evil/act@main"
expect_fail "unpinned step inside a composite action" ".github/actions/build/action.yaml: action not pinned to a commit SHA: evil/act@main"

new_repo; put ".github/workflows/bad.yml" "$(step '- uses:
        actions/checkout@v4')"
expect_fail "uses with its value on the next line" "put each action reference on the same line as its uses: key"

new_repo; put ".github/workflows/bad.yml" "$(step '- uses: "
        evil/act@main"')"
expect_fail "double-quoted value continued on the next line" "put each action reference on the same line as its uses: key"

new_repo; put ".github/workflows/bad.yml" "$(step "- uses: '
        evil/act@main'")"
expect_fail "single-quoted value continued on the next line" "put each action reference on the same line as its uses: key"

new_repo; put ".github/workflows/bad.yml" "$(step '- uses: >-
        evil/act@main')"
expect_fail "folded block value" "put each action reference on the same line as its uses: key"

new_repo; put ".github/workflows/bad.yml" "jobs:
  a:
    uses: org/repo/.github/workflows/ci.yml@main"
expect_fail "reusable workflow on a branch" "action not pinned to a commit SHA: org/repo/.github/workflows/ci.yml@main"

new_repo; put ".github/workflows/bad.yml" "$(step '- uses: actions/checkout@0123456789ABCDEF0123456789ABCDEF01234567')"
expect_fail "uppercase SHA" "action not pinned to a commit SHA: actions/checkout@0123456789ABCDEF0123456789ABCDEF01234567"

new_repo; put ".github/workflows/bad.yml" "$(step '- uses: actions/checkout@0123456789abcdef')"
expect_fail "short SHA" "action not pinned to a commit SHA: actions/checkout@0123456789abcdef"

# --- The guard refuses to pass when it has nothing to check ---
new_bare_repo; put "README.md" "x"
expect_fail "guards.yml not tracked" "could not find .github/workflows/guards.yml"

new_bare_repo
stage=no expect_fail "no tracked files" "git ls-files returned no files"

# --- Every problem is reported, not only the first ---
new_repo; put ".env" "X=1"; put "a/.DS_Store" "x"; put ".github/workflows/bad.yml" "on: [pull_request_target]
jobs: {a: {steps: [{uses: x/y@v1}]}}"
expect_fail "several problems in one run" "4 problem(s) found"

echo "test-repo-hygiene: $passed passed, $failed failed."
# A run with no cases would prove nothing.
if [ "$passed" -eq 0 ] || [ "$failed" -gt 0 ]; then
  exit 1
fi
