# Preparación entrevista PEC1 — Ridge, Gauss, LU y condicionamiento

Cómo usarlo: responde en voz alta, como en la entrevista, y sin mirar tu entrega. Si te trabas, vuelve a la sección de teoría correspondiente. Todo lo que hay aquí es algo que la PEC te exigía saber: las preguntas siguen las tareas y los criterios de corrección. En la **Parte D** tienes una guía detallada de multicolinealidad y de 1.4.2 con las lecturas exactas de los PDFs, y en la **Parte E** ejercicios de explicar. Al final hay **solo resultados finales** de los ejercicios para que te autocorrijas (sin procedimiento).

---

## Parte A — Preguntas conceptuales

### A1. Tarea 1.1 — Ecuaciones normales y multicolinealidad
1. ¿Qué dimensiones tienen X, Xᵀ, A = XᵀX y b = Xᵀy? ¿Por qué A es cuadrada?
2. ¿Por qué XᵀX es siempre simétrica?
3. ¿Qué representa el elemento aᵢⱼ de A en términos de las columnas de X? ¿Y aᵢᵢ?
4. Define multicolinealidad.
5. Explica por qué la multicolinealidad degrada κ(A). Hazlo con **valores propios**, no solo con filas "parecidas".
6. En tu informe dijiste que "cuanto mayor es aᵢⱼ, más se relacionan las variables". ¿Es del todo cierto? ¿De qué depende la magnitud de aᵢⱼ? ¿Qué cantidad mide de verdad el parecido entre dos columnas?
7. ¿Qué condición debe cumplir X para que A sea invertible? Con tu X, ¿cómo lo sabes?
8. ¿Cuáles son los valores propios de tu A? ¿Qué estructura tiene (A = I + 2·𝟏𝟏ᵀ)? ¿Qué vector propio da el valor propio grande?
9. Escribe el sistema Aw = b en forma de ecuaciones. ¿Qué es cada incógnita?

### A2. Tarea 1.2 — Eliminación gaussiana con pivoteo parcial
10. Explica el algoritmo en tres frases: fase de eliminación y fase de sustitución.
11. ¿Qué es el multiplicador mᵢₖ y qué operación elemental aplicas?
12. ¿Cómo se elige el pivote en el pivoteo parcial? ¿Por qué se pivota (pivote nulo y errores de redondeo)?
13. En tu PEC no hubo ningún intercambio de filas. ¿Por qué? ¿Seguiste el algoritmo "con pivoteo parcial" aunque no intercambiaras? ¿Cómo lo justificas ante el evaluador?
14. ¿Qué pasa si toda la columna por debajo del pivote es cero?
15. Explica la sustitución hacia atrás: ¿por qué se empieza por la última ecuación?

### A3. Tarea 1.3 — Ridge y factorización LU
16. ¿Cómo se construye M a partir de A? ¿Por qué M sigue siendo simétrica?
17. Define matriz estrictamente diagonal dominante (por filas) y compruébalo en M. ¿Lo es A?
18. ¿Qué garantiza la dominancia diagonal estricta (invertibilidad y LU sin pivoteo)?
19. ¿Qué es LU? ¿Qué hace cada matriz? ¿Qué relación tiene con la eliminación gaussiana (los mᵢₖ forman L)?
20. Factorización de Doolittle: ¿qué significa que L sea triangular inferior **unitaria**? Escribe las fórmulas de uₖⱼ y lᵢₖ.
21. Explica por qué hay dos subsistemas, Ly=b y Uw=y, y qué papel tiene el vector intermedio y (¡que no es el vector de ventas y de la PEC! ¿Cómo evitas la confusión de notación?).
22. ¿Por qué Ly=b se resuelve hacia delante y Uw=y hacia atrás?

