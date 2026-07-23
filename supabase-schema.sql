-- 📦 Esquema completo para la app de Pedidos
-- Ejecutar esto en el SQL Editor de Supabase (SQL Editor > New Query)

-- ============================================================
-- ELIMINAR TODO EXISTENTE (orden por dependencias)
-- ============================================================
DROP TABLE IF EXISTS racks CASCADE;
DROP TABLE IF EXISTS citas_cargue CASCADE;
DROP TABLE IF EXISTS despachos CASCADE;
DROP TABLE IF EXISTS unloadings CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS operators CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;

-- ============================================================
-- 📦 Tabla principal de pedidos
-- ============================================================
CREATE TABLE orders (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  date DATE NOT NULL,
  cliente TEXT NOT NULL,
  sku TEXT NOT NULL,
  kg NUMERIC NOT NULL,
  operator TEXT DEFAULT '',
  start_time TEXT DEFAULT '',
  end_time TEXT,
  type TEXT NOT NULL CHECK (type IN ('Masivo', 'Venta Directa')),
  status TEXT NOT NULL DEFAULT 'sin_operario' CHECK (status IN ('sin_operario', 'pending', 'completed', 'despachado')),
  time_spent TEXT,
  kg_per_hour NUMERIC,
  efficiency NUMERIC,
  plc TEXT,
  placa TEXT,
  cargue_start TEXT,
  cargue_end TEXT,
  cargue_time TEXT,
  despachado_kg NUMERIC DEFAULT 0,
  created_by TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_date ON orders(date);
CREATE INDEX idx_orders_cliente ON orders(cliente);
CREATE INDEX idx_orders_operator ON orders(operator);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Todos pueden leer orders" ON orders FOR SELECT USING (true);
CREATE POLICY "Todos pueden insertar orders" ON orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Todos pueden actualizar orders" ON orders FOR UPDATE USING (true);
CREATE POLICY "Todos pueden eliminar orders" ON orders FOR DELETE USING (true);

-- ============================================================
-- 📦 Despachos (cada vehículo que se carga de un pedido)
-- ============================================================
CREATE TABLE despachos (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  ruta TEXT NOT NULL DEFAULT '',
  placa TEXT NOT NULL,
  plc TEXT NOT NULL,
  kg NUMERIC NOT NULL,
  date DATE DEFAULT CURRENT_DATE,
  cargue_start TEXT NOT NULL,
  cargue_end TEXT NOT NULL,
  cargue_time TEXT NOT NULL,
  created_by TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_despachos_order ON despachos(order_id);

ALTER TABLE despachos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Todos pueden leer despachos" ON despachos FOR SELECT USING (true);
CREATE POLICY "Todos pueden insertar despachos" ON despachos FOR INSERT WITH CHECK (true);
CREATE POLICY "Todos pueden actualizar despachos" ON despachos FOR UPDATE USING (true);
CREATE POLICY "Todos pueden eliminar despachos" ON despachos FOR DELETE USING (true);

-- ============================================================
-- 🚛 Citas de cargue (programación de vehículos en bodega)
-- ============================================================
CREATE TABLE citas_cargue (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ruta TEXT NOT NULL DEFAULT '',
  placa TEXT NOT NULL,
  kg NUMERIC NOT NULL DEFAULT 0,
  tipo TEXT NOT NULL DEFAULT 'Masivo' CHECK (tipo IN ('Masivo', 'Venta Directa')),
  hora_cita TIME NOT NULL,
  hora_llegada TIME,
  retraso_minutos INT GENERATED ALWAYS AS (
    CASE 
      WHEN hora_llegada IS NOT NULL AND hora_cita IS NOT NULL
      THEN EXTRACT(EPOCH FROM (hora_llegada - hora_cita)) / 60
      ELSE NULL
    END
  ) STORED,
  cumplio_cita BOOLEAN,
  observaciones TEXT,
  created_by TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_citas_cargue_fecha ON citas_cargue(created_at);

ALTER TABLE citas_cargue ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Todos pueden leer citas_cargue" ON citas_cargue FOR SELECT USING (true);
CREATE POLICY "Todos pueden insertar citas_cargue" ON citas_cargue FOR INSERT WITH CHECK (true);
CREATE POLICY "Todos pueden actualizar citas_cargue" ON citas_cargue FOR UPDATE USING (true);
CREATE POLICY "Todos pueden eliminar citas_cargue" ON citas_cargue FOR DELETE USING (true);

-- ============================================================
-- 📦 Descargue de contenedores (PTM, peso, tiempos)
-- ============================================================
CREATE TABLE unloadings (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  date DATE NOT NULL,
  ptm TEXT NOT NULL,
  kg NUMERIC NOT NULL,
  operators JSONB DEFAULT '[]'::jsonb,
  start_time TEXT NOT NULL DEFAULT '',
  end_time TEXT NOT NULL DEFAULT '',
  time_spent TEXT,
  novedad TEXT DEFAULT '',
  novedad_resuelta BOOLEAN DEFAULT false,
  created_by TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_unloadings_date ON unloadings(date);

ALTER TABLE unloadings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Todos pueden leer unloadings" ON unloadings FOR SELECT USING (true);
CREATE POLICY "Todos pueden insertar unloadings" ON unloadings FOR INSERT WITH CHECK (true);
CREATE POLICY "Todos pueden actualizar unloadings" ON unloadings FOR UPDATE USING (true);
CREATE POLICY "Todos pueden eliminar unloadings" ON unloadings FOR DELETE USING (true);

-- ============================================================
-- 👤 Operadores (lista controlada para evitar errores)
-- ============================================================
CREATE TABLE operators (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO operators (name) VALUES
  ('sebastian'),
  ('edwin'),
  ('gongora'),
  ('emerson'),
  ('neider'),
  ('ovidio'),
  ('jean marco'),
  ('urbano'),
  ('luis');

ALTER TABLE operators ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Todos pueden leer operators" ON operators FOR SELECT USING (true);
CREATE POLICY "Todos pueden insertar operators" ON operators FOR INSERT WITH CHECK (true);
CREATE POLICY "Todos pueden eliminar operators" ON operators FOR DELETE USING (true);

-- ============================================================
-- 👤 Usuarios del sistema
-- ============================================================
CREATE TABLE usuarios (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Todos pueden leer usuarios" ON usuarios FOR SELECT USING (true);
CREATE POLICY "Todos pueden insertar usuarios" ON usuarios FOR INSERT WITH CHECK (true);

INSERT INTO usuarios (username, password) VALUES
  ('william', '2026'),
  ('dumar', '1996'),
  ('oscar', '0220'),
  ('cesar', '0000');

-- ============================================================
-- 🏭 Bodega / Racks - Ocupación y disponibilidad
-- ============================================================
CREATE TABLE racks (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo TEXT NOT NULL UNIQUE,
  posiciones INT NOT NULL DEFAULT 0,
  ocupacion INT NOT NULL DEFAULT 0,
  disponible INT GENERATED ALWAYS AS (posiciones - ocupacion) STORED,
  porcentaje_ocupacion NUMERIC GENERATED ALWAYS AS (
    CASE WHEN posiciones > 0 THEN ROUND((ocupacion::NUMERIC / posiciones) * 100, 2) ELSE 0 END
  ) STORED,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by TEXT DEFAULT ''
);

CREATE INDEX idx_racks_codigo ON racks(codigo);

ALTER TABLE racks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Todos pueden leer racks" ON racks FOR SELECT USING (true);
CREATE POLICY "Todos pueden insertar racks" ON racks FOR INSERT WITH CHECK (true);
CREATE POLICY "Todos pueden actualizar racks" ON racks FOR UPDATE USING (true);
CREATE POLICY "Todos pueden eliminar racks" ON racks FOR DELETE USING (true);

INSERT INTO racks (codigo, posiciones, ocupacion) VALUES
  ('R1', 100, 100),
  ('R2', 80, 80),
  ('R3', 80, 80),
  ('R4', 90, 80),
  ('R5', 90, 90),
  ('R6', 90, 90),
  ('R7', 90, 90),
  ('R8', 100, 100)
ON CONFLICT (codigo) DO NOTHING;
