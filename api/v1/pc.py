"""Recurso PC. No depende del módulo de monitores."""
import sqlite3
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator

from api.database import get_db
from api import relevamiento
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
    red: str | None = Field(None, max_length=50, description='Opcional. Red o segmento del equipo.')

    @field_validator('nombre', mode='before')
    @classmethod
    def _nombre(cls, v):
        return _validar_nombre(v)

    @field_validator('piso', 'red', mode='before')
    @classmethod
    def _piso(cls, v):
        return limpiar(v)


RamTipo = Literal['DDR1', 'DDR2', 'DDR3', 'DDR4', 'DDR5']
Tecnologia = Literal['SSD', 'HDD', 'desconocido']
Bus = Literal['NVMe', 'SATA', 'ATA', 'SAS', 'SCSI', 'RAID', 'otro']


class MemoriaEditar(BaseModel):
    capacidad_gb: float = Field(gt=0, le=1024, examples=[16])
    mhz: int | None = Field(None, gt=0, le=20000, examples=[2666])


class DiscoEditar(BaseModel):
    marca: str | None = Field(None, max_length=50, examples=['Kingston'])
    tecnologia: Tecnologia = 'desconocido'
    bus: Bus | None = None
    capacidad_gb: float | None = Field(None, gt=0, examples=[480])

    @field_validator('marca', mode='before')
    @classmethod
    def _marca(cls, v):
        return limpiar(v)


# campos de texto o número que se copian tal cual a la tabla equipos
_EDITABLES_TEXTO = ('so', 'usuario', 'cpu_familia', 'cpu_modelo', 'placa_fabricante', 'placa_modelo', 'video', 'red')


class PCEditar(BaseModel):
    """Solo se modifican los campos enviados. Para corregir a mano lo que el relevamiento no trajo o trajo mal.

    `memorias` y `discos`, si se envían, reemplazan la lista completa ([] la deja vacía).
    """
    nombre: str = Field(None, min_length=1, max_length=50)
    area_id: int = Field(None, gt=0)
    piso: str = Field(None, min_length=1, max_length=20)
    red: str | None = Field(None, max_length=50)
    so: str | None = Field(None, max_length=100)
    usuario: str | None = Field(None, max_length=100)
    cpu_familia: str | None = Field(None, max_length=50)
    cpu_modelo: str | None = Field(None, max_length=50)
    cpu_ghz: float | None = Field(None, gt=0, le=10)
    placa_fabricante: str | None = Field(None, max_length=100)
    placa_modelo: str | None = Field(None, max_length=100)
    video: str | None = Field(None, max_length=150)
    ram_tipo: RamTipo | None = None
    memorias: list[MemoriaEditar] = Field(None, max_length=16)
    discos: list[DiscoEditar] = Field(None, max_length=16)

    @field_validator('nombre', mode='before')
    @classmethod
    def _nombre(cls, v):
        return _validar_nombre(v)

    @field_validator('piso', *_EDITABLES_TEXTO, mode='before')
    @classmethod
    def _texto(cls, v):
        return limpiar(v)


class Ping(BaseModel):
    responde: bool
    detalle: str


class Disco(BaseModel):
    id: int
    marca: str | None
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
    ram_total_gb: float | None = Field(description='Suma de los módulos de RAM')
    ram_modulos: int = Field(description='Cantidad de módulos de RAM')


class Memoria(BaseModel):
    id: int
    capacidad_gb: float
    mhz: int | None


class PCDetalle(PC):
    memorias: list[Memoria]
    discos: list[Disco]


class PCCreada(PC):
    ping: Ping


class Relevamiento(BaseModel):
    ok: bool
    detalle: str


class Prueba(BaseModel):
    ok: bool
    detalle: str


class PruebaConexion(BaseModel):
    ping: Prueba
    wmi: Prueba | None = Field(description='Vacío si el ping falló (no se intenta WMI).')


class PCRelevada(PCDetalle):
    relevamiento: Relevamiento


# ---------------------------------------------------------------- consultas
_CAMPOS = (
    'id', 'nombre', 'piso', 'red', 'estado', 'ultimo_error', 'fecha_relevamiento', 'so', 'usuario',
    'cpu_nombre', 'cpu_familia', 'cpu_modelo', 'cpu_ghz', 'placa_fabricante', 'placa_modelo', 'video',
    'ram_tipo',
)
_SELECT = f"""
    SELECT {', '.join('e.' + c for c in _CAMPOS)}, a.id AS area_id, a.nombre AS area_nombre,
           (SELECT SUM(m.capacidad_gb) FROM memorias m WHERE m.equipo_id = e.id) AS ram_total_gb,
           (SELECT COUNT(*) FROM memorias m WHERE m.equipo_id = e.id) AS ram_modulos
    FROM equipos e LEFT JOIN areas a ON a.id = e.area_id
"""


def _a_dict(fila):
    pc = {c: fila[c] for c in (*_CAMPOS, 'ram_total_gb', 'ram_modulos')}
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