### A4. Tarea 1.4 — Normas y condicionamiento
23. Define ‖·‖∞ para vectores y para matrices. ¿Por qué ‖A‖∞ es "máxima suma de filas"?
24. ¿Cómo calculaste A⁻¹ y M⁻¹ a mano (Gauss-Jordan sobre [A|I])?
25. Define κ(A). ¿Cuál es su valor mínimo? ¿Qué significa un κ grande?
26. Enuncia y **demuestra** la cota ‖Δw‖/‖w‖ ≤ κ(A)·‖Δb‖/‖b‖.
27. ¿Es la cota del 26 una igualdad? Aplícalo a lo que dijiste en tu informe ("el impacto de los errores es 27/11 veces menor"): ¿se puede afirmar eso con rigor o solo que **la cota** es 27/11 veces menor?
28. ¿Cuál es el efecto de λ sobre los valores propios? Demuestra λᵢ(M) = λᵢ(A) + λ.
29. ¿Por qué ese desplazamiento hace bajar κ? Calcula κ₂(A) y κ₂(M) con los valores propios.
30. ¿Por qué un determinante pequeño no implica mal condicionamiento? (Ej.: αI con α pequeño.)
31. Con κ∞(A) = 9, ¿dirías que A está "mal condicionada"?

### A5. Código R y requisitos de entrega
32. ¿Por qué `solve()` estaba prohibida en las Tareas 1.2 y 1.3, pero la usas para calcular A⁻¹ en 1.4? ¿Dónde lo dice?
33. Recorre tu función `gauss_pivoteo_parcial` línea a línea. ¿Qué hace `which.max(abs(Ab[k:n,k]))` y por qué sumas `k-1`?
34. En tu `factorizacion_LU`, ¿por qué `U[i, k:n]` y no la fila entera? ¿Por qué no hace pivoteo y por qué con M no hace falta?
35. En tu `sustitucion_adelante` no divides entre `L[i,i]`. ¿Por qué es correcto aquí?
36. ¿Qué hace tu `norma_infinito` con `rowSums(abs(Mat))`?
37. Condiciones de la entrega: ¿por qué no puede haber código en el PDF? ¿Por qué deben coincidir informe y salida de R? ¿Qué es un "clean run"?

---

## Parte B — Ejercicios prácticos (a mano; verifica luego con R)

> Haz todos a mano con fracciones. Después replícalos con tus funciones de R (`gauss_pivoteo_parcial`, `factorizacion_LU`, etc.) y compara.

### B1. Ecuaciones normales
Datos: X = [[1,0,1],[0,1,1],[1,1,0],[1,1,1],[0,0,1]] (5×3), y = (2, 3, 3, 6, 1)ᵀ.
a) Calcula A = XᵀX y b = Xᵀy.
b) ¿Es A simétrica? ¿Estrictamente diagonal dominante?
c) Escribe el sistema Aw=b en forma de ecuaciones.

### B2. Gauss con pivoteo (con intercambios reales)
Resuelve con pivoteo parcial, indicando cada intercambio y cada multiplicador:

    1w₁ + 2w₂ + 1w₃ = 8
    4w₁ + 1w₂ + 2w₃ = 12
    2w₁ + 3w₂ + 3w₃ = 17

a) Muestra la matriz aumentada tras cada paso.
b) Resuelve por sustitución hacia atrás.

### B3. LU de Doolittle
M = [[4,2,1],[2,5,3],[1,3,6]], b = (7,10,10)ᵀ.
a) Verifica simetría y dominancia diagonal estricta.
b) Calcula L y U con las fórmulas de Doolittle (fila de U, columna de L por cada k).
c) Resuelve Ly=b y Uw=y.
d) Comprueba que LU = M multiplicando.

### B4. Ridge con la PEC cambiando λ
Con A y b de la PEC, construye M = A + I (λ = 1) y resuélvelo por LU. Da L, U, y, w.

### B5. Normas y condicionamiento
a) Para la M de B3, calcula ‖M‖∞, M⁻¹ (Gauss-Jordan), ‖M⁻¹‖∞ y κ∞(M).
b) Calcula los valores propios de A y de M de la PEC y deduce κ₂(A) y κ₂(M).
c) Matriz casi singular: A_ε = [[1,1],[1,1+ε]] con ε = 0.01. Calcula κ∞(A_ε) de forma exacta. Luego regulariza con λ=0.1 y recalcula κ∞.

### B6. Propagación de perturbaciones
Con A y b de la PEC, perturba b a b' = (10, 11.5, 10).
a) Calcula Δb y ‖Δb‖∞/‖b‖∞.
b) Calcula la cota teórica para el sistema ordinario (usa κ∞(A)=9).
c) Resuelve el sistema perturbado y calcula el error relativo **real** ‖Δw‖∞/‖w‖∞.
d) Repite (a)-(c) para el sistema regularizado (M, λ=2).
e) Compara: cota vs. error real. ¿Por qué la cota no es ajustada?

