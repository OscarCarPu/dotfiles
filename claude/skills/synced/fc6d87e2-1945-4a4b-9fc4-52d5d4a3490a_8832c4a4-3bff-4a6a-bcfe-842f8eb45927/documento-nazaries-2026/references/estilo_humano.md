# Escribir sin que suene a IA

Objetivo: que un lector del sector no identifique el documento como generado
automáticamente. El script `scripts/revisar_texto.py` detecta la parte mecánica de lo
que viene abajo, pero lo decisivo no se automatiza.

## Lo que de verdad delata a un modelo

Ordenado por peso real, de mayor a menor.

**1. Falta de especificidad.** El tell más fuerte, y el único que no se arregla
editando palabras. Un texto humano cita el sistema por su nombre, la fecha de la
incidencia, la cifra exacta, el nombre del proceso, la consecuencia concreta. Un texto
generado dice «diversos sistemas», «recientemente», «un porcentaje significativo»,
«mejorar la eficiencia». Regla: cada capítulo aporta al menos un dato verificable
tomado del material del cliente. Si el dato no está en el material, se pregunta al
usuario o se marca `[pendiente: dato]`. Nunca se inventa una cifra ni se rellena con
un porcentaje plausible.

**2. Uniformidad estructural.** Párrafos todos de tres frases, frases todas de longitud
media, cada capítulo con la misma secuencia de bloques, cada sección cerrada con una
frase que resume lo dicho. Un documento escrito por una persona es irregular: hay un
párrafo de seis líneas y luego una frase de cinco palabras. Alternar deliberadamente.

**3. Simetría decorativa.** Enumeraciones de tres siempre («clara, rigurosa y
estructurada»), pares de adjetivos en cada frase, viñetas de longitud calcada, títulos
todos con la misma forma gramatical. Un texto humano rompe la serie: dos elementos
aquí, cinco allá.

**4. Vocabulario de relleno.** Adjetivos que no discriminan nada: robusto, potente,
sólido, integral, holístico, clave, estratégico, innovador, disruptivo, escalable usado
como adorno. Sustantivos comodín: sinergia, ecosistema (salvo referido a comunidad
real), paradigma, hoja de ruta usado como metáfora vacía. Verbos infladores: potenciar,
maximizar, impulsar sin objeto concreto, desbloquear.

**5. Muletillas de modelo.** Lista de prohibidos en la sección siguiente.

**6. Sobrecarga de énfasis.** Negrita en cada párrafo, cursivas para señalar obviedades.
Como máximo dos o tres negritas por capítulo, y solo en la idea que el lector debe
retener si lee en diagonal.

## Prohibidos

Fórmulas de apertura y transición:

- «En un mundo cada vez más…», «En el panorama actual», «En la era de…»
- «Es importante destacar / señalar / mencionar / recordar que»
- «Cabe destacar», «Vale la pena mencionar», «No hay que olvidar que»
- «Como hemos visto», «Como se ha mencionado anteriormente»
- «En resumen», «En definitiva», «En conclusión» abriendo párrafo
- «Además», «Asimismo», «Por otro lado» encadenados párrafo tras párrafo
- «Profundicemos», «Exploremos», «Sumérgete en»

Construcciones:

- Sintaxis contrastiva: «No es X, es Y». El manual de marca la usa alguna vez («No se
  trata de qué decimos, sino de cómo…»), así que no se prohíbe del todo: **como máximo
  una por documento**, y solo si el contraste aporta información.
- «No solo… sino también».
- Negación retórica: «no es opcional, es obligatorio».
- Definir algo empezando por lo que no es.
- Gerundios de cierre: «permitiendo así», «logrando de esta manera», «generando un
  impacto», «brindando».
- Preguntas retóricas que el propio texto responde a continuación.
- «Simplemente» y «solo» cuando encubren un proceso que merece descripción.
- Calificativos que debilitan sin aportar: «quizá», «posiblemente», «en cierta medida».

Tipografía:

- Guion largo (—) y guion medio (–): ninguno en prosa. Reestructurar la frase; si hace falta un
  aparte, usar comas, punto y coma, dos puntos o paréntesis. En rótulos de portada del
  tipo «INFORME TÉCNICO – 2026» el guion es formato de la plantilla.
- Emojis e iconos: ninguno.
- Signos de exclamación: ninguno en documentos de tono experto.
- Comillas rectas mezcladas con tipográficas: unificar en «» para citas en castellano.

## Lo que sí lleva un cierre

Un informe o una propuesta terminan con un siguiente paso concreto: una reunión, una
decisión que hay que tomar, un plazo. Lo que se elimina es el cierre vacío tipo
«esperamos que este documento resulte de utilidad».

## Repaso final

Leer el documento entero de una pasada, en voz alta si es posible, y comprobar:

1. ¿Aparece al menos un dato concreto por capítulo?
2. ¿Se alternan párrafos largos y frases cortas?
3. ¿Hay alguna enumeración que no sea de tres elementos?
4. ¿Se puede sustituir algún adjetivo por un dato?
5. ¿Sobrevive alguna frase que podría estar en el documento de cualquier otra empresa?
   Si sí, sobra o hay que concretarla.
6. ¿Cuántas negritas hay por capítulo? Más de tres, quitar.
