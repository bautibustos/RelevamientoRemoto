"""Conexión a la base para la API.

La ruta se puede cambiar con INVENTARIO_DB (en el .env o como variable de entorno): sirve para
pruebas y para que dos APIs compartan la misma base en una carpeta compartida.
"""
import sqlite3

import config
from db import crear_db

RUTA_DB = config.ruta_db(crear_db.RUTA_DB)


def inicializar():
    crear_db.crear_db(RUTA_DB)


def get_db():
    """Dependencia de FastAPI: una conexión por request."""
    # check_same_thread=False: FastAPI puede abrir y usar la conexión en hilos distintos del pool.
    # La conexión espera (crear_db.ESPERA_BLOQUEO) si otra API está escribiendo la misma base.
    con = crear_db.conectar(RUTA_DB, check_same_thread=False)
    con.row_factory = sqlite3.Row
    try:
        yield con
    finally:
        con.close()
