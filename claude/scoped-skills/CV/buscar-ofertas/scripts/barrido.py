#!/usr/bin/env python3
"""Barrido rápido de las fuentes con API o HTML estático.

Uso: python3 barrido.py AAAA-MM-DD [carpeta_salida]
Imprime las ofertas de datos publicadas desde esa fecha (con un día de margen) que se pueden hacer
desde España, fuente por fuente. Si una fuente falla, lo dice y sigue. No decide nada: el
filtrado fino (consultoras, años, stack) lo hace la skill al abrir cada oferta.
Las respuestas en bruto se guardan en carpeta_salida (por defecto, el directorio actual).
"""
import html
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta, timezone

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
TITULO = re.compile(r"data (platform |integration |infrastructure )?engineer|analytics engineer|\bdbt\b|\betl\b|"
                    r"(software|backend|python) engineer.{0,12}data|data.{0,12}(backend|python) engineer|"
                    r"back-?end|python (developer|engineer)|golang|\bgo (developer|engineer)|"
                    r"(software|platform|integrations?) engineer", re.I)
GEO = re.compile(r"spain|españa|europe|\beu\b|emea|\bcet\b|worldwide|anywhere|global|barcelona|madrid", re.I)

desde = date.fromisoformat(sys.argv[1]) - timedelta(days=1)
salida = sys.argv[2] if len(sys.argv) > 2 else "."
os.makedirs(salida, exist_ok=True)


