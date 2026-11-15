// sonastik.ee — client-side dictionary search.
// Data format (data/dictionary.jsonl, one entry per line; data/meta.json):
//   { source, url, license, fetched, entries }
//   {"w":"pank","pos":"s","hom":1,"d":["mitmesuguseid rahaoperatsioone ..."]}
// The JSONL is streamed and parsed line by line, so search works while the
// rest of the dictionary is still loading.

var MAX_RESULTS = 60;

// Normalize for search: lowercase, trim, collapse whitespace.
function normalize(text) {
  return String(text || '').toLowerCase().trim().replace(/\s+/g, ' ');
}

// Prefix matches first, then substring matches elsewhere. Stable within groups.
function searchEntries(entries, query, limit) {
  var q = normalize(query);
  if (!q) return [];
  var prefixed = [];
  var contained = [];
  for (var i = 0; i < entries.length; i++) {
    var e = entries[i];
    var lower = e.w.toLowerCase();
    if (lower.startsWith(q)) {
      prefixed.push(e);
    } else if (lower.indexOf(q) !== -1) {
      contained.push(e);
    }
  }
  return prefixed.concat(contained).slice(0, limit || MAX_RESULTS);
}

function escapeHtml(text) {
  var el = document.createElement('span');
  el.textContent = text;
  return el.innerHTML;
}

function posLabel(code) {
  var labels = {
    s: 'nimisõna',
    v: 'tegusõna',
    a: 'omadussõna',
    adv: 'määrsõna',
    d: 'asesõna',
    g: 'arvsõna',
    i: 'hüüdssõna',
    j: 'sidesõna',
    k: 'kaassõna',
    y: 'lühend',
    t: 'tähtühend',
    z: 'sümbol',
    n: 'pärisnimi',
    af: 'omadussõna-fraas',
    sf: 'nimisõna-fraas'
  };
  return labels[code] || code;
}

function entryHtml(entry) {
  var hom = entry.hom > 1 ? ' <span class="text-white/50">[' + entry.hom + ']</span>' : '';
  var pos = entry.pos ? ' <span class="text-white/50">(' + escapeHtml(posLabel(entry.pos)) + ')</span>' : '';
  var defs;
  if (entry.d && entry.d.length) {
    defs = '<ul class="mt-1 space-y-1">' + entry.d.map(function (d) {
      return '<li class="text-white/80"><span class="text-white/50">&#45; </span>' + escapeHtml(d) + '</li>';
    }).join('') + '</ul>';
  } else {
    defs = '<p class="mt-1 text-white/50">- tähendus puudub selles sõnakogus</p>';
  }
  return '<article class="py-4 border-b border-white/15">'
    + '<h2 class="font-bold">' + escapeHtml(entry.w) + hom + pos + '</h2>'
    + defs
    + '</article>';
}

function renderResults(entries, count) {
  if (!entries.length) {
    return '<p class="text-white/50">&gt; ei leitud<span class="animate-pulse">_</span></p>';
  }
  var more = count > entries.length
    ? '<p class="py-3 text-xs text-white/50">+ veel ' + (count - entries.length) + ' vastet &mdash; täpsem otsing kitsendab nimekirja</p>'
    : '';
  return entries.map(entryHtml).join('') + more;
}

function fmt(n) {
  return n.toLocaleString('et-EE');
}

// Stream data/dictionary.jsonl line by line. Calls onProgress(loadedSoFar)
// after each chunk so the UI can search what has already arrived.
// baseUrl is optional and only used outside the browser (tests).
async function loadDictionary(meta, onProgress, baseUrl) {
  var root = baseUrl || '';
  var res = await fetch(root + 'data/dictionary.jsonl');
  if (!res.ok) throw new Error('HTTP ' + res.status + ' for dictionary.jsonl');
  var reader = res.body.getReader();
  var decoder = new TextDecoder();
  var buf = '';
  var entries = [];
  for (;;) {
    var r = await reader.read();
    if (r.done) break;
    buf += decoder.decode(r.value, { stream: true });
    var nl;
    while ((nl = buf.indexOf('\n')) !== -1) {
      var line = buf.slice(0, nl);
      buf = buf.slice(nl + 1);
      if (line) entries.push(JSON.parse(line));
    }
    onProgress(entries.length);
  }
  if (buf.trim()) entries.push(JSON.parse(buf));
  return { meta: meta, entries: entries };
}

function setStatus(text) {
  document.getElementById('status').textContent = text;
}

function init() {
  var input = document.getElementById('search');
  var results = document.getElementById('results');
  var entries = [];
  var meta = null;
  var debounceTimer = null;

  function runSearch() {
    if (!normalize(input.value)) {
      results.innerHTML = '<p class="text-white/50">&gt; ootan päringut&#8230;<span class="animate-pulse">_</span></p>';
      return;
    }
    var matches = searchEntries(entries, input.value, MAX_RESULTS);
    var total = searchEntries(entries, input.value, entries.length);
    results.innerHTML = renderResults(matches, total.length);
  }

  function onProgress(loaded) {
    var total = meta && meta.entries ? ' / ' + fmt(meta.entries) : '';
    setStatus('laen sõnastikku\u2026 ' + fmt(loaded) + total + ' sõna');
    runSearch();
  }

  fetch('data/meta.json')
    .then(function (res) {
      if (!res.ok) throw new Error('HTTP ' + res.status + ' for meta.json');
      return res.json();
    })
    .then(function (m) {
      meta = m;
      return loadDictionary(m, onProgress);
    })
    .then(function (data) {
      entries = data.entries;
      var sample = data.meta && data.meta.sample ? ' (näidisandmed)' : '';
      setStatus(fmt(entries.length) + ' sõna' + sample + ' · allikas: ' + (data.meta.source || 'teadmata') + ' · ' + (data.meta.license || ''));
      runSearch();
    })
    .catch(function (err) {
      setStatus('viga: sõnastikuandmed puuduvad (' + err.message + '). Käivita scripts/convert-ekss.mjs');
      results.innerHTML = '<p class="text-white/50">&gt; andmed laadimata</p>';
    });

  input.addEventListener('input', function () {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(runSearch, 60);
  });

  document.addEventListener('keydown', function (e) {
    if (e.key === '/' && document.activeElement !== input) {
      e.preventDefault();
      input.focus();
    }
  });

  document.querySelectorAll('[data-example]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      input.value = btn.getAttribute('data-example');
      input.focus();
      runSearch();
    });
  });
}

if (typeof document !== 'undefined') {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
}

// Node (for tests): expose pure functions without touching the DOM.
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { normalize: normalize, searchEntries: searchEntries, loadDictionary: loadDictionary };
}
