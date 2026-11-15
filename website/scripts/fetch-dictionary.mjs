#!/usr/bin/env node
// Fetches the EKI combined dictionary ("EKI ühendsõnastik") from the Ekilex public
// API — the same data sonaveeb.ee displays — and writes static JSON Lines the
// website streams and searches client-side.
//
// Prerequisites (one time):
//   1. Create a free account at https://ekilex.ee
//   2. Generate an API key on your profile page
//   3. export EKILEX_API_KEY="..."
//
// Usage:
//   node scripts/fetch-dictionary.mjs [options]
//
// Options:
//   --dataset CODE     Ekilex dataset code (default: eki, the EKI combined dictionary)
//   --lang CODE        Only keep words and definitions in this language (default: est)
//   --limit N          Fetch only the first N words (for testing)
//   --concurrency N    Parallel detail requests (default: 6)
//   --out PATH         Output file (default: ../data/dictionary.jsonl)
//   --fresh            Ignore and reset the checkpoint
//
// The script is resumable: completed words are appended to a checkpoint file and
// skipped on the next run. Use --fresh to start over.
//
// License: Ekilex standard license is CC BY 4.0. Attribute Eesti Keele Instituut.

import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const WEBSITE_DIR = join(SCRIPT_DIR, '..');
const CHECKPOINT_DIR = join(WEBSITE_DIR, '.checkpoints');

// EKILEX_API_URL can override the base for tests.
const API_BASE = process.env.EKILEX_API_URL || 'https://ekilex.ee/api';

function parseArgs(argv) {
  const opts = {
    dataset: 'eki',
    lang: 'est',
    limit: null,
    concurrency: 6,
    out: join(WEBSITE_DIR, 'data', 'dictionary.jsonl'),
    fresh: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dataset') opts.dataset = argv[++i];
    else if (a === '--lang') opts.lang = argv[++i];
    else if (a === '--limit') opts.limit = Number(argv[++i]);
    else if (a === '--concurrency') opts.concurrency = Number(argv[++i]);
    else if (a === '--out') opts.out = argv[++i];
    else if (a === '--fresh') opts.fresh = true;
    else {
      console.error(`unknown option: ${a}`);
      process.exit(1);
    }
  }
  return opts;
}

const opts = parseArgs(process.argv.slice(2));
const apiKey = process.env.EKILEX_API_KEY;

if (!apiKey) {
  console.error('EKILEX_API_KEY is not set.');
  console.error('Create a free account at https://ekilex.ee and generate an API key');
  console.error('on your profile page, then: export EKILEX_API_KEY="..."');
  process.exit(1);
}

const checkpointPath = join(CHECKPOINT_DIR, `${opts.dataset}-${opts.lang}.jsonl`);

