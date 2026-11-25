"""Recurso Monitores. No depende del módulo de PC.

Cada monitor tiene su propia ubicación (área y piso). La PC es un dato opcional:
un monitor se puede cargar sin PC y asignarse a una más adelante.
"""
import sqlite3

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator, model_validator

from api.database import get_db
from api.v1.comunes import Area, area_o_none, limpiar, verificar_area

router = APIRouter(prefix='/monitores', tags=['Monitores'])


# ---------------------------------------------------------------- modelos
class InterfazCantidad(BaseModel):
    nombre: str = Field(min_length=1, examples=['HDMI'])
    cantidad: int = Field(default=1, ge=1, le=10)

    @field_validator('nombre', mode='before')
    @classmethod
    def _texto(cls, v):
        return limpiar(v)


class MonitorCrear(BaseModel):
    marca: str = Field(min_length=1, max_length=60, examples=['LG'])
    modelo: str = Field(min_length=1, max_length=80, examples=['22MK400H'])
    numero_serie: str | None = Field(default=None, max_length=80)
    pulgadas: float = Field(gt=0, le=100, examples=[21.5])
    interfaces: list[InterfazCantidad] = Field(
        default_factory=list, examples=[[{'nombre': 'VGA'}, {'nombre': 'HDMI', 'cantidad': 1}]])
    area_id: int = Field(gt=0, examples=[1], description='Id del área (GET /api/v1/areas).')
    piso: str | None = Field(default=None, max_length=20, examples=['6'])
    equipo_id: int | None = Field(default=None, gt=0, description='Id de la PC a la que está conectado. Vacío = sin PC.')
    observaciones: str | None = Field(default=None, max_length=500)

    @field_validator('marca', 'modelo', 'numero_serie', 'piso', 'observaciones', mode='before')
    @classmethod
    def _texto(cls, v):
        return limpiar(v)

    @model_validator(mode='after')
    def _interfaces_unicas(self):
        nombres = [i.nombre.lower() for i in self.interfaces]
        if len(nombres) != len(set(nombres)):
            raise ValueError('Hay interfaces repetidas: usá "cantidad" en lugar de repetirlas.')
        return self


class EquipoRef(BaseModel):
    id: int
    nombre: str


class Monitor(BaseModel):
    id: int
    marca: str | None
    modelo: str | None
    numero_serie: str | None
    pulgadas: float | None
    interfaces: list[InterfazCantidad]
    area: Area | None
    piso: str | None
    equipo: EquipoRef | None
    observaciones: str | None


# ---------------------------------------------------------------- consultas
_SELECT = """
    SELECT m.id, m.marca, m.modelo, m.numero_serie, m.pulgadas, m.piso, m.observaciones,
           a.id AS area_id, a.nombre AS area_nombre,
           e.id AS equipo_id, e.nombre AS equipo_nombre
    FROM monitores m
    LEFT JOIN areas   a ON a.id = m.area_id
    LEFT JOIN equipos e ON e.id = m.equipo_id
"""


def _leer(con, where='', params=()):
    filas = con.execute(f'{_SELECT} {where} ORDER BY m.id', params).fetchall()
    if not filas:
        return []
    ids = [f['id'] for f in filas]
    interfaces = {}
    for r in con.execute(
        f"""SELECT mi.monitor_id, iv.nombre, mi.cantidad
            FROM monitor_interfaces mi JOIN interfaces_video iv ON iv.id = mi.interfaz_id
            WHERE mi.monitor_id IN ({','.join('?' * len(ids))}) ORDER BY iv.id""",
        ids,
    ):
        interfaces.setdefault(r['monitor_id'], []).append({'nombre': r['nombre'], 'cantidad': r['cantidad']})

    return [
        {
            'id': f['id'], 'marca': f['marca'], 'modelo': f['modelo'], 'numero_serie': f['numero_serie'],
            'pulgadas': f['pulgadas'], 'piso': f['piso'], 'observaciones': f['observaciones'],
            'area': area_o_none(f['area_id'], f['area_nombre']),
            'equipo': {'id': f['equipo_id'], 'nombre': f['equipo_nombre']} if f['equipo_id'] else None,
            'interfaces': interfaces.get(f['id'], []),
        }
        for f in filas
    ]


# ---------------------------------------------------------------- endpoints
@router.get('', response_model=list[Monitor], summary='Listar monitores')
def listar_monitores(
    area_id: int | None = Query(None),
    piso: str | None = Query(None),
    equipo_id: int | None = Query(None, description='Monitores conectados a esta PC'),
    sin_pc: bool | None = Query(None, description='true = solo los que no están conectados a una PC'),
    con: sqlite3.Connection = Depends(get_db),
):
    condiciones, params = [], []
    if area_id is not None:
        condiciones.append('m.area_id = ?'); params.append(area_id)
    if piso:
        condiciones.append('m.piso = ? COLLATE NOCASE'); params.append(piso.strip())
    if equipo_id is not None:
        condiciones.append('m.equipo_id = ?'); params.append(equipo_id)
    if sin_pc is True:
        condiciones.append('m.equipo_id IS NULL')
    elif sin_pc is False:
        condiciones.append('m.equipo_id IS NOT NULL')
    where = f"WHERE {' AND '.join(condiciones)}" if condiciones else ''
    return _leer(con, where, params)


@router.get('/{monitor_id}', response_model=Monitor, summary='Ver un monitor')
def ver_monitor(monitor_id: int, con: sqlite3.Connection = Depends(get_db)):
    monitores = _leer(con, 'WHERE m.id = ?', (monitor_id,))
    if not monitores:
        raise HTTPException(404, f'No existe el monitor {monitor_id}')
    return monitores[0]


@router.post('', response_model=Monitor, status_code=201, summary='Cargar un monitor')
def crear_monitor(datos: MonitorCrear, con: sqlite3.Connection = Depends(get_db)):
    verificar_area(con, datos.area_id)
    if datos.equipo_id is not None and not con.execute(
        'SELECT 1 FROM equipos WHERE id = ?', (datos.equipo_id,)
    ).fetchone():
        raise HTTPException(422, f'No existe la PC {datos.equipo_id}. Consultá las válidas en GET /api/v1/pc.')

    interfaces = []
    for interfaz in datos.interfaces:
        fila = con.execute('SELECT id FROM interfaces_video WHERE nombre = ?', (interfaz.nombre,)).fetchone()
        if not fila:
            validas = ', '.join(r[0] for r in con.execute('SELECT nombre FROM interfaces_video ORDER BY id'))
            raise HTTPException(422, f'Interfaz desconocida: {interfaz.nombre}. Válidas: {validas}')
        interfaces.append((fila['id'], interfaz.cantidad))

    with con:  # todo o nada: si algo falla no queda el monitor a medias
        try:
            cur = con.execute(
                'INSERT INTO monitores (marca, modelo, numero_serie, pulgadas, area_id, piso, equipo_id, observaciones)'
                ' VALUES (?,?,?,?,?,?,?,?)',
                (datos.marca, datos.modelo, datos.numero_serie, datos.pulgadas, datos.area_id,
                 datos.piso, datos.equipo_id, datos.observaciones),
            )
        except sqlite3.IntegrityError:
            raise HTTPException(409, f'Ya existe un monitor con número de serie {datos.numero_serie}')
        con.executemany(
            'INSERT INTO monitor_interfaces (monitor_id, interfaz_id, cantidad) VALUES (?,?,?)',
            [(cur.lastrowid, i, c) for i, c in interfaces],
        )
    return _leer(con, 'WHERE m.id = ?', (cur.lastrowid,))[0]
