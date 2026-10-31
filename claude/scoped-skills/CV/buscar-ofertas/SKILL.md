---
name: buscar-ofertas
description: Búsqueda diaria de ofertas de data engineering y backend remotas para Oscar. Recorre las fuentes fijadas, evalúa el encaje, evita duplicados con ejecuciones anteriores y añade las buenas a aplicaciones.md como "por aplicar". Usar cuando diga "busca ofertas", "buscar trabajos", "ofertas de hoy", "mira si hay algo nuevo" o /buscar-ofertas.
---

# Buscar ofertas

Oscar ejecuta esto **a diario**. Hay que encontrar pocas ofertas buenas y nuevas; las que ya ha visto no se repiten nunca. Un día sin resultados es un resultado válido: no hay que rellenar con ofertas flojas.

Esta skill **solo busca y apunta**. No adapta el CV, no escribe cartas y no aplica: eso lo hace Oscar después.

## 0. Antes de buscar

0. **Comprueba que han pasado 72 h (3 días)** desde la última búsqueda, antes de leer nada más: `python3 .claude/skills/buscar-ofertas/scripts/puede_buscar.py ofertas_vistas.md`. Si escribe `ESPERA` (sale con 1), **para aquí**: no busques, no leas fuentes y no toques ningún archivo. Contesta solo con una línea que diga cuándo fue la última búsqueda y a partir de qué hora se puede hacer la siguiente. La única excepción es que Oscar pida explícitamente forzarla ("fuerza la búsqueda", "aunque no hayan pasado 72 h").
1. Lee `CLAUDE.md` (perfil, bandas de salario y qué no exagerar), `aplicaciones.md` y `ofertas_vistas.md`.
2. Mira `Última búsqueda` en `ofertas_vistas.md` (formato `AAAA-MM-DD HH:MM`). Busca solo lo publicado desde esa fecha, con un día de margen. Si es la primera vez (`—`), busca los últimos 30 días.
3. Lee los motivos `descartada por Oscar` de `ofertas_vistas.md`: dicen qué no le gusta. Aplícalos como filtro extra.
4. Lista las subcarpetas de empresa de la carpeta del CV (todas menos `.claude`) y compáralas con la tabla "Candidaturas" de `aplicaciones.md`. Si hay una carpeta sin fila, lo más probable es que Oscar ya aplicara y no se apuntara (así pasó con Citibox). Pregúntale si aplicó y en qué fecha antes de seguir. Si dice que sí, pasa la fila de "Por aplicar" a "Candidaturas", suma una en las métricas y pon `aplicada el <fecha>` en `ofertas_vistas.md`.

## 1. Qué busca Oscar

**Tipo de puesto, por prioridad:**
- **A:** Data Engineer, Analytics Engineer, Data Platform Engineer o Python/Go Data Engineer en una **empresa de producto**. Lo que más pesa: pipelines, ingesta, dbt, Airflow, modelado en SQL. El lenguaje da igual (Python, FastAPI, Go…).
- **B:** backend en empresa de producto, **abierto desde 2026-10-14** (la oferta de datos puro es escasa y Oscar decidió bajar el listón en el tipo de puesto, no en salario ni en el resto de requisitos). Vale Python (FastAPI, Flask), Go o Rust (Go y Rust los ha usado poco: apúntalo en las pegas), APIs, integraciones, ingesta, sistemas distribuidos o plataforma. Los que tienen mucho dato (integraciones, streams, IoT, APIs de datos, como envelio) van arriba dentro de B.
- **C:** encaja a medias. Backend Django, data science junior (Oscar estudia el grado de Data Science en la UOC, pero aún no tiene experiencia; dilo en las pegas) o una empresa de fuera de Europa. Un backend Django **sigue siendo último recurso** (va a C, solo si todo lo demás encaja muy bien).

**Backend sin datos:** no se descarta. En las pegas di que es backend puro y, si aplica, que Oscar tendría que explicar que su experiencia en pipelines es de Sixtema. Siguen fuera Java o Scala solo, frontend obligatorio, SRE/Kubernetes puro y consultoría.

