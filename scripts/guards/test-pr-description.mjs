#!/usr/bin/env node
// Tests for scripts/guards/pr-description.mjs. Runs in CI (.github/workflows/guards.yml) and
// locally:
//   node scripts/guards/test-pr-description.mjs
//
// They use the repository's real PR template, so a template edit that the check can't handle
// shows up here. The last cases run the script the way CI does, with a GitHub event file.

import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { authorProse, checkPullRequest, MIN_CHARS } from './pr-description.mjs';

const template = readFileSync(
  fileURLToPath(new URL('../../.github/pull_request_template.md', import.meta.url)),
  'utf8',
);
const script = fileURLToPath(new URL('./pr-description.mjs', import.meta.url));
const footer = '\n🤖 Generated with [an AI tool](https://example.com)\n\nhttps://example.com/session/123\n';
const tickAll = (text) => text.replace(/- \[ \]/g, '- [x]');

// Synthetic description text, padded to an exact length of the author's own writing.
const prose = (n) => 'x'.repeat(n);

let passed = 0;
let failed = 0;
function test(name, fn) {
  try {
    fn();
    passed += 1;
  } catch (error) {
    failed += 1;
    console.log(`NOT OK: ${name}\n  ${error.message.split('\n').join('\n  ')}\n`);
  }
}

test('the untouched template counts as no writing', () => {
  assert.equal(authorProse(template, template), '');
});

test('ticking every checkbox adds no writing', () => {
  assert.equal(authorProse(tickAll(template), template), '');
});

test('the AI-tool footer adds no writing', () => {
  assert.equal(authorProse(template + footer, template), '');
});

test('Windows line endings are handled', () => {
  assert.equal(authorProse(template.replace(/\n/g, '\r\n'), template), '');
});

test('re-indented template lines still count as template', () => {
  const reindented = template.split('\n').map((l) => `   ${l}`).join('\n');
  assert.equal(authorProse(reindented, template), '');
});

test('headings the author adds are not counted', () => {
  assert.equal(authorProse('## My own heading\n### Another', template), '');
});

test('text the author writes under the headings is counted', () => {
  const body = template.replace('## Why\n', '## Why\nCampaigns need a census lookup.\n');
  assert.equal(authorProse(body, template), 'Campaigns need a census lookup.');
});

test('a filled-in review row is counted', () => {
  const body = template.replace('| Security | | |', '| Security | SHIP | No findings. |');
  assert.equal(authorProse(body, template), '| Security | SHIP | No findings. |');
});

test('an edited template line is counted', () => {
  const body = template.replace('Closes #', 'Closes #12');
  assert.equal(authorProse(body, template), 'Closes #12');
});

test('a description with no body is too thin', () => {
  assert.equal(checkPullRequest({ body: null, draft: false }, template).ok, false);
});

test(`${MIN_CHARS - 1} characters fail and ${MIN_CHARS} pass`, () => {
  const at = (n) => template.replace('## Why\n', `## Why\n${prose(n)}\n`);
  assert.equal(checkPullRequest({ body: at(MIN_CHARS - 1), draft: false }, template).ok, false);
  assert.equal(checkPullRequest({ body: at(MIN_CHARS), draft: false }, template).ok, true);
});

test('the template plus the footer, ticked, still fails', () => {
  const body = tickAll(template) + footer;
  const result = checkPullRequest({ body, draft: false }, template);
  assert.equal(result.ok, false);
  assert.match(result.message, /0 characters of your own writing/);
});

test('draft PRs are skipped', () => {
  assert.equal(checkPullRequest({ body: '', draft: true }, template).ok, true);
});

// --- The script as CI runs it ---
const work = mkdtempSync(join(tmpdir(), 'pr-description-'));
function runWithEvent(event) {
  const eventPath = join(work, 'event.json');
  writeFileSync(eventPath, JSON.stringify(event));
  return spawnSync(process.execPath, [script], {
    env: { PATH: process.env.PATH, GITHUB_EVENT_PATH: eventPath },
    encoding: 'utf8',
  });
}

test('CI: a thin ready PR exits 1', () => {
  const run = runWithEvent({ pull_request: { body: template, draft: false } });
  assert.equal(run.status, 1, run.stdout + run.stderr);
});

test('CI: a well-described ready PR exits 0', () => {
  const body = template.replace('## Why\n', `## Why\n${prose(MIN_CHARS)}\n`);
  const run = runWithEvent({ pull_request: { body, draft: false } });
  assert.equal(run.status, 0, run.stdout + run.stderr);
});

test('CI: a draft PR exits 0', () => {
  const run = runWithEvent({ pull_request: { body: '', draft: true } });
  assert.equal(run.status, 0, run.stdout + run.stderr);
});

test('CI: an event with no pull request exits 1 instead of passing', () => {
  const run = runWithEvent({ ref: 'refs/heads/main' });
  assert.equal(run.status, 1, run.stdout + run.stderr);
});

test('CI: no event file and no argument exits 1', () => {
  const run = spawnSync(process.execPath, [script], { env: { PATH: process.env.PATH }, encoding: 'utf8' });
  assert.equal(run.status, 1, run.stdout + run.stderr);
});

rmSync(work, { recursive: true, force: true });

console.log(`test-pr-description: ${passed} passed, ${failed} failed.`);
// A run with no cases would prove nothing.
process.exitCode = passed > 0 && failed === 0 ? 0 : 1;
