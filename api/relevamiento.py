"""Relevamiento por WMI disparado desde la API (botón "Volver a relevar" de la app).

remote_check guarda el resultado en una variable global, así que se releva de a un
equipo por vez. WMI usa COM: cada hilo que lo llama tiene que inicializarlo.
"""
import threading

from api.database import RUTA_DB
from db import db_manager

_candado = threading.Lock()


def mensaje_de_error(e):
    """Texto legible de un error de WMI/COM (ej. "Acceso denegado.")."""
    com = getattr(e, 'com_error', None)
    try:
        if com is not None and com.excepinfo and com.excepinfo[2]:
            return str(com.excepinfo[2]).strip()
    except (AttributeError, IndexError, TypeError):
        pass
    return str(e).strip() or type(e).__name__


def relevar(nombre):
    """Consulta el hardware del equipo por WMI. Devuelve el dict de remote_check.ejecutor()."""
    import pythoncom
    import remote_check

    with _candado:
        pythoncom.CoInitialize()
        try:
            return remote_check.ejecutor(nombre)
        finally:
            pythoncom.CoUninitialize()


def guardar(nombre, piso, area, red, info):
    db_manager.RUTA_DB = RUTA_DB  # la misma base que usa la API
    db_manager.guardar_relevamiento(nombre, piso, area, red, info)


def registrar_fallo(nombre, piso, area, red, estado, detalle):
    db_manager.RUTA_DB = RUTA_DB
    db_manager.registrar_fallo(nombre, piso, area, red, estado, detalle)