### B7. Código R (a escribir)
Sin mirar tu entrega, escribe desde cero las funciones de la plantilla:
a) `norma_inf(M)`.
b) `gauss_pp(A, b)` con pivoteo parcial y sustitución hacia atrás.
c) `lu_doolittle(M)` devolviendo L y U.
d) `sust_adelante(L, b)` y `sust_atras(U, y)`.
e) El flujo de la Tarea 1.3: M = A + λI → LU → y → w_ridge.

---

## Parte C — Puntos débiles probables de tu entrega (prepáralos)

(Son preguntas que un evaluador atento puede hacerte, no correcciones.)

- **Multicolinealidad (1.1)**: tu explicación habla de filas "cada vez más similares" pero no de valores propios ni de la escala. Prepara la versión con λ_min(A)→0 y κ₂ = λ_max/λ_min.
- **Interpretación de 1.4.2**: tu respuesta es solo la razón 27/11. Prepara: la cota de propagación, qué es κ, que es una cota del peor caso, y el efecto sobre los valores propios.
- **Pivoteo sin intercambios**: justifica por qué, aun así, el algoritmo es "con pivoteo parcial".
- **Uso de `solve()` en 1.4**: ten clara la frase de por qué está permitido (la prohibición era para resolver los sistemas de 1.2 y 1.3).
- **Notación**: en 1.3 usas y para el vector intermedio, y y es también el vector de ventas. Sepa explicarlo.
- **Código**: sabe explicar cada línea de tu `gauss_pivoteo_parcial` y de `factorizacion_LU`.

---

## Parte D — Guía detallada: multicolinealidad y la explicación de 1.4.2

### D0. Mapa de lecturas (qué leer y qué NO está en los PDFs)

Abreviaturas: **TEO** = `teoria/Metodos-numericos-en-algebra-nileal.pdf` (FUOC PID_00285408). **PROB-R** = `teoria/Problemas-de-metodos-numeros-en-R.pdf` (FUOC PID_00309524). **Resumen** = `apuntes/resumen-algebra-lineal.md`.

| Orden | Qué leer | Para qué |
|---|---|---|
| 1 | TEO, **desde el inicio de la sección 2 (p. 12) hasta el final de la sección 2.3 (p. 17)** | Rango/invertibilidad (p. 12), valores propios y matrices simétricas (pp. 13–14), normas vectoriales y matriciales (pp. 14–17). Imprescindible: ‖Ax‖ ≤ ‖A‖‖x‖ (ec. 18, p. 17) y ‖A‖∞ como máxima suma de filas (ec. 20, p. 17). |
| 2 | TEO, **desde el inicio de la sección 4.3 hasta el final de la p. 37** (justo antes del Ejemplo 11). Lo que importa de verdad está en **pp. 36–37**: vector residual, ec. (83) y definición de K(A) | Es el **único sitio de los PDFs donde aparece el número de condición**. Es la base de tu 1.4. |
| 3 | PROB-R, **Ejemplo 8, pp. 26–28** (regresión con ecuaciones normales resueltas por LU) | Es exactamente el procedimiento de tu PEC: XᵀX y Xᵀy, y LU. |
| 4 | Resumen, **desde "Valores y vectores propios" hasta el final de "Aplicación: potencias de una matriz"** | Diagonalización A = PDP⁻¹; atajo "A simétrica ⇒ diagonalizable", que es la base de lo que usamos aquí. |

**Lo que los PDFs NO cubren**: multicolinealidad, la fórmula κ₂ = λ_max/λ_min, y el desplazamiento λᵢ(A+λI) = λᵢ(A)+λ. Las ecuaciones normales con Ridge tampoco se deducen en ningún sitio: las da hechas el enunciado. Todo eso lo tienes explicado abajo. En la entrevista puedes citar que el concepto de κ viene de TEO p. 37 y el resto lo deduces.

**Aviso sobre un error en TEO p. 37:** el texto dice "si K(A) es menor que 1, la matriz A está bien condicionada, mientras que si es mayor que 1, mal condicionada". Eso es incorrecto: **κ(A) ≥ 1 siempre**, porque 1 = ‖I‖ = ‖AA⁻¹‖ ≤ ‖A‖‖A⁻¹‖ (propiedad 5 de normas matriciales, TEO p. 16). Se considera bien condicionada si κ es *próximo a 1* y mal condicionada si es *grande* (≫1). Si en la entrevista citas la regla de los apuntes tal cual, te pueden corregir. Mismo error en el recuadro "Importante" de la p. 37.