**Requisitos (si no cumple alguno, se descarta):**
- **Remoto al 100 %** y contratando desde **España** (vale que diga Spain, EU, Europe, EMEA, CET ±2, o "anywhere" con contrato o contractor posible desde España). Si solo dice "Remote (US)" o pide presencia en otro país, se descarta.
- **Nivel:** sin prefijo, Junior-Mid, Mid o "II". Un **"Senior" vale** solo si la oferta **dice explícitamente** que pide **4 años o menos** y no implica liderar un equipo. Si es Senior y no publica los años, se descarta (Oscar descartó Finom por eso, 2026-10-05). Se descartan Staff, Principal, Lead, Head, Manager y Founding Engineer, y también los puestos sin prefijo que piden ejercer de **"technical leader"** o liderar esfuerzos entre equipos (Oscar descartó Free2move por eso, 2026-10-05).
- **Años pedidos:** Oscar cuenta con unos 3 años en datos. Si piden 5+ años, es nivel Senior aunque el título sea "II" o no lleve prefijo. Si todo lo demás encaja bien, añádela con esa pega en primer lugar y dilo claramente en el resumen; si no, descártala. Con Ookla Data Engineer II, Oscar primero la descartó por esto y luego decidió aplicar (2026-10-05).
- **Salario:** si está publicado, el **máximo** de la banda tiene que llegar al menos a **€45.000**. Convierte USD o GBP de forma aproximada y dilo. Si no está publicado, no se descarta: se apunta "no publicado".
- **Empresa:** de producto. Se descartan consultoras, agencias, outsourcing, staffing y "body shopping" (por ejemplo Avenga, Qinshift, knowmad mood, Diverse Lynx o cualquier "software development company" que trabaje para clientes). Una empresa europea es mejor; si no lo es, va a **C** y se dice en las pegas.
- **Antigüedad:** publicada hace 45 días o menos.
- **Fuera:** solo equity, prácticas, freelance por horas por debajo del suelo, y puestos que en realidad son de otra cosa (ML research, SRE/Kubernetes puro, solo Java o Scala, frontend). Backend ya no se descarta.
- **Fuera también, por decisión de Oscar** (2026-10-03):
  - Roles de **consultoría encubierta** dentro de una empresa de producto: "Forward Deployed", professional services, migraciones para clientes, puestos donde eres el contacto principal del cliente. Da igual lo que paguen (descartó Datafold con €85–135k).
  - Puestos que **exigen frontend** (React, Next.js…), aunque sea "solo un poco".
  - Puestos con **requisitos obligatorios que no tiene y que son el núcleo del trabajo** (por ejemplo, marketing tech con GTM o ads), sobre todo si además la oferta es antigua.

**Pegas que se apuntan pero no descartan:** Snowflake, BigQuery, Databricks o Spark (salen casi siempre y Oscar no los ha usado), cloud (AWS/GCP; Oscar tiene la certificación AWS Developer pero no la ha usado en serio), Kafka o Elasticsearch como requisito central (solo los ha tocado de pasada), un idioma o lenguaje que le falte, o una empresa que ya le rechazó antes.

## 2. Fuentes, en este orden

Usa WebFetch para los listados y WebSearch para las búsquedas en ATS. Si WebFetch devuelve 403, una página vacía (contenido generado por JS) o un reto de Cloudflare, usa el **navegador headless** (más abajo). Si tampoco funciona, anótalo en el resumen y sigue con la siguiente fuente: no reintentes en bucle.

**Navegador headless (Playwright).** Los scripts están en `scripts/` dentro de esta skill y usan el Chromium del sistema (`/usr/bin/chromium`).
- Preparación, una vez por sesión: `mkdir -p <scratchpad>/pw && cd <scratchpad>/pw && npm init -y >/dev/null && npm i playwright-core`.
- Texto de una página: `NODE_PATH=<scratchpad>/pw/node_modules node .claude/skills/buscar-ofertas/scripts/pagina.js "<url>" <scratchpad>/x.txt [espera_ms]`. Guarda el título, la URL final, el texto visible y los enlaces.
- Enlaces que coinciden con una regex (por ejemplo, el botón "Apply" que lleva al ATS): `NODE_PATH=… node .claude/skills/buscar-ofertas/scripts/enlaces.js "<url>" 'apply|greenhouse|ashby|lever'`.
- Ya funcionó con: la web de Enveritas (Cloudflare), Manfred y Jobgether.

