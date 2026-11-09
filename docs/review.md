# How PoliForge reviews a change

Every pull request is reviewed before it leaves draft. The review is written down here, in the
public repo, so anyone can see exactly how code gets checked, and any contributor (or their AI
agent) can run the same review.

There are two layers. The automated layer runs on its own. The lens review is run by the author
before asking the maintainer to merge.

## Layer 1: automated checks (run on every PR)

| Check | What it catches | Where it's configured |
|---|---|---|
| Guards workflow | Thin PR descriptions; committed `.env` files and `.DS_Store`; `pull_request_target`; third-party actions not pinned to a commit SHA | `.github/workflows/guards.yml`, `scripts/guards/` |
| Secret scanning + push protection | API keys and tokens, blocked before they land | Repo settings |
| CodeQL code scanning | Injection, cross-site scripting, path traversal and similar flaws | Repo settings (default setup) |
| Dependabot | Known-vulnerable dependencies and outdated pinned actions | Repo settings, `.github/dependabot.yml` |
| Stack CI (once the stack is chosen) | Type errors, failing tests, broken builds, a run with no tests | Added with the stack decision record |

A red automated check is never fixed by weakening the check. Fix the cause, or ask the maintainer.

## Layer 2: the five-lens review

Each lens is done by **a reviewer who didn't write the change**: a person, or a separate AI agent
session that has never seen the author's reasoning. One reviewer per lens, so no lens gets skimmed
because another one found something first.

**What each reviewer gets:** the diff, the linked issue, `AGENTS.md`, and its own lens section
below. Nothing else. In particular, not the author's explanation of why the change is fine.

**What each reviewer returns:**
- A verdict: **SHIP**, **SHIP-WITH-NITS** or **FIX-THEN-SHIP**.
- Findings, each with a severity (**blocking**, **should-fix**, **nit**), the file and line, what is
  wrong, and why it matters.
- "Not applicable" is allowed when the change truly doesn't touch a lens (for example, the
  neutrality lens on a CI-only change). Say why in one line.

**Combining verdicts:**
- Any **blocking** finding from the security or the privacy-and-data lens makes the overall verdict
  FIX-THEN-SHIP, whatever the other lenses say.
- Otherwise the overall verdict is the strictest of the five.
- After fixing, re-run only the lenses that had blocking or should-fix findings, on the new diff.
- Record each lens's verdict, the findings and what you changed in the PR under "How verified".
  The maintainer reads that before merging.

### Lens 1: Security

You are reviewing for security only. Assume the repository is public and attackers read every line.
Check:
- Secrets: keys, tokens, passwords or connection strings anywhere in the diff, including tests,
  fixtures, logs and comments. Anything secret reaching client-side code or public env vars.
- Input handling: every value from a user, an external API or a file is validated before use.
  Look for injection (SQL, shell, template, prompt), path traversal and unsafe deserialization.
- Auth and access: who can call this, and is that checked on the server, not only in the UI?
- Network: outbound requests go only to hosts the code intends (no user-controlled URLs without
  an allowlist). Timeouts and error handling don't leak internals.
- CI and supply chain: new workflows or steps, permissions they request, `pull_request_target`,
  unpinned actions, new dependencies (are they maintained, widely used, and needed at all?).
- Prompt-injection exposure: does untrusted text (web pages, documents, user messages) reach an
  AI model in a way that could change what the software does?

### Lens 2: Privacy and data

You are reviewing for privacy and data handling only. Check:
- Only synthetic data appears: in tests, fixtures, seed files, examples, screenshots and docs. Test
  people are obviously fake.
- No voter-file data or real personal data, unless a decision record in `docs/decisions/` allows
  that exact use. If it does, the code follows that record (fields, retention, purpose).
- Campaign isolation: anything that stores or reads campaign data scopes every query to one
  campaign, and a test proves one campaign cannot read another's.
- Data minimization: the change stores only what it needs, and says how long it keeps it.
- Public records keep their source URL and retrieval date.
- Logs, errors and analytics don't capture personal data.

### Lens 3: Correctness and tests

You are reviewing for correctness and test quality only. Check:
- The change does what the linked issue asks, and nothing the issue didn't ask for.
- Each behaviour change has a test that would fail without it. A bug fix has a test that
  reproduces the bug.
- Edge cases: empty input, missing fields, API errors and timeouts, very large input, time zones.
- Tests test behaviour, not implementation details, and don't depend on the network or on each
  other's order.
- No test, check or suite was skipped, deleted or weakened. Any golden-set expected output that
  changed was reviewed by a human, not edited to match the model.

### Lens 4: Neutrality

You are reviewing for political neutrality and transparency only. Check:
- No party, candidate, ideology or issue position is hard-coded in prompts, rankings, defaults,
  sample data, product copy or tests.
- Every factual claim the software produces about a person, bill or vote links to its source, and
  the software says so when it has none rather than guessing.
- Generated content is a draft: nothing is sent, posted or published without an explicit human
  action.
- Prompts are in the repo and readable.
- If a prompt or ranking changed, the PR includes a symmetry check (mirrored inputs with party,
  ideology, candidate or issue-framing labels swapped) and the results look even-handed. If they
  don't, that is blocking.

### Lens 5: Maintainability

You are reviewing for maintainability only. Check:
- The change fits the architecture and the decision records in `docs/decisions/`. A new pattern,
  service, dependency or data source has a decision record or is flagged for one.
- Each external source is reached from one module only.
- Names say what things are. Code a new contributor could follow without the author present.
- Comments explain why, especially around checks and guards.
- No dead code, debugging leftovers or unrelated changes mixed in.
- The change is small enough to review. If it isn't, suggest how to split it.

## Running the review with an AI agent

For each lens, start a fresh agent session (or subagent) and give it this prompt, filled in:

> You are reviewing a pull request to PoliForge, a public, nonpartisan open-source project. You
> did not write this change. Review it through one lens only: **<lens name>**. Read `AGENTS.md`
> and the "<lens name>" section of `docs/review.md`, then the issue and the diff below. Return a
> verdict (SHIP, SHIP-WITH-NITS or FIX-THEN-SHIP) and a list of findings, each with severity
> (blocking, should-fix, nit), file and line, what is wrong and why it matters. If this lens
> doesn't apply to the change, say "Not applicable" and why in one line.
>
> Issue: <link or text>
> Diff: <diff>

Five lenses take more time and usage than one review. That is deliberate: this project puts
code quality and security ahead of speed.
