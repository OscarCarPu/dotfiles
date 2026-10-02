---
name: apuntes
description: Hacer o continuar apuntes en Markdown (Obsidian) a partir de los PDF de teoría de una asignatura, con el estilo conciso del usuario. Usar cuando pida "haz los apuntes", "esquema", "resume la sección X", "continúa", "siguiente sección" o "iguala el estilo" sobre notas de R*/apuntes/ o de cualquier asignatura en ~/edu.
---

# Apuntes al estilo del usuario

Los apuntes son **esquemas concisos** para estudiar, no una transcripción del PDF. Ante la duda, quitar.

## Dónde está cada cosa

```
<asignatura>/
  plan-docente-*.pdf
  R1/                      # reto / unidad
    teoria/*.pdf           # fuente
    apuntes/<Título>.md    # aquí se escribe
    problemas/             # ejercicios resueltos (no es tarea de esta skill)
```

- Un `.md` por PDF de teoría, con el título del módulo como nombre (con tildes y espacios): `Modelos de datos.md`.
- Sin frontmatter y sin `#` de título: el nombre del archivo ya es el título.

## Flujo

1. **Leer la nota existente** antes de nada. Si el usuario ya ha empezado una sección, continuar desde ahí respetando lo que ha escrito; no reescribir su texto salvo que pida igualar o resumir.
2. Extraer el PDF: `pdftotext -layout teoria/X.pdf <scratchpad>/x.txt`. El índice del principio da la jerarquía de secciones.
3. Si una figura aporta contenido (tablas, comparativas, ejemplos de operaciones), renderizar esa página y mirarla: `pdftoppm -r 80 -f N -l N -png X.pdf <scratchpad>/pg`.
4. Escribir **una sección del PDF cada vez** cuando el usuario va por partes ("siguiente", "continúa" = la siguiente sección del índice).
5. Antes de escribir, mirar otro apunte de la misma asignatura para igualar el estilo.

## Jerarquía

| PDF                             | Markdown                                                        |
| ------------------------------- | --------------------------------------------------------------- |
| Sección `1.`                    | `## Título` (sin número)                                        |
| Subsección `1.1.`               | `### Título`                                                    |
| `1.1.1.` corto (una definición) | Bullet anidado `- **Término**: …` con sub-bullets con tabulador |
| `1.1.1.` con fórmulas o pasos   | `#### Título`                                                   |

Se omiten: introducción del módulo, autoría, leyendas de figuras y bibliografía.

## Formato

- **Definición** de cada concepto en una frase, con el término en negrita y cerca de la redacción del PDF: `Un **modelo de datos** determina…`
- **Bullets** del tipo `- **Término**: explicación breve (ejemplo)`. Sin punto final. Ejemplos entre paréntesis, no en bullets aparte.
- `→` para consecuencias o resultados: `recupera solo ciertos campos → todas las filas`.
- Listas `1)` para clasificaciones numeradas del PDF o pasos de un proceso.
- **Tablas** solo cuando el tema es tabular de verdad: una tabla del propio PDF, una comparación de 3 o más elementos en varias dimensiones (DIKW, niveles de modelado) u operaciones con su comando/fórmula. Nunca una tabla que repita lo que ya dicen los bullets.
- `>` (cita simple) para la frase clave o la idea importante del PDF, como mucho una por sección. Sin callouts `> [!note]`.
- *Cursiva* para términos en inglés: *dataset*, *join*, *logs*.
- Español con tildes.
- Matemáticas en LaTeX (Obsidian + latex-suite): `$…$` en línea y `$$…$$` en bloque; `\operatorname{rg}`, `\iff`, `\Rightarrow`.
- Código en bloques con lenguaje (```` ```r ````, ```` ```python ````), con comentarios breves en línea; para las funciones, una tabla `operación | código`.
- Diagramas, solo si ayudan, en ```` ```mermaid ````.

## Qué dejar y qué quitar

- **Dejar**: definiciones, clasificaciones, diferencias entre conceptos parecidos (proyección frente a subconjunto), condiciones y propiedades, fórmulas y el ejemplo mínimo que aclara.
- **Quitar**: listas largas de ejemplos (dejar 3 o 4), frases de relleno ("veremos a continuación…"), repetir la definición con otras palabras, contenido que no está en la fuente.
- Una subsección del PDF suele quedar en 1–5 líneas.

## Ejemplo

```markdown
## Definiendo modelo de datos

Un **modelo de datos** determina la manera en la que se organizan y estructuran los datos.

### Estructuras de los modelos de datos

- **Estructurados**: longitud y formato determinados (números, fechas, cadenas…). Número de columnas fijo
	- **Generados por máquinas**: sensores, GPS, *logs*
	- **Generados por personas**: datos de entrada, *clickstream*
- **No estructurados**: no se ajustan a un esquema; estructura no predecible. Son la mayoría (≈ 80 %)

### Operaciones con datos

- **Unión**: junta conjuntos con **la misma estructura** y elimina duplicados
- **Proyección**: recupera solo ciertos campos → **todas** las filas de las columnas elegidas
```

Referencias de estilo del usuario: `~/edu/data-science-degree/tipologia-fuentes-datos/R1/apuntes/` y `~/edu/data-science-degree/metodos-numericos/R1/apuntes/Metodos numéricos en álgebra lineal.md` (para apuntes con matemáticas).
