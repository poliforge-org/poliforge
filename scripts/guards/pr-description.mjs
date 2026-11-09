#!/usr/bin/env node
// PR description check. Runs in CI (.github/workflows/guards.yml, job "PR description") and
// locally against a saved description:
//   node scripts/guards/pr-description.mjs path/to/description.md
// Its own tests: node scripts/guards/test-pr-description.mjs
//
// AGENTS.md asks every PR to explain why it exists, what changed and how it was verified, because
// the maintainer and future contributors read the description to decide whether the change is
// right. This check fails a ready-for-review PR whose description has fewer than MIN_CHARS
// characters of the author's own writing.
//
// "Own writing" means everything except what came from .github/pull_request_template.md: its
// HTML comments, and any line copied from it unchanged (ticking a checklist box doesn't count as
// changing it). The check reads the template itself rather than a list of its phrases, so editing
// the template can't quietly leave old boilerplate counting as prose. Headings and the footer AI
// tools add ("🤖 Generated with ...") don't count either.
//
// Draft PRs are skipped, because a draft's description is still being written. Once a PR is
// ready for review, the check runs on every update to it (new commits, edited description).
//
// Needs Node 18 or later and nothing else: it uses only Node's built-in modules and no token. In
// CI it reads the PR from the event file GitHub provides (GITHUB_EVENT_PATH). Node is used because
// GitHub's runners include it; the guards don't depend on whatever stack PoliForge picks.

import { existsSync, readFileSync, realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

// About three sentences: enough for one each on why, what changed and how it was verified. The
// review table usually adds far more; this is a floor against an empty template, not a target.
export const MIN_CHARS = 200;

const MIN_NODE_MAJOR = 18;

export const TEMPLATE_PATH = fileURLToPath(
  new URL('../../.github/pull_request_template.md', import.meta.url),
);

// Compare lines without caring about indentation, repeated spaces, the list marker (-, * or +)
// or whether a checkbox is ticked.
function normalize(line) {
  return line
    .trim()
    .replace(/\s+/g, ' ')
    .replace(/^[-*+] \[[ xX]\]/, '- [ ]');
}

// An HTML comment that is never closed hides the rest of the text, as it would on GitHub.
function withoutComments(text) {
  return text.replace(/\r\n?/g, '\n').replace(/<!--[\s\S]*?(-->|$)/g, '');
}

// Returns the author's own writing in `body`, joined into one line.
export function authorProse(body, template) {
  const templateLines = new Set(
    withoutComments(template).split('\n').map(normalize).filter(Boolean),
  );
  const kept = [];
  for (const raw of withoutComments(body ?? '').split('\n')) {
    const line = normalize(raw);
    // Everything from the AI-tool footer on is boilerplate.
    if (line.startsWith('🤖 Generated with')) break;
    if (!line || templateLines.has(line) || /^#{1,6}(\s|$)/.test(line)) continue;
    kept.push(line);
  }
  return kept.join(' ');
}

// Returns { ok, message } for a pull request. Pure, so the tests can call it directly.
export function checkPullRequest({ body, draft }, template) {
  if (draft) {
    return { ok: true, message: 'Draft PR: skipping. This check runs when the PR is marked ready.' };
  }
  const length = authorProse(body, template).length;
  if (length < MIN_CHARS) {
    return {
      ok: false,
      message:
        `PR description is too thin: ${length} characters of your own writing, need ${MIN_CHARS}. ` +
        'Fill in Why, What changed and How verified, including the review verdicts from ' +
        'docs/review.md. Lines left as they are in the template don\'t count.',
    };
  }
  return { ok: true, message: `PR description: ${length} characters of the author's own writing (minimum ${MIN_CHARS}).` };
}

function readPullRequest(argv, env) {
  if (argv.length > 0) {
    return { body: readFileSync(argv[0], 'utf8'), draft: false };
  }
  if (!env.GITHUB_EVENT_PATH) {
    throw new Error('Usage: node scripts/guards/pr-description.mjs <description file> (or run in a GitHub Actions pull_request job).');
  }
  const event = JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8'));
  // The workflow only runs this job for pull_request events. If the event has no pull request,
  // something upstream changed: fail rather than pass without checking anything.
  if (!event.pull_request) {
    throw new Error('The GitHub event has no pull_request, so there is no description to check.');
  }
  return { body: event.pull_request.body ?? '', draft: event.pull_request.draft === true };
}

function main() {
  try {
    const major = Number(process.versions.node.split('.')[0]);
    if (major < MIN_NODE_MAJOR) {
      throw new Error(`needs Node ${MIN_NODE_MAJOR} or later; this is Node ${process.versions.node}.`);
    }
    // Without the template, its boilerplate would count as the author's writing.
    if (!existsSync(TEMPLATE_PATH)) {
      throw new Error(`${TEMPLATE_PATH} is missing; the check can't tell template text from the author's writing.`);
    }
    const template = readFileSync(TEMPLATE_PATH, 'utf8');
    const result = checkPullRequest(readPullRequest(process.argv.slice(2), process.env), template);
    console.log(result.message);
    process.exitCode = result.ok ? 0 : 1;
  } catch (error) {
    console.error(`pr-description: ${error.message}`);
    process.exitCode = 1;
  }
}

// Run only when started directly, not when the tests import this file. Real paths are compared
// so a run through a symlinked folder (as /tmp is on macOS) still checks instead of exiting 0.
function startedDirectly() {
  if (!process.argv[1]) return false;
  try {
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
}

if (startedDirectly()) {
  main();
}
