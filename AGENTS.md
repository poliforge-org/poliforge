# PoliForge: rules for AI agents and contributors

This file is the working agreement for anyone changing this repository, human or AI. Claude Code,
Codex, Cursor and other agents read it automatically. Humans: start with `CONTRIBUTING.md`, then
read this.

## What this project is

PoliForge is open-source software that gives grassroots campaigns the research, planning and
outreach tools that well-funded campaigns already have. It is nonpartisan. Any lawful campaign,
of any party or none, gets the same software. Its credibility depends on that being provably true,
so neutrality and transparency are requirements here, not tone.

**Status:** pre-alpha. The architecture is being redesigned as a single repository, and the stack
is not chosen yet. Before assuming any framework, database or host, read `docs/decisions/`.

## Working agreement

**Proceed without asking:**
- Create branches locally and commit.
- Push further commits to a branch that is already on GitHub, and open **draft** pull requests.
- Run tests, builds, linters, and read-only checks of any kind.
- Add or improve tests.

**Ask the maintainer first** (Tyler Pritchard, @Tyler-Pritchard, reviews and merges):
- **The first push of any new branch.** This repo is public, so a first push is a publication.
  Show what will be pushed (files and a one-line summary) and wait for a yes. Later pushes to the
  same branch don't need asking. This rule stays until the maintainer removes it from this file.
- Merging anything into `main`.
- Creating, closing or relabelling GitHub issues in bulk (more than one at a time).
- Deployment or production settings: hosts, environment variables, domains, auth, donations.
- Adding an external service, a paid dependency, or a new data source (say what it costs and what
  its terms allow).
- Deleting data, rewriting history on shared branches, rotating keys.
- Changing the license, this file, `docs/review.md`, CI gates, or anything that weakens a check.

## This repository is public

Every push is visible to the world the moment it lands, including branches, issues and draft PRs.

- **No secrets in git, ever.** Keys and tokens live in a gitignored `.env` and in the host's
  settings. `.env.example` lists variable names with placeholder values only.
- **A committed secret is a leaked secret.** Rotate it first, then tell the maintainer. Deleting
  the commit afterwards does not un-leak it.
- Nothing sent to the browser is secret. Keys never go in client-side code or public env vars.
- In CI, never use `pull_request_target`, and never give secrets to a workflow that runs code from
  a fork. Pin every third-party action to a full commit SHA. The guards workflow checks both.
- Logs, error messages, fixtures and screenshots contain no keys and no real personal data.

## Data rules

- **Synthetic data only** in git, issues, PRs, chat threads and AI prompts during development.
  Make test people obviously fake.
- **Voter files and personal data about real voters** never go in the repo, in fixtures, or to an
  AI model, unless a decision record in `docs/decisions/` allows that specific use. State laws
  restrict how voter-file data may be used. Research before building.
- **Campaigns are isolated from each other.** Two campaigns using PoliForge may be running against
  each other. Any feature that stores campaign data needs a test proving one campaign cannot read
  another's.
- Public records (legislation, roll-call votes, census data) are fine to store. Keep the source URL
  and retrieval date with every record.

## Neutrality

- No party, candidate, ideology or issue position is hard-coded into prompts, rankings, defaults,
  sample data, product copy or tests. Every campaign runs the same code path.
- Every factual claim the software makes about a person, bill or vote links to its source. With no
  source, it says so rather than guessing.
- Generated outreach, talking points and research are **drafts for a person to review**. The
  software never sends, posts or publishes for a campaign without an explicit human action.
- Prompts live in the repo, versioned and readable. Nothing about how the AI is instructed is
  hidden.
- A change to a prompt or a ranking includes a **symmetry check**: run it on mirrored inputs (swap
  the party, ideology, candidate or issue-framing labels) and show the results in the PR. Results
  that aren't even-handed block the merge.

## External sources

- Prefer official APIs and bulk downloads to scraping. Respect terms of service, `robots.txt` and
  rate limits.
- Each external source is reached from one module only. When a guard test for that exists, keep it.
- Before building on an API, confirm it still exists and is still free. Several sources in the
  original plan may be gone.
- **Free or cheap first.** Prefer services whose free tier covers a small campaign. Note any cost
  in the PR.

## Quality bar

Code quality and security come before speed here.

- Every change comes with tests that would fail without it. A bug fix starts with a failing test.
- **A check that silently stops checking is the worst kind of bug.** CI runs the whole suite, and a
  run that collects no tests or skips a suite fails. Never weaken, skip or delete a check to get to
  green: fix the cause, or ask.
- Enforce rules in code where you can: a guard that scans the source beats a sentence here.
- **Before a PR leaves draft:**
  1. Run the full test suite, typecheck, lint and build locally, plus `scripts/guards/repo-hygiene.sh`.
  2. Run the **review in `docs/review.md`**: five lenses (security, privacy and data, correctness
     and tests, neutrality, maintainability), each done by a reviewer who didn't write the change.
  3. Fix every blocking finding, then record each lens's verdict and your responses under
     "How verified" in the PR.
- **AI features get a golden set:** fixed inputs with human-reviewed expected outputs. Never edit an
  expected output to match what the model said. If the model is wrong, mark the case pending and
  name the defect.
- Frameworks change faster than any model's training data. Read the installed version's docs
  before using an API.

## Git, issues and decisions

- **Issues:** work is tracked in this repo's GitHub Issues, planned on the PoliForge project board.
  Each issue says why it exists in plain language; agent detail goes in a collapsed
  `<details><summary>Agent notes</summary>` section at the end.
- **Branches:** `<issue number>-short-description`, for example `12-census-client`. This matches the
  name GitHub suggests from an issue's "Create a branch" link.
- **Commits** say why, not only what, and name the issue (`#12`).
- **PRs:** open as drafts, fill in the template, and link the issue (`Closes #12`). A PR whose
  description is too thin fails CI.
- **Decisions:** any significant choice (stack, license, data source, data policy) is recorded in
  `docs/decisions/NNNN-title.md`: context, decision, alternatives, consequences. This is the public
  record of why PoliForge works the way it does.
