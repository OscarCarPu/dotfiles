---
name: revision-trimestral
description: Revisión trimestral del plan de carrera de Oscar, el primer día de cada trimestre (1 ene, 1 abr, 1 jul, 1 oct). Hace el balance del trimestre que acaba, resume lo que piden las ofertas, elige los proyectos o certificaciones del siguiente con su % de tiempo y deja la tarea de la siguiente revisión en gv. Usar cuando diga "revisión trimestral", "planificación del trimestre", "revision Q planificacion Q" o /revision-trimestral.
---

# Revisión trimestral

Cierra un trimestre y planifica el siguiente. Decide **qué proyectos y qué %**, nunca cómo se hacen. Lee
primero `CLAUDE.md` de esta carpeta y respeta sus reglas duras (sin tareas, tecnologías, estimaciones ni
horas en los archivos).

## 1. Preparar

1. Lee `plan.md` (trimestre vigente), las entradas de `revisiones.md` del trimestre y
   `proyectos-futuros.md`.
2. Mide el reparto real de tiempo de todo el trimestre con la consulta de `CLAUDE.md`, agregado por
   proyecto. Solo se guardan los porcentajes.

## 2. Balance del trimestre que acaba

Por cada proyecto, pregunta a Oscar y apunta: % final de avance, % de tiempo real frente al planeado,
**qué se ha obtenido** y qué falló. Sin contenido concreto. Si algo está a medias, di qué opción
recomiendas: cerrarlo, seguir o dejarlo en la cola.

## 3. Mirar las ofertas

Lee `../CV/aplicaciones.md` y `../CV/ofertas_vistas.md` desde la última trimestral y resume **en una
línea por tendencia**, sin listar ofertas:

- Qué tecnologías y qué años se repiten.
- Los motivos de rechazo o de descarte que se repiten.

Aplica la regla de decisión de certificaciones de `../CV/plan_post_aws_failover.md` (Databricks o AWS
según lo que pidan las ofertas). Si algo no está verificado, dilo.

## 4. Elegir el siguiente trimestre

Propón, con una recomendación clara:

- **Qué proyectos** (o certificaciones) y el **% de cada uno**, sumando 100 %. Máximo dos a la vez; un
  tercero solo si lo justifica una espera de materiales o de datos. Mira `proyectos-futuros.md`.
- Si hay pico del grado en el trimestre, di qué expectativas se reducen.
- Para cada proyecto nuevo: repo nuevo, funcionalidad semireal y que Oscar pueda defenderlo.

Espera su confirmación antes de escribir.

## 5. Apuntar

1. Añade la entrada arriba de `revisiones.md` con la plantilla trimestral.
2. Reescribe `plan.md` §3 con el trimestre nuevo y §4 con las fechas siguientes. Actualiza
   `proyectos-futuros.md` (estados, entradas y salidas de la cola).
3. En `gv`, con su OK:
   - Marca como hecha la tarea de esta revisión (`finished_at`).
   - Crea en el proyecto `carrera` (id 31) la tarea «revision Qn planificacion Qn+1» con fecha el primer
     día del trimestre siguiente.
   - Si un proyecto nuevo no tiene proyecto en `gv`, créalo para poder medir el tiempo, donde indica la
     tabla "Dónde va cada proyecto en `gv`" de `CLAUDE.md` (carrera, gv, domótica o proyectos secundarios).
   - La tarea «hacer revision 2027» de `casa` cae el mismo día que esta revisión (1 de enero) para
     cruzar la información: tenla en cuenta.

## Lo que no hace

No planifica tareas de los proyectos, no lee sus repositorios, no apunta horas y no modifica el CV ni
las candidaturas.