async function api(pathname, attempt = 0) {
  const res = await fetch(`${API_BASE}${pathname}`, {
    headers: { 'ekilex-api-key': apiKey, Accept: 'application/json' },
  });
  if (res.status === 429 || res.status >= 500) {
    if (attempt >= 5) throw new Error(`giving up on ${pathname} after ${res.status}`);
    const waitMs = (429 === res.status ? 5000 : 1000) * (attempt + 1);
    await new Promise((r) => setTimeout(r, waitMs));
    return api(pathname, attempt + 1);
  }
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} for ${pathname}: ${await res.text().catch(() => '')}`);
  }
  return res.json();
}

function extractEntry(word, details) {
  const definitions = [];
  let pos = null;
  for (const lexeme of details.lexemes || []) {
    if (lexeme.datasetCode && lexeme.datasetCode !== opts.dataset) continue;
    if (!pos && Array.isArray(lexeme.pos) && lexeme.pos.length) {
      pos = lexeme.pos[0].code || lexeme.pos[0].value || null;
    }
    for (const def of (lexeme.meaning && lexeme.meaning.definitions) || []) {
      if (def.lang && def.lang !== opts.lang) continue;
      const value = (def.value || '').trim();
      if (value && !definitions.includes(value)) definitions.push(value);
    }
  }
  return {
    id: word.wordId,
    w: word.value,
    pos,
    hom: word.homonymNr || 1,
    d: definitions,
  };
}

async function fetchWordList() {
  console.log(`fetching word list for dataset "${opts.dataset}"...`);
  const words = await api(`/public_word/${opts.dataset}`);
  const seen = new Set();
  const filtered = words.filter((w) => {
    if (!w.value || w.lang !== opts.lang || seen.has(w.wordId)) return false;
    seen.add(w.wordId);
    return true;
  });
  console.log(`  ${words.length} total words, ${filtered.length} in language "${opts.lang}"`);
  return filtered;
}

function loadCheckpoint() {
  const done = new Map();
  if (existsSync(checkpointPath) && !opts.fresh) {
    for (const line of readFileSync(checkpointPath, 'utf8').split('\n')) {
      if (!line.trim()) continue;
      try {
        const entry = JSON.parse(line);
        done.set(entry.id, entry);
      } catch {
        // ignore torn last line from an interrupted run
      }
    }
    console.log(`checkpoint: ${done.size} words already fetched`);
  }
  return done;
}

async function fetchDetails(words, done) {
  const pending = words.filter((w) => !done.has(w.wordId));
  const queue = opts.limit ? pending.slice(0, opts.limit) : pending;
  const total = queue.length;
  console.log(`fetching details for ${total} words (concurrency ${opts.concurrency})...`);
  if (total === 0) return;

  const startedAt = Date.now();
  let completed = 0;
  let failed = 0;
  let index = 0;

  async function worker() {
    while (index < queue.length) {
      const word = queue[index++];
      try {
        const details = await api(`/word/details/${word.wordId}/${opts.dataset}`);
        const entry = extractEntry(word, details);
        done.set(word.wordId, entry);
        if (process.stdout.isTTY) process.stdout.write(`\r${completed + 1}/${total}`);
      } catch (err) {
        failed++;
        console.error(`\nfailed wordId=${word.wordId} (${word.value}): ${err.message}`);
      }
      completed++;
      if (completed % 500 === 0) {
        appendCheckpoint(queue, done);
      }
    }
  }

  await Promise.all(Array.from({ length: Math.min(opts.concurrency, queue.length) }, worker));
  appendCheckpoint(queue, done);

  const secs = ((Date.now() - startedAt) / 1000).toFixed(0);
  console.log(`\ndone: ${completed - failed} ok, ${failed} failed, ${secs}s`);
}

// Persist every entry fetched so far (cheap at this scale: rewrite from the map).
function appendCheckpoint(queue, done) {
  mkdirSync(CHECKPOINT_DIR, { recursive: true });
  const lines = [...done.values()].map((e) => JSON.stringify(e)).join('\n') + '\n';
  writeFileSync(checkpointPath, lines);
}

function writeOutput(words, done) {
  const wordIds = new Set(words.map((w) => w.wordId));
  const entries = [...done.values()]
    .filter((e) => wordIds.has(e.id))
    .sort((a, b) => a.w.localeCompare(b.w, 'et') || (a.hom || 1) - (b.hom || 1));

  // JSON Lines, same format convert-ekss.mjs writes: one entry per line,
  // meta as a sibling meta.json, so the browser can stream the data.
  mkdirSync(dirname(opts.out), { recursive: true });
  const lines = entries.map((e) => JSON.stringify(e)).join('\n') + '\n';
  writeFileSync(opts.out, lines);

  writeFileSync(join(dirname(opts.out), 'meta.json'), JSON.stringify({
    source: 'EKI ühendsõnastik (Ekilex)',
    url: 'https://sonaveeb.ee',
    license: 'CC BY 4.0',
    fetched: new Date().toISOString().slice(0, 10),
    entries: entries.length,
  }, null, 2) + '\n');
  console.log(`wrote ${entries.length} entries to ${opts.out}`);
}

async function main() {
  if (opts.fresh && existsSync(checkpointPath)) {
    rmSync(checkpointPath);
    console.log('checkpoint reset (--fresh)');
  }
  const words = await fetchWordList();
  if (opts.limit) {
    // With --limit, keep the alphabetical head of the list, not the API order,
    // so the sample covers a realistic slice.
    words.sort((a, b) => a.value.localeCompare(b.value, 'et'));
  }
  const done = loadCheckpoint();
  await fetchDetails(words, done);
  writeOutput(words, done);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
