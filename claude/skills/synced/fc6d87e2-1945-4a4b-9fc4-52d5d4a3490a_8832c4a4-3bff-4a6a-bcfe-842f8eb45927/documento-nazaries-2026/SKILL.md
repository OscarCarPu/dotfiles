---
name: documento-nazaries-2026
description: Genera documentos oficiales de Nazaríes en Word (.docx) con la plantilla corporativa 2026 y la identidad verbal de la marca, para informes, auditorías, memorias técnicas, presupuestos, planes de proyecto, propuestas, licitaciones y cualquier entregable con identidad corporativa. Úsala SIEMPRE que alguien del equipo pida crear, redactar, preparar o generar un informe, documento o entregable "con la plantilla", "con formato Nazaríes" u "oficial", aunque no mencione el .docx. Úsala también cuando pregunten por la voz, el tono, los principios editoriales, las brand words o la definición oficial de la empresa; cuando haya que revisar un texto para que suene a Nazaríes y no a IA; o cuando se necesiten datos corporativos (razón social y CIF, certificaciones ISO y ENS, plantilla, oficinas, clientes de referencia, premios, servicios) para una propuesta o un dosier de solvencia. El flujo es proponer la estructura, redactar con la voz de marca, auditar el texto y generar el .docx con build_doc.py.
---

# Documento oficial Nazaríes (plantilla corporativa 2026)

Genera documentos .docx con la plantilla corporativa: portada a página completa, índice con numeración y páginas, y un capítulo por sección de Word con su apertura de diseño (rótulo "CAP. XX", número de gran formato, línea) y cabecera de continuación "CAP. XX · TÍTULO". El diseño (colores, tipografía Gellix, formas, logos en cabeceras y pies) viene de la plantilla; **todo el contenido de texto se sustituye**.

La skill cubre las dos mitades del entregable: el formato lo resuelve el script, y la redacción sigue la identidad verbal de la marca (`references/`). Un documento con la plantilla perfecta y un texto que suena a IA genérica no sirve.

Todas las rutas de este documento son relativas a la carpeta de esta skill.

## Flujo de trabajo

### 0. Preparar el entorno (una vez por sesión)

Instalar las fuentes Gellix ANTES de generar nada. El script calcula las páginas del índice renderizando el documento: sin las fuentes, la paginación puede salir distinta de la real.

```bash
mkdir -p ~/.fonts && cp assets/fonts/*.ttf ~/.fonts/ && fc-cache -f
```

### 1. Recopilar el contenido y proponer la estructura

Reunir: tipo de documento, cliente, fecha/versión/referencia y el material de origen. Si la petición es abierta, **proponer primero al usuario la lista de capítulos** (título + una frase de resumen por capítulo) y esperar su OK. Si el usuario ya dio el contenido detallado, continuar directamente.

### 2. Leer las referencias antes de escribir una línea

- `references/identidad_verbal.md`: la voz de Nazaríes, los dos tonos y cuándo aplica cada uno, los principios editoriales (*Write with clarity*, *People before labels*), los recursos verbales (*Beyond*, *Scenario shift*), las brand words y la definición oficial de la empresa. Resume el manual, que está completo en `assets/NAZARIES_Identidad_Verbal.pdf`.
- `references/estilo_humano.md`: qué delata a un texto generado automáticamente y cómo evitarlo.
- `references/paleta.md`: la paleta oficial y el color que corresponde a cada elemento del documento. Solo hace falta al añadir elementos gráficos nuevos.

Y esta otra, solo cuando el documento necesita datos de la empresa (licitaciones, propuestas formales, dosieres de solvencia, memorias, contratos):

- `references/datos_empresa.md`: identificación fiscal, dimensión y equipo, certificaciones, premios, servicios, modelo PowerCrew, clientes de referencia, diferenciadores y valores vigentes. Incluye la lista de datos que no están y hay que preguntar (volumen de negocio, pólizas, fechas de certificados), y la advertencia de no inventar ninguno.

