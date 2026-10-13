# Preparación entrevista PEC1 — Ridge, Gauss, LU y condicionamiento

Cómo usarlo: responde en voz alta, como en la entrevista, y sin mirar tu entrega. Si te trabas, vuelve a la sección de teoría correspondiente. En la **Parte D** tienes una guía detallada de multicolinealidad y de 1.4.2 con las lecturas exactas de los PDFs, y en la **Parte E** ejercicios de explicar. Al final hay **solo resultados finales** de los ejercicios para que te autocorrijas (sin procedimiento).

---

## Parte A — Preguntas conceptuales

### A1. Problema y ecuaciones normales
1. ¿Qué problema resuelve mínimos cuadrados? Escribe la función a minimizar.
2. ¿Por qué se minimizan los cuadrados de los residuos y no su valor absoluto?
3. Deduce las ecuaciones normales. ¿Qué se anula y respecto a qué?
4. ¿Qué forma tiene geométricamente la solución (proyección)? ¿Qué es el residuo y a qué subespacio es ortogonal?
5. ¿Qué condición debe cumplir X para que XᵀX sea invertible? Con tu X, ¿cómo lo sabes?
6. ¿Por qué XᵀX es siempre simétrica? ¿Y semidefinida positiva? ¿Cuándo es definida positiva?
7. ¿Por qué no se recomienda en la práctica formar XᵀX (alternativas: QR, SVD)? ¿Qué le pasa al número de condición al formarla?
8. ¿Qué significa cada canal wᵢ en el contexto de negocio? ¿Qué interpretas de w = (8/7, 15/7, 8/7)?

### A2. Multicolinealidad
9. Define multicolinealidad. ¿Cómo se detecta (correlaciones, VIF, κ, valores propios)?
10. Explica por qué la multicolinealidad degrada κ(A). Hazlo con **valores propios**, no solo con filas "parecidas".
11. En tu informe dijiste que "cuanto mayor es aᵢⱼ, más se relacionan las variables". ¿Es del todo cierto? ¿De qué depende la magnitud de aᵢⱼ (escala, número de observaciones)? ¿Qué se hace para que sea comparable?
12. ¿Qué efecto tiene la multicolinealidad sobre la **varianza** de los coeficientes estimados, aunque la predicción siga siendo buena?
13. ¿Es A estrictamente diagonal dominante? (Compruébalo.) Entonces, ¿por qué no tuvimos problemas con A y sí garantizamos algo con M?
14. ¿Cuáles son los valores propios de A y de M? ¿Qué estructura tienen (A = I + 2·𝟏𝟏ᵀ)? ¿Qué vector propio da el valor propio grande?

### A3. Ridge / regularización
15. Escribe la función objetivo de Ridge. ¿Cómo se obtiene (XᵀX+λI)w = Xᵀy a partir de ella?
16. ¿Por qué XᵀX+λI es invertible para todo λ>0 aunque XᵀX sea singular?
17. ¿Cuál es el efecto de λ sobre los valores propios? Demuestra λᵢ(M) = λᵢ(A) + λ.
18. ¿Qué pasa con w cuando λ→0? ¿Y cuando λ→∞? Compruébalo con tus datos (w para λ=0, 1, 2, 5, 10).
19. ¿Es Ridge un estimador sesgado? Explica el compromiso **sesgo–varianza** y por qué te interesa.
20. ¿Cómo se elegiría λ en la práctica (validación cruzada)? ¿Por qué λ=2 en la PEC es "arbitrario"?
21. ¿Ridge penaliza el término independiente? ¿Por qué hay que estandarizar las variables antes? (El enunciado dice "observaciones estandarizadas".)
22. Diferencia entre Ridge (L2) y Lasso (L1) en una frase.
23. Tikhonov: ¿qué relación tiene con la pseudoinversa y con la SVD (factores σᵢ/(σᵢ²+λ))?

### A4. Eliminación gaussiana y pivoteo
24. Explica el algoritmo en tres frases: fase de eliminación y fase de sustitución.
25. ¿Qué es el multiplicador mᵢₖ y qué operación elemental aplicas?
26. ¿Por qué hace falta pivoteo parcial? Da dos razones: pivote nulo y **estabilidad numérica** (crecimiento de multiplicadores/errores de redondeo).
27. ¿Pivoteo parcial vs. total vs. escalado? ¿Qué se busca en cada uno?
28. En tu PEC no hubo ningún intercambio de filas. ¿Por qué? ¿Seguiste el algoritmo "con pivoteo parcial" aunque no intercambiaras? ¿Cómo lo justificas ante el evaluador?
29. Coste computacional de la eliminación (O(n³), ~2n³/3 flops) y de la sustitución (O(n²)).
30. ¿Cuándo falla el algoritmo? ¿Qué pasa si la matriz es singular (pivote nulo en toda la columna)?
31. ¿Qué es el determinante después de la eliminación? ¿Cómo afecta cada intercambio de filas?
32. ¿Cómo comprobarías que w = (8/7, 15/7, 8/7) es correcto sin repetir la eliminación? (Residuo.)

