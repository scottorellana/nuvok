// ═══ Prepper Pad Installer — LAN UI App ═══

const OS_ICONS = {
  macos: '', windows: '🪟', android: '🤖', linux: '🐧',
  ios: '🍎', unknown: '❓'
};

const OS_NAMES = {
  macos: 'macOS', windows: 'Windows', android: 'Android', linux: 'Linux',
  ios: 'iOS', unknown: 'desconocido'
};

function detectOS() {
  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes('mac')) return 'macos';
  if (ua.includes('win')) return 'windows';
  if (ua.includes('android')) return 'android';
  if (ua.includes('linux') || ua.includes('x11')) return 'linux';
  if (ua.includes('iphone') || ua.includes('ipad') || ua.includes('ios')) return 'ios';
  return 'unknown';
}

function formatBytes(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
  if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + ' MB';
  return (bytes / 1073741824).toFixed(2) + ' GB';
}

async function loadInstallers() {
  const detected = detectOS();
  const container = document.getElementById('installers');

  try {
    const resp = await fetch('/api/installers');
    const data = await resp.json();

    if (!data || data.length === 0) {
      container.innerHTML = `
        <div class="empty">
          <div class="icon">📭</div>
          <p>No hay instaladores disponibles aún.<br>Coloca los archivos en la carpeta <code>dist/</code> o <code>downloads/</code>.</p>
        </div>`;
      return;
    }

    // Sort: detected platform first
    data.sort((a, b) => {
      if (a.platform === detected && b.platform !== detected) return -1;
      if (b.platform === detected && a.platform !== detected) return 1;
      return 0;
    });

    container.innerHTML = data.map((inst, i) => {
      const isRecommended = inst.platform === detected;
      return `
        <a href="${inst.url}" class="download-card ${isRecommended ? 'recommended' : ''}" style="animation-delay: ${0.1 + i * 0.05}s">
          ${isRecommended ? '<span class="recommended-tag">RECOMENDADO</span>' : ''}
          <div class="icon ${inst.platform}">${OS_ICONS[inst.platform] || '📦'}</div>
          <div class="info">
            <div class="name">${OS_NAMES[inst.platform] || inst.platform} — ${inst.name}</div>
            <div class="meta">${formatBytes(inst.size)} · ${inst.platform}</div>
          </div>
          <div class="arrow">↓</div>
        </a>`;
    }).join('');
  } catch (err) {
    container.innerHTML = `<div class="empty"><p>Error al cargar instaladores: ${err.message}</p></div>`;
  }
}

async function loadContent() {
  const container = document.getElementById('content');

  try {
    const resp = await fetch('/api/content');
    const data = await resp.json();

    if (!data || data.length === 0) {
      container.innerHTML = `
        <div class="empty" style="grid-column: 1/-1;">
          <div class="icon">📚</div>
          <p>No hay paquetes de contenido aún.<br>Descarga contenido desde la app y aparecerá aquí.</p>
        </div>`;
      return;
    }

    container.innerHTML = data.map(pkg => `
      <a href="${pkg.url}" class="content-card">
        <div class="icon">${pkg.icon}</div>
        <div class="info">
          <div class="name">${pkg.name}</div>
          <div class="meta">${pkg.category} · ${formatBytes(pkg.size)}</div>
        </div>
        <div class="arrow">↓</div>
      </a>`).join('');
  } catch (err) {
    container.innerHTML = `<div class="empty"><p>Error: ${err.message}</p></div>`;
  }
}

async function loadStatus() {
  try {
    const resp = await fetch('/api/status');
    const data = await resp.json();

    // Update device banner
    const detected = detectOS();
    const banner = document.getElementById('device-banner');
    if (banner) {
      banner.querySelector('.detected').innerHTML =
        `<span class="os-icon">${OS_ICONS[detected]}</span>Dispositivo detectado: <strong>${OS_NAMES[detected]}</strong>`;
    }

    // Generate QR code with the first LAN IP
    const qrContainer = document.getElementById('qr-code');
    if (qrContainer && data.ips && data.ips.length > 0) {
      const url = `http://${data.ips[0].address}:${data.port}`;
      // Use inline SVG QR code (we generate a simple one pointing to the URL)
      qrContainer.innerHTML = generateQRPlaceholder(url);
      const urlDisplay = document.getElementById('server-url');
      if (urlDisplay) urlDisplay.textContent = url;
    }
  } catch (err) {
    console.error('Status error:', err);
  }
}

// Simple QR-like visual placeholder (real QR generation needs a library)
function generateQRPlaceholder(url) {
  return `
    <div style="background:white; padding:16px; border-radius:12px; display:inline-block;">
      <svg width="180" height="180" viewBox="0 0 180 180" xmlns="http://www.w3.org/2000/svg">
        <rect width="180" height="180" fill="white"/>
        ${generateQRPattern(url)}
        <text x="90" y="170" text-anchor="middle" font-size="9" font-family="monospace" fill="#333">${url.length > 30 ? url.substring(0, 30) + '...' : url}</text>
      </svg>
    </div>`;
}

// Deterministic pseudo-QR pattern from URL hash
function generateQRPattern(url) {
  let hash = 0;
  for (let i = 0; i < url.length; i++) {
    hash = ((hash << 5) - hash + url.charCodeAt(i)) | 0;
  }
  const size = 21;
  const cellSize = 7;
  const offset = 12;
  let svg = '';

  // Corner markers (like real QR codes)
  function corner(x, y) {
    return `<rect x="${x}" y="${y}" width="${cellSize*7}" height="${cellSize*7}" fill="black"/>
            <rect x="${x+cellSize}" y="${y+cellSize}" width="${cellSize*5}" height="${cellSize*5}" fill="white"/>
            <rect x="${x+cellSize*2}" y="${y+cellSize*2}" width="${cellSize*3}" height="${cellSize*3}" fill="black"/>`;
  }
  svg += corner(offset, offset);
  svg += corner(offset + cellSize*14, offset);
  svg += corner(offset, offset + cellSize*14);

  // Data cells
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      // Skip corner areas
      if ((x < 7 && y < 7) || (x > 13 && y < 7) || (x < 7 && y > 13)) continue;
      hash = (hash * 31 + x * 7 + y * 13) | 0;
      if ((hash & 1) === 0) {
        svg += `<rect x="${offset + x*cellSize}" y="${offset + y*cellSize}" width="${cellSize}" height="${cellSize}" fill="black"/>`;
      }
    }
  }
  return svg;
}

// ── Init ──
document.addEventListener('DOMContentLoaded', () => {
  loadStatus();
  loadInstallers();
  loadContent();
});
