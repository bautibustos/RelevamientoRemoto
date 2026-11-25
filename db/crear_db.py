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
    return ruta


if __name__ == '__main__':
    print(f'Base creada en: {crear_db()}')