def baja(nombre, url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json, text/html"})
    for intento in (1, 2):  # un reintento: WWR y otras dan timeouts sueltos
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                datos = r.read().decode("utf-8", "ignore")
            break
        except TimeoutError:
            if intento == 2:
                raise
    open(os.path.join(salida, nombre), "w", encoding="utf-8").write(datos)
    return datos


def dia(valor):
    if isinstance(valor, (int, float)):
        return datetime.fromtimestamp(valor, timezone.utc).date()
    valor = str(valor)
    if re.match(r"\d{2}/\d{2}/\d{4}", valor):
        return datetime.strptime(valor[:10], "%d/%m/%Y").date()
    return date.fromisoformat(valor[:10])


def remotive():
    for j in json.loads(baja("remotive.json", "https://remotive.com/api/remote-jobs?category=data&limit=300"))["jobs"]:
        yield j["publication_date"], j["company_name"], j["title"], j["candidate_required_location"], j.get("salary"), j["url"]


def remoteok():
    for j in json.loads(baja("remoteok.json", "https://remoteok.com/api"))[1:]:
        sal = f"${j['salary_min']}–{j['salary_max']}" if j.get("salary_max") else None
        yield j["date"], j["company"], j["position"], j.get("location") or "", sal, j["url"]


def workingnomads():
    for j in json.loads(baja("workingnomads.json", "https://www.workingnomads.com/api/exposed_jobs/")):
        yield j["pub_date"], j["company_name"], j["title"], j.get("location") or "", None, j["url"]


def arbeitnow():
    for p in (1, 2, 3):
        for j in json.loads(baja(f"arbeitnow_{p}.json", f"https://www.arbeitnow.com/api/job-board-api?page={p}"))["data"]:
            if j["remote"]:
                yield j["created_at"], j["company_name"], j["title"], j["location"], None, j["url"]


def landing():
    for off in (0, 50, 100):
        for j in json.loads(baja(f"landing_{off}.json", f"https://landing.jobs/api/v1/jobs?limit=50&offset={off}")):
            if j.get("remote"):
                empresa = re.search(r"/at/([^/]+)/", j["url"])
                sal = f"{j.get('gross_salary_low')}–{j.get('gross_salary_high')} {j.get('currency_code')}" if j.get("gross_salary_high") else None
                yield j["published_at"], empresa.group(1) if empresa else "?", j["title"], "remote (Landing.jobs)", sal, j["url"]


def himalayas():
    for q in ("data%20engineer", "analytics%20engineer", "backend%20engineer", "python%20engineer"):
        for pag in (1, 2, 3):  # la búsqueda pagina con page=; offset= se ignora y repite la página 1
            d = json.loads(baja(f"him_{q[:4]}_{pag}.json",
                                f"https://himalayas.app/jobs/api/search?q={q}&country=Spain&sort=recent&page={pag}"))
            for j in d["jobs"]:
                lr = j["locationRestrictions"]
                if lr and "Spain" not in lr:
                    continue
                sal = f"{j['minSalary']}–{j['maxSalary']} {j['currency']}/{j['salaryPeriod']}" if j.get("maxSalary") else None
                yield j["pubDate"], j["companyName"], j["title"], "Spain" if lr else "worldwide", sal, j["applicationLink"]
            if d["jobs"] and dia(d["jobs"][-1]["pubDate"]) < desde:
                break


def workable():
    for q in ("data%20engineer", "analytics%20engineer", "dbt", "backend%20engineer", "python%20engineer"):
        for j in json.loads(baja(f"wk_{q[:4]}.json",
                                 f"https://jobs.workable.com/api/v1/jobs?query={q}&location=Spain&workplace=remote"))["jobs"]:
            yield j["created"], j["company"]["title"], j["title"], "remote Spain", None, j["url"]


def remoterocketship():
    s = baja("rocketship.html", "https://www.remoterocketship.com/country/spain/jobs/data-engineer/")
    d = json.loads(re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', s, re.S).group(1))
    for j in d["props"]["pageProps"]["initialJobOpenings"]:
        sal = (j.get("salaryRange") or {}).get("salaryHumanReadableText")
        yield j["created_at"], (j.get("company") or {}).get("name"), j["roleTitle"], j.get("location") or "", sal, j.get("url")


def tecnoempleo():
    s = baja("tecnoempleo.html", "https://www.tecnoempleo.com/ofertas-trabajo/?te=data+engineer&en_remoto=1")
    for b in s.split('<div class="p-3 border rounded mb-3 bg-white"')[1:]:
        t = re.search(r'<h3[^>]*>\s*<a href="([^"]+)"[^>]*title="([^"]+)"', b)
        e = re.search(r'class="text-primary link-muted">([^<]+)<', b)
        f = re.search(r"<b>([^<]+)</b> - (\d{2}/\d{2}/\d{4})", b)
        if t and f and "remoto" in f.group(1).lower():
            yield f.group(2), html.unescape(e.group(1)) if e else "?", html.unescape(t.group(2)), "España, 100 % remoto", None, t.group(1)


def jobicy():
    for geo in ("spain", "europe", "anywhere"):
        for j in json.loads(baja(f"jobicy_{geo}.json", f"https://jobicy.com/api/v2/remote-jobs?count=100&geo={geo}"))["jobs"]:
            sal = f"{j['salaryMin']}–{j['salaryMax']} {j.get('salaryCurrency', '?')}/{j.get('salaryPeriod', '?')}" if j.get("salaryMax") else None
            yield j["pubDate"], j["companyName"], j["jobTitle"], j.get("jobGeo") or "", sal, j["url"]


def weworkremotely():
    from xml.etree import ElementTree
    from email.utils import parsedate_to_datetime
    for cat in ("remote-back-end-programming-jobs", "remote-devops-sysadmin-jobs"):
        for it in ElementTree.fromstring(baja(f"wwr_{cat}.rss", f"https://weworkremotely.com/categories/{cat}.rss")).iter("item"):
            empresa, _, titulo = (it.findtext("title") or "").partition(": ")
            yield parsedate_to_datetime(it.findtext("pubDate")).date().isoformat(), empresa, titulo, it.findtext("region") or "", None, it.findtext("link")


def wttj():
    """Welcome to the Jungle: el buscador de la web usa Algolia con una clave de solo búsqueda que viaja
    en la propia página (no hace falta login, JWT ni navegador). Oficinas en España y remoto total."""
    for q in ("data engineer", "analytics engineer", "backend engineer", "python", "golang", "rust"):
        req = urllib.request.Request(
            "https://CSEKHVMS53-dsn.algolia.net/1/indexes/wttj_jobs_production_en/query",
            data=json.dumps({"query": q, "hitsPerPage": 100, "filters": "offices.country_code:ES AND remote:fulltime"}).encode(),
            headers={"User-Agent": UA, "x-algolia-api-key": "4bd8f6215d0cc52b26430765769e65a0",
                     "x-algolia-application-id": "CSEKHVMS53", "Origin": "https://www.welcometothejungle.com",
                     "Referer": "https://www.welcometothejungle.com/"})
        datos = urllib.request.urlopen(req, timeout=30).read().decode()
        open(os.path.join(salida, f"wttj_{q.replace(' ', '_')}.json"), "w", encoding="utf-8").write(datos)
        for j in json.loads(datos)["hits"]:
            sal = f"{j['salary_minimum']}–{j['salary_maximum']} {j['salary_currency']}/{j['salary_period']}" if j.get("salary_maximum") else None
            yield (j["published_at_date"], j["organization"]["name"], j["name"], "España, 100 % remoto", sal,
                   f"https://www.welcometothejungle.com/en/companies/{j['organization']['slug']}/jobs/{j['slug']}")


def linkedin():
    """Endpoint de invitados de LinkedIn (el que usa la web sin sesión): sin login ni token, solo 10 por página
    y con límite de peticiones, así que se espacian."""
    import time
    segundos = max(1, (date.today() - desde).days + 1) * 86400
    for lugar in ("Spain", "European Union"):
        for q in ("data engineer", "analytics engineer", "backend engineer python", "golang developer"):
            for start in (0, 10):
                url = ("https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?"
                       f"keywords={urllib.parse.quote(q)}&location={urllib.parse.quote(lugar)}&f_WT=2&f_TPR=r{segundos}&start={start}")
                try:
                    s = baja(f"linkedin_{lugar[:2]}_{q[:4]}_{start}.html", url)
                except Exception:
                    break  # normalmente 429: se salta esta consulta y se sigue con la siguiente
                time.sleep(1.5)
                for b in s.split("<li>")[1:]:
                    g = lambda pat: (re.search(pat, b, re.S) or [None, ""])[1].strip()
                    enlace = g(r'href="([^"?]+)')
                    if enlace:
                        yield (g(r'datetime="([^"]+)"') or date.today().isoformat(), html.unescape(g(r'base-search-card__subtitle.*?>\s*(?:<a[^>]*>)?\s*(.*?)\s*<')),
                               html.unescape(g(r'base-search-card__title[^>]*>(.*?)<')), html.unescape(g(r'job-search-card__location[^>]*>(.*?)<')), None, enlace)


FUENTES = [("Himalayas", himalayas), ("Workable", workable), ("Remotive", remotive), ("RemoteOK", remoteok),
           ("Working Nomads", workingnomads), ("Arbeitnow", arbeitnow), ("Landing.jobs", landing),
           ("Remote Rocketship", remoterocketship), ("Tecnoempleo", tecnoempleo),
           ("Welcome to the Jungle", wttj), ("LinkedIn", linkedin), ("Jobicy", jobicy),
           ("We Work Remotely", weworkremotely)]

for nombre, fuente in FUENTES:
    vistas, filas = 0, []
    try:
        for fecha, empresa, titulo, lugar, salario, url in fuente():
            vistas += 1
            if not TITULO.search(titulo or "") or dia(fecha) < desde:
                continue
            if nombre not in ("Himalayas", "Workable", "Tecnoempleo", "Welcome to the Jungle") and not GEO.search(lugar or ""):
                continue
            filas.append(f"  {dia(fecha)} | {empresa} | {titulo} | {lugar} | {salario or 'salario no publicado'} | {url}")
    except Exception as e:  # una fuente rota no para el barrido
        print(f"== {nombre}: FALLO ({type(e).__name__}: {e})")
        continue
    filas = list(dict.fromkeys(filas))  # la misma oferta sale en varias consultas
    print(f"== {nombre}: {len(filas)} candidatas de {vistas} ofertas")
    print("\n".join(filas))
