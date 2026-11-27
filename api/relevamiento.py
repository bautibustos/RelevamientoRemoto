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


def probar_wmi(nombre):
    """Conexión corta por WMI (solo el sistema operativo), sin guardar nada.

    Devuelve (ok, detalle). Sirve para saber si el equipo acepta WMI antes de relevarlo.
    """
    import pythoncom
    import remote_check  # carga el .env y las credenciales
    import wmi

    with _candado:
        pythoncom.CoInitialize()
        try:
            c = wmi.WMI(nombre, user=remote_check.us, password=remote_check.pwd)
            so = next((str(o.Caption).strip() for o in c.Win32_OperatingSystem()), None)
            return True, f'WMI responde ({so}).' if so else 'WMI responde.'
        except Exception as e:  # acceso denegado, RPC no disponible, timeouts
            return False, mensaje_de_error(e)
        finally:
            pythoncom.CoUninitialize()


def guardar(nombre, piso, area, red, info):
    db_manager.RUTA_DB = RUTA_DB  # la misma base que usa la API
    db_manager.guardar_relevamiento(nombre, piso, area, red, info)


def registrar_fallo(nombre, piso, area, red, estado, detalle):
    db_manager.RUTA_DB = RUTA_DB
    db_manager.registrar_fallo(nombre, piso, area, red, estado, detalle)


def relevar_y_guardar(nombre, piso, area, red):
    """Ping + WMI + guardado del resultado (o del fallo). Devuelve (ok, detalle).

    Lo usan el endpoint "Volver a relevar" (modo normal) y el validador.
    """
    from api.red import hacer_ping

    ping = hacer_ping(nombre)
    if not ping.responde:
        registrar_fallo(nombre, piso, area, red, 'sin_respuesta', ping.detalle)
        return False, ping.detalle or 'No respondió al ping.'
    try:
        info = relevar(nombre)
    except Exception as e:  # WMI puede fallar de muchas formas (acceso, RPC, timeouts)
        detalle = mensaje_de_error(e)
        registrar_fallo(nombre, piso, area, red, 'error', detalle)
        return False, f'No se pudo consultar el hardware: {detalle}'
    guardar(nombre, piso, area, red, info)
    return True, 'Hardware actualizado desde el equipo.'