### A5. Factorización LU
33. ¿Qué es LU? ¿Qué hace cada matriz? ¿Qué relación tiene con la eliminación gaussiana (los mᵢₖ forman L)?
34. ¿Qué es la factorización de Doolittle frente a Crout y Cholesky?
35. ¿Cuándo existe LU **sin** pivoteo? (Menores principales no nulos; diagonal dominante estricta; definida positiva.) ¿Cuál de esas aplica a M?
36. ¿Y con pivoteo? Escribe PA = LU. ¿Qué es P?
37. ¿Por qué se factoriza una vez y se resuelve muchas veces? ¿Qué coste tiene factorizar vs. resolver con L y U?
38. M es simétrica definida positiva: ¿qué factorización más barata podrías haber usado? ¿Qué relación hay entre U y L (U = D·Lᵀ)? Compruébalo con tus matrices.
39. ¿Cómo se calcula det(M) a partir de U? Calcúlalo con tu U y verifica con el valor de la matriz.
40. ¿Cómo obtendrías M⁻¹ usando LU?
41. Explica por qué hay dos subsistemas, Ly=b y Uw=y, y qué papel tiene el vector intermedio y (¡que no es el vector de ventas y de la PEC! ¿Cómo evitas la confusión de notación?).
42. ¿Es única la factorización LU con L unitaria? ¿Y si no se exige diagonal unitaria?

### A6. Normas y condicionamiento
43. Define ‖·‖₁, ‖·‖₂, ‖·‖∞ para vectores y para matrices. ¿Por qué ‖A‖∞ es "máxima suma de filas"?
44. Define κ(A). ¿Cuál es su valor mínimo? ¿Cuándo vale 1? ¿Qué significa κ infinito?
45. Enuncia y **demuestra** la cota ‖Δw‖/‖w‖ ≤ κ(A)·‖Δb‖/‖b‖.
46. Enuncia la cota cuando se perturba la matriz A (ΔA), no solo b.
47. Regla práctica: "se pierden log₁₀ κ dígitos de precisión". Aplícala a κ∞(A)=9 y a un κ de 10¹⁰.
48. ¿Es la cota del 45 una igualdad? ¿Es la cota del peor caso? Aplícalo a lo que dijiste en tu informe ("el impacto de los errores es 27/11 veces menor"): ¿se puede afirmar eso con rigor o solo que **la cota** es 27/11 veces menor?
49. Calcula κ₂(A) y κ₂(M) usando valores propios. ¿Coinciden con κ∞? ¿Por qué no tienen por qué?
50. ¿κ depende de la norma? ¿Hay equivalencia entre normas de κ (cotas de n)?
51. ¿Qué diferencia hay entre **mal condicionado** (propiedad del problema) y **inestable** (propiedad del algoritmo)? ¿Es la eliminación con pivoteo estable? ¿Y sin él?
52. ¿Por qué el determinante pequeño no implica mal condicionamiento? (Ej.: αI con α pequeño.)
53. Si λ→∞, κ(M)→? ¿Entonces por qué no tomar λ enorme? (Coste: sesgo.)
54. Deduce, para tu problema, la fórmula κ∞(λ) = (9+λ)/(1+λ). Verifica en λ=0 y λ=2. ¿Es posible conseguir κ∞<1.5 con λ razonable?

### A7. Código R y requisitos de entrega
55. ¿Por qué `solve()` estaba prohibida en el solver, pero la usas para calcular A⁻¹ en 1.4? ¿Está permitido, o cómo lo justificas?
56. Recorre tu función `gauss_pivoteo_parcial` línea a línea. ¿Qué hace `which.max(abs(Ab[k:n,k]))` y por qué sumas `k-1`?
57. ¿Qué pasa en tu código si `Ab[k,k]` es 0 tras el pivoteo? ¿Detecta singularidad?
58. En tu `factorizacion_LU`, ¿por qué `U[i, k:n]` y no la fila entera? ¿Hace pivoteo? ¿Es válido para cualquier matriz? ¿Para M sí?
59. ¿Qué devuelve `A %*% w - b` con tu solución? ¿Y `max(abs(L %*% U - M))`? ¿Cómo lo usarías como test?
60. ¿Por qué `b <- Xt %*% y` da una matriz 3×1 y tú imprimes `as.vector(b)`? ¿Qué cambia entre vector y matriz columna en R?
61. ¿Qué es `byrow = TRUE`? ¿Qué pasaría sin él con la X?
62. Condiciones de la entrega: ¿por qué no puede haber código en el PDF? ¿Por qué deben coincidir informe y salida de R? ¿Qué es un "clean run"?
63. Si te pido cambiar λ a 5 en directo, ¿qué línea tocas y qué resultados cambian (M, L, U, y, w_ridge, κ(M))?
64. Si te pido que tu solver soporte matrices 4×4, ¿qué tendrías que cambiar (nada, idealmente)? ¿Hay algún bucle con `(k+1):n` que falle cuando k=n?

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
b) ¿Cuántos intercambios de filas ha habido? ¿Qué signo tiene el determinante respecto al de la diagonal resultante?
c) Haz el mismo ejercicio **sin pivoteo**. ¿Cambia la solución? ¿Y los multiplicadores?

### B3. Pivote pequeño (por qué importa el pivoteo)
Resuelve con aritmética de **3 cifras significativas** (redondeando tras cada operación):

    0.0001 w₁ + 1.00 w₂ = 1.00
    1.00   w₁ + 1.00 w₂ = 2.00

