"""Acceso a la base db/inventario.db.

Funciones principales:
    guardar_relevamiento(nombre, piso, area, red, info)  -> PC relevada OK
    registrar_fallo(nombre, piso, area, red, estado, error) -> sin respuesta / error
    equipos_a_reintentar()                              -> reemplaza a no-listadas.txt
"""
import json
import re
from datetime import datetime

from . import crear_db
from .marcas import marca_disco

# Se puede cambiar (por ejemplo en pruebas) para apuntar a otra base.
RUTA_DB = crear_db.RUTA_DB


# Bases ya creadas/migradas en este proceso: crear_db corre una sola vez por ruta,
# no en cada conexión (RUTA_DB puede cambiar, por eso se recuerda por ruta).
_bases_listas = set()


def conectar():
    ruta = str(RUTA_DB)
    if ruta not in _bases_listas:
        crear_db.crear_db(RUTA_DB)  # asegura que las tablas existan
        _bases_listas.add(ruta)
    return crear_db.conectar(RUTA_DB)


def _ahora():
    return datetime.now().strftime('%Y-%m-%d %H:%M:%S')


def obtener_area_id(con, nombre_area):
    if not nombre_area:
        return None
    con.execute('INSERT OR IGNORE INTO areas (nombre) VALUES (?)', (nombre_area,))
    return con.execute('SELECT id FROM areas WHERE nombre = ?', (nombre_area,)).fetchone()[0]


def parsear_cpu(cpu, mhz=None):
    """Devuelve (nombre, familia, modelo, ghz) a partir del nombre de WMI.

    cpu puede venir como lista de palabras (formato de remote_check) o texto.
    """
    nombre = ' '.join(cpu) if isinstance(cpu, (list, tuple)) else (cpu or '')
    nombre = ' '.join(nombre.split()) or None
    familia = modelo = None
    texto = nombre or ''

    m = re.search(r'\b(i[3579])-(\w+)', texto)                      # Intel Core iX-XXXX
    if m:
        familia, modelo = f'Core {m.group(1)}', m.group(0)
    else:
        m = re.search(r'Core\(TM\)\s+Ultra\s+(\d)\s+(\w+)', texto)  # Intel Core Ultra
        if m:
            familia, modelo = f'Core Ultra {m.group(1)}', m.group(2)
        else:
            m = re.search(r'(Ryzen\s+\d+)\s+(?:PRO\s+)?(\w+)', texto)  # AMD Ryzen
            if m:
                familia, modelo = m.group(1), m.group(2)
            else:
                m = re.search(r'(Celeron|Pentium|Xeon|Athlon)\S*\s+(?:CPU\s+)?([\w-]+)?', texto)
                if m:
                    familia, modelo = m.group(1), m.group(2)

    ghz = None
    m = re.search(r'([\d.]+)\s*GHz', texto)
    if m:
        ghz = float(m.group(1))
    elif mhz:
        ghz = round(int(mhz) / 1000, 2)
    return nombre, familia, modelo, ghz


def _entero(valor):
    try:
        return int(valor)
    except (TypeError, ValueError):
        return None