1. **EU Remote Jobs:** `https://euremotejobs.com/job-tag/data-engineering/` y `https://euremotejobs.com/remote-data-jobs/`. Son empresas en horario europeo y a menudo publican el salario.
2. **Jobgether España** (la fuente que más dio en la primera ejecución): `https://jobgether.com/remote-jobs/spain/data-engineer` (páginas 1–3: `?page=2`, `?page=3`; las rutas `/2` y `/3` devuelven siempre la página 1, comprobado el 2026-10-30) y `https://jobgether.com/remote-jobs/spain/analytics-engineer`. Hay muchas consultoras, así que fíltralas a mano. Es más útil para descubrir empresas de producto: abre la oferta en la web de la propia empresa.
   - **Fecha real con el ID:** el listado solo dice "30+ days ago", pero el ID de cada oferta (`jobgether.com/offer/<id>-…`) es un ObjectId de MongoDB y sus 8 primeros caracteres hexadecimales son el timestamp de cuando Jobgether la dio de alta (`datetime.fromtimestamp(int(id[:8], 16), UTC)`). Saca los enlaces del listado (sección `=== LINKS ===` de `pagina.js`), decodifica la fecha y quédate con las de los últimos 45 días antes de abrir nada. Es la fecha de alta en Jobgether, no la de publicación, así que la empresa pudo publicarla antes: confírmalo en el ATS. Así salió Ookla (Data Engineer II, listada como "30+ days ago" pero dada de alta hacía 37 días).
3. **Barrido por API** (añadido el 2026-10-05): `python3 .claude/skills/buscar-ofertas/scripts/barrido.py <fecha de la última búsqueda> <scratchpad>/barrido`. En un par de minutos lee catorce fuentes sin abrir el navegador y sin gastar presupuesto de páginas: Himalayas, Workable, Remotive, RemoteOK, Working Nomads, Arbeitnow, Landing.jobs, Remote Rocketship, Tecnoempleo (solo las de 100 % remoto), Welcome to the Jungle, LinkedIn, Jobicy y We Work Remotely (añadidas el 2026-10-15). Filtra por título de datos, por fecha (desde la última búsqueda, con un día de margen) y, donde se puede, por ubicación compatible con España. Imprime una línea por candidata (fecha, empresa, puesto, ubicación, salario y enlace) y dice qué fuentes fallaron.
   - El script **no decide nada**: las candidatas pasan por los mismos filtros que el resto (duplicados de la sección 3; consultoras, nivel, años y lectura de la oferta completa de la sección 4).
   - **Qué esperar de cada una**, según la prueba del 2026-10-05: **Himalayas** y **Workable** son las que más empresas de producto nuevas sacan (Smartcat, Upsun, TrustYou, MediaRadar). Workable trae el texto completo en `description` del JSON guardado. **Remote Rocketship** repite mucho Jobgether, pero da el enlace directo al ATS. **Tecnoempleo** es casi todo de consultoras (UST, Arelance, Grupo NS…). **Remotive, RemoteOK, Working Nomads, Arbeitnow y Landing.jobs** casi nunca tienen nada de datos abierto a España, pero se revisan igualmente porque cuesta poco.
   - **Welcome to the Jungle** (2026-10-15): no hace falta login, JWT ni navegador. La web busca con Algolia y la clave de solo búsqueda (`x-algolia-api-key`, app `CSEKHVMS53`) viaja en el propio HTML; el índice en inglés es `wttj_jobs_production_en` y el script filtra `offices.country_code:ES AND remote:fulltime`. Da fecha exacta, salario (cuando lo hay) y `key_missions`/`profile` con el texto de la oferta. Desde Playwright headless la web da 403 de CloudFront; no se necesita. Si dejara de funcionar, la clave se reabre capturando las peticiones a `algolia.net` de la página `/en/jobs`.
   - **LinkedIn** (2026-10-15): tampoco hace falta sesión. Se usa el endpoint de invitados `jobs-guest/jobs/api/seeMoreJobPostings/search` con `f_WT=2` (remoto) y `f_TPR` (ventana de tiempo): 10 por página, límite de peticiones (se espacian 1,5 s; si da 429 se salta esa consulta). Es lo más ruidoso (consultoras, Senior, Lead) y el filtro de ubicación deja solo España; por eso se mira tras el resto. La fecha es la de publicación en LinkedIn. **No uses el token de la cuenta de Oscar**: la sesión autenticada arriesga el bloqueo de su cuenta y no aporta nada que el endpoint público no dé.
   - **Jobicy** (campo `jobGeo` con los países) y **We Work Remotely** (RSS de backend y devops) casi siempre traen puestos Senior o de US; se revisan porque cuesta poco.
   - Descartadas el 2026-10-15: **Python.org Jobs** (el RSS no trae fecha), **Get on Board** (casi todo LatAm) y **Wellfound**, **hiring.cafe** y **Remotefront** (bloquean o dan 429).
   - Si una fuente sale con `FALLO` varios días seguidos, mira si cambió la URL o el formato y arregla el script.
