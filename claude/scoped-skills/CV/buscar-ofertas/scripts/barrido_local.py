#!/usr/bin/env python3
"""Barrido de ofertas presenciales, híbridas o remotas cerca de Ames (A Coruña): el triángulo
Santiago – A Coruña – Vigo y las ciudades de camino (Pontevedra, Padrón, Vilagarcía, Arteixo…).

Uso: python3 barrido_local.py [AAAA-MM-DD] [carpeta_salida]
Sin fecha, mira los últimos 30 días. Es independiente de barrido.py (que busca solo remoto) y NO escribe
en aplicaciones.md ni en ofertas_vistas.md: solo imprime. Sin filtro de salario, años, stack ni nivel;
solo de título (datos, backend, software, embedded/IoT) y de zona. Si una fuente falla, lo dice y sigue.

Fuentes probadas el 2026-10-27 y descartadas: Welcome to the Jungle por radio (solo NTT Data en A Coruña; el
radio trae ofertas de 100 % remoto con cientos de oficinas), Tecnoempleo (el filtro de provincia no se aplica
sin sesión), InfoJobs (solo con navegador; en A Coruña son soporte IT y poco desarrollo), Indeed y Jooble (con
navegador cargan, pero repiten LinkedIn y meten mucho ruido). Si LinkedIn deja de servir, empezar por Indeed.
"""
import html
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta, timezone

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
desde = date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] else date.today() - timedelta(days=30)
salida = sys.argv[2] if len(sys.argv) > 2 else "."
os.makedirs(salida, exist_ok=True)

CIUDADES = ("Santiago de Compostela", "A Coruña", "Vigo", "Pontevedra", "Vilagarcía de Arousa")
ZONA = re.compile(r"santiago|coru[ñn]a|vigo|pontevedra|vilagarc|padr[oó]n|arteixo|culleredo|cambre|oleiros|betanzos|"
                  r"carballo|\bames\b|bertamir|\bteo\b|oroso|ordes|caldas|redondela|porri[ñn]o|mar[ií]n|sanxenxo|"
                  r"cangas|moa[ñn]a|sada|bergondo|galicia|galiza", re.I)
CONSULTAS = ("data engineer", "analytics engineer", "ingeniero de datos", "backend developer", "python developer",
             "golang", "rust", "embedded", "firmware", "iot", "software engineer", "desarrollador software")
TITULO = re.compile(r"data|datos|analytics|\bbi\b|etl|dbt|back-?end|python|golang|\bgo\b|rust|embedded|embebido|firmware|"
                    r"\biot\b|c\+\+|software|developer|desarrollador|programador|ingenier|engineer|devops|platform|"
                    r"full-?stack|sistemas|plc|scada", re.I)


def baja(nombre, url, datos=None, cabeceras=None):
    h = {"User-Agent": UA, "Accept": "application/json, text/html"}
    h.update(cabeceras or {})
    req = urllib.request.Request(url, data=datos, headers=h)
    with urllib.request.urlopen(req, timeout=40) as r:
        s = r.read().decode("utf-8", "ignore")
    open(os.path.join(salida, nombre), "w", encoding="utf-8").write(s)
    return s


def dia(v):
    if isinstance(v, (int, float)):
        return datetime.fromtimestamp(v, timezone.utc).date()
    v = str(v)
    if re.match(r"\d{2}/\d{2}/\d{4}", v):
        return datetime.strptime(v[:10], "%d/%m/%Y").date()
    return date.fromisoformat(v[:10])


def linkedin():
    """Endpoint de invitados de LinkedIn, por ciudad y sin filtro de remoto. Se espacia por el límite de peticiones."""
    segundos = ((date.today() - desde).days + 1) * 86400
    for lugar in CIUDADES:
        for q in CONSULTAS:
            for start in (0, 10):
                url = ("https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?"
                       f"keywords={urllib.parse.quote(q)}&location={urllib.parse.quote(lugar + ', Galicia, Spain')}"
                       f"&distance=25&f_TPR=r{segundos}&start={start}")
                try:
                    s = baja(f"linkedin_{lugar[:4]}_{q[:5]}_{start}.html", url)
                except Exception:
                    break  # normalmente 429: se salta esta consulta
                time.sleep(1.5)
                bloques = s.split("<li>")[1:]
                for b in bloques:
                    g = lambda pat: (re.search(pat, b, re.S) or [None, ""])[1].strip()
                    enlace = g(r'href="([^"?]+)')
                    if enlace:
                        yield (g(r'datetime="([^"]+)"') or date.today().isoformat(),
                               html.unescape(g(r'base-search-card__subtitle.*?>\s*(?:<a[^>]*>)?\s*(.*?)\s*<')),
                               html.unescape(g(r'base-search-card__title[^>]*>(.*?)<')),
                               html.unescape(g(r'job-search-card__location[^>]*>(.*?)<')), None, enlace)
                if len(bloques) < 10:
                    break


FUENTES = [("LinkedIn (ciudades)", linkedin)]
vistos = set()
for nombre, fuente in FUENTES:
    n, filas = 0, []
    try:
        for fecha, empresa, titulo, lugar, salario, url in fuente():
            n += 1
            if not TITULO.search(titulo or "") or dia(fecha) < desde:
                continue
            if not ZONA.search(lugar or ""):
                continue
            clave = url.split("?")[0].lower()
            if clave in vistos:
                continue
            vistos.add(clave)
            filas.append(f"  {dia(fecha)} | {empresa} | {titulo} | {lugar} | {salario or 'salario no publicado'} | {url}")
    except Exception as e:  # una fuente rota no para el barrido
        print(f"== {nombre}: FALLO ({type(e).__name__}: {e})")
        continue
    print(f"== {nombre}: {len(filas)} candidatas de {n} ofertas leídas")
    print("\n".join(sorted(filas, reverse=True)))
