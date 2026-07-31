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
  MONTHLY_DOWNLOAD_LIMIT,
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
  // Tope ANTES de leer: sin esto, cualquier anónimo puede hacer bufferizar
  // cuerpos gigantes antes siquiera de validar la firma. Un webhook real de
  // Lemon Squeezy pesa unos pocos KB.
  const len = Number(request.headers.get('content-length') ?? 0);
  if (!len || len > 100_000) {
    return new Response('payload too large', { status: 413 });
  }
  const raw = await request.text();
  const ok = await verifyLsSignature(
      raw, request.headers.get('X-Signature'), env.LS_SIGNING_SECRET);
  if (!ok) return new Response('bad signature', { status: 401 });

  let event;
  try {
    event = parseLsEvent(JSON.parse(raw));
  } catch (_) {
    return new Response('bad json', { status: 400 });
  }
  if (!event) return new Response('ignored', { status: 200 });

  if (event.type === 'order_created') {
    const key = crypto.randomUUID();
    // Idempotente (LS reintenta webhooks), y sin resucitar reembolsos: si la
    // fila ya existe — incluso como 'revoked' por un webhook fuera de orden —
    // no se toca.
    await env.DB.prepare(
        `INSERT INTO purchases (order_id, email, key, status, created_at)
         VALUES (?, ?, ?, 'active', datetime('now'))
         ON CONFLICT(order_id) DO NOTHING`)
        .bind(event.orderId, event.email, key).run();
    ctx.waitUntil(upsertGhlContact(env, event.email));
  } else if (event.type === 'order_refunded') {
    // Upsert, no UPDATE: los webhooks pueden llegar fuera de orden y un
    // reembolso que aterriza ANTES que su alta debe quedar registrado — si
    // solo actualizáramos, el alta posterior dejaría la clave activa y el
    // reembolso se perdería para siempre.
    await env.DB.prepare(
        `INSERT INTO purchases (order_id, email, key, status, created_at)
         VALUES (?, ?, ?, 'revoked', datetime('now'))
         ON CONFLICT(order_id) DO UPDATE SET status = 'revoked'`)
        .bind(event.orderId, event.email, crypto.randomUUID()).run();
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
  // donde se vende Nuvok se caen).
  //
  // El contador se incrementa en TODA petición, con o sin Range. La versión
  // anterior solo cobraba offset==0, y eso rompía el muro entero: bastaba
  // `Range: bytes=1-` para descargar el 99.99% del archivo sin gastar nunca
  // el límite mensual — una clave filtrada servía descargas infinitas. Una
  // reanudación legítima cuesta una descarga; con 25/mes a un hogar real le
  // sobra, y el header lo elige el cliente, así que no puede decidir si paga.
  const rangeHeader = request.headers.get('Range');
  const m = rangeHeader?.match(/^bytes=(\d+)-$/);
  const offset = m ? Number(m[1]) : 0;

  // Cobro ATÓMICO en un solo statement, antes de tocar R2. La versión
  // leer-calcular-escribir tenía una carrera clásica: N descargas paralelas
  // leían el mismo contador y escribían N veces "contador+1" — N descargas
  // al precio de una. Aquí la condición y el incremento viajan juntos: si no
  // hay fila devuelta, no hay descarga.
  const claimed = await env.DB.prepare(
      `UPDATE purchases
       SET month_dl_count = CASE WHEN month = ?1 THEN month_dl_count + 1 ELSE 1 END,
           month = ?1
       WHERE key = ?2 AND status = 'active'
         AND (month IS NOT ?1 OR month_dl_count < ?3)
       RETURNING month_dl_count`)
      .bind(nowMonth, key, MONTHLY_DOWNLOAD_LIMIT).first();
  if (!claimed) return deny(policy.allow ? 'limit' : policy.reason);

  const obj = await env.RELEASES.get(
      file.name, offset > 0 ? { range: { offset } } : undefined);
  if (!obj) return new Response('not found', { status: 404 });

  // El nombre viene de NUESTRO releases.json, pero un manifiesto es un dato,
  // no código: comillas o CRLF en un nombre no deben poder tocar el header.
  const safeName = file.name.replace(/[^\w.\-]/g, '_');
  const headers = {
    'content-type': 'application/octet-stream',
    'content-disposition': `attachment; filename="${safeName}"`,
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
    // Nada de 500 con stack ante entradas raras: dos de las rutas son
    // anónimas y un %-encoding inválido o un manifiesto corrupto no deben
    // filtrar internals ni ensuciar métricas de error.
    try {
      const url = new URL(request.url);
      if (request.method === 'POST' && url.pathname === '/webhook/lemonsqueezy') {
        return await handleWebhook(request, env, ctx);
      }
      if (request.method === 'GET' && url.pathname === '/api/downloads') {
        return await handleList(url, env);
      }
      const dl = url.pathname.match(/^\/api\/dl\/([^/]+)$/);
      if (request.method === 'GET' && dl) {
        let fileName;
        try {
          fileName = decodeURIComponent(dl[1]);
        } catch (_) {
          return new Response('not found', { status: 404 });
        }
        return await handleDownload(request, url, env, fileName);
      }
      return new Response('nuvok-store', { status: 200 });
    } catch (_) {
      return new Response('internal error', { status: 500 });
    }
  },
};
