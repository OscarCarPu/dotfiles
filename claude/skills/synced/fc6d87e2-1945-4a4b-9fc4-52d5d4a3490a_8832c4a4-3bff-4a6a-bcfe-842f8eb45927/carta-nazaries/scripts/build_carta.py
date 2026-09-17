#!/usr/bin/env python3
"""Genera una carta o declaración de Nazaríes sobre el papel corporativo.

Uso:
    python3 scripts/build_carta.py contenido.json "Declaracio_Responsable.docx"
    python3 scripts/build_carta.py            # imprime el esquema del JSON

El script copia assets/plantilla_carta.docx (papel con logo, pie y márgenes),
sustituye el marcador <!--BODY--> por los párrafos generados y escribe el .docx.
No toca cabecera, pie, estilos ni imágenes.
"""

import json
import os
import re
import shutil
import sys
import zipfile

AQUI = os.path.dirname(os.path.abspath(__file__))
PLANTILLA = os.path.join(AQUI, "..", "assets", "plantilla_carta.docx")

# --- Constantes de diseño, tomadas del papel corporativo -------------------
TINTA = "00333B"        # verde azulado oscuro: todo el texto
ACENTO = "C1E4D6"       # verde claro: solo el cargo en la firma
CUERPO = "Gellix"       # regular
ENFASIS = "Gellix Medium"
TAM = "18"              # medios puntos -> 9 pt
SANGRIA = "3402"        # twips: la columna de texto arranca a 6 cm del margen
ESPACIADO = '<w:spacing w:after="160" w:line="20" w:lineRule="atLeast"/>'
NUMID_VINETA = "4"      # lista de guiones ya definida en numbering.xml

ESQUEMA = """
{
  "bloques": [
    {"tipo": "titulo",  "texto": "DECLARACIÓ RESPONSABLE"},
    {"tipo": "parrafo", "texto": "Texto justificado. Admite **énfasis** en Gellix Medium."},
    {"tipo": "vinetas", "items": ["Primer punto", "Segundo punto"]},
    {"tipo": "espacio"},
    {"tipo": "firma",   "nombre": "Eduardo Haro Amate", "cargo": "CEO"}
  ]
}

Tipos de bloque:
  titulo   - una linea, Gellix Medium en negrita. Normalmente uno solo, arriba.
  parrafo  - texto justificado. **entre asteriscos** -> Gellix Medium negrita.
  vinetas  - lista de guiones. Usar poco: una carta se lee mejor en prosa.
  espacio  - parrafo en blanco. Antes de la firma se ponen 3 o 4.
  firma    - nombre en tinta + cargo en verde claro, sin justificar.
"""


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def run(texto, fuente=CUERPO, negrita=False, color=TINTA, tam=TAM):
    rpr = f'<w:rFonts w:ascii="{fuente}" w:eastAsia="Calibri" w:hAnsi="{fuente}" w:cs="Calibri"/>'
    if negrita:
        rpr += "<w:b/><w:bCs/>"
    rpr += f'<w:color w:val="{color}"/><w:sz w:val="{tam}"/><w:szCs w:val="{tam}"/>'
    return (f"<w:r><w:rPr>{rpr}</w:rPr>"
            f'<w:t xml:space="preserve">{esc(texto)}</w:t></w:r>')


def runs_con_enfasis(texto):
    """Parte el texto por **...** y devuelve los runs correspondientes."""
    salida = []
    for i, trozo in enumerate(re.split(r"\*\*(.+?)\*\*", texto)):
        if not trozo:
            continue
        if i % 2:
            salida.append(run(trozo, fuente=ENFASIS, negrita=True))
        else:
            salida.append(run(trozo))
    return "".join(salida)


def parrafo(contenido_runs, justificar=True, extra_ppr="", ind=None):
    # El esquema de OOXML fija el orden de los hijos de w:pPr:
    # numPr va antes que spacing e ind, y jc despues. Alterarlo invalida el docx.
    ind = ind or f'<w:ind w:left="{SANGRIA}"/>'
    ppr = f"<w:pPr>{extra_ppr}{ESPACIADO}{ind}"
    if justificar:
        ppr += '<w:jc w:val="both"/>'
    ppr += "</w:pPr>"
    return f"<w:p>{ppr}{contenido_runs}</w:p>"


def construir(bloques):
    partes = []
    for b in bloques:
        tipo = b.get("tipo")
        if tipo == "titulo":
            partes.append(parrafo(run(b["texto"], fuente=ENFASIS, negrita=True)))
        elif tipo == "parrafo":
            partes.append(parrafo(runs_con_enfasis(b["texto"])))
        elif tipo == "vinetas":
            extra = (f'<w:numPr><w:ilvl w:val="0"/>'
                     f'<w:numId w:val="{NUMID_VINETA}"/></w:numPr>')
            # Sin este ind explicito el guion se va al margen izquierdo,
            # fuera de la columna de texto.
            ind_vin = (f'<w:ind w:left="{int(SANGRIA) + 340}" w:hanging="340"/>')
            for item in b["items"]:
                partes.append(parrafo(runs_con_enfasis(item),
                                      extra_ppr=extra, ind=ind_vin))
        elif tipo == "espacio":
            partes.append(parrafo(""))
        elif tipo == "firma":
            cuerpo = run(b["nombre"])
            cuerpo += ('<w:r><w:rPr><w:rFonts w:ascii="%s" w:hAnsi="%s"/>'
                       '<w:color w:val="%s"/><w:sz w:val="%s"/></w:rPr><w:br/></w:r>'
                       % (CUERPO, CUERPO, TINTA, TAM))
            cuerpo += run(b["cargo"], negrita=True, color=ACENTO)
            partes.append(parrafo(cuerpo, justificar=False))
        else:
            raise SystemExit(f"Tipo de bloque desconocido: {tipo!r}")
    return "".join(partes)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        print(ESQUEMA)
        return 0

    with open(sys.argv[1], encoding="utf-8") as fh:
        datos = json.load(fh)
    destino = sys.argv[2]

    if not os.path.exists(PLANTILLA):
        raise SystemExit(f"No encuentro la plantilla en {PLANTILLA}")

    tmp = destino + ".tmp.docx"
    shutil.copy(PLANTILLA, tmp)

    with zipfile.ZipFile(tmp) as z:
        contenidos = {n: z.read(n) for n in z.namelist()}

    doc = contenidos["word/document.xml"].decode("utf-8")
    if "<!--BODY-->" not in doc:
        raise SystemExit("La plantilla no tiene el marcador <!--BODY-->; "
                         "se habrá regenerado mal.")
    doc = doc.replace("<!--BODY-->", construir(datos["bloques"]))
    contenidos["word/document.xml"] = doc.encode("utf-8")

    with zipfile.ZipFile(destino, "w", zipfile.ZIP_DEFLATED) as z:
        for nombre, datos_bin in contenidos.items():
            z.writestr(nombre, datos_bin)
    os.remove(tmp)

    print(f"Escrito {destino}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
