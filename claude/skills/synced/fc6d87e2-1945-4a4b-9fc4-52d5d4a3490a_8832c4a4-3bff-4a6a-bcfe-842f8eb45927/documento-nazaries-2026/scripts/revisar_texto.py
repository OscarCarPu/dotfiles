#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
revisar_texto.py — Audita el JSON de contenido antes de generar el documento.

Detecta las marcas mecánicas de texto generado automáticamente y las desviaciones
de la identidad verbal de Nazaríes. Lo que no detecta (falta de especificidad real,
frases que valdrían para cualquier empresa) está en references/estilo_humano.md y
hay que revisarlo leyendo.

Uso:
    python3 revisar_texto.py contenido.json

Salida: hallazgos agrupados por gravedad. Devuelve 1 si hay algo de gravedad ALTA.
"""

import json
import re
import statistics
import sys
import unicodedata

# ---------------------------------------------------------------------------
# Patrones
# ---------------------------------------------------------------------------

# (regex, mensaje). Se aplican sobre el texto en minúsculas sin tildes.
ALTA = [
    (r'en un mundo cada vez mas', 'apertura de relleno'),
    (r'en el panorama actual', 'apertura de relleno'),
    (r'en la era de', 'apertura de relleno'),
    (r'es importante (destacar|senalar|mencionar|recordar|tener en cuenta)',
     'muletilla: di la cosa directamente'),
    (r'cabe (destacar|senalar|mencionar)', 'muletilla: di la cosa directamente'),
    (r'vale la pena (mencionar|destacar)', 'muletilla'),
    (r'no hay que olvidar', 'muletilla'),
    (r'\bno solo\b.{0,80}\bsino tambien\b', 'construccion "no solo... sino tambien"'),
    (r'permitiendo asi|logrando (asi|de esta manera)|generando asi',
     'gerundio de cierre'),
    (r'\bbrindando\b', 'gerundio de cierre'),
    (r'sumerg(ete|irse|ete en)', 'lenguaje de blog'),
    (r'desbloquear (el|todo el) potencial', 'lenguaje de blog'),
    (r'\bholistic[oa]s?\b', 'adjetivo vacio'),
    (r'\bsinergias?\b', 'sustantivo comodin'),
    (r'\bdisruptiv[oa]s?\b', 'adjetivo de relleno'),
    (r'\bparadigma\b', 'sustantivo comodin'),
    (r'\bx[oa]s\b|@s\b', 'formas con x o @: la marca usa expresiones neutras naturales'),
    (r'\bintelligenia\b', 'marca retirada: la empresa es solo «nazaríes»'),
]

# Tipos de bloque que son prosa redactada. Los rótulos de portada y las celdas de
# tabla se excluyen de las reglas tipográficas: ahí el guion medio o una cifra
# suelta son formato de la plantilla, no redacción.
PROSA = {'parrafo', 'vineta', 'nota', 'h2', 'h3', 'titulo', 'subtitulo'}

# Se aplican sobre el texto original y solo a prosa.
ALTA_PROSA = [
    (r'—', 'guion largo (—): reestructura la frase o usa comas, dos puntos o parentesis'),
    (r'–', 'guion medio (–): reestructura la frase'),
    (r'[\U0001F300-\U0001FAFF\u2600-\u27BF]', 'emoji o icono'),
    (r'!', 'signo de exclamacion en documento de tono experto'),
]

MEDIA = [
    (r'\brobust[oa]s?\b', 'adjetivo que no discrimina: concreta'),
    (r'\bpotentes?\b', 'adjetivo que no discrimina'),
    (r'\bintegral(es)?\b', 'adjetivo que no discrimina'),
    (r'\b(aspecto|factor|elemento|punto|pieza) clave\b', '"clave" como adorno'),
    (r'\binnovador[ao]s?\b', 'adjetivo de relleno'),
    (r'\bpotenciar\b|\bmaximizar\b', 'verbo inflador'),
    (r'\bhoja de ruta\b', 'metafora gastada: di calendario, plan o fases'),
    (r'\bestado del arte\b|\bde vanguardia\b', 'expresion de relleno'),
    (r'\bsimplemente\b', 'encubre un proceso que merece descripcion'),
    (r'\b(quiza|quizas|posiblemente|en cierta medida|podria decirse)\b',
     'calificativo que debilita sin aportar'),
    (r'\btransformacion digital\b', 'termino generico: concreta que cambia'),
    (r'(\+\s?15|mas de 15|15) anos de experiencia',
     'antiguedad heredada de material antiguo: calcula desde 2008'),
    (r'soluciones de vanguardia', 'formulacion descartada por la identidad verbal'),
    (r'como (hemos visto|se ha mencionado)', 'referencia interna de relleno'),
    (r'profundicemos|exploremos', 'lenguaje de blog'),
]

# Aperturas de parrafo que no deben repetirse
CONECTORES = ['ademas', 'asimismo', 'por otro lado', 'por su parte', 'en este sentido',
              'cabe', 'no obstante', 'sin embargo', 'en resumen', 'en definitiva',
              'en conclusion', 'por tanto', 'por lo tanto']

CONTRASTIVA = re.compile(r'no (se trata de|es)\b.{0,120}?\b(sino|es)\b')


def sin_tildes(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s)
                   if unicodedata.category(c) != 'Mn')


def normaliza(s):
    return sin_tildes(s.lower())


# ---------------------------------------------------------------------------
# Recolección de textos
# ---------------------------------------------------------------------------

def recolectar(contenido):
    """Devuelve [(ubicacion, tipo, texto)] de todo el contenido redactado."""
    fuera = []
    p = contenido.get('portada', {})
    for k in ('rotulo', 'titulo', 'subtitulo'):
        if p.get(k):
            fuera.append((f'portada.{k}', k, p[k]))
    for d in p.get('datos', []):
        fuera.append(('portada.datos', 'dato', f"{d.get('rotulo','')} {d.get('valor','')}"))
    if contenido.get('indice', {}).get('resumen'):
        fuera.append(('indice.resumen', 'parrafo', contenido['indice']['resumen']))
    for i, cap in enumerate(contenido.get('capitulos', []), 1):
        fuera.append((f'cap {i}.titulo', 'titulo', cap.get('titulo', '')))
        if cap.get('resumen'):
            fuera.append((f'cap {i}.resumen', 'parrafo', cap['resumen']))
        for j, b in enumerate(cap.get('bloques', []), 1):
            u = f'cap {i}.bloque {j} ({b.get("tipo")})'
            t = b.get('tipo')
            if t in ('parrafo', 'h2', 'h3', 'nota'):
                fuera.append((u, t, b.get('texto', '')))
            elif t == 'vinetas':
                for k, it in enumerate(b.get('items', []), 1):
                    fuera.append((f'{u} item {k}', 'vineta', it))
            elif t == 'tabla':
                for celda in b.get('cabecera', []):
                    fuera.append((u, 'celda', celda))
                for fila in b.get('filas', []) + ([b['fila_total']] if b.get('fila_total') else []):
                    for celda in fila:
                        fuera.append((u, 'celda', celda))
    return fuera


def frases(texto):
    partes = re.split(r'(?<=[.:;?])\s+|\n', texto)
    return [f.strip() for f in partes if len(f.strip()) > 1]


# ---------------------------------------------------------------------------
# Comprobaciones
# ---------------------------------------------------------------------------

def revisar(contenido):
    hallazgos = {'ALTA': [], 'MEDIA': [], 'ESTRUCTURA': []}
    textos = recolectar(contenido)

    # --- patrones de palabra y tipografia
    for ubic, tipo, texto in textos:
        norm = normaliza(texto)
        for patron, msg in ALTA:
            if re.search(patron, norm):
                hallazgos['ALTA'].append((ubic, msg))
        if tipo in PROSA:
            for patron, msg in ALTA_PROSA:
                if re.search(patron, texto):
                    hallazgos['ALTA'].append((ubic, msg))
        for patron, msg in MEDIA:
            if re.search(patron, norm):
                hallazgos['MEDIA'].append((ubic, msg))

    # --- sintaxis contrastiva: como maximo una en todo el documento
    contrastivas = [u for u, _t, tx in textos if CONTRASTIVA.search(normaliza(tx))]
    if len(contrastivas) > 1:
        hallazgos['ALTA'].append(
            (', '.join(contrastivas),
             f'{len(contrastivas)} construcciones "no es X, sino Y": deja como maximo una'))

    # --- parrafos: longitud y uniformidad
    parrafos = [(u, tx) for u, t, tx in textos if t == 'parrafo']
    n_frases = [len(frases(tx)) for _u, tx in parrafos]
    if len(n_frases) >= 4 and len(set(n_frases)) == 1:
        hallazgos['ESTRUCTURA'].append(
            ('parrafos', f'todos los parrafos tienen {n_frases[0]} frases: rompe la simetria'))
    if len(n_frases) >= 4 and statistics.pstdev(n_frases) < 0.5:
        hallazgos['ESTRUCTURA'].append(
            ('parrafos', 'longitud de parrafo casi identica en todo el documento'))

    # --- frases: longitud media y variedad
    todas = [f for _u, tx in parrafos for f in frases(tx)]
    palabras = [len(f.split()) for f in todas]
    if palabras:
        media = statistics.mean(palabras)
        if media > 28:
            hallazgos['ESTRUCTURA'].append(
                ('frases', f'media de {media:.0f} palabras por frase: parte las mas largas'))
        cortas = [p for p in palabras if p <= 8]
        if len(todas) >= 10 and not cortas:
            hallazgos['ESTRUCTURA'].append(
                ('frases', 'ninguna frase corta (8 palabras o menos) en todo el documento'))

    # --- aperturas de parrafo repetidas
    aperturas = {}
    for u, tx in parrafos:
        primera = normaliza(tx).lstrip()
        for c in CONECTORES:
            if primera.startswith(c):
                aperturas.setdefault(c, []).append(u)
    for c, us in aperturas.items():
        if len(us) > 1:
            hallazgos['MEDIA'].append(
                (', '.join(us), f'{len(us)} parrafos empiezan por "{c}"'))

    # --- enumeraciones de tres
    triadas = 0
    for _u, _t, tx in textos:
        triadas += len(re.findall(r'\b[\wáéíóúñ]+, [\wáéíóúñ]+ y [\wáéíóúñ]+\b', tx))
    if triadas >= 4:
        hallazgos['ESTRUCTURA'].append(
            ('enumeraciones', f'{triadas} enumeraciones de tres elementos: varia el numero'))

    # --- negritas por capitulo
    for i, cap in enumerate(contenido.get('capitulos', []), 1):
        n = sum(len(re.findall(r'\*\*', json.dumps(b, ensure_ascii=False))) // 2
                for b in cap.get('bloques', []))
        if n > 3:
            hallazgos['MEDIA'].append((f'cap {i}', f'{n} negritas: deja como maximo tres'))

    # --- especificidad: al menos un dato concreto por capitulo
    for i, cap in enumerate(contenido.get('capitulos', []), 1):
        cuerpo = json.dumps(cap, ensure_ascii=False)
        if not re.search(r'\d', cuerpo):
            hallazgos['ESTRUCTURA'].append(
                (f'cap {i}', 'ningun dato numerico: anade una cifra, fecha o plazo real'))

    # --- viñetas de longitud calcada
    for i, cap in enumerate(contenido.get('capitulos', []), 1):
        for j, b in enumerate(cap.get('bloques', []), 1):
            if b.get('tipo') == 'vinetas':
                largos = [len(x.split()) for x in b.get('items', [])]
                if len(largos) >= 3 and statistics.pstdev(largos) < 1.2:
                    hallazgos['ESTRUCTURA'].append(
                        (f'cap {i}.bloque {j}',
                         'viñetas de longitud practicamente identica'))

    # --- estructura de capitulos repetida
    firmas = [tuple(b.get('tipo') for b in c.get('bloques', []))
              for c in contenido.get('capitulos', [])]
    if len(firmas) >= 3 and len(set(firmas)) == 1:
        hallazgos['ESTRUCTURA'].append(
            ('capitulos', 'todos los capitulos con la misma secuencia de bloques'))

    # --- marcadores pendientes
    for u, _t, tx in textos:
        if re.search(r'\[pendiente', tx, re.I) or 'XXX' in tx:
            hallazgos['ALTA'].append((u, 'marcador pendiente sin resolver'))

    return hallazgos


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    contenido = json.load(open(sys.argv[1], encoding='utf-8'))
    h = revisar(contenido)

    orden = [('ALTA', 'Corregir antes de generar'),
             ('MEDIA', 'Revisar'),
             ('ESTRUCTURA', 'Estructura y ritmo')]
    total = sum(len(v) for v in h.values())
    if total == 0:
        print('Sin hallazgos mecanicos. Queda la revision de fondo: '
              'especificidad, frases genericas y ritmo (references/estilo_humano.md).')
        return
    for clave, titulo in orden:
        if not h[clave]:
            continue
        print(f'\n{titulo} ({len(h[clave])}):')
        vistos = set()
        for ubic, msg in h[clave]:
            firma = (ubic, msg)
            if firma in vistos:
                continue
            vistos.add(firma)
            print(f'  {ubic}: {msg}')
    print(f'\nTotal: {total} hallazgos. '
          'Recuerda la revision de fondo (references/estilo_humano.md).')
    sys.exit(1 if h['ALTA'] else 0)


if __name__ == '__main__':
    main()
