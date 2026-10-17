---
name: apuntes
description: Hacer o continuar apuntes en Markdown a partir de los PDF de teoría de una asignatura, con el estilo conciso del usuario. Usar cuando pida "haz los apuntes", "esquema", "resume la sección X", "continúa", "siguiente sección" o "iguala el estilo" sobre notas de R*/apuntes/ o de cualquier asignatura en ~/edu.
---

# Apuntes al estilo del usuario

Los apuntes son **esquemas concisos** para estudiar, no una transcripción del PDF. Ante la duda, quitar.

**Nunca escribir en los archivos de apuntes.** El usuario los edita él mismo (nvim, Typst): el contenido se le entrega **en el chat**, en un bloque de código, y él lo pega. Solo se lee la nota (y el PDF); no usar Edit/Write sobre `apuntes/` aunque pida "escribe" o "continúa", salvo que diga expresamente que lo escriba tú.

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
4. Entregar en el chat **una sección del PDF cada vez** cuando el usuario va por partes ("siguiente", "continúa" = la siguiente sección del índice).
5. Antes de escribir, mirar otro apunte de la misma asignatura para igualar el estilo.

## Jerarquía

| PDF                             | Markdown                                                        |
| ------------------------------- | --------------------------------------------------------------- |
| Sección `1.`                    | `# Título` (sin número)                                         |
| Subsección `1.1.`               | `## Título`                                                     |
| `1.1.1.` corto (una definición) | Bullet anidado `- **Término**: …` con sub-bullets con tabulador |
| `1.1.1.` con fórmulas o pasos   | `### Título`                                                    |

Se omiten: introducción del módulo, autoría, leyendas de figuras y bibliografía.

## Formato

- **Definición** de cada concepto en una frase, con el término en negrita y cerca de la redacción del PDF: `Un **modelo de datos** determina…`
- **Bullets** del tipo `- **Término**: explicación breve (ejemplo)`. Sin punto final. Ejemplos entre paréntesis, no en bullets aparte.
- `→` para consecuencias o resultados: `recupera solo ciertos campos → todas las filas`.
- Listas `1)` para clasificaciones numeradas del PDF o pasos de un proceso.
- **Tablas** solo cuando el tema es tabular de verdad: una tabla del propio PDF, una comparación de 3 o más elementos en varias dimensiones (DIKW, niveles de modelado) u operaciones con su comando/fórmula. Nunca una tabla que repita lo que ya dicen los bullets.
- **Nota** con `::: nota` … `:::` (en lugar de `>`): raro. Solo para una frase que el PDF destaca como definición o regla central y que no cabe como bullet; por defecto, ninguna. Nunca para resumir o cerrar una sección. Sin callouts `> [!note]` ni citas `>`.
  ```
  ::: nota
  Texto de la nota
  :::
  ```
- *Cursiva* para términos en inglés: *dataset*, *join*, *logs*.
- Español con tildes.
- Matemáticas en **sintaxis Typst**: `$…$` en línea y `$$…$$` en bloque; `$op("rg") (A)$`, `<=>`, `=>`. Los apuntes antiguos están en LaTeX: no convertirlos salvo que el usuario lo pida, y al continuar uno de ellos escribir lo nuevo en Typst.
  - Separar con espacios las letras que se multiplican: `$X^T X$`, `$A w = b$`, `$v^T A v$`, `$A A^(-1)$`. `$Xw$` sería una variable llamada "Xw".
  - Grupos con paréntesis, no llaves: `$a_(i j)$`, `$A^(-1)$`, `$sum_(k=1)^m$`. Un solo carácter va sin paréntesis: `$x_i$`, `$X^T$`, `$kappa_2$`, `$lambda_min$`.
  - Tras un subíndice o superíndice de un carácter, dejar un espacio antes de `(`: `$lambda_i (M)$`. Sin él, Typst mete el `(M)` en el subíndice.
  - Símbolos por nombre, sin barra: `lambda`, `kappa`, `Delta`, `epsilon`, `theta`, `alpha`, `oo` (∞), `dot` (·), `times`, `approx`, `<=`, `>=`, `!=`, `->`, `=>`, `<=>`, `>>`.
  - Fracciones `$(a)/(b)$`; normas `$norm(A)_oo$`; raíces `$sqrt(x)$`; `$tilde(x)$`; `$bold(1)$`; operadores con nombre `$op("rg") (X)$`; texto `$w_"ridge"$`.
  - Matrices `$mat(1, 2; 3, 4)$` (`,` separa columnas y `;` filas); sistemas `$$cases(x + y = 1, x - y = 0)$$`.
  - Coma decimal `$0","167$`: con `$0,167$` Typst añade un espacio tras la coma. Llaves literales con barra: `$\{7, 1, 1\}$`.
  - Si se puede, compilar las fórmulas para comprobarlas: `pip install typst` en un venv del scratchpad y `typst.compile(...)` sobre un `.typ` con cada fórmula.
- Código en bloques con lenguaje (```` ```r ````, ```` ```python ````), con comentarios breves en línea; para las funciones, una tabla `operación | código`.
- **Diagramas** en ```` ```mermaid ```` (nunca árboles o flechas en ASCII), cuando ayuden: flujos de ejecución, dependencias entre pasos, arquitecturas, jerarquías. Pequeños y sin decorar (`flowchart LR`/`TD`, sin estilos); un diagrama por idea, y no repetir en bullets lo que ya muestra.

## Qué dejar y qué quitar

- **Dejar**: definiciones, clasificaciones, diferencias entre conceptos parecidos (proyección frente a subconjunto), condiciones y propiedades, fórmulas y el ejemplo mínimo que aclara.
- **Quitar**: listas largas de ejemplos (dejar 3 o 4), frases de relleno ("veremos a continuación…"), repetir la definición con otras palabras, contenido que no está en la fuente.
- Una subsección del PDF suele quedar en 1–5 líneas.

## Ejemplo

```markdown
# Definiendo modelo de datos

Un **modelo de datos** determina la manera en la que se organizan y estructuran los datos.

## Estructuras de los modelos de datos

- **Estructurados**: longitud y formato determinados (números, fechas, cadenas…). Número de columnas fijo
	- **Generados por máquinas**: sensores, GPS, *logs*
	- **Generados por personas**: datos de entrada, *clickstream*
- **No estructurados**: no se ajustan a un esquema; estructura no predecible. Son la mayoría (≈ 80 %)

## Operaciones con datos

- **Unión**: junta conjuntos con **la misma estructura** y elimina duplicados
- **Proyección**: recupera solo ciertos campos → **todas** las filas de las columnas elegidas
```

Referencias de estilo del usuario: `~/edu/data-science-degree/tipologia-fuentes-datos/R1/apuntes/` y `~/edu/data-science-degree/metodos-numericos/R1/apuntes/Metodos numéricos en álgebra lineal.md` (para apuntes con matemáticas; de ellos se copia el estilo, no la notación, que está en LaTeX).
