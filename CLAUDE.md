@AGENTS.md

# Claude-specific notes

`AGENTS.md` above is the whole working agreement; this section only adds what is specific to
Claude sessions.

- **Review:** before taking a PR out of draft, follow `docs/review.md`. Run each lens as its own
  subagent, and give it only the diff, the issue, `AGENTS.md` and that lens's section of
  `docs/review.md`. Never pass this session's reasoning or summary of the change. Run the lenses in
  parallel, then paste the verdicts and your responses into the PR.
- **First push of a new branch:** ask the maintainer in chat and wait for a yes (see `AGENTS.md`).
- **Don't read `.env` files** or print environment variables. If you need to know whether a
  variable is set, check for its presence without echoing the value.
- **Ask before running anything that costs money** (paid API calls, a golden run against a live
  model) unless the issue or brief already approves it.
- **Questions go to the maintainer** (the person you're working with), not into assumptions. List
  open questions at the end of your reply or in the session report.
- Verify current facts (APIs, laws, prices, whether a service still exists) with a web search
  before relying on them, and cite what you found.
