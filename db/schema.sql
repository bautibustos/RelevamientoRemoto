-- Esquema de inventario (SQLite >= 3.37 por STRICT)
-- Recordar: PRAGMA foreign_keys = ON; en cada conexión.

-- ============================================================
-- Catálogo de áreas
-- ============================================================
CREATE TABLE IF NOT EXISTS areas (
    id      INTEGER PRIMARY KEY,
    nombre  TEXT NOT NULL UNIQUE COLLATE NOCASE
) STRICT;

-- ============================================================
-- PCs + datos obtenidos remotamente (último relevamiento)
-- ============================================================
CREATE TABLE IF NOT EXISTS equipos (
    id                  INTEGER PRIMARY KEY,
    nombre              TEXT NOT NULL UNIQUE COLLATE NOCASE,   -- PC0002

    -- ubicación
    piso                TEXT,                                  -- texto libre: "6", "PB", "EP"
    area_id             INTEGER REFERENCES areas(id) ON DELETE SET NULL,
    red                 TEXT,

    -- sistema
    so                  TEXT,
    usuario             TEXT,

    -- procesador
    cpu_nombre          TEXT,
    cpu_familia         TEXT,
    cpu_modelo          TEXT,
    cpu_ghz             REAL,

    -- placa madre
    placa_fabricante    TEXT,
    placa_modelo        TEXT,

    -- video
    video               TEXT,

    -- memoria
    ram_tipo            TEXT CHECK (ram_tipo IN ('DDR1','DDR2','DDR3','DDR4','DDR5')),
                                                               -- módulos, MHz y total: tabla memorias

    -- control
    estado              TEXT NOT NULL DEFAULT 'pendiente'
                        CHECK (estado IN ('pendiente','ok','sin_respuesta','error')),
    ultimo_error        TEXT,
    fecha_relevamiento  TEXT,                                  -- ISO 8601
    datos_crudos        TEXT,                                  -- JSON completo de WMI

    -- cola del validador (modo doble API): una PC 'pendiente' con reclamado_en es la que
    -- un validador está relevando en este momento. La API la informa como 'relevando'.
    reclamado_por       TEXT,                                  -- nombre del validador
    reclamado_en        TEXT                                   -- cuándo la tomó (ISO 8601)
) STRICT;

CREATE INDEX IF NOT EXISTS idx_equipos_area ON equipos(area_id);

-- ============================================================
-- Validadores (modo doble API): cada uno anota cada tanto que sigue vivo,
-- así la API de afuera sabe si hay alguien procesando la cola.
-- ============================================================
CREATE TABLE IF NOT EXISTS validadores (
    nombre          TEXT PRIMARY KEY,                          -- SERVIDOR01 (pid 1234)
    ultimo_latido   TEXT NOT NULL,                             -- ISO 8601
    equipo_actual   TEXT                                       -- PC que está relevando, si hay
) STRICT;

-- ============================================================
-- Discos internos (1 PC -> N discos). Los USB no se registran.
-- ============================================================
CREATE TABLE IF NOT EXISTS discos (
    id              INTEGER PRIMARY KEY,
    equipo_id       INTEGER NOT NULL REFERENCES equipos(id) ON DELETE CASCADE,
    marca           TEXT,                                      -- se deduce de MSFT_PhysicalDisk.Model
    tecnologia      TEXT NOT NULL DEFAULT 'desconocido'
                    CHECK (tecnologia IN ('SSD','HDD','desconocido')),
    bus             TEXT CHECK (bus IN ('NVMe','SATA','ATA','SAS','SCSI','RAID','otro')),
    capacidad_gb    REAL
) STRICT;

CREATE INDEX IF NOT EXISTS idx_discos_equipo ON discos(equipo_id);

-- ============================================================
-- Módulos de memoria RAM (1 PC -> N módulos, ej. 16 GB + 4 GB).
-- El total de la PC es la suma de sus módulos.
-- ============================================================
CREATE TABLE IF NOT EXISTS memorias (
    id              INTEGER PRIMARY KEY,
    equipo_id       INTEGER NOT NULL REFERENCES equipos(id) ON DELETE CASCADE,
    capacidad_gb    REAL NOT NULL CHECK (capacidad_gb > 0),   -- Win32_PhysicalMemory.Capacity
    mhz             INTEGER CHECK (mhz > 0)                    -- Win32_PhysicalMemory.Speed
) STRICT;

CREATE INDEX IF NOT EXISTS idx_memorias_equipo ON memorias(equipo_id);

-- ============================================================
-- Monitores
--   equipo_id NULL  -> monitor sin PC (depósito, sala, etc.)
--   varios monitores con el mismo equipo_id -> PC con 2+ monitores
--   PC sin ningún monitor apuntándole -> PC sin monitor
-- ============================================================
CREATE TABLE IF NOT EXISTS interfaces_video (
    id      INTEGER PRIMARY KEY,
    nombre  TEXT NOT NULL UNIQUE COLLATE NOCASE
) STRICT;

CREATE TABLE IF NOT EXISTS monitores (
    id                  INTEGER PRIMARY KEY,
    marca               TEXT,
    modelo              TEXT,
    numero_serie        TEXT UNIQUE,                           -- NULL permitido (varios sin serie)
    pulgadas            REAL CHECK (pulgadas IS NULL OR pulgadas > 0),

    -- asignación
    equipo_id           INTEGER REFERENCES equipos(id) ON DELETE SET NULL,

    -- ubicación propia (para monitores sin PC)
    piso                TEXT,
    area_id             INTEGER REFERENCES areas(id) ON DELETE SET NULL,

    observaciones       TEXT
) STRICT;

CREATE INDEX IF NOT EXISTS idx_monitores_equipo ON monitores(equipo_id);

-- Un monitor puede tener varias entradas (VGA + HDMI, 2x DisplayPort, etc.)
CREATE TABLE IF NOT EXISTS monitor_interfaces (
    monitor_id      INTEGER NOT NULL REFERENCES monitores(id) ON DELETE CASCADE,
    interfaz_id     INTEGER NOT NULL REFERENCES interfaces_video(id),
    cantidad        INTEGER NOT NULL DEFAULT 1 CHECK (cantidad > 0),
    PRIMARY KEY (monitor_id, interfaz_id)
) STRICT;

-- ============================================================
-- Valores iniciales de catálogos
-- ============================================================
INSERT OR IGNORE INTO interfaces_video (nombre) VALUES
    ('VGA'), ('DVI'), ('HDMI'), ('DisplayPort'), ('Mini DisplayPort'), ('USB-C');