a) Sin pivoteo. b) Con pivoteo parcial. c) Compara con la solución exacta. ¿Qué multiplicador aparece en (a)?

### B4. LU de Doolittle
M = [[4,2,1],[2,5,3],[1,3,6]], b = (7,10,10)ᵀ.
a) Verifica simetría y dominancia diagonal estricta.
b) Calcula L y U con las fórmulas de Doolittle (fila de U, columna de L por cada k).
c) Resuelve Ly=b y Uw=y.
d) Calcula det(M) a partir de U.
e) ¿Es M definida positiva? Verifica con los pivotes. Obtén también la factorización LDLᵀ.
f) Comprueba que LU = M multiplicando.

### B5. LU con pivoteo
M = [[0,2,1],[1,1,1],[2,1,3]], b = (3,3,6)ᵀ.
a) Explica por qué falla LU sin pivoteo.
b) Calcula P, L, U tales que PA = LU.
c) Resuelve el sistema (¡recuerda aplicar P a b!).

### B6. Ridge con la PEC cambiando λ
Con A y b de la PEC:
a) Construye M(λ) para λ = 1 y resuelve por LU. Da L, U, y, w.
b) Verifica el patrón: ¿por qué w₁ = w₃ siempre? (Simetría de A y de b.)
c) Calcula ‖w‖₂ para λ=0, 1, 2. ¿Qué observas?
d) Usa la estructura M = aI + 2J (J=matriz de unos) para deducir M⁻¹ en general. Con eso, rederiva w(λ) en función de λ.

### B7. Normas y condicionamiento
a) Para A y M de la PEC, calcula ‖·‖₁ y ‖·‖∞. ¿Por qué coinciden aquí? (Simetría.)
b) Calcula κ₁(A) y κ₁(M).
c) Calcula los valores propios de A y de M y deduce κ₂(A), κ₂(M).
d) Demuestra que κ∞(M)(λ) = (9+λ)/(1+λ) y calcula para λ = 0, 1, 2, 5, 10.
e) Matriz casi singular: A_ε = [[1,1],[1,1+ε]] con ε = 0.01. Calcula κ∞(A_ε) de forma exacta. Luego regulariza con λ=0.1 y recalcula κ∞.

### B8. Propagación de perturbaciones
Con A y b de la PEC, perturba b a b' = (10, 11.5, 10).
a) Calcula Δb y ‖Δb‖∞/‖b‖∞.
b) Calcula la cota teórica para el sistema ordinario (usa κ∞(A)=9).
c) Resuelve el sistema perturbado y calcula el error relativo **real** ‖Δw‖∞/‖w‖∞.
d) Repite (a)-(c) para el sistema regularizado (M, λ=2).
e) Compara: cota vs. error real. ¿Se cumple siempre cota ≥ real? ¿Por qué la cota no es ajustada?
f) Mismo ejercicio perturbando ahora un dato de X (por ejemplo X₁₁ de 1 a 1.1): ¿qué cambia en la teoría (perturbación en A)?

### B9. Verificación y diagnóstico
a) Para cada solución obtenida (B2, B4, B6) calcula el residuo r = Aw − b y su norma. ¿Cuánto debería ser?
b) ¿Qué indica un residuo pequeño en un sistema mal condicionado? (El residuo pequeño no implica error pequeño.)
c) Da un ejemplo 2×2 donde residuo pequeño pero error grande.

### B10. Código R (a escribir)
Sin mirar tu entrega, escribe desde cero:
a) `norma_inf(M)`.
b) `gauss_pp(A, b)` con detección de pivote nulo (`stop` si |pivote| < 1e-12).
c) `lu_doolittle(M)` devolviendo L y U.
d) `ridge_lu(X, y, lambda)` que construya M, factorice y resuelva con sustituciones propias.
e) `cond_inf(M)` sin usar `solve()` en el solver (¿cómo obtendrías M⁻¹ columna a columna con tus propias sustituciones?).
f) Tests: `all.equal(L %*% U, M)`, `max(abs(A %*% w - b)) < 1e-10`.
g) Un bucle que muestre κ∞(M(λ)) para λ = 0, 0.5, 1, 2, 5, 10 y compáralo con tu fórmula (9+λ)/(1+λ).

### B11. Preguntas de "qué pasaría si" (oral)
1. ¿Y si una columna de X fuese exactamente la suma de otras dos? ¿Qué pasa con A, con el solver, con Ridge?
2. ¿Y si y se multiplica por 10? ¿Cambia κ? ¿Cambia w?
3. ¿Y si escalas la primera columna de X por 1000? ¿Cómo afecta a A, κ y por qué se estandariza?
4. ¿Y si λ=0.0001? ¿Resuelve el problema de la multicolinealidad?
5. ¿Y si te dicen que la matriz es 10 000×10 000? ¿Qué método y por qué (coste O(n³), memoria, matrices dispersas, métodos iterativos)?

---

## Parte C — Puntos débiles probables de tu entrega (prepáralos)

(Son preguntas que un evaluador atento puede hacerte, no correcciones.)

