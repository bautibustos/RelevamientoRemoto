"""Crea (o actualiza) la base de datos db/inventario.db a partir de db/schema.sql.

Se puede ejecutar varias veces: las tablas usan IF NOT EXISTS y los
catálogos INSERT OR IGNORE, así que no borra ni duplica datos.
"""
import sqlite3
from pathlib import Path

CARPETA = Path(__file__).resolve().parent
RUTA_DB = CARPETA / 'inventario.db'
RUTA_ESQUEMA = CARPETA / 'schema.sql'


def conectar(ruta=RUTA_DB):
    conexion = sqlite3.connect(ruta)
    conexion.execute('PRAGMA foreign_keys = ON')
    return conexion


def crear_db(ruta=RUTA_DB):
    with conectar(ruta) as conexion:
        conexion.executescript(RUTA_ESQUEMA.read_text(encoding='utf-8'))
        migrar(conexion)
    return ruta


def _columnas(con, tabla):
    return {fila[1] for fila in con.execute(f'PRAGMA table_info({tabla})')}


def migrar(con):
    """Lleva una base creada con un esquema anterior al actual, sin perder datos.

    - RAM: ram_total_gb / ram_modulos pasan a la tabla memorias (un registro por módulo),
      tomando las capacidades del relevamiento guardado en datos_crudos.
    - RAM: los MHz pasan de equipos.ram_mhz a cada módulo (memorias.mhz).
    - Discos: modelo pasa a marca y se quita numero_serie.
    """
    try:
        from .marcas import marca_disco
    except ImportError:  # ejecutado como script: python db/crear_db.py
        from marcas import marca_disco

    equipos = _columnas(con, 'equipos')
    if 'ram_modulos' in equipos or 'ram_total_gb' in equipos:
        con.execute("""
            INSERT INTO memorias (equipo_id, capacidad_gb)
            SELECT e.id, CAST(j.value AS REAL)
            FROM equipos e, json_each(e.datos_crudos, '$.memoria.capacidad') j
            WHERE json_valid(e.datos_crudos) AND CAST(j.value AS REAL) > 0
              AND NOT EXISTS (SELECT 1 FROM memorias m WHERE m.equipo_id = e.id)
        """)
        for columna in ('ram_total_gb', 'ram_modulos'):
            if columna in equipos:
                con.execute(f'ALTER TABLE equipos DROP COLUMN {columna}')

    if 'mhz' not in _columnas(con, 'memorias'):
        con.execute('ALTER TABLE memorias ADD COLUMN mhz INTEGER CHECK (mhz > 0)')
    if 'ram_mhz' in _columnas(con, 'equipos'):
        con.execute("""
            UPDATE memorias SET mhz = (SELECT e.ram_mhz FROM equipos e WHERE e.id = memorias.equipo_id)
            WHERE mhz IS NULL
              AND (SELECT e.ram_mhz FROM equipos e WHERE e.id = memorias.equipo_id) > 0
        """)
        con.execute('ALTER TABLE equipos DROP COLUMN ram_mhz')

    discos = _columnas(con, 'discos')
    if 'modelo' in discos:
        con.execute('ALTER TABLE discos RENAME COLUMN modelo TO marca')
        for id_, modelo in con.execute('SELECT id, marca FROM discos').fetchall():
            con.execute('UPDATE discos SET marca = ? WHERE id = ?', (marca_disco(modelo), id_))
    if 'numero_serie' in discos:
        con.execute('ALTER TABLE discos DROP COLUMN numero_serie')


if __name__ == '__main__':
    print(f'Base creada en: {crear_db()}')