---

### D1. Multicolinealidad, paso a paso

**Paso 1. Qué es cada elemento de A = XᵀX.**
Las columnas de X son las variables x₁, x₂, x₃ (canales). Entonces aᵢⱼ = xᵢ·xⱼ (producto escalar), y en particular aᵢᵢ = ‖xᵢ‖². Como xᵢ·xⱼ = ‖xᵢ‖‖xⱼ‖cosθᵢⱼ, la cantidad que mide "cuánto se parecen" dos variables es
 cosθᵢⱼ = aᵢⱼ / √(aᵢᵢ·aⱼⱼ),
que es la correlación de Pearson cuando las columnas están centradas. En tu PEC es 2/√(3·3) = 2/3 para los tres pares. El elemento aᵢⱼ por sí solo **no** mide parecido: depende de la escala de las variables (si multiplicas x₁ por 1000, a₁₂ se multiplica por 1000 sin que las variables sean más parecidas). Por eso el enunciado habla de observaciones estandarizadas.

**Paso 2. Multicolinealidad exacta = A singular.**
Si una columna es combinación lineal de las otras, las columnas de X son linealmente dependientes, rg(X) < n, y rg(XᵀX) = rg(X) < n. Por la lista de equivalencias de TEO p. 12 (A⁻¹ existe ⇔ det ≠ 0 ⇔ filas y columnas l.i. ⇔ rango n), A no es invertible: el sistema Aw = b no tiene solución única, y Gauss encuentra un pivote nulo.

**Paso 3. Multicolinealidad aproximada = A casi singular.**
Para cualquier vector v, vᵀAv = vᵀXᵀXv = ‖Xv‖² ≥ 0, así que los valores propios de A son ≥ 0. Si existe un v unitario con Xv ≈ 0 (una combinación de columnas casi nula, es decir, columnas casi dependientes), entonces vᵀAv ≈ 0, de modo que A tiene un valor propio λ_min ≈ 0.

**Paso 4. De λ_min ≈ 0 a κ grande.**
Como A es simétrica, tiene valores propios reales (TEO p. 13, afirmación 1) y es diagonalizable con vectores propios ortonormales: A = Σ λᵢ vᵢvᵢᵀ (Resumen, "A simétrica ⇒ diagonalizable"). Entonces:
- ‖A‖₂ = λ_max.
- A⁻¹ = Σ (1/λᵢ) vᵢvᵢᵀ, luego ‖A⁻¹‖₂ = 1/λ_min.
- **κ₂(A) = ‖A‖₂‖A⁻¹‖₂ = λ_max / λ_min.**
Cuando λ_min → 0, ‖A⁻¹‖ y κ se disparan.
Ojo: tu informe usó κ∞, que no se calcula con valores propios; pero ambas normas son equivalentes salvo factores que dependen de n (TEO p. 16, ec. 14–16), así que el fenómeno es el mismo.

**Paso 5. Tu matriz.**
A = I + 2·𝟏𝟏ᵀ, con 𝟏 = (1,1,1)ᵀ. Sus valores propios son 7 (vector propio (1,1,1): "los tres canales suben juntos") y 1, 1 (cualquier vector ortogonal a (1,1,1), por ejemplo (1,−1,0)). Entonces κ₂(A) = 7: **moderado, no severo**. Es un ejemplo didáctico del mecanismo, no un caso de multicolinealidad grave.
Para ver el caso extremo mira el 2×2 de B5c: A_ε = [[1,1],[1,1+ε]] tiene valores propios ≈ 2+ε y ≈ ε/2, luego κ₂ ≈ 4/ε.

---

### D2. La explicación de 1.4.2, paso a paso

**Paso 1. La cota de la ec. (83), TEO p. 37.**
 ‖x − x̃‖ / ‖x‖ ≤ κ(A) · ‖r‖ / ‖b‖.
Nuestra versión (perturbación en b) es la misma: si x̃ resuelve Ax̃ = b + Δb, entonces el residuo es r = b − Ax̃ = −Δb. Por eso en tu informe puedes decir "perturbación en los datos" y en el libro verás "residuo".

