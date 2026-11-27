"""API del inventario.

Ejecutar desde la carpeta del proyecto:
    python -m uvicorn api.main:app --reload

Documentación interactiva: http://127.0.0.1:8000/docs

Modo doble API (ver README): MODO_API=carga en la PC de afuera, VALIDADOR=1 en la de adentro.
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import config
from api import database
from api.v1 import router as router_v1


@asynccontextmanager
async def lifespan(app):
    database.inicializar()  # crea las tablas si faltan
    validador = None
    if config.validador_activo():
        from api.validador import Validador
        log = logging.getLogger('validador')
        log.setLevel(logging.INFO)
        if not log.handlers:  # que se vea en la consola de uvicorn
            manejador = logging.StreamHandler()
            manejador.setFormatter(logging.Formatter('%(asctime)s validador: %(message)s', '%H:%M:%S'))
            log.addHandler(manejador)
        validador = Validador()
        validador.iniciar_en_segundo_plano()
    yield
    if validador:
        validador.detener()


app = FastAPI(title='Relevamiento Remoto', version='1.0.0', lifespan=lifespan)

# El frontend (Flutter web) se sirve desde otro puerto: se habilitan solo orígenes locales
# y de redes privadas (para abrirlo desde el celular en la red interna).
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=(
        r'http://(localhost|127\.0\.0\.1|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+'
        r'|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)(:\d+)?'
    ),
    allow_methods=['GET', 'POST', 'PATCH'],
    allow_headers=['Content-Type'],
)

app.include_router(router_v1, prefix='/api/v1')
