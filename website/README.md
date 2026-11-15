# sonastik.ee website

A static, single-page Estonian dictionary: type a word, read its definition.
Black and white, monospace, Tailwind CSS, no build step, no server — the whole
dictionary is a JSON Lines file streamed and searched in the browser.

## Where the dictionary comes from

[sonaveeb.ee](https://sonaveeb.ee) is the dictionary portal of the
[Estonian Language Institute](https://eki.ee) (EKI). Its content lives in EKI's
[Ekilex](https://ekilex.ee) database and is licensed
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0), so it may be mirrored
with attribution. There are two ways to get it — a bulk download (recommended,
no account needed) and the Ekilex API.

### 1. Bulk download: EKSS XML (default)

EKI publishes the finished **Eesti keele seletav sõnaraamat** (EKSS — the
explanatory dictionary that underlies the ühendsõnastik's definitions) as a
single ~70 MB XML file, CC BY 4.0, from their download archive:

- archive: https://arhiiv.eki.ee/litsens/ (please fill in the contact form there once)
- data: `.../idkaart/ekss/ekss_EKI_CCBY40.xml`

The converter streams the XML (never loads it whole into memory) and writes
`data/dictionary.jsonl` (one entry per line) plus `data/meta.json`:

```sh
node scripts/convert-ekss.mjs
```

This is what the committed data was built from (~118k entries, ~12 MB). To
refresh, delete `.cache/` and rerun.

Note: this is a curated conversion, not a verbatim dump. It joins EKSS
compound notation (`märk|sõnastik`, `\aabitsa\raamat` -> `märksõnastik`,
`aabitsaraamat`), maps word classes to display codes, derives verbs from
morphology type (EKSS does not tag them directly), prefixes domain labels
(`(geogr) järsk paekallas`), and drops morphology pseudo-entries, suffix
entries and zero-definition phrase entries. The dump has two article classes
— `<s:A>` and `<s:A s:Al="all">` (compounds) — both are converted.

### 2. Ekilex API (current ühendsõnastik)

For the continuously updated EKI combined dictionary instead of the 2009 EKSS
edition, use the public [Ekilex API](https://ekilex.ee/api-reference.html)
(free account + API key, also CC BY 4.0):

```sh
export EKILEX_API_KEY="your-key"   # create at https://ekilex.ee
node scripts/fetch-dictionary.mjs --limit 200   # test slice
node scripts/fetch-dictionary.mjs                # full run (~150k words, resumable)
```

Both scripts produce the same JSONL + meta.json output, so the site works
with either. Note the EKSS download is one request; the API route needs one
request per word.

## Data format

`data/meta.json` describes the dataset; `data/dictionary.jsonl` is JSON Lines,
one entry per line, sorted by word (then homonym):

```jsonc
{"w":"pank","pos":"s","hom":1,"d":["mitmesuguseid rahaoperatsioone ..."]}
```

The browser streams the JSONL and parses it line by line, so search works
while the file is still downloading and the status line shows load progress.

`pos` codes: `s` noun, `v` verb, `a` adjective, `adv` adverb, `d` pronoun,
`g` numeral, `i` interjection, `j` conjunction, `k` adposition. `hom` is the
homonym number (pank 1 = bank, pank 2 = mass, pank 3 = cliff).

## Layout

```
website/
├── index.html              the page
├── app.js                  client-side search
├── vendor/tailwind.js      Tailwind Play CDN, stored locally
├── data/
│   ├── dictionary.jsonl    generated dictionary (JSON Lines, committed, CC BY 4.0)
│   └── meta.json           dataset metadata (source, license, entry count)
├── scripts/
│   ├── convert-ekss.mjs      EKSS XML download -> dictionary.jsonl (default)
│   └── fetch-dictionary.mjs   Ekilex API -> dictionary.jsonl (alternative)
└── test/
    └── mock-ekilex.mjs       mock Ekilex API for testing the fetch script
```

## Run it

Any static file server works:

```sh
cd website
python3 -m http.server 8000
# open http://localhost:8000
```

`fetch()` does not work from `file://`, so use a server, not a double-click.

## License and attribution

Dictionary data: © Eesti Keele Instituut — EKSS / EKI ühendsõnastik, via EKI's
download archive and Ekilex, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0).
The site footer attributes the source. Site code: same license as the
repository root (LGPL-2.1-or-later).
