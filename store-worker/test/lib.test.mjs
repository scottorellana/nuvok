// Tests de la lógica pura de la tienda.
// Correr: node --test store-worker/test/lib.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  MONTHLY_DOWNLOAD_LIMIT,
  downloadPolicy,
  monthKey,
  parseLsEvent,
  verifyLsSignature,
} from '../src/lib.js';

// Firma de referencia calculada con el mismo algoritmo que usa Lemon
// Squeezy (HMAC-SHA256 hex del cuerpo crudo).
async function sign(body, secret) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
      'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false,
      ['sign']);
  const mac = await crypto.subtle.sign('HMAC', key, enc.encode(body));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, '0'))
      .join('');
}

test('acepta la firma correcta y rechaza todo lo demás', async () => {
  const body = '{"meta":{"event_name":"order_created"}}';
  const good = await sign(body, 'secreto');
  assert.equal(await verifyLsSignature(body, good, 'secreto'), true);
  assert.equal(await verifyLsSignature(body, good, 'otro-secreto'), false);
  assert.equal(await verifyLsSignature(body + ' ', good, 'secreto'), false,
      'un byte cambiado en el cuerpo invalida la firma');
  assert.equal(await verifyLsSignature(body, 'deadbeef', 'secreto'), false);
  assert.equal(await verifyLsSignature(body, null, 'secreto'), false);
  assert.equal(await verifyLsSignature(body, good, ''), false,
      'sin secreto configurado NADA debe pasar');
});

test('la firma acepta mayúsculas (LS no documenta la caja)', async () => {
  const body = '{}';
  const good = await sign(body, 's');
  assert.equal(await verifyLsSignature(body, good.toUpperCase(), 's'), true);
});

test('parseLsEvent extrae orden y correo, y rechaza payloads deformes', () => {
  const e = parseLsEvent({
    meta: { event_name: 'order_created' },
    data: { id: 123, attributes: { user_email: 'ana@example.com' } },
  });
  assert.deepEqual(e, {
    type: 'order_created', orderId: '123', email: 'ana@example.com',
  });
  assert.equal(parseLsEvent({}), null);
  assert.equal(parseLsEvent({ meta: {} }), null);
  assert.equal(parseLsEvent({ meta: { event_name: 'x' }, data: {} }), null);
});

test('política de descargas: activa pasa, revocada y desconocida no', () => {
  assert.equal(downloadPolicy({ status: 'active', month_dl_count: 3 }).allow,
      true);
  assert.equal(downloadPolicy({ status: 'revoked' }).allow, false);
  assert.equal(downloadPolicy(null).allow, false);
});

test('el límite mensual corta en 25, no antes', () => {
  const at24 = downloadPolicy(
      { status: 'active', month_dl_count: MONTHLY_DOWNLOAD_LIMIT - 1 });
  const at25 = downloadPolicy(
      { status: 'active', month_dl_count: MONTHLY_DOWNLOAD_LIMIT });
  assert.equal(at24.allow, true);
  assert.equal(at25.allow, false);
  assert.equal(at25.reason, 'limit',
      'el motivo distingue límite (mensaje amable) de clave mala');
});

test('monthKey agrupa por mes UTC', () => {
  assert.equal(monthKey(new Date(Date.UTC(2026, 6, 31))), '2026-07');
  assert.equal(monthKey(new Date(Date.UTC(2026, 11, 1))), '2026-12');
});
