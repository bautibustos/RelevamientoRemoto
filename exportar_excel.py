"""Exporta la base de inventario a salida.xlsx respetando su formato.

Módulo independiente: no importa nada del resto del proyecto. Solo necesita
la base SQLite (la abre en modo solo lectura), openpyxl y la planilla base.

Toma salida.xlsx como plantilla: conserva la fila de encabezados con su formato,
los anchos de columna y la inmovilización, borra las filas de datos y las vuelve
a escribir desde la base. Las columnas se ubican por el texto del encabezado,
así que se pueden reordenar en el Excel sin tocar este archivo.

Uso por consola:
    python exportar_excel.py                       -> db/inventario.db -> salida.xlsx
    python exportar_excel.py otra_salida.xlsx      -> usa salida.xlsx como base y guarda en otro archivo
"""
import sqlite3
import sys
from pathlib import Path

from openpyxl import load_workbook

CARPETA = Path(__file__).resolve().parent
DB_POR_DEFECTO = CARPETA / 'db' / 'inventario.db'
PLANTILLA_POR_DEFECTO = CARPETA / 'salida.xlsx'
HOJA = 'Hoja1'

# Una fila por PC. Cada alias es el texto exacto del encabezado en la planilla.
CONSULTA = """
    SELECT
        e.nombre                                        AS "ID",
        e.piso                                          AS "Piso",
        a.nombre                                        AS "Area",
        e.so                                            AS "Sistema operativo",
        TRIM(CASE WHEN e.cpu_nombre LIKE '%Intel%' THEN 'Intel '
                  WHEN e.cpu_nombre LIKE '%AMD%'   THEN 'AMD '
                  ELSE '' END || COALESCE(e.cpu_familia, '')) AS "Procesador-Marca",
        e.cpu_modelo                                    AS "Procesador-Generacion",
        e.cpu_ghz                                       AS "Procesador-GHz",
        e.placa_fabricante                              AS "Mother-Marca",
        e.placa_modelo                                  AS "Mother-Modelo",
        e.video                                         AS "Video",
        e.ram_tipo                                      AS "RAM-Tecnologia",
        (SELECT SUM(capacidad_gb) FROM memorias m
          WHERE m.equipo_id = e.id)                     AS "RAM-Total",
        (SELECT GROUP_CONCAT(COALESCE(mhz, '?'), ' + ') FROM
           (SELECT mhz FROM memorias m WHERE m.equipo_id = e.id ORDER BY m.id)) AS "RAM-Mhz",
        (SELECT GROUP_CONCAT(printf('%g', capacidad_gb), ' + ') FROM
           (SELECT capacidad_gb FROM memorias m WHERE m.equipo_id = e.id ORDER BY m.id)) AS "RAM-Cant. Modulos",
        (SELECT ROUND(SUM(capacidad_gb), 2) FROM discos d
          WHERE d.equipo_id = e.id AND d.tecnologia = 'SSD')   AS "SSD",
        (SELECT GROUP_CONCAT(marca, ' / ') FROM discos d
          WHERE d.equipo_id = e.id AND d.tecnologia = 'SSD')   AS "Marca-SSD",
        (SELECT ROUND(SUM(capacidad_gb), 2) FROM discos d
          WHERE d.equipo_id = e.id AND d.tecnologia = 'HDD')   AS "HDD",
        (SELECT GROUP_CONCAT(marca, ' / ') FROM discos d
          WHERE d.equipo_id = e.id AND d.tecnologia = 'HDD')   AS "Marca-HDD",
        e.red                                           AS "RED",
        e.usuario                                       AS "Usuario",
        e.datos_crudos                                  AS "Crudo"
    FROM equipos e
    LEFT JOIN areas a ON a.id = e.area_id
    WHERE e.fecha_relevamiento IS NOT NULL   -- equipos relevados al menos una vez
    ORDER BY a.nombre, e.piso, e.nombre
"""


def _abrir_solo_lectura(ruta_db):
    ruta_db = Path(ruta_db)
    if not ruta_db.exists():
        raise FileNotFoundError(f'No existe la base: {ruta_db}')
    return sqlite3.connect(f'{ruta_db.as_uri()}?mode=ro', uri=True)


def exportar(ruta_db=DB_POR_DEFECTO, ruta_salida=PLANTILLA_POR_DEFECTO, plantilla=PLANTILLA_POR_DEFECTO):
    """Vuelca la base en la planilla. Devuelve la cantidad de equipos exportados."""
    plantilla = Path(plantilla)
    if not plantilla.exists():
        raise FileNotFoundError(f'No existe la planilla base: {plantilla}')

    con = _abrir_solo_lectura(ruta_db)
    try:
        cursor = con.execute(CONSULTA)
        columnas = [c[0] for c in cursor.description]
        filas = cursor.fetchall()
    finally:
        con.close()

    libro = load_workbook(plantilla)
    hoja = libro[HOJA]

    # columna de la planilla para cada encabezado (las que no están en la consulta quedan vacías)
    posicion = {str(c.value).strip(): c.column for c in hoja[1] if c.value is not None}
    destino = [(i, posicion[nombre]) for i, nombre in enumerate(columnas) if nombre in posicion]

    if hoja.max_row > 1:
        hoja.delete_rows(2, hoja.max_row - 1)

    for n, fila in enumerate(filas, start=2):
        for i, columna in destino:
            hoja.cell(row=n, column=columna, value=fila[i])

    try:
        libro.save(ruta_salida)
    except PermissionError:
        raise PermissionError(
            f'No se pudo guardar {ruta_salida}: probablemente esté abierto en Excel. Cerralo y volvé a intentar.'
        ) from None
    return len(filas)


if __name__ == '__main__':
    salida = sys.argv[1] if len(sys.argv) > 1 else PLANTILLA_POR_DEFECTO
    try:
        cantidad = exportar(DB_POR_DEFECTO, salida)
    except (FileNotFoundError, PermissionError) as e:
        sys.exit(str(e))
    print(f'Exportados {cantidad} equipos a {salida}')
