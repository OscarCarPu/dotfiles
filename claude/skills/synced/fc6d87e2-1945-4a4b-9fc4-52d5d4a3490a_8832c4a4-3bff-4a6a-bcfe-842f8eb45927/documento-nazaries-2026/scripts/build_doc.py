#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_doc.py — Genera un documento oficial de Nazaríes a partir de
la plantilla corporativa (plantilla_word_v1.docx) y un JSON de contenido.

Uso:
    python3 build_doc.py contenido.json salida.docx [--template RUTA] [--sin-paginas-toc]

El JSON de contenido tiene esta forma (todas las cadenas en texto plano;
se admite \n para saltos de línea y **negrita** en párrafos, viñetas y notas):

{
  "portada": {
    "rotulo":   "INFORME TÉCNICO – 2026",
    "titulo":   "Título grande\ncon salto de línea opcional",
    "subtitulo":"Frase de apoyo bajo el título.\nHasta tres líneas separadas por \\n.",
    "datos": [
      {"rotulo": "PREPARADO PARA", "valor": "Cliente S.L."},
      {"rotulo": "FECHA",          "valor": "Julio 2026"},
      {"rotulo": "VERSIÓN",        "valor": "v1.0"},
      {"rotulo": "REFERENCIA",     "valor": "NZ-2026-041"}
    ]
  },
  "indice": { "resumen": "Texto introductorio bajo el título Índice." },
  "capitulos": [
    {
      "titulo":  "Resumen ejecutivo",
      "resumen": "Entradilla del capítulo (aparece en verde bajo el título).",
      "bloques": [
        {"tipo": "parrafo", "texto": "Párrafo normal justificado. Admite **negrita**."},
        {"tipo": "h2",      "texto": "Subtítulo numerado (2.1., 2.2., ...)"},
        {"tipo": "h3",      "texto": "Encabezado menor en azul matiz"},
        {"tipo": "vinetas", "items": ["Primera viñeta", "Segunda viñeta"]},
        {"tipo": "tabla",
         "cabecera":  ["Fase", "Duración", "Entregables"],
         "filas":     [["01 · Descubrimiento", "2 semanas", "Auditoría y roadmap"]],
         "fila_total": ["Total", "", "16 semanas"],
         "anchos":    [3, 2, 4]},
        {"tipo": "nota", "texto": "Caja destacada sobre fondo turquesa claro. Admite **negrita**."}
      ]
    }
  ]
}

Notas:
- "datos" de portada admite de 0 a 4 pares rótulo/valor; las columnas sobrantes se vacían.
- "fila_total" y "anchos" de tabla son opcionales.
- La numeración la pone el generador: capítulos 01, 02 ... 09, 10, 11 y subtítulos n.1., n.2.
- Si LibreOffice (soffice) está disponible, los números de página del índice se calculan
  renderizando el documento; si no, quedan estimados y Word los corrige al abrir
  (updateFields queda activado).
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

def esc(s):
    """Escapa texto para contenido XML."""
    return (s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
             .replace('"', '&quot;'))


def warn(msg):
    print(f"  [aviso] {msg}", file=sys.stderr)


