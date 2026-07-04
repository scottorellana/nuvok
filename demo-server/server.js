// ═════════════════════════════════════════════════════════════
// Prepper Pad — Demo Server
// Serves a web showcase with guides, diagrams and features.
// Pure Node.js, zero dependencies.
// ═════════════════════════════════════════════════════════════
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const PORT = parseInt(process.env.PORT || '8849');
const HOST = '0.0.0.0';
const PUBLIC_DIR = path.join(import.meta.dirname, 'public');

fs.mkdirSync(PUBLIC_DIR, { recursive: true });

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function mimeFor(filename) {
  return MIME[path.extname(filename).toLowerCase()] || 'application/octet-stream';
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  res.setHeader('Access-Control-Allow-Origin', '*');

  let pathname = url.pathname;
  if (pathname === '/' || pathname === '') pathname = '/index.html';

  const filePath = path.join(PUBLIC_DIR, pathname);
  const resolved = path.resolve(filePath);

  if (!resolved.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  if (!fs.existsSync(resolved) || fs.statSync(resolved).isDirectory()) {
    res.writeHead(404);
    res.end('Not found');
    return;
  }

  res.writeHead(200, { 'Content-Type': mimeFor(resolved) });
  fs.createReadStream(resolved).pipe(res);
});

server.listen(PORT, HOST, () => {
  console.log(`\n🎒 Prepper Pad Demo → http://localhost:${PORT}\n`);
});
