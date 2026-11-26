import sqlite3

from fastapi import APIRouter, Depends

from api.database import get_db
from api.v1.comunes import Area as Catalogo  # mismo formato: id y nombre

router = APIRouter(prefix='/interfaces', tags=['Interfaces de video'])


@router.get('', response_model=list[Catalogo], summary='Listar interfaces de video (VGA, HDMI...)')
def listar_interfaces(con: sqlite3.Connection = Depends(get_db)):
    return [dict(r) for r in con.execute('SELECT id, nombre FROM interfaces_video ORDER BY id')]