def die(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Generación de runs con soporte de \n y **negrita**
# ---------------------------------------------------------------------------

RPR_MEDIUM = '<w:rPr><w:rFonts w:ascii="Gellix Medium" w:hAnsi="Gellix Medium"/></w:rPr>'


def runs_de_texto(texto, rpr_normal='', rpr_negrita=RPR_MEDIUM):
    """Convierte texto con \n y **negrita** en una secuencia de runs OOXML."""
    partes = []
    lineas = texto.split('\n')
    for i, linea in enumerate(lineas):
        if i > 0:
            partes.append('<w:r>%s<w:br/></w:r>' % rpr_normal)
        # segmenta por **...**
        for j, seg in enumerate(re.split(r'\*\*(.+?)\*\*', linea)):
            if seg == '':
                continue
            rpr = rpr_negrita if j % 2 == 1 else rpr_normal
            partes.append('<w:r>%s<w:t xml:space="preserve">%s</w:t></w:r>'
                          % (rpr, esc(seg)))
    return ''.join(partes)


# ---------------------------------------------------------------------------
# Bloques de contenido de capítulo
# ---------------------------------------------------------------------------

def p_heading1(titulo, bm_name, bm_id):
    return ('<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr>'
            f'<w:bookmarkStart w:id="{bm_id}" w:name="{bm_name}"/>'
            f'<w:r><w:t xml:space="preserve">{esc(titulo)}</w:t></w:r>'
            f'<w:bookmarkEnd w:id="{bm_id}"/></w:p>')


def p_resumen(texto):
    return ('<w:p><w:pPr><w:pStyle w:val="Resumencaptulo"/></w:pPr>'
            + runs_de_texto(texto) + '</w:p>')


def p_parrafo(texto):
    return '<w:p>' + runs_de_texto(texto) + '</w:p>'


def p_h2(texto, numero):
    """Subtítulo con su número escrito de forma literal ("2.1.").

    La numeración automática de nivel 2 tomaba el número de capítulo del contador
    de Título 1, y ese contador tiene que dar 01..09, 10, 11 para el índice. Los
    dos formatos son incompatibles en un mismo esquema de lista, así que el número
    del subtítulo lo escribe el generador, que ya sabe en qué capítulo está.
    """
    return ('<w:p><w:pPr><w:pStyle w:val="Heading2"/>'
            '<w:numPr><w:ilvl w:val="1"/><w:numId w:val="0"/></w:numPr>'
            '<w:ind w:left="760" w:hanging="760"/></w:pPr>'
            f'<w:r><w:t xml:space="preserve">{numero}</w:t></w:r>'
            '<w:r><w:tab/></w:r>'
            f'<w:r><w:t xml:space="preserve">{esc(texto)}</w:t></w:r></w:p>')


def p_h3(texto):
    return ('<w:p><w:pPr><w:pStyle w:val="Heading3"/></w:pPr>'
            f'<w:r><w:t xml:space="preserve">{esc(texto)}</w:t></w:r></w:p>')


def p_vinetas(items):
    out = []
    for i, item in enumerate(items):
        after = '160' if i == len(items) - 1 else '60'
        out.append(
            f'<w:p><w:pPr><w:spacing w:after="{after}"/>'
            '<w:ind w:left="454" w:hanging="284"/><w:jc w:val="left"/></w:pPr>'
            '<w:r><w:rPr><w:color w:val="66888D"/></w:rPr>'
            '<w:t xml:space="preserve">—  </w:t></w:r>'
            + runs_de_texto(item) + '</w:p>')
    return ''.join(out)


# --- tablas -----------------------------------------------------------------

ANCHO_TABLA = 9440   # dxa útiles (A4, márgenes 1134 y sangría de tabla 160)
TCMAR = ('<w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="160" w:type="dxa"/>'
         '<w:bottom w:w="120" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tcMar>')


def _celda(ancho, fill, rpr, texto, spacing='<w:spacing w:before="120" w:after="120"/>'):
    return (f'<w:tc><w:tcPr><w:tcW w:w="{ancho}" w:type="dxa"/>'
            f'<w:shd w:val="clear" w:color="{fill}" w:fill="{fill}"/>'
            f'{TCMAR}<w:vAlign w:val="center"/></w:tcPr>'
            f'<w:p><w:pPr>{spacing}<w:jc w:val="left"/></w:pPr>'
            f'<w:r>{rpr}<w:t xml:space="preserve">{esc(texto)}</w:t></w:r></w:p></w:tc>')


def bloque_tabla(cabecera, filas, fila_total=None, anchos=None):
    ncols = len(cabecera)
    if anchos and len(anchos) == ncols:
        total = sum(anchos)
        widths = [int(ANCHO_TABLA * a / total) for a in anchos]
    else:
        widths = [ANCHO_TABLA // ncols] * ncols
    widths[-1] += ANCHO_TABLA - sum(widths)

    rpr_head = ('<w:rPr><w:rFonts w:ascii="Gellix Medium" w:hAnsi="Gellix Medium"/>'
                '<w:color w:val="FFFFFF"/><w:sz w:val="21"/></w:rPr>')
    rpr_col0 = ('<w:rPr><w:rFonts w:ascii="Gellix Medium" w:hAnsi="Gellix Medium"/>'
                '<w:sz w:val="21"/></w:rPr>')
    rpr_data = '<w:rPr><w:color w:val="66888D"/><w:sz w:val="21"/></w:rPr>'
    rpr_tot = ('<w:rPr><w:rFonts w:ascii="Gellix Medium" w:hAnsi="Gellix Medium"/>'
               '<w:sz w:val="20"/></w:rPr>')

    xml = ['<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/>'
           f'<w:tblW w:w="{ANCHO_TABLA}" w:type="dxa"/>'
           '<w:tblInd w:w="160" w:type="dxa"/>'
           '<w:tblBorders><w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
           '<w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
           '<w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
           '<w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
           '<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
           '<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/></w:tblBorders>'
           '<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1"'
           ' w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr><w:tblGrid>']
    for w in widths:
        xml.append(f'<w:gridCol w:w="{w}"/>')
    xml.append('</w:tblGrid>')

    # cabecera
    xml.append('<w:tr><w:trPr><w:tblHeader/></w:trPr>')
    for w, txt in zip(widths, cabecera):
        xml.append(_celda(w, '00333B', rpr_head, txt))
    xml.append('</w:tr>')

    # filas de datos con bandas alternas
    for r, fila in enumerate(filas):
        fill = 'FFFFFF' if r % 2 == 0 else 'F5F5F5'
        xml.append('<w:tr>')
        for c, (w, txt) in enumerate(zip(widths, fila)):
            xml.append(_celda(w, fill, rpr_col0 if c == 0 else rpr_data, txt))
        xml.append('</w:tr>')

    # fila total destacada en turquesa
    if fila_total:
        xml.append('<w:tr>')
        for w, txt in zip(widths, fila_total):
            xml.append(_celda(w, 'C1E4D6', rpr_tot, txt))
        xml.append('</w:tr>')

    xml.append('</w:tbl><w:p><w:pPr><w:spacing w:after="0"/>'
               '<w:rPr><w:sz w:val="8"/></w:rPr></w:pPr></w:p>')
    return ''.join(xml)


def bloque_nota(texto):
    """Caja destacada: tabla de una celda sobre fondo turquesa claro."""
    return ('<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/>'
            f'<w:tblW w:w="{ANCHO_TABLA}" w:type="dxa"/>'
            '<w:tblInd w:w="160" w:type="dxa"/>'
            '<w:tblBorders><w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
            '<w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
            '<w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
            '<w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
            '<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
            '<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/></w:tblBorders>'
            '<w:tblLook w:val="04A0"/></w:tblPr>'
            f'<w:tblGrid><w:gridCol w:w="{ANCHO_TABLA}"/></w:tblGrid>'
            f'<w:tr><w:tc><w:tcPr><w:tcW w:w="{ANCHO_TABLA}" w:type="dxa"/>'
            '<w:shd w:val="clear" w:color="E6F4EF" w:fill="E6F4EF"/>'
            '<w:tcMar><w:top w:w="220" w:type="dxa"/><w:left w:w="340" w:type="dxa"/>'
            '<w:bottom w:w="220" w:type="dxa"/><w:right w:w="340" w:type="dxa"/></w:tcMar>'
            '<w:vAlign w:val="center"/></w:tcPr>'
            '<w:p><w:pPr><w:spacing w:after="0" w:line="276" w:lineRule="auto"/>'
            '<w:jc w:val="left"/></w:pPr>'
            + runs_de_texto(texto) +
            '</w:p></w:tc></w:tr></w:tbl>'
            '<w:p><w:pPr><w:spacing w:after="0"/>'
            '<w:rPr><w:sz w:val="8"/></w:rPr></w:pPr></w:p>')


def render_bloque(b, num_capitulo=1, contador_h2=None):
    t = b.get('tipo')
    if t == 'parrafo':
        return p_parrafo(b['texto'])
    if t == 'h2':
        contador_h2[0] += 1
        return p_h2(b['texto'], f'{num_capitulo}.{contador_h2[0]}.')
    if t == 'h3':
        return p_h3(b['texto'])
    if t == 'vinetas':
        return p_vinetas(b['items'])
    if t == 'tabla':
        return bloque_tabla(b['cabecera'], b.get('filas', []),
                            b.get('fila_total'), b.get('anchos'))
    if t == 'nota':
        return bloque_nota(b['texto'])
    die(f"Tipo de bloque desconocido: {t!r}")


# ---------------------------------------------------------------------------
# Manipulación de la plantilla
# ---------------------------------------------------------------------------

def dividir_en_secciones(body):
    """Divide el cuerpo en trozos por párrafos que contienen <w:sectPr."""
    chunks, pos = [], 0
    for m in re.finditer(r'<w:p\b[^>]*>(?:(?!</w:p>).)*?<w:sectPr.*?</w:p>', body, re.DOTALL):
        chunks.append(body[pos:m.end()])
        pos = m.end()
    chunks.append(body[pos:])   # última sección (sectPr a nivel de body)
    return chunks


def reemplazo_unico(chunk, viejo, nuevo, descripcion):
    n = chunk.count(viejo)
    if n == 0:
        die(f"No se encontró en la plantilla el ancla de {descripcion}. "
            "¿Se ha modificado assets/plantilla_word_v1.docx?")
    return chunk.replace(viejo, nuevo, 1)


def forzar_alineacion_izquierda(chunk, aguja):
    """Fuerza jc=left en el párrafo que contiene `aguja`.

    El estilo Normal de la plantilla justifica el texto (jc=both). En la portada
    eso estira las líneas cortadas con <w:br/> (el título grande) de un margen a
    otro, así que hay que forzar la alineación a la izquierda.
    """
    if not aguja:
        return chunk
    i = chunk.find(aguja)
    if i == -1:
        return chunk
    ini = chunk.rfind('<w:p ', 0, i)
    fin = chunk.find('</w:p>', i) + len('</w:p>')
    if ini == -1 or fin <= ini:
        return chunk
    p = chunk[ini:fin]
    if '<w:jc ' in p:
        p_nuevo = re.sub(r'<w:jc w:val="[^"]*"/>', '<w:jc w:val="left"/>', p, 1)
    elif '<w:pPr>' in p:
        pos_rpr = p.find('<w:rPr>', p.find('<w:pPr>'))
        pos_fin_ppr = p.find('</w:pPr>')
        corte = pos_rpr if 0 < pos_rpr < pos_fin_ppr else pos_fin_ppr
        p_nuevo = p[:corte] + '<w:jc w:val="left"/>' + p[corte:]
    else:
        corte = p.find('>') + 1
        p_nuevo = p[:corte] + '<w:pPr><w:jc w:val="left"/></w:pPr>' + p[corte:]
    return chunk[:ini] + p_nuevo + chunk[fin:]


def editar_portada(chunk, portada):
    # 1) rótulo superior
    chunk = reemplazo_unico(
        chunk, '<w:t>PROPUESTA TÉCNICA – 2026</w:t>',
        f'<w:t xml:space="preserve">{esc(portada.get("rotulo", ""))}</w:t>',
        'rótulo de portada')

    # 2) título grande (run con t + br + t)
    lineas = [esc(l) for l in portada.get('titulo', '').split('\n')]
    nuevo_titulo = '<w:br/>'.join(f'<w:t xml:space="preserve">{l}</w:t>' for l in lineas)
    chunk = reemplazo_unico(
        chunk,
        '<w:t xml:space="preserve">Claridad </w:t><w:br/><w:t>para decidir y avanzar</w:t>',
        nuevo_titulo, 'título de portada')

    # 3) subtítulo (tres párrafos; se reparte por líneas)
    lineas_sub = portada.get('subtitulo', '').split('\n')
    l1 = lineas_sub[0] if len(lineas_sub) > 0 else ''
    l2 = lineas_sub[1] if len(lineas_sub) > 1 else ''
    l3 = '\n'.join(lineas_sub[2:]) if len(lineas_sub) > 2 else ''
    chunk = reemplazo_unico(
        chunk, '<w:t>Plataforma de datos e inteligencia para [Cliente].</w:t>',
        f'<w:t xml:space="preserve">{esc(l1)}</w:t>', 'subtítulo (línea 1)')
    chunk = reemplazo_unico(
        chunk, '<w:t>Convertimos la complejidad en dirección y en</w:t>',
        f'<w:t xml:space="preserve">{esc(l2)}</w:t>', 'subtítulo (línea 2)')
    chunk = reemplazo_unico(
        chunk, '<w:t>mejores decisiones</w:t>',
        f'<w:t xml:space="preserve">{esc(l3)}</w:t>', 'subtítulo (línea 3)')
    # el punto suelto que remata el subtítulo de ejemplo
    chunk = chunk.replace('<w:t>.</w:t>', '<w:t xml:space="preserve"></w:t>', 1)

    # 4) tabla de datos: rótulos y valores
    datos = list(portada.get('datos', []))[:4]
    while len(datos) < 4:
        datos.append({'rotulo': '', 'valor': ''})
    rotulos_orig = ['PROPUESTA PARA', 'FECHA', 'VALIDEZ', 'REFERENCIA']
    valores_orig = ['[Cliente]', 'Marzo 2026', '30 días', 'NZ-2026-014']
    for orig, d in zip(rotulos_orig, datos):
        chunk = reemplazo_unico(
            chunk, f'<w:t xml:space="preserve">{orig}</w:t>'
            if orig == 'PROPUESTA PARA' else f'<w:t>{orig}</w:t>',
            f'<w:t xml:space="preserve">{esc(d.get("rotulo", ""))}</w:t>',
            f'rótulo de datos "{orig}"')
    for orig, d in zip(valores_orig, datos):
        chunk = reemplazo_unico(
            chunk, f'<w:t>{orig}</w:t>',
            f'<w:t xml:space="preserve">{esc(d.get("valor", ""))}</w:t>',
            f'valor de datos "{orig}"')

    # 5) la portada se alinea a la izquierda (el estilo Normal justifica)
    for aguja in [esc(lineas[0])] + [esc(x) for x in (l1, l2, l3)]:
        if aguja.strip():
            chunk = forzar_alineacion_izquierda(chunk, aguja)
    return chunk


def entrada_toc(idx, titulo, bm, pagina, primera):
    """Genera una entrada TOC1 (la primera abre el campo TOC)."""
    pre = ''
    if primera:
        pre = ('<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
               '<w:r><w:instrText xml:space="preserve"> TOC \\o &quot;1-1&quot; \\h \\z \\u '
               '</w:instrText></w:r>'
               '<w:r><w:fldChar w:fldCharType="separate"/></w:r>')
    num = f'{idx:02d}'
    return ('<w:p><w:pPr><w:pStyle w:val="TOC1"/><w:rPr><w:noProof/></w:rPr></w:pPr>'
            + pre +
            f'<w:hyperlink w:anchor="{bm}" w:history="1">'
            '<w:r><w:rPr><w:rStyle w:val="Hyperlink"/><w:noProof/></w:rPr>'
            f'<w:t xml:space="preserve">{num} {esc(titulo)}</w:t></w:r>'
            '<w:r><w:rPr><w:noProof/><w:webHidden/></w:rPr><w:tab/></w:r>'
            '<w:r><w:rPr><w:noProof/><w:webHidden/></w:rPr>'
            '<w:fldChar w:fldCharType="begin"/></w:r>'
            '<w:r><w:rPr><w:noProof/><w:webHidden/></w:rPr>'
            f'<w:instrText xml:space="preserve"> PAGEREF {bm} \\h </w:instrText></w:r>'
            '<w:r><w:rPr><w:noProof/><w:webHidden/></w:rPr>'
            '<w:fldChar w:fldCharType="separate"/></w:r>'
            '<w:r><w:rPr><w:noProof/><w:webHidden/></w:rPr>'
            f'<w:t>{pagina}</w:t></w:r>'
            '<w:r><w:rPr><w:noProof/><w:webHidden/></w:rPr>'
            '<w:fldChar w:fldCharType="end"/></w:r>'
            '</w:hyperlink></w:p>')


def editar_indice(chunk, indice, capitulos, bookmarks, paginas):
    # título opcional
    if indice.get('titulo'):
        chunk = reemplazo_unico(chunk, '<w:t>Índice</w:t>',
                                f'<w:t xml:space="preserve">{esc(indice["titulo"])}</w:t>',
                                'título del índice')
    # resumen del índice
    pat = re.compile(
        r'(<w:p\b[^>]*>(?:(?!</w:p>).)*?<w:pStyle w:val="Resumencaptulo"/>'
        r'(?:(?!</w:p>).)*?</w:pPr>)(?:(?!</w:p>).)*?(</w:p>)', re.DOTALL)
    m = pat.search(chunk)
    if not m:
        die('No se encontró el resumen del índice en la plantilla.')
    chunk = (chunk[:m.start()] + m.group(1)
             + runs_de_texto(indice.get('resumen', '')) + m.group(2)
             + chunk[m.end():])

    # sustituir el bloque de entradas TOC1
    entradas = re.findall(r'<w:p\b[^>]*>(?:(?!</w:p>).)*?w:val="TOC1"(?:(?!</w:p>).)*?</w:p>',
                          chunk, re.DOTALL)
    if not entradas:
        die('No se encontraron entradas TOC1 en la plantilla.')
    ini = chunk.find(entradas[0])
    fin = chunk.find(entradas[-1]) + len(entradas[-1])
    nuevas = ''.join(
        entrada_toc(i + 1, cap['titulo'], bookmarks[i], paginas[i], i == 0)
        for i, cap in enumerate(capitulos))
    return chunk[:ini] + nuevas + chunk[fin:]


def arreglar_estilo_indice(tmp):
    """Elimina la numeración automática del estilo TOC1.

    El estilo TOC1 de la plantilla lleva su propia numeración (01, 02…) marcada
    como texto oculto (<w:vanish/>): Word no la muestra, pero LibreOffice y
    Google Docs sí, y el número aparece duplicado ("01  01 Título") porque el
    texto de la entrada ya incluye el número del capítulo. Al quitarla, el
    índice se ve igual en Word y correcto en cualquier visor. Se reajusta la
    sangría, que la aportaba el nivel de lista.
    """
    ruta = os.path.join(tmp, 'word', 'styles.xml')
    styles = open(ruta, encoding='utf-8').read()
    m = re.search(r'<w:style w:type="paragraph"[^>]*w:styleId="TOC1">.*?</w:style>',
                  styles, re.DOTALL)
    if not m:
        warn('No se encontró el estilo TOC1; el índice puede mostrar el número '
             'duplicado en visores distintos de Word.')
        return
    bloque = m.group(0)
    nuevo = re.sub(r'<w:numPr>.*?</w:numPr>', '', bloque, flags=re.DOTALL)
    nuevo = re.sub(r'<w:ind[^/]*/>', '<w:ind w:left="560" w:hanging="560"/>', nuevo, 1)
    open(ruta, 'w', encoding='utf-8').write(styles.replace(bloque, nuevo, 1))


def arreglar_numeracion_capitulos(tmp):
    """Hace que la numeración de capítulo sea 01, 02 … 09, 10, 11.

    La plantilla la define con el formato literal "0%1", que a partir del capítulo
    diez produce "010". Ese número no se ve en el cuerpo (va en blanco a 1 pt),
    pero es el que Word copia al índice cuando refresca los campos. Con
    `decimalZero` el cero solo se añade por debajo de diez.
    """
    ruta = os.path.join(tmp, 'word', 'numbering.xml')
    n = open(ruta, encoding='utf-8').read()
    bloques = re.findall(r'<w:lvl w:ilvl="0"[^>]*>(?:(?!</w:lvl>).)*?'
                         r'<w:pStyle w:val="Heading1"/>(?:(?!</w:lvl>).)*?</w:lvl>',
                         n, re.DOTALL)
    if not bloques:
        warn('No se encontró la numeración de Título 1; con más de nueve capítulos '
             'el índice puede mostrar "010" tras refrescar los campos en Word.')
        return
    for b in bloques:
        nuevo = (b.replace('<w:numFmt w:val="decimal"/>',
                           '<w:numFmt w:val="decimalZero"/>')
                  .replace('<w:lvlText w:val="0%1"/>', '<w:lvlText w:val="%1"/>'))
        n = n.replace(b, nuevo, 1)
    open(ruta, 'w', encoding='utf-8').write(n)


def extraer_sectpr(chunk):
    m = re.search(r'<w:sectPr.*?</w:sectPr>', chunk, re.DOTALL)
    if not m:
        die('No se pudo extraer un sectPr de la plantilla.')
    return m.group(0)


def construir_capitulo(cap, bm, bm_id, sectpr, num_capitulo):
    partes = [p_heading1(cap['titulo'], bm, bm_id)]
    if cap.get('resumen'):
        partes.append(p_resumen(cap['resumen']))
    contador_h2 = [0]
    for b in cap.get('bloques', []):
        partes.append(render_bloque(b, num_capitulo, contador_h2))
    if sectpr is not None:   # capítulos que no son el último
        partes.append('<w:p><w:pPr><w:spacing w:after="0"/>'
                      f'<w:rPr><w:sz w:val="2"/></w:rPr>{sectpr}</w:pPr></w:p>')
    return ''.join(partes)


# ---------------------------------------------------------------------------
# Cabeceras por capítulo con número y título literales
#
# La plantilla usa campos STYLEREF para el número gigante y el rótulo
# "CAP. XX · TÍTULO". Word los resuelve bien, pero LibreOffice y Google Docs
# los muestran como "Error: Reference source not found". Como el generador
# conoce el número y el título de cada capítulo, crea una pareja de cabeceras
# por capítulo con los valores ya escritos: el resultado es idéntico en Word
# y correcto en cualquier otro visor.
# ---------------------------------------------------------------------------

CT_HEADER = ('application/vnd.openxmlformats-officedocument.'
             'wordprocessingml.header+xml')
REL_HEADER = ('http://schemas.openxmlformats.org/officeDocument/2006/'
              'relationships/header')


def _sin_campos(xml):
    """Elimina los campos (begin..separate y end) dejando el resultado literal."""
    xml = re.sub(r'<w:fldChar w:fldCharType="begin"/>.*?'
                 r'<w:fldChar w:fldCharType="separate"/>', '', xml, flags=re.DOTALL)
    return xml.replace('<w:fldChar w:fldCharType="end"/>', '')


def _sin_blip_svg(xml):
    """Quita la variante SVG de las imágenes recortadas con srcRect.

    El símbolo "n" de la cabecera de continuación es un recorte (srcRect) de una
    imagen que viene en dos versiones: PNG y SVG. LibreOffice y Google Docs
    aplican mal el recorte sobre el SVG y dibujan el símbolo deformado y a menor
    tamaño. Al dejar solo el PNG (1792x1500 px para un icono de 11 pt, de sobra),
    el recorte se aplica bien en todos los visores.
    """
    if 'srcRect' not in xml:
        return xml
    return re.sub(r'<a:extLst><a:ext uri="\{96DAC541-7B7A-43D3-8B79-37D633B846F1\}">'
                  r'.*?</a:extLst>', '', xml, flags=re.DOTALL)


def hornear_cabeceras(tmp, capitulos):
    """Crea headerA{i}/headerC{i} con número y título literales.
    Devuelve [(rid_apertura, rid_continuacion), ...] por capítulo."""
    ruta = lambda *p: os.path.join(tmp, *p)
    h_ap = _sin_campos(open(ruta('word', 'header4.xml'), encoding='utf-8').read())
    h_cont = _sin_blip_svg(
        _sin_campos(open(ruta('word', 'header2.xml'), encoding='utf-8').read()))
    rels_cont = open(ruta('word', '_rels', 'header2.xml.rels'), encoding='utf-8').read()

    rels_doc = open(ruta('word', '_rels', 'document.xml.rels'), encoding='utf-8').read()
    ctypes = open(ruta('[Content_Types].xml'), encoding='utf-8').read()

    refs, nuevas_rels, nuevos_ct = [], [], []
    for i, cap in enumerate(capitulos):
        num = f'{i + 1:02d}'
        titulo_may = cap['titulo'].upper()
        fa, fc = f'headerA{i + 1}.xml', f'headerC{i + 1}.xml'
        open(ruta('word', fa), 'w', encoding='utf-8').write(
            h_ap.replace('>06<', f'>{num}<'))
        open(ruta('word', fc), 'w', encoding='utf-8').write(
            h_cont.replace('>06<', f'>{num}<')
                  .replace('>PLAN DE TRABAJO<', f'>{esc(titulo_may)}<'))
        # la cabecera de continuación lleva el logo: necesita sus relaciones
        open(ruta('word', '_rels', fc + '.rels'), 'w', encoding='utf-8').write(rels_cont)
        ra, rc = f'rIdCapA{i + 1}', f'rIdCapC{i + 1}'
        nuevas_rels.append(f'<Relationship Id="{ra}" Type="{REL_HEADER}" Target="{fa}"/>')
        nuevas_rels.append(f'<Relationship Id="{rc}" Type="{REL_HEADER}" Target="{fc}"/>')
        nuevos_ct.append(f'<Override PartName="/word/{fa}" ContentType="{CT_HEADER}"/>')
        nuevos_ct.append(f'<Override PartName="/word/{fc}" ContentType="{CT_HEADER}"/>')
        refs.append((ra, rc))

    rels_doc = rels_doc.replace('</Relationships>',
                                ''.join(nuevas_rels) + '</Relationships>', 1)
    open(ruta('word', '_rels', 'document.xml.rels'), 'w', encoding='utf-8').write(rels_doc)
    ctypes = ctypes.replace('</Types>', ''.join(nuevos_ct) + '</Types>', 1)
    open(ruta('[Content_Types].xml'), 'w', encoding='utf-8').write(ctypes)
    return refs


def sectpr_con_refs(sectpr_base, rid_ap, rid_cont, rid_footer_ap):
    """Inserta referencias explícitas de cabecera/pie en un sectPr."""
    sectpr = re.sub(r'<w:(header|footer)Reference[^/]*/>', '', sectpr_base)
    refs = (f'<w:headerReference w:type="first" r:id="{rid_ap}"/>'
            f'<w:headerReference w:type="default" r:id="{rid_cont}"/>'
            f'<w:footerReference w:type="first" r:id="{rid_footer_ap}"/>')
    return re.sub(r'(<w:sectPr[^>]*>)', r'\1' + refs, sectpr, 1)


# ---------------------------------------------------------------------------
# Números de página reales (renderizado con LibreOffice)
# ---------------------------------------------------------------------------

def _soffice():
    for cand in ('soffice', 'libreoffice'):
        path = shutil.which(cand)
        if path:
            return path
    return None


def paginas_reales(docx_path, capitulos):
    """Devuelve la página PDF donde arranca cada capítulo, o None si no hay soffice."""
    soffice = _soffice()
    if not soffice or not shutil.which('pdftotext'):
        return None
    with tempfile.TemporaryDirectory() as tmp:
        env = dict(os.environ)
        try:
            subprocess.run(
                [soffice, '--headless',
                 f'-env:UserInstallation=file://{tmp}/lo_profile',
                 '--convert-to', 'pdf', '--outdir', tmp, docx_path],
                check=True, capture_output=True, timeout=300, env=env)
        except Exception as e:
            warn(f'No se pudo renderizar para calcular páginas ({e}).')
            return None
        pdf = os.path.join(tmp, os.path.splitext(os.path.basename(docx_path))[0] + '.pdf')
        if not os.path.exists(pdf):
            return None
        # El índice puede ocupar más de una página cuando hay muchos capítulos, y
        # sus entradas contienen los títulos: buscar desde la página 3 daría un
        # falso positivo. Se localiza la última página con puntos conductores.
        fin_indice = 2
        for pg in range(2, 12):
            try:
                out = subprocess.run(['pdftotext', '-f', str(pg), '-l', str(pg), pdf, '-'],
                                     check=True, capture_output=True, timeout=60)
            except subprocess.CalledProcessError:
                break
            if '........' in out.stdout.decode('utf-8', 'replace'):
                fin_indice = pg
            else:
                break

        paginas, pagina_busqueda = [], fin_indice
        for cap in capitulos:
            titulo = ' '.join(cap['titulo'].split())
            encontrada = None
            for pg in range(pagina_busqueda + 1, 400):
                try:
                    out = subprocess.run(
                        ['pdftotext', '-f', str(pg), '-l', str(pg), pdf, '-'],
                        check=True, capture_output=True, timeout=60)
                except subprocess.CalledProcessError:
                    break
                texto = ' '.join(out.stdout.decode('utf-8', 'replace').split())
                if texto == '' and pg > pagina_busqueda + 60:
                    break
                if titulo in texto:
                    encontrada = pg
                    break
            if encontrada is None:
                warn(f'No se localizó la página del capítulo «{cap["titulo"]}».')
                return None
            paginas.append(encontrada)
            pagina_busqueda = encontrada
        return paginas


# ---------------------------------------------------------------------------
# Empaquetado
# ---------------------------------------------------------------------------

def desempaquetar(docx, destino):
    with zipfile.ZipFile(docx) as z:
        for info in z.infolist():
            if info.filename.endswith('/'):
                continue
            ruta = os.path.join(destino, info.filename)
            os.makedirs(os.path.dirname(ruta), exist_ok=True)
            with z.open(info) as f, open(ruta, 'wb') as g:
                g.write(f.read())


def empaquetar(carpeta, salida):
    if os.path.exists(salida):
        os.remove(salida)
    archivos = []
    for raiz, _dirs, fics in os.walk(carpeta):
        for f in fics:
            ruta = os.path.join(raiz, f)
            archivos.append((os.path.relpath(ruta, carpeta).replace(os.sep, '/'), ruta))
    archivos.sort(key=lambda t: (t[0] != '[Content_Types].xml', t[0]))
    with zipfile.ZipFile(salida, 'w', zipfile.ZIP_DEFLATED) as z:
        for nombre, ruta in archivos:
            z.write(ruta, nombre)


# ---------------------------------------------------------------------------
# Principal
# ---------------------------------------------------------------------------

def generar(contenido, plantilla, salida, calcular_paginas=True):
    capitulos = contenido.get('capitulos', [])
    if not capitulos:
        die('El contenido no tiene capítulos.')

    bookmarks = [f'_Toc90000{i + 1:04d}' for i in range(len(capitulos))]
    paginas_estimadas = [3 + 2 * i for i in range(len(capitulos))]

    def montar(paginas):
        tmp = tempfile.mkdtemp(prefix='nazaries_doc_')
        desempaquetar(plantilla, tmp)
        ruta_doc = os.path.join(tmp, 'word', 'document.xml')
        xml = open(ruta_doc, encoding='utf-8').read()

        ini_body = xml.find('<w:body>') + len('<w:body>')
        fin_body = xml.rfind('</w:body>')
        cabecera_xml, cola_xml = xml[:ini_body], xml[fin_body:]
        chunks = dividir_en_secciones(xml[ini_body:fin_body])
        if len(chunks) != 11:
            die(f'La plantilla no tiene la estructura esperada '
                f'(se esperaban 11 secciones y hay {len(chunks)}).')

        portada = editar_portada(chunks[0], contenido.get('portada', {}))
        indice = editar_indice(chunks[1], contenido.get('indice', {}),
                               capitulos, bookmarks, paginas)

        sectpr_cap1 = extraer_sectpr(chunks[2])      # con refs de apertura
        sectpr_medio = extraer_sectpr(chunks[3])     # sin refs
        sectpr_final = extraer_sectpr(chunks[10])    # sectPr del body

        # pie de apertura de capítulo (footer4) — se reutiliza tal cual
        m_foot = re.search(r'<w:footerReference w:type="first" r:id="([^"]+)"/>',
                           sectpr_cap1)
        if not m_foot:
            die('No se encontró el pie de apertura de capítulo en la plantilla.')
        rid_footer_ap = m_foot.group(1)

        # cabeceras con número y título literales, una pareja por capítulo
        refs_caps = hornear_cabeceras(tmp, capitulos)

        # el índice no debe mostrar el número duplicado
        arreglar_estilo_indice(tmp)
        # numeración de capítulo 01..09, 10, 11 en lugar de "010"
        arreglar_numeracion_capitulos(tmp)

        cuerpo_caps = []
        n = len(capitulos)
        for i, cap in enumerate(capitulos):
            if i < n - 1:
                sectpr = sectpr_con_refs(sectpr_medio, refs_caps[i][0],
                                         refs_caps[i][1], rid_footer_ap)
            else:
                sectpr = None
            cuerpo_caps.append(construir_capitulo(cap, bookmarks[i], 900 + i, sectpr, i + 1))

        # sectPr de cierre del documento (última sección = último capítulo)
        cierre = sectpr_con_refs(sectpr_final, refs_caps[-1][0],
                                 refs_caps[-1][1], rid_footer_ap)

        nuevo = (cabecera_xml + portada + indice + ''.join(cuerpo_caps)
                 + cierre + cola_xml)
        open(ruta_doc, 'w', encoding='utf-8').write(nuevo)

        # activar la actualización de campos al abrir en Word
        ruta_set = os.path.join(tmp, 'word', 'settings.xml')
        settings = open(ruta_set, encoding='utf-8').read()
        if '<w:updateFields' not in settings:
            upd = '<w:updateFields w:val="true"/>'
            for ancla in ('<w:hdrShapeDefaults>', '<w:footnotePr>', '<w:compat>',
                          '</w:settings>'):
                if ancla in settings:
                    settings = settings.replace(ancla, upd + ancla, 1)
                    break
            open(ruta_set, 'w', encoding='utf-8').write(settings)

        empaquetar(tmp, salida)
        shutil.rmtree(tmp, ignore_errors=True)

    montar(paginas_estimadas)

    if calcular_paginas:
        reales = paginas_reales(salida, capitulos)
        if reales and reales != paginas_estimadas:
            montar(reales)
            print(f'  Páginas del índice calculadas: {reales}')
        elif reales:
            print(f'  Páginas del índice calculadas: {reales}')
        else:
            warn('Los números de página del índice quedan estimados; '
                 'Word los corregirá al abrir el documento.')

    print(f'Documento generado: {salida}')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    plantilla = None
    for i, a in enumerate(sys.argv):
        if a == '--template' and i + 1 < len(sys.argv):
            plantilla = sys.argv[i + 1]
            args = [x for x in args if x != plantilla]
    if len(args) != 2:
        print(__doc__)
        sys.exit(1)
    ruta_json, salida = args
    if plantilla is None:
        plantilla = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 '..', 'assets', 'plantilla_word_v1.docx')
    if not os.path.exists(plantilla):
        die(f'No existe la plantilla: {plantilla}')
    contenido = json.load(open(ruta_json, encoding='utf-8'))
    generar(contenido, plantilla, salida,
            calcular_paginas='--sin-paginas-toc' not in sys.argv)


if __name__ == '__main__':
    main()
