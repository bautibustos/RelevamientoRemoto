"""Configuración leída del .env (o de variables de entorno ya definidas, que tienen prioridad).

Variables:
    WMI_USUARIO / WMI_PASSWORD  credenciales para WMI (vacías = sesión actual de Windows)
    INVENTARIO_DB               ruta de la base; puede ser una carpeta compartida
                                (ej. \\\\SERVIDOR01\\d$\\inv\\db\\inventario.db). Vacía = db/inventario.db
    MODO_API                    'normal' (por defecto): la API hace ping y releva por WMI.
                                'carga': la API solo guarda; el ping y el relevamiento los hace
                                un validador que corre dentro de la red.
    VALIDADOR                   1 = la API arranca también el validador en segundo plano.
    VALIDADOR_INTERVALO         segundos entre búsquedas de PCs pendientes (por defecto 5).
"""
import os
from pathlib import Path

RUTA_ENV = Path(__file__).with_name('.env')


def cargar_env(ruta=RUTA_ENV):
    """Carga KEY=VALOR del .env en os.environ (sin pisar variables ya definidas)."""
    if not ruta.exists():
        return
    for linea in ruta.read_text(encoding='utf-8').splitlines():
        linea = linea.strip()
        if linea and not linea.startswith('#') and '=' in linea:
            clave, valor = linea.split('=', 1)
            valor = valor.strip()
            # Solo se quitan comillas si envuelven el valor completo ("..." o '...'):
            # una comilla que forma parte de la contraseña se respeta.
            if len(valor) >= 2 and valor[0] == valor[-1] and valor[0] in '"\'':
                valor = valor[1:-1]
            os.environ.setdefault(clave.strip(), valor)


cargar_env()


def ruta_db(por_defecto):
    """Ruta de la base: INVENTARIO_DB si está definida, si no la indicada."""
    return Path(os.environ.get('INVENTARIO_DB') or por_defecto)


def modo_api():
    modo = os.environ.get('MODO_API', 'normal').strip().lower()
    return modo if modo in ('normal', 'carga') else 'normal'


def validador_activo():
    return os.environ.get('VALIDADOR', '').strip().lower() in ('1', 'si', 'sí', 'true')


def validador_intervalo():
    try:
        return max(1.0, float(os.environ.get('VALIDADOR_INTERVALO', '5')))
    except ValueError:
        return 5.0
