// Lógica pura de la tienda de Nuvok — sin IO, verificable con `node --test`.
//
// El Worker (index.js) solo cablea esto a D1/R2. Mantener la lógica aquí es
// lo que permite probar firma, política de descargas y parsing sin desplegar.

/// Verifica la firma HMAC-SHA256 (hex) que Lemon Squeezy manda en
/// X-Signature. Comparación en tiempo constante: la firma de un webhook es
/// exactamente el lugar donde un timing leak duele.
export async function verifyLsSignature(rawBody, signatureHex, secret) {
  if (!signatureHex || !secret) return false;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
      'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false,
      ['sign']);
  const mac = await crypto.subtle.sign('HMAC', key, enc.encode(rawBody));
  const expected = [...new Uint8Array(mac)]
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
  const given = signatureHex.trim().toLowerCase();
  if (given.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ given.charCodeAt(i);
  }
  return diff === 0;
}

/// Extrae lo que nos importa de un webhook de Lemon Squeezy, o null si el
/// payload no trae lo mínimo (nunca confiar en la forma del JSON ajeno).
export function parseLsEvent(json) {
  const type = json?.meta?.event_name;
  const orderId = json?.data?.id;
  const email = json?.data?.attributes?.user_email ?? null;
  if (!type || !orderId) return null;
  return { type, orderId: String(orderId), email };
}

/// Política de descarga para una compra. Límite suave: 25 descargas por mes
/// disuaden la clave publicada en un foro sin castigar a un hogar real.
export const MONTHLY_DOWNLOAD_LIMIT = 25;

export function downloadPolicy(purchase) {
  if (!purchase) return { allow: false, reason: 'unknown_key' };
  if (purchase.status === 'revoked') {
    return { allow: false, reason: 'revoked' };
  }
  if ((purchase.month_dl_count ?? 0) >= MONTHLY_DOWNLOAD_LIMIT) {
    return { allow: false, reason: 'limit' };
  }
  return { allow: true, reason: 'ok' };
}

/// La clave de mes que agrupa el contador (se pasa la fecha para poder
/// testear sin reloj).
export function monthKey(date) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
}
