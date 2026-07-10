// ═════════════════════════════════════════════════════════════
// Nuvok — Local Installer Server
// Serves installers + content packages to any device on the LAN.
// No internet required. Pure Node.js, zero dependencies.
// ═════════════════════════════════════════════════════════════
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';

const PORT = parseInt(process.env.PORT || '8848');
const HOST = '0.0.0.0'; // Listen on all interfaces (LAN accessible)

// ── Paths ──
const ROOT = path.resolve(import.meta.dirname, '..');
const DIST_DIR = path.join(ROOT, 'dist');
const DOWNLOADS_DIR = path.join(import.meta.dirname, 'downloads');
const NUVOK_DIR = path.join(os.homedir(), 'Nuvok');
const PUBLIC_DIR = path.join(import.meta.dirname, 'public');

// ── Ensure downloads dir exists ──
fs.mkdirSync(DOWNLOADS_DIR, { recursive: true });
fs.mkdirSync(PUBLIC_DIR, { recursive: true });

// True if `child` is `parent` itself or a path underneath it. A bare
// startsWith() on strings would also accept a sibling like
// "NuvokEvil" when parent is "Nuvok" — this checks the real
// directory boundary instead.
function isInside(child, parent) {
  const rel = path.relative(parent, child);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

// ── MIME types ──
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.dmg': 'application/octet-stream',
  '.apk': 'application/vnd.android.package-archive',
  '.exe': 'application/vnd.microsoft.portable-executable',
  '.msi': 'application/x-msi',
  '.deb': 'application/vnd.debian.binary-package',
  '.appimage': 'application/octet-stream',
  '.zim': 'application/octet-stream',
  '.pmtiles': 'application/octet-stream',
  '.gguf': 'application/octet-stream',
  '.zip': 'application/zip',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

const CONTENT_ALLOWLIST = Object.freeze({
  zim: new Set(['.zim']),
  maps: new Set(['.pmtiles']),
  models: new Set(['.gguf']),
});

function safeAttachmentName(filename) {
  return path.basename(filename).replace(/[\r\n"\\]/g, '_').slice(0, 160) || 'download.bin';
}

function mimeFor(filename) {
  return MIME[path.extname(filename).toLowerCase()] || 'application/octet-stream';
}

// ── Scan for available installers ──
function installerVersion(filename) {
  const match = /(?:^|[-_])v?(\d+\.\d+\.\d+(?:\+\d+)?)(?=\.|[-_]|$)/i.exec(filename);
  return match ? match[1] : null;
}

function compareSemver(a, b) {
  const pa = String(a || '0.0.0').split('+')[0].split('.').map((x) => parseInt(x, 10) || 0);
  const pb = String(b || '0.0.0').split('+')[0].split('.').map((x) => parseInt(x, 10) || 0);
  for (let i = 0; i < 3; i++) {
    if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) - (pb[i] || 0);
  }
  return 0;
}

function scanInstallers() {
  const all = [];

  // Scan dist/ directory
  const dirs = [DIST_DIR, DOWNLOADS_DIR];
  for (const dir of dirs) {
    if (!fs.existsSync(dir)) continue;
    for (const file of fs.readdirSync(dir)) {
      const full = path.join(dir, file);
      if (!fs.statSync(full).isFile()) continue;
      const ext = path.extname(file).toLowerCase();
      const platform = detectPlatform(file);
      if (platform) {
        all.push({
          name: file,
          platform,
          size: fs.statSync(full).size,
          path: path.relative(ROOT, full),
          url: `/download/${encodeURIComponent(file)}?from=${encodeURIComponent(path.relative(ROOT, full))}`,
          version: installerVersion(file),
          mtimeMs: fs.statSync(full).mtimeMs,
        });
      }
    }
  }

  // Only expose the latest/current app version per platform. Prefer files whose
  // filename carries the pubspec version (e.g. Nuvok-v0.2.2.dmg) so the
  // page never shows both "latest" and an older/versioned artifact. If a
  // platform has no versioned file yet, fall back to its newest file.
  const current = pubspecVersion();
  const latest = {};
  for (const inst of all) {
    const existing = latest[inst.platform];
    const currentMatch = inst.version === current;
    const existingCurrentMatch = existing?.version === current;
    let wins = false;
    if (!existing) {
      wins = true;
    } else if (currentMatch !== existingCurrentMatch) {
      wins = currentMatch;
    } else if (inst.version && existing.version && compareSemver(inst.version, existing.version) !== 0) {
      wins = compareSemver(inst.version, existing.version) > 0;
    } else {
      wins = inst.mtimeMs > existing.mtimeMs;
    }
    if (wins) latest[inst.platform] = inst;
  }
  return Object.values(latest).map(({ mtimeMs, version, ...inst }) => inst);
}

function detectPlatform(filename) {
  const lower = filename.toLowerCase();
  if (lower.endsWith('.dmg') || lower.endsWith('.app')) return 'macos';
  if (lower.endsWith('.apk')) return 'android';
  if (lower.endsWith('.exe') || lower.endsWith('.msi')) return 'windows';
  if (lower.endsWith('.deb') || lower.endsWith('.appimage') || lower.endsWith('.rpm')) return 'linux';
  return null;
}

// ── Update manifest (/version.json) ──
// Reads the version straight from pubspec.yaml so it can never drift from
// what was actually built, and hashes whatever installer is newest per
// platform in dist/. This is what lib/modules/update/update_service.dart
// polls — see installer-server's README for why this can't live in the
// private source repo (no anonymous access to private release assets).
function pubspecVersion() {
  try {
    const text = fs.readFileSync(path.join(ROOT, 'pubspec.yaml'), 'utf8');
    const m = /^version:\s*([0-9.]+)/m.exec(text);
    return m ? m[1] : '0.0.0';
  } catch {
    return '0.0.0';
  }
}

const sha256Cache = new Map();

function sha256Of(filePath) {
  const stat = fs.statSync(filePath);
  const key = `${filePath}:${stat.mtimeMs}`;
  if (sha256Cache.has(key)) return sha256Cache.get(key);

  // Installers are ~GB-sized. Hash incrementally so /version.json can be
  // generated without buffering the whole DMG/APK in RAM.
  const hash = crypto.createHash('sha256');
  const fd = fs.openSync(filePath, 'r');
  try {
    const buffer = Buffer.allocUnsafe(4 * 1024 * 1024);
    let bytesRead = 0;
    do {
      bytesRead = fs.readSync(fd, buffer, 0, buffer.length, null);
      if (bytesRead > 0) hash.update(buffer.subarray(0, bytesRead));
    } while (bytesRead > 0);
  } finally {
    fs.closeSync(fd);
  }
  const digest = hash.digest('hex');
  sha256Cache.set(key, digest);
  return digest;
}

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

function sendRangeNotSatisfiable(res, size) {
  res.writeHead(416, {
    'Content-Range': `bytes */${size}`,
    'Accept-Ranges': 'bytes',
  });
  res.end('Range not satisfiable');
}

function readDistManifest() {
  const manifestPath = path.join(DIST_DIR, 'version.json');
  if (!fs.existsSync(manifestPath)) return {};
  try {
    return JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch {
    return {};
  }
}

function buildVersionManifest(lanUrl) {
  const distManifest = readDistManifest();
  const byPlatform = {};
  for (const inst of scanInstallers()) {
    // Newest file wins if there happen to be several builds for a platform.
    const existing = byPlatform[inst.platform];
    const full = path.join(ROOT, inst.path);
    if (existing && existing.mtimeMs >= fs.statSync(full).mtimeMs) continue;
    const platformManifest = {
      mtimeMs: fs.statSync(full).mtimeMs,
      url: `${lanUrl}${inst.url}`,
      sha256: sha256Of(full),
      sizeBytes: inst.size,
    };
    if (inst.platform === 'android' && distManifest.signing) {
      platformManifest.signing = distManifest.signing;
    }
    byPlatform[inst.platform] = platformManifest;
  }
  const platforms = {};
  for (const [key, v] of Object.entries(byPlatform)) {
    platforms[key] = {
      url: v.url,
      sha256: v.sha256,
      sizeBytes: v.sizeBytes,
      ...(v.signing ? { signing: v.signing } : {}),
    };
  }
  return {
    version: pubspecVersion(),
    notes: 'Última versión disponible en tu red local.',
    platforms,
  };
}

// ── Scan for content packages ──
function scanContent() {
  const categories = [
    { dir: 'zim', label: 'Biblioteca', exts: ['.zim'], icon: '📖' },
    { dir: 'maps', label: 'Mapas', exts: ['.pmtiles'], icon: '🗺️' },
    { dir: 'models', label: 'Modelos IA', exts: ['.gguf'], icon: '🧠' },
  ];

  const packages = [];
  for (const cat of categories) {
    const dir = path.join(NUVOK_DIR, cat.dir);
    if (!fs.existsSync(dir)) continue;
    for (const file of fs.readdirSync(dir)) {
      const full = path.join(dir, file);
      if (!fs.statSync(full).isFile()) continue;
      const ext = path.extname(file).toLowerCase();
      if (!cat.exts.includes(ext)) continue;
      packages.push({
        name: file,
        category: cat.label,
        icon: cat.icon,
        type: cat.dir,
        size: fs.statSync(full).size,
        url: `/content/${cat.dir}/${encodeURIComponent(file)}`,
      });
    }
  }
  return packages;
}

// ── Get LAN IP addresses ──
function getLanIPs() {
  const ifaces = os.networkInterfaces();
  const ips = [];
  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        ips.push({ name, address: iface.address });
      }
    }
  }
  return ips;
}

