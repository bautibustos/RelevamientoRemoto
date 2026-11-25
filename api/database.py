"""Conexión a la base para la API.

La ruta se puede cambiar con la variable de entorno INVENTARIO_DB (útil para pruebas).
"""
import os
import sqlite3
from pathlib import Path

from db import crear_db

RUTA_DB = Path(os.environ.get('INVENTARIO_DB', crear_db.RUTA_DB))


def inicializar():
    crear_db.crear_db(RUTA_DB)


def get_db():
    """Dependencia de FastAPI: una conexión por request."""
    # check_same_thread=False: FastAPI puede abrir y usar la conexión en hilos distintos del pool
    con = sqlite3.connect(RUTA_DB, check_same_thread=False)
    con.row_factory = sqlite3.Row
    con.execute('PRAGMA foreign_keys = ON')
    try:
        yield con
    finally:
        con.close()