4. **Hacker News "Who is hiring?":** usa la API de Algolia con `curl`.
   - Para encontrar el hilo del mes: `curl -s 'https://hn.algolia.com/api/v1/search_by_date?tags=story,author_whoishiring&hitsPerPage=3'` y quédate con el que se titula "Who is hiring?".
   - Para leer solo los comentarios nuevos: `curl -s 'https://hn.algolia.com/api/v1/search?tags=comment,story_<ID>&query=<termino>&numericFilters=created_at_i><epoch_ultima_busqueda>&hitsPerPage=100'`. Los términos son `data engineer`, `analytics engineer`, `dbt`, `airflow` y `data platform`. Quédate con los que mencionan Europe, EU, EMEA, Spain, CET o anywhere.
   - Guarda cada respuesta en un archivo del scratchpad (`curl -o`) y procésalos después. Si encadenas varias peticiones en una sola tubería, alguna llega vacía y rompe el `json.loads`.
   - Quédate solo con los comentarios de primer nivel (`parent_id == story_id`). Para leer un post completo: `https://hn.algolia.com/api/v1/items/<id>`.
   - Guarda el ID del hilo en `ofertas_vistas.md` ("Último hilo de HN…").
5. **ATS de empresas de producto**, con WebSearch. Rinde poco: `site:` suele devolver agregadores o páginas cerradas (404). Haz como mucho 2 búsquedas. Así salen las ofertas que nunca llegan a los agregadores:
   - `site:job-boards.greenhouse.io "data engineer" remote (Spain OR Europe OR EMEA)`
   - `site:jobs.lever.co "data engineer" remote (Spain OR Europe)`
   - `site:jobs.ashbyhq.com "data engineer" remote (Spain OR Europe)`
   - Haz lo mismo con `"analytics engineer"`.
6. **Outer Join:** `https://outerjoin.us`. Ofertas remotas de datos, pero casi todas de EE. UU. y sin filtro de región: lee en cada una si contratan en Europa.
7. **Manfred:** `https://www.getmanfred.com/en/job-offers`. Mercado español, con salario siempre publicado. Se lee con `pagina.js`. Tiene poco volumen (unas 15 ofertas activas en total, y en la primera ejecución ninguna era de datos) y el listado no dice la empresa: abre solo las que tengan pinta de datos.

LinkedIn ya se lee en el barrido (ver arriba), pero Oscar puede mirar a mano sus recomendaciones. La bolsa de dbt (`getdbt.com/analytics-engineering/jobs/`) ya no existe: redirige a la página de empleo de dbt Labs.

