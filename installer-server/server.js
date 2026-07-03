// ═════════════════════════════════════════════════════════════
// Prepper Pad — Local Installer Server
// Serves installers + content packages to any device on the LAN.
// No internet required. Pure Node.js, zero dependencies.
// ═════════════════════════════════════════════════════════════
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execSync } from 'node:child_process';

const PORT = parseInt(process.env.PORT || '8848');
const HOST = '0.0.0.0'; // Listen on all interfaces (LAN accessible)

// ── Paths ──
const ROOT = path.resolve(import.meta.dirname, '..');
const DIST_DIR = path.join(ROOT, 'dist');
const DOWNLOADS_DIR = path.join(import.meta.dirname, 'downloads');
const PREPPERPAD_DIR = path.join(os.homedir(), 'PrepperPad');
const PUBLIC_DIR = path.join(import.meta.dirname, 'public');

// ── Ensure downloads dir exists ──
fs.mkdirSync(DOWNLOADS_DIR, { recursive: true });
fs.mkdirSync(PUBLIC_DIR, { recursive: true });

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

function mimeFor(filename) {
  return MIME[path.extname(filename).toLowerCase()] || 'application/octet-stream';
}

// ── Scan for available installers ──
function scanInstallers() {
  const installers = [];

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
        installers.push({
          name: file,
          platform,
          size: fs.statSync(full).size,
          path: path.relative(ROOT, full),
          url: `/download/${encodeURIComponent(file)}?from=${encodeURIComponent(path.relative(ROOT, full))}`,
        });
      }
    }
  }

  return installers;
}

function detectPlatform(filename) {
  const lower = filename.toLowerCase();
  if (lower.endsWith('.dmg') || lower.endsWith('.app')) return 'macos';
  if (lower.endsWith('.apk')) return 'android';
  if (lower.endsWith('.exe') || lower.endsWith('.msi')) return 'windows';
  if (lower.endsWith('.deb') || lower.endsWith('.appimage') || lower.endsWith('.rpm')) return 'linux';
  return null;
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
    const dir = path.join(PREPPERPAD_DIR, cat.dir);
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
      server: 'Prepper Pad Installer',
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
function handleDownload(req, res, url) {
  // /download/:filename?from=relative/path
  const from = url.searchParams.get('from');
  let filePath;
  if (from) {
    filePath = path.join(ROOT, from);
  } else {
    const filename = decodeURIComponent(url.pathname.split('/download/')[1] || '');
    filePath = path.join(DIST_DIR, filename);
  }

  // Prevent path traversal
  const resolved = path.resolve(filePath);
  if (!resolved.startsWith(ROOT) && !resolved.startsWith(DOWNLOADS_DIR) && !resolved.startsWith(PREPPERPAD_DIR)) {
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
    const match = /bytes=(\d*)-(\d*)/.exec(range);
    if (match) {
      const start = match[1] ? parseInt(match[1]) : 0;
      const end = match[2] ? parseInt(match[2]) : stat.size - 1;
      const chunkSize = end - start + 1;
      const stream = fs.createReadStream(resolved, { start, end });
      res.writeHead(206, {
        'Content-Range': `bytes ${start}-${end}/${stat.size}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': chunkSize,
        'Content-Type': mimeFor(filename),
        'Content-Disposition': `attachment; filename="${filename}"`,
      });
      stream.pipe(res);
      return true;
    }
  }

  res.writeHead(200, {
    'Content-Type': mimeFor(filename),
    'Content-Length': stat.size,
    'Content-Disposition': `attachment; filename="${filename}"`,
    'Accept-Ranges': 'bytes',
  });
  fs.createReadStream(resolved).pipe(res);
  return true;
}

// ── Content package download ──
function handleContent(req, res, url) {
  // /content/:type/:filename
  const parts = url.pathname.split('/');
  if (parts.length < 4) return false;
  const type = parts[2]; // zim, maps, models
  const filename = decodeURIComponent(parts.slice(3).join('/'));
  const filePath = path.join(PREPPERPAD_DIR, type, filename);

  const resolved = path.resolve(filePath);
  if (!resolved.startsWith(PREPPERPAD_DIR)) {
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
    const match = /bytes=(\d*)-(\d*)/.exec(range);
    if (match) {
      const start = match[1] ? parseInt(match[1]) : 0;
      const end = match[2] ? parseInt(match[2]) : stat.size - 1;
      const stream = fs.createReadStream(resolved, { start, end });
      res.writeHead(206, {
        'Content-Range': `bytes ${start}-${end}/${stat.size}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': end - start + 1,
        'Content-Type': mimeFor(filename),
        'Content-Disposition': `attachment; filename="${filename}"`,
      });
      stream.pipe(res);
      return true;
    }
  }

  res.writeHead(200, {
    'Content-Type': mimeFor(filename),
    'Content-Length': stat.size,
    'Content-Disposition': `attachment; filename="${filename}"`,
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

  if (!resolved.startsWith(PUBLIC_DIR)) {
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
  const url = new URL(req.url, `http://${req.headers.host}`);

  // CORS for LAN access
  res.setHeader('Access-Control-Allow-Origin', '*');

  // API routes
  if (url.pathname.startsWith('/api/')) {
    if (handleAPI(req, res, url)) return;
  }

  // Download routes
  if (url.pathname.startsWith('/download/')) {
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
  console.log('║   🎒 Prepper Pad — Installer Server              ║');
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
