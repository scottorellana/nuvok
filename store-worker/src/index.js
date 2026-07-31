// nuvok-store: el Worker del muro de descarga (spec 2026-07-29).
//
// Rutas:
//   POST /webhook/lemonsqueezy  ← compras y reembolsos (firma verificada)
//   GET  /api/downloads?key=    ← lista de instaladores para una clave
//   GET  /api/dl/:file?key=     ← streamea el binario desde R2 (con Range)
//
// Bindings (wrangler.toml): DB (D1), RELEASES (R2).
// Secrets: LS_SIGNING_SECRET; opcionales GHL_TOKEN + GHL_LOCATION_ID para
// volcar cada comprador al CRM (GoHighLevel/Hexona) con su etiqueta.
import {
  downloadPolicy,
  monthKey,
  parseLsEvent,
  verifyLsSignature,
} from './lib.js';

const JSON_HEADERS = { 'content-type': 'application/json; charset=utf-8' };

// El catálogo de release vive en R2 como releases.json:
// { "version": "0.6.0", "files": [{ "os": "macos", "name": "Nuvok-macOS-v0.6.0.dmg",
//   "bytes": 123, "sha256": "..." }, ...] }
async function releaseManifest(env) {
  const obj = await env.RELEASES.get('releases.json');
  if (!obj) return null;
  return obj.json();
}

async function purchaseByKey(env, key) {
  if (!/^[0-9a-f-]{36}$/i.test(key ?? '')) return null;
  return env.DB.prepare(
      'SELECT * FROM purchases WHERE key = ?').bind(key).first();
}

/// Respuesta uniforme para clave mala/revocada: no revelar cuál de las dos
/// fue impide enumerar claves válidas.
function deny(reason) {
  const status = reason === 'limit' ? 429 : 403;
  const msg = reason === 'limit'
      ? 'Límite mensual de descargas alcanzado. Escríbenos a hola@nuvok.org.'
      : 'Clave no válida.';
  return new Response(JSON.stringify({ error: msg }), {
    status,
    headers: JSON_HEADERS,
  });
}

/// Comprador nuevo → contacto en el CRM (GHL/Hexona) con la etiqueta
/// 'nuvok-comprador', para que las automatizaciones (bienvenida, onboarding)
/// disparen solas. Best-effort: la venta jamás depende del CRM.
async function upsertGhlContact(env, email) {
  if (!env.GHL_TOKEN || !env.GHL_LOCATION_ID || !email) return;
  try {
    await fetch('https://services.leadconnectorhq.com/contacts/upsert', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.GHL_TOKEN}`,
        Version: '2021-07-28',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        locationId: env.GHL_LOCATION_ID,
        email,
        tags: ['nuvok-comprador'],
        source: 'nuvok.org',
      }),
    });
  } catch (_) {
    // El CRM caído no puede romper la compra.
  }
}

async function handleWebhook(request, env, ctx) {
  const raw = await request.text();
  const ok = await verifyLsSignature(
      raw, request.headers.get('X-Signature'), env.LS_SIGNING_SECRET);
  if (!ok) return new Response('bad signature', { status: 401 });

  const event = parseLsEvent(JSON.parse(raw));
  if (!event) return new Response('ignored', { status: 200 });

  if (event.type === 'order_created') {
    const key = crypto.randomUUID();
    // Idempotente: Lemon Squeezy reintenta webhooks y un pedido no puede
    // generar dos claves.
    await env.DB.prepare(
        `INSERT INTO purchases (order_id, email, key, status, created_at)
         VALUES (?, ?, ?, 'active', datetime('now'))
         ON CONFLICT(order_id) DO NOTHING`)
        .bind(event.orderId, event.email, key).run();
    ctx.waitUntil(upsertGhlContact(env, event.email));
  } else if (event.type === 'order_refunded') {
    await env.DB.prepare(
        `UPDATE purchases SET status = 'revoked' WHERE order_id = ?`)
        .bind(event.orderId).run();
  }
  return new Response('ok', { status: 200 });
}

async function handleList(url, env) {
  const purchase = await purchaseByKey(env, url.searchParams.get('key'));
  const policy = downloadPolicy(purchase);
  if (!policy.allow && policy.reason !== 'limit') return deny(policy.reason);
  const manifest = await releaseManifest(env);
  if (!manifest) {
    return new Response(JSON.stringify({ error: 'Sin release publicado.' }),
        { status: 503, headers: JSON_HEADERS });
  }
  return new Response(JSON.stringify(manifest), { headers: JSON_HEADERS });
}

async function handleDownload(request, url, env, fileName) {
  const key = url.searchParams.get('key');
  const purchase = await purchaseByKey(env, key);

  // Contador mensual: se reinicia cuando cambia el mes.
  const nowMonth = monthKey(new Date());
  const effective = purchase && purchase.month !== nowMonth
      ? { ...purchase, month_dl_count: 0 }
      : purchase;
  const policy = downloadPolicy(effective);
  if (!policy.allow) return deny(policy.reason);

  const manifest = await releaseManifest(env);
  const file = manifest?.files?.find((f) => f.name === fileName);
  if (!file) return new Response('not found', { status: 404 });

  // Reanudación: honrar "Range: bytes=N-" (son cientos de MB y las redes
  // donde se vende Nuvok se caen). Una reanudación no cuenta como descarga
  // nueva para el límite mensual.
  const rangeHeader = request.headers.get('Range');
  const m = rangeHeader?.match(/^bytes=(\d+)-$/);
  const offset = m ? Number(m[1]) : 0;
  const obj = await env.RELEASES.get(
      file.name, offset > 0 ? { range: { offset } } : undefined);
  if (!obj) return new Response('not found', { status: 404 });

  if (offset === 0) {
    await env.DB.prepare(
        `UPDATE purchases SET month = ?, month_dl_count = ? WHERE key = ?`)
        .bind(nowMonth, (effective.month_dl_count ?? 0) + 1, key).run();
  }

  const headers = {
    'content-type': 'application/octet-stream',
    'content-disposition': `attachment; filename="${file.name}"`,
    'accept-ranges': 'bytes',
  };
  if (offset > 0) {
    headers['content-range'] = `bytes ${offset}-${obj.size - 1}/${obj.size}`;
    headers['content-length'] = String(obj.size - offset);
    return new Response(obj.body, { status: 206, headers });
  }
  headers['content-length'] = String(obj.size);
  return new Response(obj.body, { headers });
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method === 'POST' && url.pathname === '/webhook/lemonsqueezy') {
      return handleWebhook(request, env, ctx);
    }
    if (request.method === 'GET' && url.pathname === '/api/downloads') {
      return handleList(url, env);
    }
    const dl = url.pathname.match(/^\/api\/dl\/([^/]+)$/);
    if (request.method === 'GET' && dl) {
      return handleDownload(request, url, env, decodeURIComponent(dl[1]));
    }
    return new Response('nuvok-store', { status: 200 });
  },
};
