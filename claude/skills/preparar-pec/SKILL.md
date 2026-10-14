---
name: preparar-pec
description: Crear un documento de preparación en Markdown para dominar una PEC (o reto/práctica) a partir de su enunciado, los PDF de teoría, los problemas y los apuntes, con preguntas conceptuales, ejercicios análogos, guía de lecturas con páginas, puntos débiles, ejercicios de explicar y resultados para autocorregirse. Usar cuando el usuario pida "prepárame la PEC", "documento para dominar la PEC", "preparación de la entrevista", "quiero entender bien lo que respondo en la PEC" o algo parecido sobre una asignatura de ~/edu.
---

# Documento de preparación de una PEC

Sirve para que el usuario **domine lo que va a responder** en la PEC (o lo que ya respondió, si hay entrevista o revisión). No es para resolverle la PEC: es un cuaderno de entrenamiento en el que él contesta y luego se autocorrige.

**Referencias de estilo obligatorias** (junto a este archivo, en `referencias/`). Leer la del modo que toque antes de escribir. Imitar la estructura, el tono, la densidad y el formato; no copiar su contenido.
- `ejemplo-completo-metodos-numericos-PEC1.md`: el documento que el usuario eligió como modelo. Es el **modo normal**.
- `ejemplo-escueto-metodos-numericos-PEC1.md`: el mismo, recortado a lo que la PEC exigía. Es el **modo escueto**.

## Alcance: dos modos

**Modo normal (por defecto).** El centro es la PEC, pero el documento puede explayarse:
- La teoría que el enunciado da por supuesta y no está en los PDF ni en los apuntes. Por ejemplo, de dónde salen las ecuaciones normales cuando el enunciado da la fórmula hecha.
- El porqué de los métodos que se aplican y sus alternativas (pivoteo, Cholesky frente a LU, coste computacional).
- **Temas del reto que están en los apuntes o en los PDF aunque la PEC no los pida**: lo que se trabajó en esas secciones y la PEC dejó fuera, y las conexiones con lo que sí pide. Citar siempre dónde está (apunte o página del PDF).
- Extensiones naturales del problema de la PEC (en el ejemplo: sesgo–varianza, validación cruzada, Lasso, SVD), con medida.

Marcar como `(ampliación)` al final de la pregunta, del ejercicio o del paso todo lo que no haga falta para responder la PEC. Así, con prisa, se puede leer solo el núcleo. Lo que la PEC exige debe estar entero antes de añadir ampliaciones, y estas no deben pesar más que el núcleo.

**Modo escueto.** Cuando el usuario diga que tiene prisa, que lo quiere escueto o que solo quiere lo que tuvo (o tiene) que saber. Solo lo que hay que saber para responder la PEC: cada pregunta, ejercicio o paso debe poder ligarse a una tarea o a un criterio de corrección concreto. Sin marcas `(ampliación)` porque no hay ampliaciones.

## Fuentes y dónde están

```
<asignatura>/
  R1/                         # reto / unidad
    teoria/*.pdf              # módulos FUOC (citar por página)
    problemas/                # PDF de problemas resueltos
    apuntes/*.md              # apuntes del usuario (vocabulario y notación)
    PECn/                     # enunciado (.pdf), plantilla (.R/.ipynb), ejemplo de otro año,
                              # entrega del usuario (.md/.pdf/.R) y solución oficial si ya salió
    <enunciado>.pdf           # a veces el enunciado está en R1/ y no en PECn/
```

Extraer cada PDF a texto en el scratchpad (`pdftotext -layout X.pdf <scratchpad>/x.txt`). Para citar páginas, extraer **página a página** (`pdftotext -f N -l N`) o buscar con `grep` en una extracción sin `-layout` contando los saltos de página (`\f`). Las páginas que se citen deben ser las impresas en el PDF y estar comprobadas.

## Primero: en qué momento está el usuario

Mirar qué hay en la carpeta de la PEC y decidirlo sin preguntar:

