import sqlite3

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator

from api.database import get_db
from api.v1.comunes import Area, limpiar

router = APIRouter(prefix='/areas', tags=['Áreas'])


class AreaCrear(BaseModel):
    nombre: str = Field(min_length=1, max_length=100, examples=['Administración'])

    @field_validator('nombre', mode='before')
    @classmethod
    def _nombre(cls, v):
        return limpiar(v)


@router.get('', response_model=list[Area], summary='Listar áreas')
def listar_areas(con: sqlite3.Connection = Depends(get_db)):
    return [dict(r) for r in con.execute('SELECT id, nombre FROM areas ORDER BY nombre')]


@router.post('', response_model=Area, status_code=201, summary='Crear un área')
def crear_area(datos: AreaCrear, con: sqlite3.Connection = Depends(get_db)):
    with con:
        try:
            cur = con.execute('INSERT INTO areas (nombre) VALUES (?)', (datos.nombre,))
        except sqlite3.IntegrityError:
            existente = con.execute('SELECT id, nombre FROM areas WHERE nombre = ?', (datos.nombre,)).fetchone()
            raise HTTPException(409, f'Ya existe el área "{existente["nombre"]}" con id {existente["id"]}')
    return {'id': cur.lastrowid, 'nombre': datos.nombre}
