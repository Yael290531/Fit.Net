-- ═══════════════════════════════════════════════════════════════════════
-- FIT.NET – Migration: Crear tablas en Supabase
--
-- Ejecutar este SQL en el SQL Editor de tu dashboard de Supabase:
--   https://supabase.com/dashboard → SQL Editor → New Query
--
-- Estas tablas replican el esquema local de Drift/SQLite para
-- sincronizar los datos de las sucursales en la nube.
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1. Tabla: usuarios ─────────────────────────────────────────────
-- Autenticación simple (sin Supabase Auth).
-- En producción se recomienda usar Supabase Auth con bcrypt.
CREATE TABLE IF NOT EXISTS usuarios (
  id SERIAL PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  rol TEXT NOT NULL CHECK (rol IN ('adminGlobal', 'cajero')),
  sucursal_asignada TEXT
);

-- Usuarios de prueba (mismos que en database_service.dart)
INSERT INTO usuarios (username, password, rol, sucursal_asignada) VALUES
  ('admin', 'admin123', 'adminGlobal', NULL),
  ('cajero_centro', 'centro123', 'cajero', 'Sucursal Centro'),
  ('cajero_norte', 'norte123', 'cajero', 'Sucursal Norte')
ON CONFLICT (username) DO NOTHING;

-- ── 2. Tabla: clientes ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS clientes (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  telefono TEXT,
  sucursal_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- ── 3. Tabla: tarjetas ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tarjetas (
  id_tarjeta TEXT PRIMARY KEY,
  cliente_id TEXT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  saldo DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  sucursal_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- ── 4. Tabla: movimientos ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS movimientos (
  id TEXT PRIMARY KEY,
  id_tarjeta TEXT NOT NULL REFERENCES tarjetas(id_tarjeta) ON DELETE RESTRICT,
  sucursal_id TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('recarga', 'pago', 'ajuste', 'reversion')),
  monto DOUBLE PRECISION NOT NULL CHECK (monto > 0),
  fecha TIMESTAMPTZ NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  sync_attempts INT NOT NULL DEFAULT 0,
  last_sync_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarjetas ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientos ENABLE ROW LEVEL SECURITY;

-- Políticas de lectura (SELECT)
CREATE POLICY "Permitir lectura pública" ON usuarios FOR SELECT USING (true);
CREATE POLICY "Permitir lectura pública" ON clientes FOR SELECT USING (true);
CREATE POLICY "Permitir lectura pública" ON tarjetas FOR SELECT USING (true);
CREATE POLICY "Permitir lectura pública" ON movimientos FOR SELECT USING (true);

-- Políticas de inserción (INSERT)
CREATE POLICY "Permitir inserción pública" ON clientes FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir inserción pública" ON tarjetas FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir inserción pública" ON movimientos FOR INSERT WITH CHECK (true);

-- Políticas de actualización (UPDATE)
CREATE POLICY "Permitir actualización pública" ON clientes FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Permitir actualización pública" ON tarjetas FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Permitir actualización pública" ON movimientos FOR UPDATE USING (true) WITH CHECK (true);

-- Políticas de eliminación (DELETE)
CREATE POLICY "Permitir eliminación pública" ON clientes FOR DELETE USING (true);
CREATE POLICY "Permitir eliminación pública" ON tarjetas FOR DELETE USING (true);
CREATE POLICY "Permitir eliminación pública" ON movimientos FOR DELETE USING (true);

-- ═══════════════════════════════════════════════════════════════════════
-- ÍNDICES
-- ═══════════════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_clientes_sucursal ON clientes(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_cliente ON tarjetas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_tarjetas_sucursal ON tarjetas(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_tarjeta ON movimientos(id_tarjeta);
CREATE INDEX IF NOT EXISTS idx_movimientos_sucursal ON movimientos(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_fecha ON movimientos(fecha);

-- ── 5. Tabla: suscripciones ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS suscripciones (
  id TEXT PRIMARY KEY,
  cliente_id TEXT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  sucursal_id TEXT NOT NULL,
  tipo_suscripcion TEXT NOT NULL CHECK (tipo_suscripcion IN ('mensual', 'semanal', 'diaria')),
  monto_pagado DOUBLE PRECISION NOT NULL CHECK (monto_pagado > 0),
  fecha_inicio TIMESTAMPTZ NOT NULL,
  fecha_fin TIMESTAMPTZ NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE suscripciones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Permitir lectura pública" ON suscripciones FOR SELECT USING (true);
CREATE POLICY "Permitir inserción pública" ON suscripciones FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir actualización pública" ON suscripciones FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Permitir eliminación pública" ON suscripciones FOR DELETE USING (true);

CREATE INDEX IF NOT EXISTS idx_suscripciones_cliente ON suscripciones(cliente_id);
CREATE INDEX IF NOT EXISTS idx_suscripciones_sucursal ON suscripciones(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_suscripciones_fecha_fin ON suscripciones(fecha_fin);
