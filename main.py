import os
import subprocess

import remote_check
from db import db_manager

CARPETA = 'files'
IGNORAR = {'no-listadas.txt'}


def leer_ubicacion(nombre_archivo):
    """'6 - Administración - GOB.txt' -> ('6', 'Administración', 'GOB')"""
    base = nombre_archivo[:-4] if nombre_archivo.lower().endswith('.txt') else nombre_archivo
    partes = [p.strip() for p in base.split(' - ')]
    piso, area, red = (partes + [None, None, None])[:3]
    return piso, area, red


def leer_equipos(ruta):
    with open(ruta, 'r', encoding='utf-8') as f:
        return [linea.strip() for linea in f if linea.strip()]


def responde(nombre_equipo):
    ping = subprocess.run(
        ['ping', '-n', '1', '-w', '1000', nombre_equipo], capture_output=True, text=True
    )
    return ping.returncode == 0


def relevar(nombre_equipo, piso, area, red):
    """Releva una PC y la guarda en la base. Devuelve True si se relevó."""
    print(f'{nombre_equipo} ({piso} / {area} / {red})')
    if not responde(nombre_equipo):
        db_manager.registrar_fallo(nombre_equipo, piso, area, red, 'sin_respuesta', 'No responde al ping')
        print('  sin respuesta')
        return False

    try:
        caracteristicas = remote_check.ejecutor(nombre_equipo)
    except Exception as e:
        db_manager.registrar_fallo(nombre_equipo, piso, area, red, 'error', str(e))
        print(f'  error: {e}')
        return False

    db_manager.guardar_relevamiento(nombre_equipo, piso, area, red, caracteristicas)
    print('  guardado en la base')
    return True


def listadas():
    for nombre_archivo in sorted(os.listdir(CARPETA)):
        ruta = os.path.join(CARPETA, nombre_archivo)
        if not os.path.isfile(ruta) or nombre_archivo in IGNORAR:
            continue
        piso, area, red = leer_ubicacion(nombre_archivo)
        for nombre_equipo in leer_equipos(ruta):
            relevar(nombre_equipo, piso, area, red)


def no_listadas():
    for nombre_equipo, piso, area, red in db_manager.equipos_a_reintentar():
        relevar(nombre_equipo, piso, area, red)


def main(ejecutar=0):
    if ejecutar == 0:
        listadas()
    else:
        no_listadas()
    print('\nPara generar el Excel: python exportar_excel.py')


if __name__ == '__main__':
    main(int(input('0 = relevar archivos de files/, 1 = reintentar los que fallaron: ')))