- **Multicolinealidad (1.1)**: tu explicación habla de filas "cada vez más similares" pero no de valores propios ni de la escala. Prepara la versión con λ_min(A)→0 y κ₂ = λ_max/λ_min.
- **Interpretación de 1.4.2**: tu respuesta es solo la razón 27/11. Prepara: la cota de propagación, qué es κ, que es una cota del peor caso, y el efecto sobre los valores propios.
- **Sesgo**: ¿qué se pierde a cambio de reducir κ? Debe aparecer en tu discurso.
- **Pivoteo sin intercambios**: justifica por qué, aun así, el algoritmo es "con pivoteo parcial".
- **Uso de `solve()` en 1.4**: ten clara la frase de por qué está permitido (la prohibición era para resolver los sistemas de 1.2 y 1.3).
- **Notación**: en 1.3 usas y para el vector intermedio, y y es también el vector de ventas. Sepa explicarlo.
- **Código**: sabe explicar cada línea de tu `gauss_pivoteo_parcial` y de `factorizacion_LU`, y qué pasaría con matrices que necesiten pivoteo en LU.

---

## Parte D — Guía detallada: multicolinealidad y la explicación de 1.4.2

### D0. Mapa de lecturas (qué leer y qué NO está en los PDFs)

Abreviaturas: **TEO** = `teoria/Metodos-numericos-en-algebra-nileal.pdf` (FUOC PID_00285408). **PROB-R** = `teoria/Problemas-de-metodos-numeros-en-R.pdf` (FUOC PID_00309524). **Resumen** = `apuntes/resumen-algebra-lineal.md`.

| Orden | Qué leer | Para qué |
|---|---|---|
| 1 | TEO, **desde el inicio de la sección 2 (p. 12) hasta el final de la sección 2.3 (p. 17)** | Rango/invertibilidad (p. 12), valores propios y matrices simétricas (pp. 13–14), normas vectoriales y matriciales (pp. 14–17). Imprescindible: la propiedad ‖AB‖ ≤ ‖A‖‖B‖ (p. 16), ‖Ax‖ ≤ ‖A‖‖x‖ (ec. 18, p. 17) y ‖A‖∞ como máxima suma de filas (ec. 20, p. 17). |
| 2 | TEO, **desde el inicio de la sección 4.3 hasta el final de la p. 37** (justo antes del Ejemplo 11). Lo que importa de verdad está en **pp. 36–37**: vector residual, Ejemplo 10, ec. (83) y definición de K(A) | Es el **único sitio de los PDFs donde aparece el número de condición**. Es la base de tu 1.4. |
| 3 | PROB-R, **desde el inicio de la sección 2.3 hasta el final de la p. 17** (Ejemplo 2 de PCA con covarianzas mal condicionadas por escalas distintas) | Ilustra que la **escala** de las variables deteriora el condicionamiento y que normalizar es la receta. Conecta con la crítica de tu frase "cuanto mayor es aᵢⱼ…". |
| 4 | PROB-R, **Ejemplo 8, pp. 26–28** (regresión con ecuaciones normales resueltas por LU; compras y visitas están muy correlacionadas) | Es exactamente el escenario de tu PEC con datos reales. |
| 5 | PROB-R, **desde el inicio de la sección 4.4.2 hasta el final de la p. 41** (potencia inversa, autovalor mínimo de una SPD) | Cómo se estima λ_min, justo la cantidad que dispara κ₂. |
| 6 | Resumen, **desde "Valores y vectores propios" hasta el final de "Aplicación: potencias de una matriz"** | Diagonalización A = PDP⁻¹; atajo "A simétrica ⇒ diagonalizable", que es la base de lo que usamos aquí. |

**Lo que los PDFs NO cubren** (por eso lo notas flojo; no es culpa tuya): Ridge, multicolinealidad, matriz definida positiva, la fórmula κ₂ = λ_max/λ_min, y el desplazamiento λᵢ(A+λI) = λᵢ(A)+λ. Todo eso sale de la teoría general de álgebra lineal y regresión y lo tienes explicado abajo. En la entrevista puedes citar que el concepto de κ viene de TEO p. 37 y el resto lo deduces.

**Aviso sobre un error en TEO p. 37:** el texto dice "si K(A) es menor que 1, la matriz A está bien condicionada, mientras que si es mayor que 1, mal condicionada". Eso es incorrecto: **κ(A) ≥ 1 siempre**, porque 1 = ‖I‖ = ‖AA⁻¹‖ ≤ ‖A‖‖A⁻¹‖ (propiedad 5 de normas matriciales, TEO p. 16). Se considera bien condicionada si κ es *próximo a 1* y mal condicionada si es *grande* (≫1). Si en la entrevista citas la regla de los apuntes tal cual, te pueden corregir. Mismo error en el recuadro "Importante" de la p. 37.

---

### D1. Multicolinealidad, paso a paso

**Paso 1. Qué es cada elemento de A = XᵀX.**
Las columnas de X son las variables x₁, x₂, x₃ (canales). Entonces aᵢⱼ = xᵢ·xⱼ (producto escalar), y en particular aᵢᵢ = ‖xᵢ‖². Como xᵢ·xⱼ = ‖xᵢ‖‖xⱼ‖cosθᵢⱼ, la cantidad que mide "cuánto se parecen" dos variables es
 cosθᵢⱼ = aᵢⱼ / √(aᵢᵢ·aⱼⱼ),
