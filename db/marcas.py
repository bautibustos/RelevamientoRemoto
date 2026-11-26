"""Deduce la marca de un disco a partir del modelo que informa WMI.

WMI devuelve un solo texto con marca y modelo juntos (ej. "KINGSTON SA400S37480G",
"ST1000DM010-2EP102", "WDC WD10EZEX-08WN4A0"). Muchos fabricantes no ponen su nombre
y solo se reconocen por el prefijo del modelo.
"""
import re

# (expresión regular sobre el modelo en mayúsculas, marca)
_PATRONES = [
    (r'^ST\d', 'Seagate'),
    (r'^(WDC\b|WD[\s\d])', 'Western Digital'),
    (r'^(HGST|HTS\d|HDS\d|HUS\d)', 'HGST'),
    (r'^HITACHI', 'Hitachi'),
    (r'^(SAMSUNG|MZ[-\w]{2})', 'Samsung'),
    (r'^(KINGSTON|SA400|SUV\d|SKC\d|SNV\d|SV300|SEDC)', 'Kingston'),
    (r'^(CRUCIAL|CT\d)', 'Crucial'),
    (r'^(MICRON|MTFD)', 'Micron'),
    (r'^(KIOXIA|KBG\d|KXG\d)', 'Kioxia'),
    (r'^(TOSHIBA|THNS|MQ\d|DT01)', 'Toshiba'),
    (r'^SANDISK', 'SanDisk'),
    (r'^INTEL', 'Intel'),
    (r'^(SK ?HYNIX|HFS\d|HFM\d)', 'SK hynix'),
    (r'^(ADATA|XPG)', 'ADATA'),
    (r'^(SPCC|SILICON POWER)', 'Silicon Power'),
    (r'^(LITE-?ON|LITEON)', 'Lite-On'),
    (r'^MAXTOR', 'Maxtor'),
    (r'^PNY', 'PNY'),
    (r'^LEXAR', 'Lexar'),
    (r'^PATRIOT', 'Patriot'),
    (r'^(TEAM|T-FORCE)', 'Team Group'),
    (r'^NETAC', 'Netac'),
    (r'^HIKVISION', 'Hikvision'),
    (r'^GIGABYTE', 'Gigabyte'),
    (r'^APACER', 'Apacer'),
    (r'^HP\b', 'HP'),
]


def marca_disco(modelo):
    """'KINGSTON SA400S37480G' -> 'Kingston'. Si no se reconoce, la primera palabra del modelo."""
    if not modelo or not str(modelo).strip():
        return None
    texto = ' '.join(str(modelo).split())
    mayus = texto.upper()
    for patron, marca in _PATRONES:
        if re.match(patron, mayus):
            return marca
    # sin marca reconocida: la primera palabra que no sea genérica ("NVMe", "SSD"...)
    palabras = [p for p in texto.split() if p.upper() not in {'NVME', 'SSD', 'HDD', 'SATA', 'M.2', 'PCIE'}]
    return palabras[0] if palabras else None
