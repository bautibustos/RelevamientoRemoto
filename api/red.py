"""Consulta de red para la API: ping a un equipo por nombre o IP."""
import platform
import re
import subprocess
from dataclasses import dataclass

# Nombre de equipo o IP: letras, números, punto, guion y guion bajo; no puede empezar con guion
# (así nunca se interpreta como una opción del comando ping).
NOMBRE_VALIDO = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]*$')


@dataclass
class ResultadoPing:
    responde: bool
    detalle: str


def hacer_ping(nombre: str, espera_ms: int = 1000) -> ResultadoPing:
    """Un solo ping. No lanza excepciones: cualquier problema se informa en el resultado."""
    if not NOMBRE_VALIDO.match(nombre):
        return ResultadoPing(False, 'Nombre de equipo inválido para hacer ping.')

    if platform.system() == 'Windows':
        # -4: las respuestas IPv6 de Windows no traen "TTL=", que es lo que confirma la respuesta
        comando = ['ping', '-4', '-n', '1', '-w', str(espera_ms), nombre]
    else:
        comando = ['ping', '-c', '1', '-W', str(max(1, espera_ms // 1000)), nombre]

    try:
        r = subprocess.run(comando, capture_output=True, text=True, timeout=espera_ms / 1000 + 5)
    except subprocess.TimeoutExpired:
        return ResultadoPing(False, 'El ping no terminó a tiempo.')
    except OSError as e:
        return ResultadoPing(False, f'No se pudo ejecutar ping: {e}')

    # En Windows, "Host de destino inaccesible" devuelve código 0: se confirma con el TTL de la respuesta.
    if r.returncode == 0 and 'TTL=' in r.stdout.upper():
        return ResultadoPing(True, 'Respondió al ping.')
    return ResultadoPing(False, 'No responde al ping.')