que es la correlación de Pearson cuando las columnas están centradas. En tu PEC es 2/√(3·3) = 2/3 para los tres pares. El elemento aᵢⱼ por sí solo **no** mide parecido: depende de la escala de las variables y del número de observaciones (si multiplicas x₁ por 1000, a₁₂ se multiplica por 1000 sin que las variables sean más parecidas).
Lectura: TEO p. 12 (definición de matriz simétrica) y PROB-R pp. 16–17.

**Paso 2. Multicolinealidad exacta = A singular.**
Si una columna es combinación lineal de las otras, las columnas de X son linealmente dependientes, rg(X) < n, y rg(XᵀX) = rg(X) < n. Por la lista de equivalencias de TEO p. 12 (A⁻¹ existe ⇔ det ≠ 0 ⇔ filas y columnas l.i. ⇔ rango n), A no es invertible: el sistema Aw = b no tiene solución única (hay infinitas), y Gauss encuentra un pivote nulo.

**Paso 3. Multicolinealidad aproximada = A casi singular.**
Es el caso interesante. Para cualquier vector v, vᵀAv = vᵀXᵀXv = ‖Xv‖² ≥ 0. Dos consecuencias:
- Todos los valores propios de A son ≥ 0 (A es semidefinida positiva). Si las columnas son l.i., son > 0 (definida positiva).
- Si existe un v unitario con Xv ≈ 0 (una combinación de columnas casi nula, es decir, columnas casi dependientes), entonces vᵀAv ≈ 0, de modo que A tiene un valor propio λ_min ≈ 0.

**Paso 4. De λ_min ≈ 0 a κ grande.**
Como A es simétrica, tiene valores propios reales (TEO p. 13, afirmación 1) y es diagonalizable con vectores propios ortonormales: A = Σ λᵢ vᵢvᵢᵀ (Resumen, "A simétrica ⇒ diagonalizable"). Entonces:
- ‖A‖₂ = λ_max.
- A⁻¹ = Σ (1/λᵢ) vᵢvᵢᵀ, luego ‖A⁻¹‖₂ = 1/λ_min.
- **κ₂(A) = ‖A‖₂‖A⁻¹‖₂ = λ_max / λ_min.**
El valor propio máximo no puede hacerse pequeño (λ_max ≥ traza(A)/n), así que cuando λ_min → 0, κ → ∞.
Ojo: tu informe usó κ∞, que no se calcula con valores propios; pero ambas normas son equivalentes salvo factores que dependen de n (TEO p. 16, ec. 14–16), así que el fenómeno es el mismo.

**Paso 5. Por qué importa en estadística: la varianza.**
Con el modelo y = Xw + ε, ε de media 0 y varianza σ² (no correlados), la solución MCO tiene covarianza σ²·A⁻¹ = σ² Σ (1/λᵢ) vᵢvᵢᵀ. En la dirección vᵢ la varianza vale σ²/λᵢ: las direcciones con λ pequeño tienen varianza enorme. Es decir: aunque las predicciones sean razonables, **los coeficientes individuales son inestables** y no puedes decidir cuánto del efecto corresponde a cada canal. Esto es lo que dice el enunciado ("las estimaciones sufren alta variancia").

**Paso 6. Tu matriz.**
A = I + 2·𝟏𝟏ᵀ, con 𝟏 = (1,1,1)ᵀ. Sus valores propios son 7 (vector propio (1,1,1): "los tres canales suben juntos") y 1, 1 (cualquier vector ortogonal a (1,1,1), por ejemplo (1,−1,0)). Entonces κ₂(A) = 7: **moderado, no severo**. Es un ejemplo didáctico del mecanismo, no un caso de multicolinealidad grave. Si te lo preguntan, di eso: sirve para ver cómo λ lo mejora, pero los números son pequeños.
Para ver el caso extremo mira el 2×2 de B7e: A_ε = [[1,1],[1,1+ε]] tiene valores propios ≈ 2+ε y ≈ ε/2, luego κ₂ ≈ 4/ε.

**Paso 7. Escala y estandarización.**
PROB-R pp. 16–17 muestra que una variable del orden de 10⁶ junto a otra del orden de 10⁰ da una matriz de covarianzas mal condicionada **solo por la escala**. Por eso se estandariza antes de aplicar Ridge: la penalización λ‖w‖² trata igual a todos los coeficientes, y si las variables tienen escalas distintas penaliza injustamente a unas. El enunciado habla de "observaciones estandarizadas" por eso.

**Paso 8. Cómo se detecta.** Correlaciones altas entre columnas, valores propios de XᵀX cercanos a 0, κ grande, VIF alto (VIF_j = 1/(1−R²_j)), y coeficientes que cambian mucho al añadir o quitar una variable.

**Lectura de caso real:** PROB-R Ejemplo 8, pp. 26–28: compras (x₁) y visitas (x₂) tienen correlación de Pearson ≈ 0,91. Es el mismo patrón en datos reales.

---

### D2. La explicación de 1.4.2, paso a paso

**Paso 1. Residuo y error.** Lee TEO pp. 36–37. El Ejemplo 10 muestra que un residuo pequeño no implica error pequeño: con A = [[1,2],[1.0001,2]] y x̃ = (3,0)ᵀ el residuo es ‖r‖∞ = 0.0002 pero el error es ‖x−x̃‖∞ = 2. La causa es que A está casi singular (κ∞(A) = 60002).

