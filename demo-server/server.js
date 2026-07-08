// ═════════════════════════════════════════════════════════════
// Prepper Pad — Demo Server
// Serves a web showcase with guides, diagrams and features.
// Pure Node.js, zero dependencies. LAN-safe defaults applied.
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

// True if `child` is `parent` itself or a path underneath it. A bare
// startsWith() on strings would also accept a sibling like "publicEvil"
// when parent is "public" — this checks the real directory boundary.
function isInside(child, parent) {
  const rel = path.relative(parent, child);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

// 416 Range Not Satisfiable response for browsers / download managers
// that send malformed Range headers.
function sendRangeNotSatisfiable(res, size) {
  res.writeHead(416, {
    'Content-Range': `bytes */${size}`,
    'Accept-Ranges': 'bytes',
  });
  res.end('Range not satisfiable');
}

// Parse a single HTTP Range header. Supports the three shapes:
//   bytes=START-END   bytes=START-   bytes=-SUFFIX
// Returns null when malformed or unsatisfiable.
function parseRange(range, size) {
  const match = /^bytes=(\d*)-(\d*)$/.exec(range || '');
  if (!match) return null;
  let start;
  let end;
  if (match[1] === '' && match[2] === '') return null;
  if (match[1] === '') {
    const suffixLength = parseInt(match[2], 10);
    if (!Number.isSafeInteger(suffixLength) || suffixLength <= 0) return null;
    start = Math.max(size - suffixLength, 0);
    end = size - 1;
  } else {
    start = parseInt(match[1], 10);
    end = match[2] === '' ? size - 1 : parseInt(match[2], 10);
    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end)) return null;
  }
  if (start < 0 || end < start || start >= size) return null;
  return { start, end: Math.min(end, size - 1) };
}

const server = http.createServer((req, res) => {
  // An empty/missing Host header makes `new URL(req.url, 'http://')` throw
  // ERR_INVALID_URL, which would crash the whole process (DoS). Fall back
  // to a safe placeholder so the request is still handled (and rejected)
  // instead of taking the server down.
  let url;
  try {
    url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  } catch {
    res.writeHead(400);
    res.end('Bad Request');
    return;
  }

  // LAN-safe defaults: no MIME sniffing, no framing, explicit CORS so
  // phones/tablets on the same network can fetch metadata.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');

  let pathname = url.pathname;
  if (pathname === '/' || pathname === '') pathname = '/index.html';

  const filePath = path.join(PUBLIC_DIR, pathname);
  const resolved = path.resolve(filePath);

  // Prevent path traversal — use isInside() instead of startsWith() so a
  // sibling like "publicEvil" doesn't pass the boundary check.
  if (!isInside(resolved, PUBLIC_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  if (!fs.existsSync(resolved) || fs.statSync(resolved).isDirectory()) {
    res.writeHead(404);
    res.end('Not found');
    return;
  }

  const stat = fs.statSync(resolved);
  const range = req.headers.range;

  if (range) {
    const parsed = parseRange(range, stat.size);
    if (!parsed) {
      sendRangeNotSatisfiable(res, stat.size);
      return;
    }
    const { start, end } = parsed;
    res.writeHead(206, {
      'Content-Range': `bytes ${start}-${end}/${stat.size}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': end - start + 1,
      'Content-Type': mimeFor(resolved),
    });
    fs.createReadStream(resolved, { start, end }).pipe(res);
    return;
  }

  res.writeHead(200, {
    'Content-Type': mimeFor(resolved),
    'Content-Length': stat.size,
    'Accept-Ranges': 'bytes',
  });
  fs.createReadStream(resolved).pipe(res);
});

server.listen(PORT, HOST, () => {
  console.log(`\n🎒 Prepper Pad Demo → http://localhost:${PORT}\n`);
});