| Situación | Qué hay | Cómo es el documento |
|---|---|---|
| **Antes de entregar** | Solo enunciado (y quizá un borrador) | No resolver las tareas de la PEC ni dar sus resultados. Las preguntas se refieren al enunciado ("¿qué condición debe cumplir la matriz del apartado 1.3 para…?") y los ejercicios son **análogos con otros datos**. Si hay borrador, Parte C con puntos débiles en forma de pregunta, sin dar la respuesta correcta. Título: `Preparación PECn — <temas>` |
| **Después de entregar** | Entrega (y quizá solución oficial) | Se pueden usar los números de la PEC y de la entrega. Parte C con los puntos débiles reales, comparando con la solución si existe. Si hay entrevista o defensa, orientar al oral. Título: `Preparación entrevista PECn — <temas>` |

Guardar en `PECn/preparacion-PECn.md` o `PECn/preparacion-entrevista-PECn.md`. Si ya existe, leerlo y preguntar si se amplía o se rehace.

## Flujo

1. Leer el enunciado completo, **sobre todo los criterios de corrección y la puntuación**. El peso de cada tarea decide cuánto espacio recibe.
2. Leer los apuntes del usuario de los temas implicados (notación y nivel) y localizar en `teoria/` y `problemas/` dónde se explica cada concepto que pide la PEC. Anotar páginas, ecuaciones y ejemplos. En modo normal, anotar también lo que está en esas secciones y la PEC no usa, como candidato a ampliación.
3. Listar lo que la PEC pide y **no está en los PDF**, y cualquier **error o imprecisión de los PDF** que pueda hacerle fallar. Las dos cosas van en D0.
4. Si hay entrega: leerla entera (informe y código) y, si existe, la solución oficial. Ejecutar el código en limpio para ver que funciona.
5. Diseñar los ejercicios de la Parte B (ver abajo) y **calcular todos los resultados con código** (Rscript o `python -I`) en el scratchpad. Nunca escribir un resultado sin haberlo calculado.
6. Escribir el documento y, al final, decir en el chat qué partes tiene y en qué temas se ha centrado, en 3 o 4 líneas.

## Estructura

Encabezado `# Preparación … — <temas>` y un párrafo **Cómo usarlo** (responder en voz alta y sin mirar, volver a la teoría si se atasca, dónde está cada parte, resultados al final sin procedimiento). Partes separadas por `---`.

### Parte A — Preguntas conceptuales
- Agrupadas en bloques `### A1. <tema>` que siguen el orden de las tareas de la PEC (en modo escueto, uno por tarea: `### A1. Tarea 1.1 — <tema>`), más uno final de **código y requisitos de entrega** si la PEC tiene código.
- **Numeración continua** en todo el documento (1, 2, … 64), para poder decir "la pregunta 45".
- Concretas y ligadas a la PEC: los datos del enunciado, las funciones de la plantilla, lo que pide cada criterio. Mezclar definir, deducir o demostrar, comprobar con los datos, "¿por qué?" y "¿qué pasaría si…?".
- Si hay entrega, citar frases literales del usuario y preguntar si son rigurosas.
- Proporción: unas 6–10 preguntas por bloque y más en las tareas con más puntos.

### Parte B — Ejercicios prácticos
- `### B1. <tema>` con datos concretos y apartados a), b), c).
- **Análogos a las tareas de la PEC con otros datos**, y además alguna variante que haga visible lo que con los datos de la PEC no se ve (en el ejemplo: un sistema con intercambios reales de filas porque en la PEC no hubo ninguno, y una matriz casi singular).
- Diseñar los datos **hacia atrás** para que los resultados sean limpios (elegir la solución y calcular los datos a partir de ella).
- Si la asignatura tiene código: un bloque "escribe desde cero sin mirar tu entrega" con funciones y tests, y la consigna de verificar a mano con su propio código.
- Cerrar con preguntas orales de "qué pasaría si".
- En asignaturas sin cálculo (bases de datos, redes, fuentes de datos), los ejercicios son casos, diseños, consultas o diagramas pequeños con un resultado comprobable.

### Parte C — Puntos débiles probables
- Solo si hay entrega o borrador. Bullets `- **Tema (tarea)**: qué le pueden preguntar y qué preparar`.
- Aclarar que son preguntas que haría un evaluador atento, no correcciones.