**Paso 2. La cota de la ec. (83), TEO p. 37.**
 ‖x − x̃‖ / ‖x‖ ≤ κ(A) · ‖r‖ / ‖b‖.
Nuestra versión (perturbación en b) es la misma: si x̃ resuelve Ax̃ = b + Δb, entonces el residuo es r = b − Ax̃ = −Δb. Por eso en tu informe puedes decir "perturbación en los datos" y en el libro verás "residuo".

**Paso 3. Demostración (cuatro líneas, memorízala).**
1. A(w+Δw) = b+Δb y Aw = b, restando: AΔw = Δb, luego Δw = A⁻¹Δb.
2. Por ‖Ax‖ ≤ ‖A‖‖x‖ (TEO p. 17, ec. 18) aplicada a A⁻¹: ‖Δw‖ ≤ ‖A⁻¹‖‖Δb‖.
3. De Aw = b: ‖b‖ ≤ ‖A‖‖w‖, es decir, 1/‖w‖ ≤ ‖A‖/‖b‖.
4. Multiplicando 2 por 3: ‖Δw‖/‖w‖ ≤ ‖A‖‖A⁻¹‖ · ‖Δb‖/‖b‖ = κ(A)·‖Δb‖/‖b‖.

**Paso 4. Qué significa.** κ es el **factor máximo de amplificación** del error relativo: un 1 % de error en los datos puede convertirse en un κ % de error en la solución. Regla práctica: se pierden unos log₁₀κ dígitos significativos. Para κ∞(A) = 9 se pierde un dígito; no es dramático.

**Paso 5. Es cota del peor caso.** Se alcanza cuando b apunta en la dirección del valor propio máximo (así w es pequeño: λ_max·w = b) y Δb apunta en la dirección del valor propio mínimo (así Δw es grande: λ_min·Δw = Δb). Para una matriz simétrica y la norma 2, este caso extremo sí alcanza la cota exactamente (ver E7). Con perturbaciones "normales" el error real es bastante menor: en B8, 0,167 real frente a 0,409 de cota con A y 0,095 frente a 0,167 con M.

**Paso 6. Cómo cambia λ el condicionamiento.** Si A tiene valores propios λᵢ, entonces M = A + λI tiene valores propios λᵢ + λ (mismos vectores propios, pues (A+λI)v = λᵢv + λv). En tu caso: A → {7,1,1}, M → {9,3,3}. Entonces
 κ₂(A+λI) = (λ_max + λ) / (λ_min + λ),
que **decrece monótonamente de λ_max/λ_min (en λ = 0) hasta 1 (λ → ∞)**. Con tus números: (7+λ)/(1+λ): λ=0 → 7, λ=2 → 3.
Con la norma ∞ y esta matriz concreta (estructura aI + 2J): κ∞(λ) = (9+λ)/(1+λ): λ=0 → 9, λ=2 → 11/3. Es lo que tú calculaste a mano.
Interpretación: el valor propio pequeño (el que amplificaba el ruido, 1/λ_min) queda "levantado" a λ_min + λ, así que 1/λ_min deja de explotar. Ese es el mecanismo, y es lo que le falta a tu texto (solo daba el cociente 27/11).

**Paso 7. Cuantificación para la entrevista.**
- Cota de amplificación: de 9 a 11/3 ⇒ factor 27/11 ≈ 2,45 menor.
- Ejemplo: error relativo del 1 % en y ⇒ cota 9 % con A y 3,67 % con M.
- Matiz: "la cota es 27/11 veces menor" ≠ "el error real es 27/11 veces menor".

**Paso 8. Qué se paga: el sesgo.** Ridge resuelve (XᵀX+λI)w = Xᵀy, que no es el problema original. Las componentes de la solución se encogen. En la base de vectores propios, OLS divide por λᵢ y Ridge por λᵢ + λ, de modo que la componente en la dirección i se multiplica por **λᵢ/(λᵢ+λ)**. Para tu caso, λ = 2: dirección (1,1,1): 7/9 ≈ 0,78; direcciones ortogonales: 1/3 ≈ 0,33. Se encoge mucho más justo donde A era más débil. Es el compromiso **sesgo–varianza**: más sesgo, menos varianza. Con λ → ∞: w → Xᵀy/λ → 0 (todo sesgo). Por eso λ se elige por validación cruzada y no al azar.

**Paso 9. Precisión sobre qué estabiliza.** κ es una propiedad del **problema** (la matriz), no del algoritmo. La eliminación gaussiana con pivoteo es estable en la práctica; lo que Ridge mejora es el problema, no el método. Una perturbación en la matriz (en X) también se amplifica por κ aproximadamente (resultado estándar ‖Δw‖/‖w‖ ≲ κ‖ΔA‖/‖A‖; no figura en los PDFs).

**Paso 10. Un detalle fino.** Ridge también se puede ver como el MCO del problema ampliado [X; √λ I] w ≈ [y; 0], cuya matriz es siempre de rango completo si λ>0 (por eso M es invertible aun con X de rango deficiente). Ese razonamiento fuerza la invertibilidad y se menciona en la pregunta 16.

---

