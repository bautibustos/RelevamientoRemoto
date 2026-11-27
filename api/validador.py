"""Validador: procesa la cola de PCs 'pendiente' (modo doble API).

Corre en una PC dentro de la red, con acceso por WMI a los equipos. Toma de a una PC
pendiente, la marca como reclamada (la API la muestra como 'relevando'), le hace ping,
la releva por WMI y guarda el resultado: 'ok', 'sin_respuesta' o 'error'.

Mientras corre, anota un latido en la tabla validadores para que la API de afuera sepa
que hay alguien procesando la cola.

Uso:
    python -m api.validador           (proceso aparte)
    VALIDADOR=1 en el .env            (lo arranca la API en segundo plano)
"""
import logging
import os
import socket
import threading

import config
from api import relevamiento
from api.database import RUTA_DB
from db import db_manager

log = logging.getLogger('validador')

# cada cuántos segundos se anota el latido (debe ser menor que db_manager.LATIDO_VENCE)
LATIDO_CADA = 15


class Validador:
    def __init__(self, nombre=None, intervalo=None):
        self.nombre = nombre or f'{socket.gethostname()} (pid {os.getpid()})'
        self.intervalo = intervalo or config.validador_intervalo()
        self._parar = threading.Event()
        self._actual = None  # PC que se está relevando, para el latido
        db_manager.RUTA_DB = RUTA_DB  # la misma base que usa la API

    def procesar_uno(self):
        """Releva la próxima PC de la cola. Devuelve False si la cola estaba vacía."""
        fila = db_manager.reclamar_siguiente(self.nombre)
        if not fila:
            return False
        _, nombre, piso, area, red = fila
        self._actual = nombre
        self._latir_una_vez()  # la API de afuera ve enseguida qué PC se está relevando
        log.info('relevando %s', nombre)
        try:
            ok, detalle = relevamiento.relevar_y_guardar(nombre, piso, area, red)
        except Exception as e:  # p. ej. la base no está accesible: el reclamo vence y se reintenta
            log.exception('no se pudo guardar el resultado de %s', nombre)
            ok, detalle = False, str(e)
        finally:
            self._actual = None
        log.info('%s: %s - %s', nombre, 'ok' if ok else 'falló', detalle)
        return True

    def ejecutar(self):
        """Procesa la cola hasta que se llame a detener()."""
        log.info('validador "%s" usando la base %s', self.nombre, RUTA_DB)
        latidos = threading.Thread(target=self._latir, name='validador-latido', daemon=True)
        latidos.start()
        try:
            while not self._parar.is_set():
                try:
                    hubo_trabajo = self.procesar_uno()
                except Exception:
                    log.exception('error leyendo la cola; se reintenta en %s s', self.intervalo)
                    hubo_trabajo = False
                if not hubo_trabajo:
                    self._parar.wait(self.intervalo)
        finally:
            self._parar.set()
            try:
                db_manager.dar_de_baja_validador(self.nombre)
            except Exception:
                log.warning('no se pudo dar de baja el validador (la base no está accesible)')

    def iniciar_en_segundo_plano(self):
        hilo = threading.Thread(target=self.ejecutar, name='validador', daemon=True)
        hilo.start()
        return hilo

    def detener(self):
        self._parar.set()

    def _latir_una_vez(self):
        try:
            db_manager.latido(self.nombre, self._actual)
        except Exception:
            log.warning('no se pudo anotar el latido (la base no está accesible)')

    def _latir(self):
        while not self._parar.is_set():
            self._latir_una_vez()
            self._parar.wait(LATIDO_CADA)


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s', datefmt='%H:%M:%S')
    validador = Validador()
    try:
        validador.ejecutar()
    except KeyboardInterrupt:
        validador.detener()
