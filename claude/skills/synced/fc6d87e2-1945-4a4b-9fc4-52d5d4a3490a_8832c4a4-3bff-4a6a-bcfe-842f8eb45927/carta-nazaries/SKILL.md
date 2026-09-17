---
name: carta-nazaries
description: "Genera cartas, declaraciones responsables, escritos y certificados de Nazaríes en Word (.docx) sobre el papel corporativo: logo, columna de texto a 6 cm, tipografía Gellix y pie con datos de contacto. Úsala SIEMPRE que alguien pida redactar, preparar o generar una carta, una declaración, una declaración responsable, un escrito de subsanación, un escrito de alegaciones, un recurso, un certificado, una autorización, un compromiso o un anexo de pliego cumplimentado, aunque no mencione el formato ni el .docx. Úsala también cuando digan 'con nuestro papel', 'con la plantilla de carta', 'en formato carta' o 'como el documento de siempre'. No es para informes largos ni memorias técnicas con portada e índice: para eso está documento-nazaries-2026."
---

# Carta o declaración de Nazaríes

Documentos de una a tres páginas sobre el papel corporativo: cabecera con el
logotipo, texto en una columna desplazada a la derecha y pie con el lema
*What if?* y los datos de contacto.

El papel está en `assets/plantilla_carta.docx` y ya contiene cabecera, pie,
imágenes y márgenes. **No se toca ninguna de esas partes**: solo se rellena el
cuerpo. El resultado se genera con `scripts/build_carta.py`.

## Flujo de trabajo

### 0. Instalar las fuentes Gellix (una vez por sesión)

```bash
mkdir -p ~/.fonts && cp /mnt/skills/organization/documento-nazaries-2026/assets/fonts/*.ttf ~/.fonts/ && fc-cache -f
```

Sin esto el .docx sigue siendo correcto (referencia a Gellix por nombre), pero
cualquier conversión a PDF que hagas para revisarlo saldrá con una fuente
sustituta y no verás el documento real.

### 1. Reunir los datos antes de escribir

Destinatario, asunto, qué se pide o se declara, quién firma y con qué cargo.
Los datos de la empresa, el apoderado y el poder notarial están en la skill
`datos-licitacion-nazaries`: consúltala en vez de tirar de memoria, y no
inventes ningún dato que no esté ahí.

### 2. Escribir el JSON de contenido

```bash
python3 scripts/build_carta.py     # imprime el esquema completo
```

Versión corta:

```json
{
  "bloques": [
    {"tipo": "titulo",  "texto": "DECLARACIÓ RESPONSABLE"},
    {"tipo": "espacio"},
    {"tipo": "parrafo", "texto": "Cuerpo justificado, con **énfasis** si hace falta."},
    {"tipo": "vinetas", "items": ["Un punto", "Otro punto"]},
    {"tipo": "espacio"},
    {"tipo": "espacio"},
    {"tipo": "espacio"},
    {"tipo": "firma",   "nombre": "Eduardo Haro Amate", "cargo": "CEO"}
  ]
}
```

Convenciones de redacción:

- Un solo `titulo`, arriba, en mayúsculas y en una línea.
- La fecha va en su propio párrafo, justo antes de los espacios de la firma, con
  la fórmula *"a fecha de la firma electrónica"* (catalán: *"a data de la
  signatura electrònica"*). Nunca una fecha concreta.
- Tres o cuatro `espacio` entre la fecha y la `firma`, para dejar hueco de firma
  manuscrita si acaba imprimiéndose.
- Las `vinetas` con cuentagotas. Una carta se lee mejor en prosa; las listas
  delatan un texto montado a trozos.
- El idioma es el del destinatario, no el nuestro: si el organismo es catalán,
  la carta va en catalán, tratamientos y fórmula de firma incluidos.

### 3. Generar

```bash
python3 scripts/build_carta.py contenido.json "Declaracio_Responsable_Rehabita.docx"
```

Nombre de archivo: `[Tipo]_[Destinatario o expediente].docx`.

### 4. Verificar antes de entregar

```bash
python /mnt/skills/public/docx/scripts/office/validate.py salida.docx --original assets/plantilla_carta.docx
python /mnt/skills/public/docx/scripts/office/soffice.py --headless --convert-to pdf salida.docx
pdftoppm -jpeg -r 100 salida.pdf pag && ls pag-*.jpg   # y mirar las imágenes
```

Mirar el render de verdad, no solo confiar en que validó: lo que más falla es
el texto que desborda a una segunda página casi vacía y la firma que queda
separada del cuerpo.

## Cuando el documento es un modelo de un pliego

Caso frecuente y con una trampa. Si lo que se cumplimenta es un anexo tasado de
un pliego (declaración responsable, modelo de proposición, compromiso de UTE),
el **formato** puede pasarse a este papel, pero el **texto** es intocable: se
reproduce literalmente, con sus erratas, sin reordenar apartados ni mejorar la
redacción. Se rellenan los huecos y nada más. Muchos pliegos excluyen por no
seguir el modelo.

Procedimiento: extraer el texto del modelo del PDF con `pdftotext -layout`,
rasterizar la página con `pdftoppm` para ver casillas y marcas que el extractor
pierde, y al terminar comparar palabra por palabra el resultado contra el
original con `difflib.SequenceMatcher`. Las únicas diferencias admisibles son
los huecos rellenados.

Lo que aún no esté decidido (casillas, opciones SÍ/NO, importes) se deja
señalado y se lista aparte para que lo resuelva una persona. No se marca por
defecto.

## El diseño, por si hay que tocarlo

Constantes al principio de `scripts/build_carta.py`:

| Elemento | Valor |
|---|---|
| Tipografía | Gellix 9 pt; Gellix Medium para énfasis y títulos |
| Tinta | `00333B` (verde azulado oscuro), todo el texto |
| Acento | `C1E4D6` (verde claro), solo el cargo bajo la firma |
| Columna de texto | sangría izquierda de 3402 twips (6 cm) |
| Interlineado | `after 160`, `line 20 atLeast` |
| Página | A4, márgenes 2 cm laterales, 5,3 cm superior, 5,25 cm inferior |

Esa sangría de 6 cm es lo que define el aire del papel. Si un párrafo se sale de
la columna, es que se ha generado sin `w:ind`, no que la plantilla esté mal.

Detalle técnico: en `w:pPr` el esquema OOXML exige que `numPr` vaya antes que
`spacing` e `ind`, y `jc` después. Alterar ese orden produce un .docx que Word
abre pero que no valida.

## Relación con otras skills

- `documento-nazaries-2026`: informes, memorias y propuestas largas, con portada,
  índice y capítulos. Si el documento lleva portada, es esa y no esta.
- `datos-licitacion-nazaries`: de dónde salen el CIF, el apoderado, el DNI y el
  poder notarial. Es la fuente; esta skill solo los coloca.
