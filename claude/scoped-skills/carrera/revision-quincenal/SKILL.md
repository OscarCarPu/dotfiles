---
name: revision-quincenal
description: Revisión quincenal del plan de carrera de Oscar (cada dos lunes). Mide el % de tiempo real por proyecto desde gv, repasa el tiempo total, los huecos y las pérdidas de tiempo del periodo, le pregunta el % de avance, lo que obtiene y lo que falla de cada uno, decide si añadir un proyecto, reducir expectativas o reajustar los %, y lo apunta en revisiones.md sin contenido concreto. Usar cuando diga "revisión quincenal", "revisión de carrera", "toca la revisión del lunes" o /revision-quincenal.
---

# Revisión quincenal

Dura 20-30 minutos. Es una revisión del **plan**, no del contenido de los proyectos: no se planifican
tareas, no se estiman horas, no se abren los repos. Lee primero `CLAUDE.md` de esta carpeta y respeta sus
reglas duras.

## 1. Preparar

1. Lee `plan.md` §3 (trimestre vigente) y la última entrada **quincenal** de `revisiones.md`: de ahí
   salen la fecha de la revisión anterior y los % planeados. La trimestral es independiente: aunque
   caiga cerca, esta revisión se hace igual.

## 2. Medir el tiempo real

Ejecuta la consulta de `CLAUDE.md` (sección "Medir el % de tiempo") con los ids de `gv` de la tabla de
`plan.md` §3 y la fecha de la revisión anterior. Calcula el reparto **entre los proyectos de la tabla**
y compáralo con el planeado.

Mira además **todo el tiempo del periodo, no solo carrera** (carrera sigue siendo lo principal):

- **Horas totales:** total registrado, por proyecto raíz y por tarea, y por día. La tarea «Nazaries» es
  trabajo: cuenta en el total, pero no en el reparto de carrera.
- **Huecos:** los tramos largos sin registrar fuera de las noches, cruzados con `plan_blocks`. Pregúntale
  a Oscar si están justificados; no lo deduzcas.
- **Pérdidas de tiempo:** si algo concreto se llevó mucho tiempo, sobre todo si superó a los proyectos de
  carrera. Compara también con los bloques planificados.

Trabaja las horas con Oscar **en la conversación**. En los archivos solo se apuntan porcentajes y
conclusiones generales, nunca horas.

## 3. Preguntar, proyecto por proyecto

1. **% de avance** del proyecto respecto a lo que se propuso para este trimestre.
2. **Qué se está obteniendo** (un resultado o capacidad en general, sin nombres de tareas, tecnologías ni
   diseño).
3. **Qué falla** (bloqueos, desgana, falta de materiales o de datos).

Si no sabe algo, apunta "sin dato". No lo inventes ni lo deduzcas del repositorio.

## 4. Decidir

Con los datos, da una recomendación sobre cada punto, sin repasar todas las opciones:

- ¿Hace falta **añadir** un proyecto? Solo cabe si hay menos de dos activos, o si un tercero se justifica
  por una espera de materiales o de datos (mira `proyectos-futuros.md`).
- ¿Hay que **reducir expectativas**? Tiene en cuenta los picos del grado (entregas del 8 al 15 de enero
  de 2027).
- ¿Hay que **reajustar los %** porque el tiempo real se aleja del plan?
- ¿Qué falla y qué no?

## 5. Apuntar

1. Añade la entrada arriba de `revisiones.md` con la plantilla quincenal: tabla por proyecto (% de
   avance, % de tiempo plan → real, qué se obtiene, qué falla), decisiones y próxima revisión.
2. Si Oscar confirma un cambio de proyectos o de %, actualiza `plan.md` §3 (y `proyectos-futuros.md` si
   un proyecto sale o entra de la cola). Si entra un proyecto sin proyecto en `gv`, ofrece crearlo.
3. La próxima revisión es el lunes dentro de 14 días, aunque caiga cerca de una trimestral.

## Lo que no hace

No planifica ni estima tareas de un proyecto, no lee repositorios, no apunta horas, no toca el CV ni
las candidaturas y no mira las ofertas (eso es de la trimestral).
