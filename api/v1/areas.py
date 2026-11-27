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
        v = limpiar(v)
        if v is None:
            raise ValueError('El nombre del área no puede estar vacío.')
        return v


class AreaResumen(Area):
    cantidad_pc: int
    cantidad_monitores: int


@router.get('', response_model=list[AreaResumen], summary='Listar áreas con la cantidad de equipos')
def listar_areas(con: sqlite3.Connection = Depends(get_db)):
    return [dict(r) for r in con.execute(
        """
        SELECT a.id, a.nombre,
               (SELECT COUNT(*) FROM equipos   e WHERE e.area_id = a.id) AS cantidad_pc,
               (SELECT COUNT(*) FROM monitores m WHERE m.area_id = a.id) AS cantidad_monitores
        FROM areas a
        ORDER BY a.nombre
        """
    )]


@router.post('', response_model=Area, status_code=201, summary='Crear un área')
def crear_area(datos: AreaCrear, con: sqlite3.Connection = Depends(get_db)):
    with con:
        try:
            cur = con.execute('INSERT INTO areas (nombre) VALUES (?)', (datos.nombre,))
        except sqlite3.IntegrityError:
            existente = con.execute('SELECT id, nombre FROM areas WHERE nombre = ?', (datos.nombre,)).fetchone()
            raise HTTPException(409, f'Ya existe el área "{existente["nombre"]}" con id {existente["id"]}')
    return {'id': cur.lastrowid, 'nombre': datos.nombre}


@router.patch('/{area_id}', response_model=Area, summary='Renombrar un área',
              description='Cambia el nombre del área. Las PCs y monitores de esa área no se tocan.')
def editar_area(area_id: int, datos: AreaCrear, con: sqlite3.Connection = Depends(get_db)):
    if not con.execute('SELECT 1 FROM areas WHERE id = ?', (area_id,)).fetchone():
        raise HTTPException(404, f'No existe el área {area_id}')
    with con:
        try:
            con.execute('UPDATE areas SET nombre = ? WHERE id = ?', (datos.nombre, area_id))
        except sqlite3.IntegrityError:
            existente = con.execute('SELECT id, nombre FROM areas WHERE nombre = ?', (datos.nombre,)).fetchone()
            raise HTTPException(409, f'Ya existe el área "{existente["nombre"]}" con id {existente["id"]}')
    return {'id': area_id, 'nombre': datos.nombre}
