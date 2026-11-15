// Throwaway mock of the two Ekilex endpoints used by fetch-dictionary.mjs.
// Run: node test/mock-ekilex.mjs  (serves http://127.0.0.1:8790)
import { createServer } from 'node:http';

const words = [
  { wordId: 1, value: 'käsi', valuePrese: 'käsi', lang: 'est', homonymNr: 1 },
  { wordId: 2, value: 'lustakas', valuePrese: 'lustakas', lang: 'est', homonymNr: 1 },
  { wordId: 3, value: 'puu', valuePrese: 'puu', lang: 'est', homonymNr: 1 },
  { wordId: 4, value: 'puu', valuePrese: 'puu', lang: 'est', homonymNr: 2 },
  { wordId: 9, value: 'chair', valuePrese: 'chair', lang: 'eng', homonymNr: 1 },
];

const details = {
  1: { lexemes: [{ datasetCode: 'eki', pos: [{ code: 's' }], meaning: { definitions: [{ value: 'inimese kehaosa', lang: 'est' }, { value: 'arm', lang: 'eng' }] } }] },
  2: { lexemes: [{ datasetCode: 'eki', pos: [{ code: 'a' }], meaning: { definitions: [{ value: 'lõbus ja naljakas', lang: 'est' }] } }] },
  3: { lexemes: [{ datasetCode: 'eki', pos: [{ code: 's' }], meaning: { definitions: [{ value: 'puittaim', lang: 'est' }] } }] },
  4: { lexemes: [{ datasetCode: 'eki', pos: [{ code: 's' }], meaning: { definitions: [] } }] },
};

createServer((req, res) => {
  res.setHeader('content-type', 'application/json');
  const url = new URL(req.url, 'http://x');
  if (!req.headers['ekilex-api-key']) {
    res.statusCode = 403;
    res.end('{}');
    return;
  }
  if (url.pathname === '/api/public_word/eki') {
    res.end(JSON.stringify(words));
  } else if (url.pathname.startsWith('/api/word/details/')) {
    const id = url.pathname.split('/')[4];
    res.end(JSON.stringify(details[id] || { lexemes: [] }));
  } else {
    res.statusCode = 404;
    res.end('{}');
  }
}).listen(8790, '127.0.0.1', () => console.log('mock ekilex on 8790'));
