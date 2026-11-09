<!--
Fill in every section in your own words. When the PR is marked ready for review, the guards
workflow fails it if the description has too little of your own writing. Lines left exactly as
they are in this template don't count (scripts/guards/pr-description.mjs).
-->

Closes #

## Why
<!-- The problem or goal, in plain language. What someone reading this in a year needs to know. -->

## What changed
<!-- The change in user terms first, then anything surprising about how it's built. -->

## How verified
<!-- Commands you ran locally and their results (tests, typecheck, lint, build, repo-hygiene). -->

### Review (docs/review.md)
| Lens | Verdict | Findings and what changed in response |
|---|---|---|
| Security | | |
| Privacy and data | | |
| Correctness and tests | | |
| Neutrality | | |
| Maintainability | | |

## Checklist
- [ ] Synthetic data only. No real personal or voter data anywhere in this PR.
- [ ] No secrets, keys or tokens, including in tests, logs and screenshots.
- [ ] Tests that would fail without this change.
- [ ] If a prompt or ranking changed: symmetry check results included above.
- [ ] If a new external service, dependency or data source: its cost and terms are stated, and a
      decision record is added or linked.
