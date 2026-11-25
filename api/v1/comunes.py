"""Piezas compartidas por los recursos de la v1 (sin lógica de PC ni de monitores)."""
from fastapi import HTTPException
from pydantic import BaseModel


class Area(BaseModel):
    id: int
    nombre: str


def limpiar(valor):
    """Saca espacios de más; un texto vacío pasa a None."""
    if isinstance(valor, str):
        valor = ' '.join(valor.split())
        return valor or None
    return valor


def verificar_area(con, area_id):
    """Devuelve el área o responde 422 si el id no existe."""
    fila = con.execute('SELECT id, nombre FROM areas WHERE id = ?', (area_id,)).fetchone()
    if not fila:
        raise HTTPException(422, f'No existe el área {area_id}. Consultá las válidas en GET /api/v1/areas.')
    return dict(fila)


def area_o_none(area_id, area_nombre):
    return {'id': area_id, 'nombre': area_nombre} if area_id is not None else None
