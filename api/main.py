"""API del inventario.

Ejecutar desde la carpeta del proyecto:
    python -m uvicorn api.main:app --reload

Documentación interactiva: http://127.0.0.1:8000/docs
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI

from api import database
from api.v1 import router as router_v1


@asynccontextmanager
async def lifespan(app):
    database.inicializar()  # crea las tablas si faltan
    yield


app = FastAPI(title='Relevamiento Remoto', version='1.0.0', lifespan=lifespan)
app.include_router(router_v1, prefix='/api/v1')