function formatBytes(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}

// ── API: JSON endpoints ──
function handleAPI(req, res, url) {
  const p = url.pathname;

  if (p === '/api/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      server: 'Nuvok Installer',
      version: '1.0.0',
      ips: getLanIPs(),
      port: PORT,
    }));
    return true;
  }

  if (p === '/api/installers') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(scanInstallers()));
    return true;
  }

  if (p === '/api/content') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(scanContent()));
    return true;
  }

  return false;
}

// ── File download handler ──
function isTopLevelDistAsset(urlPathname) {
  const filename = decodeURIComponent(urlPathname.slice(1));
  if (!filename || filename !== path.basename(filename) || filename.includes('\0')) return false;
  const ext = path.extname(filename).toLowerCase();
  return ['.apk', '.dmg', '.txt'].includes(ext) && fs.existsSync(path.join(DIST_DIR, filename));
}

function handleDownload(req, res, url) {
  // /download/:filename?from=relative/path, or direct top-level dist assets
  // like /nuvok-v0.2.8.apk and /CHECKSUMS-v0.2.8.txt.
  const from = url.searchParams.get('from');
  let filePath;
  if (from) {
    filePath = path.join(ROOT, from);
  } else if (url.pathname.startsWith('/download/')) {
    const filename = decodeURIComponent(url.pathname.split('/download/')[1] || '');
    filePath = path.join(DIST_DIR, filename);
  } else {
    const filename = decodeURIComponent(url.pathname.slice(1));
    filePath = path.join(DIST_DIR, filename);
  }

  // Prevent path traversal and arbitrary repo reads. /download may only serve
  // release artifacts staged in dist/ or installer-server/downloads/; content
  // files under ~/Nuvok are exposed exclusively via /content/:type/:file.
  const resolved = path.resolve(filePath);
  if (!isInside(resolved, DIST_DIR) && !isInside(resolved, DOWNLOADS_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return true;
  }

  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isFile()) {
    res.writeHead(404);
    res.end('Not found');
    return true;
  }

  const filename = path.basename(resolved);
  const stat = fs.statSync(resolved);
  const range = req.headers.range;

  // Support range requests for large files
  if (range) {
    const parsed = parseRange(range, stat.size);
    if (!parsed) {
      sendRangeNotSatisfiable(res, stat.size);
      return true;
    }
    const { start, end } = parsed;
    const chunkSize = end - start + 1;
    const stream = fs.createReadStream(resolved, { start, end });
    res.writeHead(206, {
      'Content-Range': `bytes ${start}-${end}/${stat.size}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': chunkSize,
      'Content-Type': mimeFor(filename),
      'Content-Disposition': `attachment; filename="${safeAttachmentName(filename)}"`,
    });
    stream.pipe(res);
    return true;
  }

  res.writeHead(200, {
    'Content-Type': mimeFor(filename),
    'Content-Length': stat.size,
    'Content-Disposition': `attachment; filename="${safeAttachmentName(filename)}"`,
    'Accept-Ranges': 'bytes',
  });
  fs.createReadStream(resolved).pipe(res);
  return true;
}

// ── Content package download ──
function handleContent(req, res, url) {
  // /content/:type/:filename — only public content packages are served.
  // Never expose ~/Nuvok wholesale: it also contains settings, notes and
  // mesh identity/channel keys that must stay local to the device.
  const parts = url.pathname.split('/');
  if (parts.length !== 4) return false;
  const type = parts[2]; // zim, maps, models
  const allowedExts = CONTENT_ALLOWLIST[type];
  if (!allowedExts) {
    res.writeHead(403);
    res.end('Forbidden');
    return true;
  }
  const filename = decodeURIComponent(parts[3]);
  if (!filename || filename !== path.basename(filename) || filename.includes('\0')) {
    res.writeHead(400);
    res.end('Bad Request');
    return true;
  }
  const ext = path.extname(filename).toLowerCase();
  if (!allowedExts.has(ext)) {
    res.writeHead(403);
    res.end('Forbidden');
    return true;
  }
  const filePath = path.join(NUVOK_DIR, type, filename);

  const resolved = path.resolve(filePath);
  if (!isInside(resolved, NUVOK_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return true;
  }

  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isFile()) {
    res.writeHead(404);
    res.end('Not found');
    return true;
  }

  const stat = fs.statSync(resolved);
  const range = req.headers.range;

  if (range) {
    const parsed = parseRange(range, stat.size);
    if (!parsed) {
      sendRangeNotSatisfiable(res, stat.size);
      return true;
    }
    const { start, end } = parsed;
    const stream = fs.createReadStream(resolved, { start, end });
    res.writeHead(206, {
      'Content-Range': `bytes ${start}-${end}/${stat.size}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': end - start + 1,
      'Content-Type': mimeFor(filename),
      'Content-Disposition': `attachment; filename="${safeAttachmentName(filename)}"`,
    });
    stream.pipe(res);
    return true;
  }

  res.writeHead(200, {
    'Content-Type': mimeFor(filename),
    'Content-Length': stat.size,
    'Content-Disposition': `attachment; filename="${safeAttachmentName(filename)}"`,
    'Accept-Ranges': 'bytes',
  });
  fs.createReadStream(resolved).pipe(res);
  return true;
}