### Parte D — Guía detallada de los temas difíciles
Para los 1–3 temas que más cuestan o más puntúan, o donde la entrega es más floja.
- **D0. Mapa de lecturas**: abreviaturas de las fuentes (`**TEO** = teoria/X.pdf (FUOC PID_…)`) y una tabla `Orden | Qué leer | Para qué` con rangos precisos ("desde el inicio de la sección 4.3 hasta el final de la p. 37"). Después, **qué no cubren los PDF** y los **avisos de errores** de los PDF, con la corrección.
- **D1, D2…**: explicación por `**Paso N. Título.**`, de la intuición a la demostración, con los datos de la PEC (o de un ejercicio análogo si aún no se ha entregado) y la lectura que respalda cada paso. Incluir lo que gana y lo que cuesta cada técnica, y los matices de rigor (cota frente a valor real, propiedad del problema frente a la del algoritmo).
- **Frases que conviene evitar**: afirmaciones imprecisas típicas, con la versión correcta entre paréntesis.

### Parte E — Ejercicios de explicar
- `### E1. <título>`: una consigna oral de 1–2 minutos, `*Checklist:*` con las ideas que debe cubrir (separadas por `;`) y `*Lectura:*` apuntando a la sección D o a las páginas del PDF.
- Incluir: demostraciones clave, reformular una frase débil (si hay entrega), construir un caso extremo, detectar el error de un PDF, **un simulacro de "explícame la tarea X" con guion numerado** y **preguntas trampa**.

### Resultados finales para autocorrección
- Solo resultados, **sin procedimiento**, en el orden de los ejercicios: `**B4**: w = (1, 1, 1); det(M) = 67.`
- Cuando el resultado entero revelaría demasiado, dar una autocomprobación ("la traza debe ser 10").
- Antes de entregar la PEC, no incluir nunca resultados de las tareas de la propia PEC.

## Formato

- Español con tildes; segunda persona del singular ("tu entrega", "explícalo").
- Matemáticas en **sintaxis Typst** dentro del Markdown, en todo el documento empezando por las preguntas: `$…$` en línea y `$$…$$` en bloque. Nada de LaTeX (`\frac`, `_{…}`, `\lambda`) ni de Unicode matemático suelto (ᵀ, ᵢ, ‖, κ, λ). Las referencias de `referencias/` están en Unicode porque son anteriores a esta regla: de ellas se copia la estructura, no la notación. El documento de la PEC1 (`metodos-numericos/R1/PEC1/preparacion-entrevista-PEC1.md`) ya está en Typst y sirve de ejemplo de notación.
  - Separar con espacios las letras que se multiplican: `$X^T X$`, `$A w = b$`, `$v^T A v$`, `$A A^(-1)$`. `$Xw$` sería una variable llamada "Xw".
  - Grupos con paréntesis, no llaves: `$a_(i j)$`, `$A^(-1)$`, `$sum_(k=1)^m$`. Un solo carácter va sin paréntesis: `$x_i$`, `$X^T$`, `$kappa_2$`, `$lambda_min$`.
  - Tras un subíndice o superíndice de un carácter, dejar un espacio antes de `(`: `$lambda_i (M)$`. Sin él, Typst mete el `(M)` en el subíndice.
  - Símbolos por nombre, sin barra: `lambda`, `kappa`, `Delta`, `epsilon`, `theta`, `alpha`, `oo` (∞), `dot` (·), `times`, `approx`, `<=`, `>=`, `!=`, `->`, `=>`, `<=>`, `>>`.
  - Fracciones `$(a)/(b)$`; normas `$norm(A)_oo$`; raíces `$sqrt(x)$`; `$tilde(x)$`; `$bold(1)$`; operadores con nombre `$op("rg") (X)$`; texto `$w_"ridge"$`.
  - Matrices `$mat(1, 2; 3, 4)$` (`,` separa columnas y `;` filas); sistemas `$$cases(x + y = 1, x - y = 0)$$`.
  - Coma decimal `$0","167$`: con `$0,167$` Typst añade un espacio tras la coma. Llaves literales con barra: `$\{7, 1, 1\}$`.
  - Si se puede, compilar las fórmulas para comprobarlas: `pip install typst` en un venv del scratchpad y `typst.compile(...)` sobre un `.typ` con cada fórmula.
- Negrita para la idea clave de cada pregunta o paso, no para frases enteras. Sin emojis ni callouts.
- Tamaño orientativo para una PEC de cuatro tareas: unas 400 líneas en modo normal y 250–300 en modo escueto. Que crezca por profundidad en lo difícil, no por relleno.