**Paso 2. Demostración (cuatro líneas, memorízala).**
1. A(w+Δw) = b+Δb y Aw = b, restando: AΔw = Δb, luego Δw = A⁻¹Δb.
2. Por ‖Ax‖ ≤ ‖A‖‖x‖ (TEO p. 17, ec. 18) aplicada a A⁻¹: ‖Δw‖ ≤ ‖A⁻¹‖‖Δb‖.
3. De Aw = b: ‖b‖ ≤ ‖A‖‖w‖, es decir, 1/‖w‖ ≤ ‖A‖/‖b‖.
4. Multiplicando 2 por 3: ‖Δw‖/‖w‖ ≤ ‖A‖‖A⁻¹‖ · ‖Δb‖/‖b‖ = κ(A)·‖Δb‖/‖b‖.

**Paso 3. Qué significa.** κ es el **factor máximo de amplificación** del error relativo: un 1 % de error en los datos puede convertirse en un κ % de error en la solución.

**Paso 4. Es cota del peor caso.** Con perturbaciones concretas el error real suele ser menor: en B6, 0,167 real frente a 0,409 de cota con A y 0,095 frente a 0,167 con M.

**Paso 5. Cómo cambia λ el condicionamiento.** Si A tiene valores propios λᵢ, entonces M = A + λI tiene valores propios λᵢ + λ (mismos vectores propios, pues (A+λI)v = λᵢv + λv). En tu caso: A → {7,1,1}, M → {9,3,3}. Entonces
 κ₂(A+λI) = (λ_max + λ) / (λ_min + λ),
que **decrece al aumentar λ**. Con tus números: 7 → 3.
Interpretación: el valor propio pequeño (el que amplificaba el ruido, 1/λ_min) queda "levantado" a λ_min + λ, así que 1/λ_min deja de explotar. Ese es el mecanismo, y es lo que le falta a tu texto (solo daba el cociente 27/11).

**Paso 6. Cuantificación para la entrevista.**
- Cota de amplificación: de 9 a 11/3 ⇒ factor 27/11 ≈ 2,45 menor.
- Ejemplo: error relativo del 1 % en y ⇒ cota 9 % con A y 3,67 % con M.
- Matiz: "la cota es 27/11 veces menor" ≠ "el error real es 27/11 veces menor".

---

### D3. Frases que conviene evitar en la entrevista
- "La multicolinealidad hace que a_ij sea grande." (depende de la escala)
- "κ < 1 es bien condicionada." (κ ≥ 1 siempre)
- "El error es 27/11 veces menor." (la cota lo es)
- "Mi A está muy mal condicionada." (κ₂ = 7; moderada)

---

## Parte E — Ejercicios de explicar (pregunta oral + checklist de ideas)

Para cada uno: responde en voz alta en 1–2 minutos y marca en la checklist qué ideas cubriste. Si te dejas más de dos, relee la sección indicada.

### E1. Multicolinealidad exacta frente a aproximada
Explica la diferencia usando el rango de X, el rango de A y la invertibilidad. *Checklist:* columnas l.d.; rg(XᵀX) = rg(X); A singular (TEO p. 12); w no único; aproximada = A invertible pero casi singular; qué hace Gauss en cada caso. *Lectura:* D1 pasos 2–3.

### E2. Multicolinealidad y número de condición con valores propios
Explica sin mirar apuntes por qué λ_min ≈ 0 dispara κ₂. Luego calcula vectores y valores propios de tu A e interpreta qué significa cada uno en términos de canales. *Checklist:* vᵀAv = ‖Xv‖²; simétrica ⇒ valores propios reales; A = Σλᵢvᵢvᵢᵀ; A⁻¹ con 1/λᵢ; κ₂ = λ_max/λ_min; (1,1,1) con valor 7; (1,−1,0) con valor 1. *Lectura:* D1 pasos 3–5; TEO pp. 13–14.

### E3. Reformula tu frase del informe
Tu frase: "cuanto mayor es el elemento aᵢⱼ, más se relacionan esas dos variables". Explica por qué es incorrecta o incompleta y reescríbela correctamente en 2–3 frases. Después calcula el coseno entre las columnas de tu X. *Checklist:* dependencia de la escala; fórmula cosθ = aᵢⱼ/√(aᵢᵢaⱼⱼ); centrar ⇒ Pearson; estandarizar. *Lectura:* D1 paso 1.