@router.get('/{pc_id}', response_model=PCDetalle, summary='Ver una PC con sus módulos de RAM y discos')
def ver_pc(pc_id: int, con: sqlite3.Connection = Depends(get_db)):
    fila = con.execute(f'{_SELECT} WHERE e.id = ?', (pc_id,)).fetchone()
    if not fila:
        raise HTTPException(404, f'No existe la PC {pc_id}')
    pc = _a_dict(fila)
    pc['memorias'] = [dict(m) for m in con.execute(
        'SELECT id, capacidad_gb, mhz FROM memorias WHERE equipo_id = ? ORDER BY capacidad_gb DESC, id', (pc_id,),
    )]
    pc['discos'] = [dict(d) for d in con.execute(
        'SELECT id, marca, tecnologia, bus, capacidad_gb FROM discos WHERE equipo_id = ? ORDER BY id',
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
                'INSERT INTO equipos (nombre, piso, area_id, red) VALUES (?,?,?,?)',
                (datos.nombre, datos.piso, datos.area_id, datos.red),
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


@router.patch('/{pc_id}', response_model=PCDetalle, summary='Editar una PC',
              description='Modifica ubicación y hardware. Solo cambia los campos enviados; '
                          '"memorias" y "discos" reemplazan la lista completa. Devuelve la PC con sus módulos y discos.')
def editar_pc(pc_id: int, datos: PCEditar, con: sqlite3.Connection = Depends(get_db)):
    if not con.execute('SELECT 1 FROM equipos WHERE id = ?', (pc_id,)).fetchone():
        raise HTTPException(404, f'No existe la PC {pc_id}')
    cambios = datos.model_dump(exclude_unset=True)
    for campo in ('nombre', 'area_id', 'piso', 'memorias', 'discos'):
        if campo in cambios and cambios[campo] is None:
            raise HTTPException(422, f'El campo {campo} no puede quedar vacío.')
    if 'area_id' in cambios:
        verificar_area(con, cambios['area_id'])
    memorias = cambios.pop('memorias', None)
    discos = cambios.pop('discos', None)

    with con:
        if cambios:
            columnas = ', '.join(f'{c} = ?' for c in cambios)
            try:
                con.execute(f'UPDATE equipos SET {columnas} WHERE id = ?', (*cambios.values(), pc_id))
            except sqlite3.IntegrityError:
                raise HTTPException(409, f'Ya existe la PC {cambios.get("nombre")}')
        if memorias is not None:
            con.execute('DELETE FROM memorias WHERE equipo_id = ?', (pc_id,))
            con.executemany('INSERT INTO memorias (equipo_id, capacidad_gb, mhz) VALUES (?,?,?)',
                            [(pc_id, m['capacidad_gb'], m['mhz']) for m in memorias])
        if discos is not None:
            con.execute('DELETE FROM discos WHERE equipo_id = ?', (pc_id,))
            con.executemany('INSERT INTO discos (equipo_id, marca, tecnologia, bus, capacidad_gb) VALUES (?,?,?,?,?)',
                            [(pc_id, d['marca'], d['tecnologia'], d['bus'], d['capacidad_gb']) for d in discos])
    return ver_pc(pc_id, con)


@router.post('/{pc_id}/relevar', response_model=PCRelevada, summary='Volver a relevar una PC',
             description='Hace ping al equipo y, si responde, consulta su hardware por WMI y lo guarda '
                         '(reemplaza módulos de RAM y discos). Si falla, la PC queda "sin_respuesta" o "error" '
                         'y conserva el último hardware conocido. Puede tardar hasta un minuto.')
def relevar_pc(pc_id: int, con: sqlite3.Connection = Depends(get_db)):
    fila = con.execute(
        'SELECT e.nombre, e.piso, e.red, a.nombre AS area FROM equipos e '
        'LEFT JOIN areas a ON a.id = e.area_id WHERE e.id = ?', (pc_id,),
    ).fetchone()
    if not fila:
        raise HTTPException(404, f'No existe la PC {pc_id}')
    nombre, piso, red, area = fila['nombre'], fila['piso'], fila['red'], fila['area']

    ping = hacer_ping(nombre)
    if not ping.responde:
        relevamiento.registrar_fallo(nombre, piso, area, red, 'sin_respuesta', ping.detalle)
        resultado = {'ok': False, 'detalle': ping.detalle or 'No respondió al ping.'}
    else:
        try:
            info = relevamiento.relevar(nombre)
        except Exception as e:  # WMI puede fallar de muchas formas (acceso, RPC, timeouts)
            detalle = relevamiento.mensaje_de_error(e)
            relevamiento.registrar_fallo(nombre, piso, area, red, 'error', detalle)
            resultado = {'ok': False, 'detalle': f'No se pudo consultar el hardware: {detalle}'}
        else:
            relevamiento.guardar(nombre, piso, area, red, info)
            resultado = {'ok': True, 'detalle': 'Hardware actualizado desde el equipo.'}

    pc = ver_pc(pc_id, con)
    pc['relevamiento'] = resultado
    return pc


@router.post('/{pc_id}/probar', response_model=PruebaConexion, summary='Probar ping y WMI',
             description='Hace ping al equipo y, si responde, una conexión corta por WMI. '
                         'No guarda nada ni cambia el estado: es solo un diagnóstico. '
                         'Para actualizar el hardware usar POST /pc/{id}/relevar.')
def probar_pc(pc_id: int, con: sqlite3.Connection = Depends(get_db)):
    fila = con.execute('SELECT nombre FROM equipos WHERE id = ?', (pc_id,)).fetchone()
    if not fila:
        raise HTTPException(404, f'No existe la PC {pc_id}')
    ping = hacer_ping(fila['nombre'])
    resultado = {'ping': {'ok': ping.responde, 'detalle': ping.detalle}, 'wmi': None}
    if ping.responde:
        ok, detalle = relevamiento.probar_wmi(fila['nombre'])
        resultado['wmi'] = {'ok': ok, 'detalle': detalle}
    return resultado