**Welcome to the Jungle:** la búsqueda de la web sin login ya no da resultados (2026-10-05), pero el barrido consulta directamente su Algolia (ver arriba). Las recomendaciones por "matching" con su cuenta las sigue viendo Oscar a mano; recuérdaselo en el resumen.

**Empresas de producto que ya aparecieron y conviene volver a mirar** (aunque hoy no tengan nada que encaje): Typeform, Filigran (sus ofertas encajaban salvo por los años), Nansen, Oyster.

Límite orientativo por ejecución: unas 20–25 páginas abiertas en total. Gasta el presupuesto en abrir ofertas que prometen, no en repasar listados enteros.

## 3. Evitar duplicados

Antes de evaluar una oferta en detalle, comprueba si ya está:

1. **Normaliza la URL:** sin `?utm_…` ni otros parámetros de seguimiento, sin `/` final y en minúsculas. Busca con `grep -i` en `aplicaciones.md` y `ofertas_vistas.md`.
2. **Busca la empresa** con `grep -i "<empresa>"` en los dos archivos. Una misma oferta suele salir en varias webs con URLs distintas, así que si coinciden la empresa y un puesto equivalente (por ejemplo "Data Engineer" y "Data Engineer (Remote, EU)"), es un duplicado.
3. Si es la misma empresa pero **otro puesto**, no es un duplicado. Evalúala igual y, si la empresa ya le rechazó o ya tiene una candidatura abierta, dilo en las pegas.
4. Si es una oferta re-publicada de una que Oscar ya rechazó o descartó, se descarta sin volver a evaluarla.

## 4. Evaluar

- **Abre siempre la oferta completa** (mejor en la web de la propia empresa) antes de añadirla. No decidas solo con el resumen del listado. Hay que confirmar: remoto desde España, años que piden, salario, stack y fecha.
- **No te fíes de lo que resume Jobgether.** En la primera ejecución dio por buenas tres ofertas que no lo eran: Nebius era Senior con 5+ años y no "3+"; Air Apps era de Data Analyst presencial en Lisboa; Ruby Labs era de agosto. Comprueba siempre con la API pública del ATS, que da el texto real, la fecha de publicación y a veces el salario:
  - Ashby (WebFetch no ve nada porque la página se genera con JS): `curl -s -o <scratchpad>/x.json "https://api.ashbyhq.com/posting-api/job-board/<org>?includeCompensation=true"`. Busca la oferta por su `id`; usa los campos `descriptionHtml`, `publishedAt`, `compensation.compensationTierSummary`, `location` e `isRemote`. Si el `id` no está, la oferta ya se cerró.
  - Greenhouse: `https://boards-api.greenhouse.io/v1/boards/<org>/jobs/<id>`, campos `content` y `updated_at`. Para ver todas las ofertas de la empresa: `/v1/boards/<org>/jobs`.
  - Si la página está detrás de Cloudflare (403), ábrela con `pagina.js`. Si aun así no carga, pon "no verificada" en las pegas.
  - Ojo con las ofertas "permanentes": hay empresas que tienen la misma oferta abierta durante años, y los agregadores las muestran como nuevas. Por ejemplo, la de Enveritas está abierta desde 2024 y pide 7+ años. Mira `first_published` en Greenhouse o `publishedAt` en Ashby.
- No inventes nada. Si un dato no aparece, pon "no publicado" o "?".
- **La oficina de Greenhouse no basta para dar por bueno el remoto desde España.** Veriff listaba "Spain (Remote)" entre sus oficinas y el formulario de solicitud decía que solo contrataban en Estonia (Oscar la descartó el 2026-10-30). Busca en el texto una frase explícita sobre el país ("remote in Spain", "we hire in…") y, si el texto no lo dice, mira las preguntas del formulario (en Greenhouse vienen en `questions` con `?questions=true`). Si solo lo dice la ficha de oficinas, ponlo en las pegas como "remoto desde España sin confirmar en el texto".
- **Remoto sin confirmar = no vale.** Si el texto de la oferta no dice que es remoto (solo lo marca el filtro de LinkedIn) y la oferta es de una ciudad, trátala como híbrida y descártala, salvo que la web de la empresa lo confirme. Oscar lo descartó con Glovo (2026-10-27): era híbrido y se había añadido con el remoto "no verificado".
- Cada oferta evaluada en detalle, se añada o no, va a `ofertas_vistas.md`. Así mañana no se vuelve a mirar. Las que se descartan a simple vista desde el listado (consultora evidente, Staff o Lead, solo US) se apuntan solo si es probable que vuelvan a salir. No hace falta llenar el registro de ruido.

