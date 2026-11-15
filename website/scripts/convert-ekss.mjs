#!/usr/bin/env node
// Converts the downloadable EKSS — "Eesti keele seletav sõnaraamat" (Estonian
// explanatory dictionary, EKI) — XML dump into data/dictionary.jsonl for the
// static site. No API key or account needed.
//
// Source (CC BY 4.0, © Eesti Keele Instituut):
//   https://arhiiv.eki.ee/litsens/           (EKI download archive)
//   .../idkaart/ekss/ekss_EKI_CCBY40.xml     (the dictionary itself)
// EKI asks downloaders to leave contact details in the form on the archive
// page; please do that once if you use this dataset.
//
// Usage:
//   node scripts/convert-ekss.mjs [--xml PATH] [--out PATH] [--no-download]
//
// The XML dump (~70 MB) is streamed, never loaded whole into memory. The
// output is JSON Lines (one entry per line) plus a small meta.json, so the
// browser can stream the dictionary too. The XML is cached in .cache/ and
// only downloaded once.

import { createReadStream, createWriteStream, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { once } from 'node:events';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const WEBSITE_DIR = join(SCRIPT_DIR, '..');
const CACHE_DIR = join(WEBSITE_DIR, '.cache');
const XML_URL = 'https://arhiiv.eki.ee/litsents/idkaart/ekss/ekss_EKI_CCBY40.xml';

function parseArgs(argv) {
  const opts = {
    xml: join(CACHE_DIR, 'ekss_EKI_CCBY40.xml'),
    out: join(WEBSITE_DIR, 'data', 'dictionary.jsonl'),
    download: true,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--xml') opts.xml = argv[++i];
    else if (a === '--out') opts.out = argv[++i];
    else if (a === '--no-download') opts.download = false;
    else { console.error(`unknown option: ${a}`); process.exit(1); }
  }
  return opts;
}

const opts = parseArgs(process.argv.slice(2));

async function ensureXml() {
  if (existsSync(opts.xml)) {
    console.log(`using cached XML: ${opts.xml}`);
    return;
  }
  if (!opts.download) {
    console.error(`XML not found at ${opts.xml} (and --no-download given)`);
    process.exit(1);
  }
  console.log(`downloading ${XML_URL} ...`);
  mkdirSync(dirname(opts.xml), { recursive: true });
  const res = await fetch(XML_URL);
  if (!res.ok) throw new Error(`download failed: HTTP ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  writeFileSync(opts.xml, buf);
  console.log(`saved ${buf.length} bytes to ${opts.xml}`);
}

// s:sl word-class codes -> the short codes app.js displays.
const SL_MAP = {
  s: 's', adj: 'a', adv: 'adv', interj: 'i', postp: 'k', prep: 'k',
  pron: 'd', num: 'g', konj: 'j', 'indekl adj': 'a', 'indekl pron': 'd',
};

function decodeEntities(text) {
  return text
    .replace(/<[^>]+>/g, '')       // strip nested markup (s:vtxh etc.)
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

function posOf(article) {
  const sl = article.match(/<s:sl>([^<]+)<\/s:sl>/);
  if (sl) return SL_MAP[sl[1]] || sl[1];
  // No s:sl: verbs have morphology type 37+, particles/abbreviations have none.
  const mt = article.match(/<s:mt>(\d+)<\/s:mt>/);
  if (mt && Number(mt[1]) >= 37) return 'v';
  return null;
}

function definitionsOf(article) {
  // Definitions live in s:dg groups, but also bare inside s:tygrp/s:tygtp
  // (e.g. the intro sense of verbs). Walk tokens in document order, keeping
  // a stack of optional domain labels (s:v, e.g. "muus") from open s:dg groups.
  const defs = [];
  const tokenRe = /<s:dg>|<\/s:dg>|<s:v>([^<]*)<\/s:v>|<s:d>([\s\S]*?)<\/s:d>/g;
  const domainStack = [];
  for (const m of article.matchAll(tokenRe)) {
    if (m[0] === '<s:dg>') {
      domainStack.push(null);
    } else if (m[0] === '</s:dg>') {
      domainStack.pop();
    } else if (m[1] !== undefined) {
      if (domainStack.length) domainStack[domainStack.length - 1] = m[1];
    } else {
      const domain = domainStack.length ? domainStack[domainStack.length - 1] : null;
      const value = (domain ? `(${domain}) ` : '') + decodeEntities(m[2]);
      if (value && !defs.includes(value)) defs.push(value);
    }
  }
  return defs;
}

// One <s:A> article -> one entry, or null if it should not be indexed.
// The dump has two article classes: <s:A> (main words) and
// <s:A s:Al="all"> (compound entries, e.g. "\aabitsa\kirjandus"). Both are
// real headwords in EKI's marksonad.txt and both are converted.
function convertArticle(article, homCount) {
  const wordMatch = article.match(/<s:m[^>]*>([^<]+)<\/s:m>/);
  if (!wordMatch) return null;
  // "|" and "\" mark compound boundaries; EKI's own headword list uses the
  // joined form ("märk|sõnastik" / "\aabitsa\raamat" -> "märksõnastik").
  const word = decodeEntities(wordMatch[1]).replace(/[|\\]/g, '');
  // Skip morphology subentries (undecoded &ema;/&eml; stem markup),
  // suffix pseudo-entries and anything still containing an entity.
  if (!word || word.includes('&') || word.startsWith('-')) return null;

  // Homonyms are separate articles; s:i holds the number when there is one.
  const iAttr = article.match(/<s:m[^>]*\ss:i="(\d+)"/);
  const hom = iAttr ? Number(iAttr[1]) : (homCount.get(word) || 0) + 1;
  homCount.set(word, Math.max(homCount.get(word) || 0, hom));

  // Fully-parenthesized s:d values are usage notes, not definitions.
  const defs = definitionsOf(article).filter((v) => !/^\([^()]*\)$/.test(v));
  if (!defs.length) return null;

  return { w: word, pos: posOf(article), hom, d: defs };
}

// Stream the XML, extracting complete articles (either <s:A> or
// <s:A s:Al="all"> ... </s:A>) without holding the whole document in memory.
async function* readArticles(xmlPath) {
  const stream = createReadStream(xmlPath, { encoding: 'utf8', highWaterMark: 1 << 20 });
  const articleRe = /<s:A(?:\s[^>]*)?>([\s\S]*?)<\/s:A>/g;
  let buf = '';
  for await (const chunk of stream) {
    buf += chunk;
    // exec (not matchAll) advances lastIndex on the regex itself, so we know
    // how far complete matches reached; the rest is an incomplete tail.
    articleRe.lastIndex = 0;
    let consumed = 0;
    for (let m; (m = articleRe.exec(buf)) !== null;) {
      yield m[1];
      consumed = articleRe.lastIndex;
    }
    buf = buf.slice(consumed);
  }
}

async function convert() {
  const entries = [];
  const homCount = new Map();
  for await (const article of readArticles(opts.xml)) {
    const entry = convertArticle(article, homCount);
    if (entry) entries.push(entry);
  }
  // Sort once at the end: prefix-first search display relies on it.
  entries.sort((a, b) => a.w.localeCompare(b.w, 'et') || a.hom - b.hom);
  return entries;
}

async function writeJsonl(entries) {
  mkdirSync(dirname(opts.out), { recursive: true });
  const out = createWriteStream(opts.out, { encoding: 'utf8' });
  for (const entry of entries) {
    if (!out.write(JSON.stringify(entry) + '\n')) {
      await once(out, 'drain');
    }
  }
  out.end();
  await once(out, 'finish');
}

async function main() {
  await ensureXml();
  console.log('parsing XML (streaming)...');
  const entries = await convert();
  await writeJsonl(entries);

  const meta = {
    source: 'Eesti keele seletav sõnaraamat 2009 (EKI)',
    url: 'https://eki.ee/dict/ekss/',
    license: 'CC BY 4.0',
    fetched: new Date().toISOString().slice(0, 10),
    entries: entries.length,
  };
  const metaPath = join(dirname(opts.out), 'meta.json');
  writeFileSync(metaPath, JSON.stringify(meta, null, 2) + '\n');
  console.log(`wrote ${entries.length} entries to ${opts.out}`);
  console.log(`wrote ${metaPath}`);
}

main().catch((err) => { console.error(err); process.exit(1); });