### D3. Frases que conviene evitar en la entrevista
- "La multicolinealidad hace que a_ij sea grande." (depende de la escala)
- "κ < 1 es bien condicionada." (κ ≥ 1 siempre)
- "El error es 27/11 veces menor." (la cota lo es)
- "Ridge mejora el algoritmo." (mejora el problema)
- "Mi A está muy mal condicionada." (κ₂ = 7; moderada)
- "Ridge no tiene inconvenientes." (introduce sesgo)

---

## Parte E — Ejercicios de explicar (pregunta oral + checklist de ideas)

Para cada uno: responde en voz alta en 1–2 minutos y marca en la checklist qué ideas cubriste. Si te dejas más de dos, relee la sección indicada.

### E1. Multicolinealidad exacta frente a aproximada
Explica la diferencia usando el rango de X, el rango de A y la invertibilidad. *Checklist:* columnas l.d.; rg(XᵀX) = rg(X); A singular (TEO p. 12); w no único; aproximada = A invertible pero casi singular; qué hace Gauss en cada caso. *Lectura:* D1 pasos 2–3.

### E2. Por qué los valores propios de A son ≥ 0
Demuestra vᵀAv = ‖Xv‖² y concluye. ¿Cuándo es A definida positiva? *Checklist:* usar (Xv)ᵀ(Xv); diferencia entre ≥0 y >0; relación con columnas l.i.

### E3. Multicolinealidad y número de condición con valores propios
Explica sin mirar apuntes por qué λ_min ≈ 0 dispara κ₂. Luego calcula vectores y valores propios de tu A e interpreta qué significa cada uno en términos de canales. *Checklist:* simétrica ⇒ valores propios reales; A = Σλᵢvᵢvᵢᵀ; A⁻¹ con 1/λᵢ; κ₂ = λ_max/λ_min; (1,1,1) con valor 7; (1,−1,0) con valor 1. *Lectura:* D1 pasos 4 y 6; TEO pp. 13–14.

### E4. Reformula tu frase del informe
Tu frase: "cuanto mayor es el elemento aᵢⱼ, más se relacionan esas dos variables". Explica por qué es incorrecta o incompleta y reescríbela correctamente en 2–3 frases. Después calcula (a) el coseno entre las columnas de tu X y (b) la correlación entre compras y visitas del Ejemplo 8 de PROB-R (p. 26). *Checklist:* dependencia de la escala; fórmula cosθ = aᵢⱼ/√(aᵢᵢaⱼⱼ); centrar ⇒ Pearson; estandarizar. *Lectura:* D1 paso 1 y 7; PROB-R pp. 16–17.

### E5. Varianza de los coeficientes
Explica de dónde sale Cov(w) = σ²A⁻¹ y por qué una λ pequeña infla la varianza. Compara traza(A⁻¹) y traza(M⁻¹) para tu PEC e interpreta. *Checklist:* w = A⁻¹Xᵀy es lineal en y; Cov(Ay) = A Cov(y) Aᵀ; varianza σ²/λᵢ por dirección; traza = Σ1/λᵢ. *Lectura:* D1 paso 5.

### E6. Demuestra la cota de propagación
Escribe la demostración completa de ‖Δw‖/‖w‖ ≤ κ‖Δb‖/‖b‖ sin mirar. Indica qué propiedad de normas usas en cada paso. *Checklist:* Δw = A⁻¹Δb; ‖Ax‖ ≤ ‖A‖‖x‖ (TEO p. 17); ‖b‖ ≤ ‖A‖‖w‖; combinarlas. *Lectura:* D2 pasos 2–3; TEO pp. 36–37.

### E7. Caso en que la cota se alcanza
Para tu A y para tu M (λ=2), construye b y Δb (en norma 2) que hagan que el error relativo real sea exactamente κ₂·‖Δb‖/‖b‖. Usa ‖Δb‖/‖b‖ = 0.01 y calcula el error relativo resultante en ambos casos. *Checklist:* b ∥ vector propio de λ_max; Δb ∥ vector propio de λ_min; por qué entonces la cota es exacta. *Lectura:* D2 paso 5.

### E8. Cómo λ mejora κ
Demuestra que los valores propios de A+λI son λᵢ+λ. Deduce κ₂(λ) para tu A y comprueba κ₂(0) y κ₂(2). Después demuestra, con M = aI + 2J, que κ∞(λ) = (9+λ)/(1+λ). *Checklist:* (A+λI)v = (λᵢ+λ)v; κ₂ decrece con λ; límite 1; ¿por qué κ₂ y κ∞ no coinciden? *Lectura:* D2 paso 6.

### E9. La frase "27/11 veces menor"
Redacta en 4 frases la conclusión correcta de 1.4.2. Debe incluir: la cota, los valores 9 y 11/3, el factor 27/11 como factor de la **cota**, y por qué el error real no tiene por qué mejorar exactamente ese factor (usa tus números de B8). *Checklist:* cota ≠ error real; peor caso; unidades de "veces menor"; matiz de que sigue siendo ventaja. *Lectura:* D2 pasos 5 y 7.

### E10. Encogimiento de Ridge por direcciones
Demuestra que en la dirección del vector propio vᵢ la solución de Ridge es la de MCO multiplicada por λᵢ/(λᵢ+λ). Verifica con tu PEC la componente en (1,1,1)/√3 para λ=2, comparando la media de w (OLS) con la media de w_ridge. *Checklist:* descomponer b en base propia; dividir por λᵢ frente a λᵢ+λ; la media de w es proporcional a la componente en (1,1,1). *Lectura:* D2 paso 8.

