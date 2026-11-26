"""Recurso PC. No depende del módulo de monitores."""
import sqlite3
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator

from api.database import get_db
from api.red import NOMBRE_VALIDO, hacer_ping
from api.v1.comunes import Area, area_o_none, limpiar, verificar_area

router = APIRouter(prefix='/pc', tags=['PC'])

Estado = Literal['pendiente', 'ok', 'sin_respuesta', 'error']


# ---------------------------------------------------------------- modelos
def _validar_nombre(v):
    v = limpiar(v)
    if isinstance(v, str):
        v = v.upper()
        if not NOMBRE_VALIDO.match(v):
            raise ValueError('El nombre solo puede tener letras, números, punto, guion y guion bajo, '
                             'y no puede empezar con guion.')
    return v


class PCCrear(BaseModel):
    nombre: str = Field(min_length=1, max_length=50, examples=['PC0002'])
    area_id: int = Field(gt=0, examples=[1], description='Id del área (GET /api/v1/areas).')
    piso: str = Field(min_length=1, max_length=20, examples=['6'], description='Texto libre: "6", "PB", "EP"...')

    @field_validator('nombre', mode='before')
    @classmethod
    def _nombre(cls, v):
        return _validar_nombre(v)

    @field_validator('piso', mode='before')
    @classmethod
    def _piso(cls, v):
        return limpiar(v)


class PCEditar(BaseModel):
    """Solo se modifican los campos enviados. El hardware no se edita: lo completa el relevamiento."""
    nombre: str = Field(None, min_length=1, max_length=50)
    area_id: int = Field(None, gt=0)
    piso: str = Field(None, min_length=1, max_length=20)
    red: str | None = Field(None, max_length=50)

    @field_validator('nombre', mode='before')
    @classmethod
    def _nombre(cls, v):
        return _validar_nombre(v)

    @field_validator('piso', 'red', mode='before')
    @classmethod
    def _texto(cls, v):
        return limpiar(v)


class Ping(BaseModel):
    responde: bool
    detalle: str


class Disco(BaseModel):
    id: int
    modelo: str | None
    numero_serie: str | None
    tecnologia: str
    bus: str | None
    capacidad_gb: float | None


class PC(BaseModel):
    id: int
    nombre: str
    piso: str | None
    area: Area | None
    red: str | None
    estado: Estado
    ultimo_error: str | None
    fecha_relevamiento: str | None
    so: str | None
    usuario: str | None
    cpu_nombre: str | None
    cpu_familia: str | None
    cpu_modelo: str | None
    cpu_ghz: float | None
    placa_fabricante: str | None
    placa_modelo: str | None
    video: str | None
    ram_tipo: str | None
    ram_total_gb: int | None
    ram_mhz: int | None
    ram_modulos: int | None


class PCDetalle(PC):
    discos: list[Disco]


class PCCreada(PC):
    ping: Ping


# ---------------------------------------------------------------- consultas
_CAMPOS = (
    'id', 'nombre', 'piso', 'red', 'estado', 'ultimo_error', 'fecha_relevamiento', 'so', 'usuario',
    'cpu_nombre', 'cpu_familia', 'cpu_modelo', 'cpu_ghz', 'placa_fabricante', 'placa_modelo', 'video',
    'ram_tipo', 'ram_total_gb', 'ram_mhz', 'ram_modulos',
)
_SELECT = f"""
    SELECT {', '.join('e.' + c for c in _CAMPOS)}, a.id AS area_id, a.nombre AS area_nombre
    FROM equipos e LEFT JOIN areas a ON a.id = e.area_id
"""


def _a_dict(fila):
    pc = {c: fila[c] for c in _CAMPOS}
    pc['area'] = area_o_none(fila['area_id'], fila['area_nombre'])
    return pc


