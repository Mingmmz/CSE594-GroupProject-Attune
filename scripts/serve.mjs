import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const root = new URL('../app/', import.meta.url);
const files = new Map([
  ['/', ['index.html', 'text/html']],
  ['/index.html', ['index.html', 'text/html']],
  ['/styles.css', ['styles.css', 'text/css']],
  ['/app.mjs', ['app.mjs', 'text/javascript']],
  ['/scenarios.mjs', ['scenarios.mjs', 'text/javascript']],
  ['/model.mjs', ['model.mjs', 'text/javascript']],
  ['/favicon.svg', ['favicon.svg', 'image/svg+xml']],
]);
const port = Number(process.env.PORT ?? 4173);
const server = createServer(async (req, res) => {
  const file = files.get(req.url.split('?')[0]);
  if (!file || !['GET', 'HEAD'].includes(req.method)) {
    res.writeHead(404).end('Not found');
    return;
  }
  try {
    const body = await readFile(fileURLToPath(new URL(file[0], root)));
    res.writeHead(200, {
      'Content-Type': file[1] + '; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    res.end(req.method === 'HEAD' ? undefined : body);
  } catch {
    res.writeHead(500).end('Unable to load the demo');
  }
});
server.listen(port, '127.0.0.1', () => console.log('ATTUNE is running at http://127.0.0.1:' + server.address().port));