### E4. Demuestra la cota de propagación
Escribe la demostración completa de ‖Δw‖/‖w‖ ≤ κ‖Δb‖/‖b‖ sin mirar. Indica qué propiedad de normas usas en cada paso. *Checklist:* Δw = A⁻¹Δb; ‖Ax‖ ≤ ‖A‖‖x‖ (TEO p. 17); ‖b‖ ≤ ‖A‖‖w‖; combinarlas. *Lectura:* D2 pasos 1–2; TEO pp. 36–37.

### E5. Cómo λ mejora κ
Demuestra que los valores propios de A+λI son λᵢ+λ. Deduce κ₂(λ) para tu A y comprueba κ₂(0) y κ₂(2). *Checklist:* (A+λI)v = (λᵢ+λ)v; mismos vectores propios; κ₂ decrece con λ; ¿por qué κ₂ y κ∞ no coinciden? *Lectura:* D2 paso 5.

### E6. La frase "27/11 veces menor"
Redacta en 4 frases la conclusión correcta de 1.4.2. Debe incluir: la cota, los valores 9 y 11/3, el factor 27/11 como factor de la **cota**, y por qué el error real no tiene por qué mejorar exactamente ese factor (usa tus números de B6). *Checklist:* cota ≠ error real; peor caso; unidades de "veces menor"; matiz de que sigue siendo ventaja. *Lectura:* D2 pasos 4 y 6.

### E7. Detecta el error del PDF
Explica por qué la frase "K(A) < 1 ⇒ bien condicionada" de TEO p. 37 es incorrecta. Demuestra κ(A) ≥ 1. *Checklist:* 1 = ‖I‖ = ‖AA⁻¹‖ ≤ ‖A‖‖A⁻¹‖; qué quiere decir "bien condicionada" realmente.

### E8. Simulacro de 2 minutos: "Explícame 1.4.2"
Prepara y di en voz alta tu respuesta completa a 1.4.2 con este guion. Lo ideal es cronometrarte.
1. Qué mide κ y cuánto valen κ∞(A) y κ∞(M).
2. Cota de propagación (fórmula + una línea de por qué).
3. Qué efecto tiene λ en los valores propios y por qué baja κ.
4. Cuantificación: 9 → 11/3, factor 27/11 en la cota.
5. Matiz: peor caso, no el error real.

### E9. Preguntas trampa
1. ¿Por qué no basta mirar el determinante de A para saber si está mal condicionada? (Ejemplo: αI con α pequeño.)
2. Si κ∞(A)=9, ¿dirías que A está "mal condicionada"? ¿A partir de qué valor lo dirías?
3. ¿Y si una columna de X fuese exactamente la suma de otras dos? ¿Qué pasa con A y con tu solver?
4. ¿Es A estrictamente diagonal dominante? Si no lo es, ¿por qué Gauss funcionó igual?

---

## Resultados finales para autocorrección (sin procedimiento)

**B1**: autocomprobación: la traza de A debe ser la suma de los cuadrados de todos los elementos de X, que es 10.

**B2**: w = (1, 2, 3). Dos intercambios de filas.

**B3**: solución w = (1, 1, 1). L tiene l₂₁ = 1/2, l₃₁ = 1/4.

**B4**: w(λ=1) = (9/8, 13/8, 9/8).

**B5**: a) κ∞(M) = 420/67 ≈ 6,27. b) κ₂(A) = 7, κ₂(M) = 3. c) κ∞(A_ε) = 404.01; con λ=0.1, κ∞ ≈ 20.15.

**B6** (perturbación b'=(10, 11.5, 10)): ‖Δb‖/‖b‖ = 0.5/11 ≈ 0.04545. Sistema ordinario: cota ≈ 0.409, error real ≈ 0.1667. Regularizado (λ=2): cota ≈ 0.1667, error real ≈ 0.0946.

Contrasta todo con tus propias funciones de R.

**E3**: cosθ entre columnas de X = 2/3 (los tres pares).

**E5**: κ₂(A) = 7 y κ₂(M) = 3; κ₂(λ) = (7+λ)/(1+λ).