# ---------------------------------------------------------------- endpoints
@router.get('', response_model=list[PC], summary='Listar PCs')
def listar_pcs(
    q: str | None = Query(None, description='Parte del nombre del equipo'),
    area_id: int | None = Query(None),
    piso: str | None = Query(None),
    estado: Estado | None = Query(None),
    con: sqlite3.Connection = Depends(get_db),
):
    condiciones, params = [], []
    if q and q.strip():
        # se escapan % y _ para que se busquen como texto literal
        patron = q.strip().replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
        condiciones.append("e.nombre LIKE ? ESCAPE '\\'"); params.append(f'%{patron}%')
    if area_id is not None:
        condiciones.append('e.area_id = ?'); params.append(area_id)
    if piso:
        condiciones.append('e.piso = ? COLLATE NOCASE'); params.append(piso.strip())
    if estado:
        condiciones.append('e.estado = ?'); params.append(estado)
    where = f"WHERE {' AND '.join(condiciones)}" if condiciones else ''
    return [_a_dict(f) for f in con.execute(f'{_SELECT} {where} ORDER BY e.nombre', params)]


@router.get('/{pc_id}', response_model=PCDetalle, summary='Ver una PC con sus discos')
def ver_pc(pc_id: int, con: sqlite3.Connection = Depends(get_db)):
    fila = con.execute(f'{_SELECT} WHERE e.id = ?', (pc_id,)).fetchone()
    if not fila:
        raise HTTPException(404, f'No existe la PC {pc_id}')
    pc = _a_dict(fila)
    pc['discos'] = [dict(d) for d in con.execute(
        'SELECT id, modelo, numero_serie, tecnologia, bus, capacidad_gb FROM discos WHERE equipo_id = ? ORDER BY id',
        (pc_id,),
    )]
    return pc


@router.post('', response_model=PCCreada, status_code=201, summary='Cargar una PC',
             description='Da de alta la PC y le hace un ping. Si responde queda "pendiente" de relevar; '
                         'si no, queda "sin_respuesta". El resultado del ping vuelve en el campo "ping".')
def crear_pc(datos: PCCrear, con: sqlite3.Connection = Depends(get_db)):
    verificar_area(con, datos.area_id)
    with con:
        try:
            cur = con.execute(
                'INSERT INTO equipos (nombre, piso, area_id) VALUES (?,?,?)',
                (datos.nombre, datos.piso, datos.area_id),
            )
        except sqlite3.IntegrityError:
            raise HTTPException(409, f'Ya existe la PC {datos.nombre}')
    pc_id = cur.lastrowid

    # el ping se hace con la PC ya guardada: si falla, el alta no se pierde
    ping = hacer_ping(datos.nombre)
    if not ping.responde:
        with con:
            con.execute("UPDATE equipos SET estado = 'sin_respuesta', ultimo_error = ? WHERE id = ?",
                        (ping.detalle, pc_id))

    pc = _a_dict(con.execute(f'{_SELECT} WHERE e.id = ?', (pc_id,)).fetchone())
    pc['ping'] = {'responde': ping.responde, 'detalle': ping.detalle}
    return pc


@router.patch('/{pc_id}', response_model=PC, summary='Editar una PC',
              description='Modifica nombre, área, piso o red. Solo cambia los campos enviados.')
def editar_pc(pc_id: int, datos: PCEditar, con: sqlite3.Connection = Depends(get_db)):
    if not con.execute('SELECT 1 FROM equipos WHERE id = ?', (pc_id,)).fetchone():
        raise HTTPException(404, f'No existe la PC {pc_id}')
    cambios = datos.model_dump(exclude_unset=True)
    for campo in ('nombre', 'area_id', 'piso'):
        if campo in cambios and cambios[campo] is None:
            raise HTTPException(422, f'El campo {campo} no puede quedar vacío.')
    if 'area_id' in cambios:
        verificar_area(con, cambios['area_id'])

    if cambios:
        columnas = ', '.join(f'{c} = ?' for c in cambios)
        with con:
            try:
                con.execute(f'UPDATE equipos SET {columnas} WHERE id = ?', (*cambios.values(), pc_id))
            except sqlite3.IntegrityError:
                raise HTTPException(409, f'Ya existe la PC {cambios.get("nombre")}')
    return _a_dict(con.execute(f'{_SELECT} WHERE e.id = ?', (pc_id,)).fetchone())