Por defecto, los documentos de esta skill usan el **tono experto y de criterio** (informes, auditorías, propuestas, memorias, presupuestos). Se cambia al **tono cercano y de evolución** cuando el destinatario es el propio equipo o la comunidad: onboarding, cultura, marca empleadora.

Lo que más pesa para que el documento no parezca generado: **especificidad**. Cada capítulo debe apoyarse en un dato del material del cliente (cifra, fecha, nombre de sistema, plazo). Si el dato no está, se pregunta al usuario. Nunca se inventa una cifra.

### 3. Escribir el JSON de contenido

Ejecutar `python3 scripts/build_doc.py` sin argumentos imprime el esquema completo. Versión compacta:

```json
{
  "portada": {
    "rotulo":    "INFORME TÉCNICO – 2026",
    "titulo":    "Título grande\ncon salto opcional",
    "subtitulo": "Hasta tres líneas\nseparadas por \\n.",
    "datos": [ {"rotulo": "PREPARADO PARA", "valor": "Cliente S.L."},
               {"rotulo": "FECHA", "valor": "Julio 2026"},
               {"rotulo": "VERSIÓN", "valor": "v1.0"},
               {"rotulo": "REFERENCIA", "valor": "NZ-2026-041"} ]
  },
  "indice": { "resumen": "Texto introductorio bajo el título Índice." },
  "capitulos": [
    { "titulo": "Resumen ejecutivo",
      "resumen": "Entradilla en verde bajo el título del capítulo.",
      "bloques": [
        {"tipo": "parrafo", "texto": "Párrafo justificado. Admite **negrita**."},
        {"tipo": "h2", "texto": "Subtítulo numerado automáticamente (n.1., n.2., …)"},
        {"tipo": "h3", "texto": "Encabezado menor en azul matiz, sin numerar"},
        {"tipo": "vinetas", "items": ["Una viñeta", "Otra viñeta"]},
        {"tipo": "tabla",
         "cabecera": ["Fase", "Duración", "Objetivo"],
         "filas": [["01 · Descubrimiento", "2 semanas", "Auditoría y roadmap"]],
         "fila_total": ["Total", "16 semanas", ""],
         "anchos": [3, 2, 5]},
        {"tipo": "nota", "texto": "Caja destacada sobre fondo turquesa claro."}
      ] }
  ]
}
```

`fila_total` y `anchos` (pesos relativos de columna) son opcionales. En `parrafo`, `vinetas` y `nota`: `**texto**` → Gellix Medium (énfasis corporativo) y `\n` → salto de línea.

Reglas de contenido:
- **No escribir números en los títulos** de capítulo ni en los h2: los pone el generador. Los capítulos van 01, 02 … 09, 10, 11 y los subtítulos n.1., n.2. No hay límite de capítulos.
- Título de portada: máximo 2 líneas cortas (~22 caracteres por línea; cuerpo 45 pt). Usar `\n` para el salto.
- Subtítulo de portada: hasta 3 líneas separadas por `\n`. Datos de portada: hasta 4 pares, rótulos cortos en MAYÚSCULAS.
- `resumen` de capítulo: 1–3 frases; es la entradilla que da aire a la apertura.
- Redactar en el idioma del usuario (castellano por defecto), con la voz y el tono de las referencias del paso 2.

### 4. Auditar el texto

```bash
python3 scripts/revisar_texto.py contenido.json
```

Detecta guiones largos, muletillas de modelo, adjetivos vacíos, formas con x o @, sintaxis contrastiva repetida, párrafos de longitud calcada, viñetas simétricas, exceso de enumeraciones de tres, exceso de negritas y capítulos sin ningún dato numérico. Corregir todo lo que salga como ALTA y decidir sobre el resto. Devuelve 1 si queda algo de gravedad alta.

Lo que el script no ve hay que leerlo: frases que valdrían para cualquier empresa, adjetivos donde debería haber un dato, secciones que se cierran resumiendo lo ya dicho. La lista de repaso está al final de `references/estilo_humano.md`.

