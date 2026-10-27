#!/usr/bin/env python3
"""Dice si han pasado 72 h desde la última búsqueda apuntada en ofertas_vistas.md.

Uso: python3 puede_buscar.py [ruta/a/ofertas_vistas.md]
Sale con 0 y escribe "OK ..." si se puede buscar; sale con 1 y escribe "ESPERA ..." si no.
Lee la línea "Última búsqueda: AAAA-MM-DD HH:MM" (hora local). Si solo hay fecha, cuenta desde las 00:00.
"""
import re
import sys
from datetime import datetime, timedelta

ruta = sys.argv[1] if len(sys.argv) > 1 else "ofertas_vistas.md"
texto = open(ruta, encoding="utf-8").read()
m = re.search(r"Última búsqueda:\s*(\d{4}-\d{2}-\d{2})(?:[ T](\d{2}:\d{2}))?", texto)
if not m:
    print("OK: no hay última búsqueda apuntada")
    sys.exit(0)

ultima = datetime.fromisoformat(f"{m.group(1)} {m.group(2) or '00:00'}")
siguiente = ultima + timedelta(hours=72)
ahora = datetime.now()
if ahora >= siguiente:
    print(f"OK: última búsqueda {ultima:%Y-%m-%d %H:%M}, hace {(ahora - ultima) // timedelta(hours=1)} h")
    sys.exit(0)

falta = siguiente - ahora
h, resto = divmod(int(falta.total_seconds()), 3600)
print(f"ESPERA: última búsqueda {ultima:%Y-%m-%d %H:%M}; la siguiente se puede hacer a partir de {siguiente:%Y-%m-%d %H:%M} (faltan {h} h {resto // 60} min)")
sys.exit(1)