### E11. Sesgo y varianza
Explica por qué aceptar sesgo puede ser buena idea. ¿Qué pasa con λ muy grande? ¿Y con λ=0.0001 en una X con columnas casi idénticas? ¿Cómo elegirías λ? *Checklist:* error cuadrático = sesgo² + varianza; Ridge reduce varianza más de lo que aumenta sesgo²; λ→∞ ⇒ w→0; validación cruzada. *Lectura:* D2 paso 8; pregunta 19 y 20 de la Parte A.

### E12. Residuo pequeño, error grande
Con el sistema del Ejemplo 10 de TEO (p. 36), calcula κ∞ y explica por qué el residuo no sirve como indicador fiable. Después propón qué mirarías en un sistema real para sospechar este problema. *Checklist:* det casi 0; ‖A⁻¹‖ enorme; ec. (83); comprobar κ antes de fiarse del residuo. *Lectura:* TEO pp. 36–37.

### E13. Detecta el error del PDF
Explica por qué la frase "K(A) < 1 ⇒ bien condicionada" de TEO p. 37 es incorrecta. Demuestra κ(A) ≥ 1. *Checklist:* 1 = ‖I‖ = ‖AA⁻¹‖ ≤ ‖A‖‖A⁻¹‖; qué quiere decir "bien condicionada" realmente; κ = 1 se alcanza con matrices ortogonales en norma 2.

### E14. Simulacro de 2 minutos: "Explícame 1.4.2"
Prepara y di en voz alta tu respuesta completa a 1.4.2 con este guion. Lo ideal es cronometrarte.
1. Qué mide κ y cuánto valen κ∞(A) y κ∞(M).
2. Cota de propagación (fórmula + una línea de por qué).
3. Qué efecto tiene λ en los valores propios y por qué baja κ.
4. Cuantificación: 9 → 11/3, factor 27/11 en la cota.
5. Matiz: peor caso, no el error real.
6. Coste: sesgo; compromiso sesgo–varianza.
7. Cierre: λ se elige por validación cruzada.

### E15. Preguntas trampa
1. ¿Ridge soluciona la multicolinealidad **exacta**? (M invertible sí, pero ¿qué dice de la identificabilidad de cada coeficiente?)
2. ¿Estandarizar las variables cambia κ(XᵀX)? ¿Y los coeficientes?
3. ¿Reducir κ siempre mejora la predicción?
4. ¿Por qué no basta mirar el determinante de A para saber si está mal condicionada? (Ejemplo: αI con α pequeño.)
5. Si κ∞(A)=9, ¿diríais que A está "mal condicionada"? ¿A partir de qué valor lo diríais y por qué?
6. ¿La regularización cambia la solución? ¿Es lo que queremos?

---

## Resultados finales para autocorrección (sin procedimiento)

**B1**: autocomprobación: la traza de A debe ser la suma de los cuadrados de todos los elementos de X, que es 10.

**B2**: w = (1, 2, 3). Dos intercambios de filas.

**B3**: exacta ≈ (1.0001, 0.9999). Sin pivoteo con 3 cifras sale w₁ = 0, w₂ = 1 (multiplicador 10⁴). Con pivoteo sale w₁ = 1.00, w₂ = 1.00.

**B4**: solución w = (1, 1, 1); det(M) = 67. L tiene l₂₁ = 1/2, l₃₁ = 1/4.

**B5**: solución w = (1, 1, 1).

**B6**: w(λ=1) = (9/8, 13/8, 9/8); w(λ=2) = (28/27, 37/27, 28/27); w(λ=5) ≈ (0.8056, 0.9722, 0.8056).

**B7**: κ₂(A) = 7, κ₂(M) = 3. κ∞(λ): λ=0 → 9; λ=1 → 5; λ=2 → 11/3; λ=5 → 7/3; λ=10 → 19/11. Para A_ε: κ∞ = 404.01. Con λ=0.1: κ∞ ≈ 20.15.

**B8** (perturbación b'=(10, 11.5, 10)): ‖Δb‖/‖b‖ = 0.5/11 ≈ 0.04545. Sistema ordinario: cota ≈ 0.409, error real ≈ 0.1667. Regularizado (λ=2): cota ≈ 0.1667, error real ≈ 0.0946.

Contrasta todo con tus propias funciones de R.

**E4**: cosθ entre columnas de X = 2/3 (los tres pares). Correlación de Pearson compras–visitas del Ejemplo 8 ≈ 0,906.

**E5**: traza(A⁻¹) = 15/7 ≈ 2,143; traza(M⁻¹) = 7/9 ≈ 0,778.

**E7** (con ‖Δb‖/‖b‖ = 0,01 en norma 2): error relativo real = 0,07 con A y 0,03 con M (iguales a κ₂·0,01).

**E8**: κ₂(A) = 7 y κ₂(M) = 3; κ₂(λ) = (7+λ)/(1+λ).

**E10**: factores de encogimiento con λ=2: 7/9 en la dirección (1,1,1) y 1/3 en las ortogonales; la media de w pasa de 31/21 a 31/27, cociente 7/9.

**E12**: κ∞ = 60002.
