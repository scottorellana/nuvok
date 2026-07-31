-- Compras de Nuvok. Mínimo deliberado: las tarjetas viven en Lemon Squeezy;
-- aquí solo lo necesario para entregar descargas. Borrar a un comprador a
-- pedido = un DELETE.
CREATE TABLE IF NOT EXISTS purchases (
  order_id       TEXT PRIMARY KEY,          -- id del pedido en Lemon Squeezy
  email          TEXT,
  key            TEXT UNIQUE NOT NULL,      -- UUIDv4: la clave del comprador
  status         TEXT NOT NULL DEFAULT 'active',  -- active | revoked
  created_at     TEXT NOT NULL,
  month          TEXT,                      -- 'YYYY-MM' del contador vigente
  month_dl_count INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_purchases_key ON purchases (key);