### 5. Generar el documento

```bash
python3 scripts/build_doc.py contenido.json "Informe_Cliente_Tema.docx"
```

Nombre de archivo: `[Tipo]_[Cliente]_[Tema].docx` (p. ej. `Auditoria_DistribucionesVega_PlataformaDatos.docx`).

El script monta portada, índice y capítulos (una sección de Word por capítulo), escribe las cabeceras de cada capítulo y calcula las páginas reales del índice renderizando el documento con LibreOffice. Con `--sin-paginas-toc` se salta ese cálculo: las páginas quedan estimadas y Word las corrige al abrir.

### 6. Validar antes de entregar

```bash
python /mnt/skills/public/docx/scripts/office/validate.py salida.docx --original assets/plantilla_word_v1.docx
```

Si algo parece raro (títulos que desbordan, páginas del índice descuadradas), convertir a
PDF y comprobar el texto:

```bash
python /mnt/skills/public/docx/scripts/office/soffice.py --headless --convert-to pdf salida.docx
pdftotext -layout salida.pdf - | less
```

### 7. Entregar

Copiar el .docx a `/mnt/user-data/outputs` y compartirlo con `present_files`. PDF solo si lo piden.

## Detalles técnicos que conviene saber

- **Cabeceras horneadas.** La plantilla usa campos STYLEREF para el número y el título de
  cada cabecera, y esos campos fallan fuera de Word. El script escribe una pareja de
  cabeceras por capítulo con los valores ya puestos. Consecuencia práctica: si alguien
  renombra un capítulo a mano en Word, su cabecera no se actualiza sola; lo correcto es
  regenerar el documento.
- **Correcciones que el script aplica sobre la plantilla**, porque son defectos que se ven
  fuera de Word o que la plantilla arrastra latentes: alineación izquierda en la portada
  (el estilo Normal justifica y estira el título), número del índice sin duplicar, símbolo
  "n" de la cabecera de continuación a su tamaño real y numeración de capítulo con
  `decimalZero`, que da 01..09, 10, 11 en lugar del "010" del formato original.
- **Numeración de subtítulos.** El número del subtítulo ("2.1.") lo escribe el generador
  como texto, no como lista automática: el contador de Título 1 tiene que dar 01..09, 10 y
  los dos formatos no conviven en un mismo esquema de lista. Consecuencia práctica: si
  alguien inserta un subtítulo a mano en Word, los siguientes no se renumeran solos; lo
  correcto es regenerar.
- **El asset `assets/plantilla_word_v1.docx`** es la plantilla oficial con los runs de
  texto normalizados. No sustituirla sin revisar las anclas del script: si `build_doc.py`
  falla con "No se encontró en la plantilla el ancla…", es que la plantilla cambió.
- **Elementos decorativos del ejemplo de la plantilla** (tarjetas de valor, workstreams
  con iconos, páginas de estadísticas sobre fondo oscuro) no los genera el script: son
  maquetación manual. Si el usuario los pide, generar el documento base y editar el OOXML
  aparte, avisando del esfuerzo extra.
- **Color.** La plantilla y el generador usan solo la paleta oficial
  (`references/paleta.md`, fuente en `assets/PALETA_NAZARIES_RGB.ase`). La plantilla que
  entregó bRIDA traía veintiún colores fuera de paleta y se han sustituido por su
  equivalente oficial más cercano. Única excepción: la portada, que conserva los colores
  originales porque el equivalente más cercano fusiona capas de su rampa de fondo y pierde
  profundidad. Al añadir cualquier elemento nuevo, tomar el color de esa referencia.

## Relación con otras skills

- `logos-nazaries`: logos oficiales en SVG para otros entregables (esta plantilla ya lleva los suyos en cabeceras, pies y portada).
- `propuesta-cliente` y `presentation-cliente`: formatos específicos ya establecidos (propuesta .docx clásica y presentación .pptx). Si el usuario pide explícitamente esos formatos, valorar esas skills; para documentos con la plantilla corporativa 2026, usar esta.
