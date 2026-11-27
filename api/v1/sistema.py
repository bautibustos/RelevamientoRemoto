"""Estado del sistema: modo de la API, validadores vivos y cola de PCs pendientes."""
import sqlite3
from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

import config
from api.database import get_db
from db import db_manager

router = APIRouter(prefix='/sistema', tags=['Sistema'])


class Validador(BaseModel):
    nombre: str
    ultimo_latido: str
    equipo_actual: str | None
    activo: bool = Field(description='Anotó un latido en el último minuto.')


class Cola(BaseModel):
    pendientes: int = Field(description='PCs esperando que un validador las tome.')
    relevando: int = Field(description='PCs que un validador está relevando ahora.')


class Sistema(BaseModel):
    modo: Literal['normal', 'carga'] = Field(
        description='"normal": esta API hace ping y releva. "carga": solo guarda; releva el validador.')
    validador_local: bool = Field(description='Esta API corre también un validador (VALIDADOR=1).')
    validadores: list[Validador]
    cola: Cola


@router.get('', response_model=Sistema, summary='Ver el modo de la API, los validadores y la cola')
def ver_sistema(con: sqlite3.Connection = Depends(get_db)):
    limite_latido = db_manager.limite_latido()
    validadores = [
        {'nombre': f['nombre'], 'ultimo_latido': f['ultimo_latido'], 'equipo_actual': f['equipo_actual'],
         'activo': f['ultimo_latido'] >= limite_latido}
        for f in con.execute('SELECT nombre, ultimo_latido, equipo_actual FROM validadores ORDER BY nombre')
    ]
    limite = db_manager.limite_reclamo()
    relevando, pendientes = con.execute(
        """
        SELECT COALESCE(SUM(reclamado_en IS NOT NULL AND reclamado_en >= ?), 0),
               COALESCE(SUM(reclamado_en IS NULL OR reclamado_en < ?), 0)
        FROM equipos WHERE estado = 'pendiente'
        """,
        (limite, limite),
    ).fetchone()
    return {
        'modo': config.modo_api(),
        'validador_local': config.validador_activo(),
        'validadores': validadores,
        'cola': {'pendientes': pendientes, 'relevando': relevando},
    }