## 5. Escribir

**En `aplicaciones.md`, sección "Por aplicar"**, una fila por oferta, insertada **justo debajo de la cabecera de la tabla** (las más nuevas arriba):

```
| 2026-10-03 | Empresa | Puesto exacto | A | €50–60k / no publicado | 1 frase: por qué encaja con su perfil | 1 frase: qué le falta o qué tiene en contra | [web](url) |
```

En "Por qué encaja", busca el solape real con lo que Oscar ha hecho de verdad (pipelines en Python con Airflow en Sixtema, dbt y Postgres en `central-pipeline`, ingesta MQTT en Go, años de PostgreSQL), como hace la carta de envelio. No fuerces encajes que no existen.

**En `ofertas_vistas.md`**, una fila por cada oferta evaluada, insertada justo debajo de la cabecera de la tabla:

```
| 2026-10-03 | Empresa | Puesto | url normalizada | añadida / descartada | motivo corto |
```

Actualiza también `Última búsqueda:` con la fecha y hora de ahora (`date '+%Y-%m-%d %H:%M'`), que es lo que lee la comprobación de 72 h del paso 0, y, si leíste el hilo de HN, su ID.

No toques la tabla de candidaturas ni las métricas: eso se actualiza cuando Oscar aplica de verdad.

## 6. Resumen en el chat

Corto, salvo las ofertas nuevas, que van **en detalle**:
- Las ofertas nuevas añadidas, cada una con: empresa, puesto, prioridad, salario, por qué encaja, pegas y **la URL completa en el propio detalle**, siempre (Oscar tuvo que pedirla el 2026-10-27).
- Cuántas se revisaron y cuántas se descartaron en esta ejecución, con los motivos más comunes.
- **Estadísticas totales** (al final, después de actualizar los archivos de la sección 5): ejecuta `python3 .claude/skills/buscar-ofertas/scripts/estadisticas.py` y pega su salida tal cual en una tabla: ofertas vistas, válidas, aplicadas, rechazadas, con entrevista y pendientes. Definiciones:
  - **Vistas:** filas de `ofertas_vistas.md` (una fila agrupada de varias ofertas cuenta como una, así que es un mínimo).
  - **Válidas:** vistas que no fueron `descartada` por la skill (añadidas, aplicadas y descartadas por Oscar).
  - **Aplicadas:** filas de "Candidaturas". **Rechazadas:** las de estado `rechazada…`. **Con entrevista:** estado `entrevista` u `oferta` (una rechazada "sin entrevista" no cuenta; si hubo entrevista y luego rechazo, anótalo en el estado como `rechazada (tras entrevista)`).
  - **Pendientes:** candidaturas sin resolver (`enviada`, `sin respuesta`, `entrevista`), más cuántas siguen en "Por aplicar".
  - Si Oscar corrige una cifra a mano, arregla la fila de origen, no el resultado.
- Las fuentes que fallaron **y qué has hecho para arreglarlas**. Una fuente caída se arregla siempre en la misma ejecución (mira el error, corrige `barrido.py` y vuelve a lanzar esa fuente); no se deja para otro día ni se limita a anotarla. Solo si es imposible (la web bloquea o cerró la API) dilo y explica por qué. Ejemplo: Jobicy falló el 2026-10-27 por `salaryCurrency` ausente y se arregló con `.get()`.
- Si en "Por aplicar" hay filas de hace más de 14 días, recuérdaselo a Oscar: o aplica o las descarta.