// ── Static file server for public/ ──
function serveStatic(req, res, url) {
  let pathname = url.pathname;
  if (pathname === '/' || pathname === '') pathname = '/index.html';

  const filePath = path.join(PUBLIC_DIR, pathname);
  const resolved = path.resolve(filePath);

  if (!isInside(resolved, PUBLIC_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return true;
  }

  if (!fs.existsSync(resolved) || fs.statSync(resolved).isDirectory()) {
    return false;
  }

  res.writeHead(200, { 'Content-Type': mimeFor(resolved) });
  fs.createReadStream(resolved).pipe(res);
  return true;
}

// ── Main server ──
const server = http.createServer((req, res) => {
  // An empty/missing Host header makes `new URL(req.url, 'http://')` throw
  // ERR_INVALID_URL, which would crash the whole process (DoS). Fall back to
  // a safe placeholder so the request is still handled (and rejected) instead
  // of taking the server down.
  let url;
  try {
    url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  } catch {
    res.writeHead(400);
    res.end('Bad Request');
    return;
  }

  // LAN-safe defaults: no external dependencies, no MIME sniffing, no framing,
  // and explicit CORS so phones/tablets on the same network can fetch metadata.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');

  // API routes
  if (url.pathname.startsWith('/api/')) {
    if (handleAPI(req, res, url)) return;
  }

  // Update manifest — what UpdateService (lib/modules/update/) polls to
  // find out whether a newer version exists and where to fetch it.
  if (url.pathname === '/version.json') {
    const ips = getLanIPs();
    const lanUrl = `http://${ips[0]?.address ?? 'localhost'}:${PORT}`;
    const body = JSON.stringify(buildVersionManifest(lanUrl));
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(body);
    return;
  }

  // Download routes
  if (url.pathname.startsWith('/download/') || isTopLevelDistAsset(url.pathname)) {
    if (handleDownload(req, res, url)) return;
  }

  // Content routes
  if (url.pathname.startsWith('/content/')) {
    if (handleContent(req, res, url)) return;
  }

  // Static files
  if (serveStatic(req, res, url)) return;

  // 404
  res.writeHead(404, { 'Content-Type': 'text/html' });
  res.end('<h1>404 — Not found</h1>');
});

server.listen(PORT, HOST, () => {
  const ips = getLanIPs();
  console.log('\n╔══════════════════════════════════════════════════╗');
  console.log('║   🎒 Nuvok — Installer Server              ║');
  console.log('╠══════════════════════════════════════════════════╣');
  console.log('║                                                  ║');
  console.log('║  Abre cualquiera de estas URLs en tu navegador:  ║');
  console.log('║                                                  ║');
  for (const ip of ips) {
    const url = `http://${ip.address}:${PORT}`;
    console.log(`║  ${url.padEnd(46)} ║`);
  }
  console.log('║                                                  ║');
  console.log(`║  Puerto: ${String(PORT).padEnd(37)} ║`);
  console.log('║  Estado: ACTIVO · accesible desde tu LAN        ║');
  console.log('║                                                  ║');
  console.log('╚══════════════════════════════════════════════════╝\n');

  // Show available installers
  const installers = scanInstallers();
  if (installers.length > 0) {
    console.log('📦 Instaladores disponibles:');
    for (const inst of installers) {
      console.log(`   ${inst.platform.padEnd(8)} ${inst.name} (${formatBytes(inst.size)})`);
    }
  } else {
    console.log('⚠️  No se encontraron instaladores en dist/');
  }

  const content = scanContent();
  if (content.length > 0) {
    console.log('\n📚 Paquetes de contenido disponibles:');
    for (const pkg of content) {
      console.log(`   ${pkg.icon} ${pkg.name} (${formatBytes(pkg.size)})`);
    }
  }
  console.log('\n');
});