def guardar_relevamiento(nombre, piso, area, red, info):
    """Inserta o actualiza la PC con los datos de remote_check.ejecutor()."""
    cpu_nombre, cpu_familia, cpu_modelo, cpu_ghz = parsear_cpu(info.get('cpu'), info.get('cpu_mhz'))
    placa = info.get('placa') or (None, None)
    memoria = info.get('memoria') or {}
    modulos = memoria.get('capacidad') or []

    con = conectar()
    try:
        with con:
            area_id = obtener_area_id(con, area)
            con.execute(
                """
                INSERT INTO equipos (
                    nombre, piso, area_id, red, so, usuario,
                    cpu_nombre, cpu_familia, cpu_modelo, cpu_ghz,
                    placa_fabricante, placa_modelo, video,
                    ram_tipo,
                    estado, ultimo_error, fecha_relevamiento, datos_crudos
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,'ok',NULL,?,?)
                ON CONFLICT(nombre) DO UPDATE SET
                    piso=excluded.piso, area_id=excluded.area_id, red=excluded.red,
                    so=excluded.so, usuario=excluded.usuario,
                    cpu_nombre=excluded.cpu_nombre, cpu_familia=excluded.cpu_familia,
                    cpu_modelo=excluded.cpu_modelo, cpu_ghz=excluded.cpu_ghz,
                    placa_fabricante=excluded.placa_fabricante, placa_modelo=excluded.placa_modelo,
                    video=excluded.video,
                    ram_tipo=excluded.ram_tipo,
                    estado='ok', ultimo_error=NULL,
                    fecha_relevamiento=excluded.fecha_relevamiento,
                    datos_crudos=excluded.datos_crudos
                """,
                (
                    nombre, piso, area_id, red, info.get('so'), info.get('Usuario'),
                    cpu_nombre, cpu_familia, cpu_modelo, cpu_ghz,
                    placa[0], placa[1], info.get('video'),
                    memoria.get('ddr'),
                    _ahora(), json.dumps(info, ensure_ascii=False, default=str),
                ),
            )
            equipo_id = con.execute('SELECT id FROM equipos WHERE nombre = ?', (nombre,)).fetchone()[0]

            # módulos de RAM y discos se reemplazan por los del último relevamiento
            con.execute('DELETE FROM memorias WHERE equipo_id = ?', (equipo_id,))
            # relevamientos anteriores no traen mhz_modulos: se usa el MHz general para todos
            mhz_modulos = memoria.get('mhz_modulos') or [memoria.get('mhz')] * len(modulos)
            for capacidad, mhz in zip(modulos, mhz_modulos):
                try:
                    capacidad = float(capacidad)
                except (TypeError, ValueError):
                    continue
                mhz = _entero(mhz)
                if capacidad > 0:
                    con.execute('INSERT INTO memorias (equipo_id, capacidad_gb, mhz) VALUES (?,?,?)',
                                (equipo_id, capacidad, mhz if mhz and mhz > 0 else None))

            con.execute('DELETE FROM discos WHERE equipo_id = ?', (equipo_id,))
            for disco in info.get('disco') or []:
                if disco.get('bus') == 'USB':
                    continue
                tecnologia = disco.get('tecnologia')
                con.execute(
                    'INSERT INTO discos (equipo_id, marca, tecnologia, bus, capacidad_gb) VALUES (?,?,?,?,?)',
                    (
                        equipo_id, marca_disco(disco.get('marca')),
                        tecnologia if tecnologia in ('SSD', 'HDD') else 'desconocido',
                        disco.get('bus'), disco.get('capacidad'),
                    ),
                )
        return equipo_id
    finally:
        con.close()


def registrar_fallo(nombre, piso, area, red, estado, error=None):
    """Marca la PC como 'sin_respuesta' o 'error' sin borrar su último hardware conocido."""
    con = conectar()
    try:
        with con:
            area_id = obtener_area_id(con, area)
            con.execute(
                """
                INSERT INTO equipos (nombre, piso, area_id, red, estado, ultimo_error)
                VALUES (?,?,?,?,?,?)
                ON CONFLICT(nombre) DO UPDATE SET
                    piso=excluded.piso, area_id=excluded.area_id, red=excluded.red,
                    estado=excluded.estado, ultimo_error=excluded.ultimo_error
                """,
                (nombre, piso, area_id, red, estado, error),
            )
    finally:
        con.close()


def registrar_equipo(nombre, piso, area, red):
    """Da de alta la PC con estado 'pendiente'. Si ya existe, solo actualiza su ubicación."""
    con = conectar()
    try:
        with con:
            area_id = obtener_area_id(con, area)
            con.execute(
                """
                INSERT INTO equipos (nombre, piso, area_id, red) VALUES (?,?,?,?)
                ON CONFLICT(nombre) DO UPDATE SET
                    piso=excluded.piso, area_id=excluded.area_id, red=excluded.red
                """,
                (nombre, piso, area_id, red),
            )
    finally:
        con.close()


def equipos_a_reintentar():
    """Lista de (nombre, piso, area, red) con estado sin_respuesta o error."""
    con = conectar()
    try:
        return con.execute(
            """
            SELECT e.nombre, e.piso, a.nombre, e.red
            FROM equipos e LEFT JOIN areas a ON a.id = e.area_id
            WHERE e.estado IN ('sin_respuesta', 'error')
            ORDER BY e.nombre
            """
        ).fetchall()
    finally:
        con.close()
