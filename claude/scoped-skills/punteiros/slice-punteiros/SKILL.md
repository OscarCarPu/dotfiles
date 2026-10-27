---
name: slice-punteiros
description: Lamina piezas del proyecto punteiros (punteiro, segmentos de prueba, escariador, capuchón) con el CLI de Orca aplicando los ajustes finales de CAMBIOS_SLICER.md. Úsalo siempre que se pida laminar, sacar gcode o preparar una placa de estas piezas.
---

# slice-punteiros

Antes de laminar **lee `CAMBIOS_SLICER.md`** (raíz del proyecto, `~/docs/punteiros/`): son los ajustes
finales que no están en los perfiles (arcos de los agujeros, capa mínima, elevación Z, colocación en la
placa, comprobaciones). Aplica eso y nada más.

## Pasos

1. **Lamina con el script de la skill**, que aplica todo lo de `CAMBIOS_SLICER.md` y hace las dos pasadas
   (exportar 3MF → meter rangos y recolocar conservando la `z` → laminar):
   ```sh
   python3 .claude/skills/slice-punteiros/laminar.py pla|asa arriba|abajo|anilla [--n N] [--sin-anilla] [--sin-pie] [--espera S] [-f]
   python3 .claude/skills/slice-punteiros/laminar.py pla|asa tramo Z0 Z1 [--n N] [--espera S] [-f]   # prueba, sin soporte
   python3 .claude/skills/slice-punteiros/laminar.py pla|asa arriba --hasta Z [...]   # la torre con pie cortada en z modelo Z (con sus arcos)
   python3 .claude/skills/slice-punteiros/laminar.py pla arriba --perfiles DIR [...]   # perfiles antiguos resueltos (DIR/machine|process|filament/<nombres de siempre>)
   python3 .claude/skills/slice-punteiros/laminar.py pla arriba --rangos [...]   # con arcos, techos y reborde (descartados)
   ```
   - `arriba` lleva el pie de agarre (STL `punteiro_do_arriba_pie`, soporte 100 y `support_on_build_plate_only`
     0); `abajo` va con anilla salvo `--sin-anilla`. Por defecto 2 copias; `--n N` las pone en rejilla
     centrada con 15 mm entre piezas y el brim dentro de la cama, y dice cuántas caben si no caben.
   - Hace `make`, aplana los perfiles (máquina `core-one-obxidian`, proceso y filamento punteiros del material:
     los del 31 de julio con la base del pie), pone los rangos del pie (con `--rangos`, también los de
     `arcos_agujeros.py`) y deja `gcode/v<actual+1>/pruebas/DD_MM_<mat>_<pieza>_xN.{gcode,3mf}` (actual = la `vN` más alta
     de `stls/`). No sobrescribe sin `-f`.
   - `anilla`: la anilla suelta, con el proceso de punteiros, sin soporte ni rangos; caben 9.
   - **Set de una versión validada:** `make laminar V=N [MAT=pla]` (congela `stls/vN/` —STL, perfiles tal cual y
     resueltos, laminado— y lamina todo con esos perfiles en `gcode/vN/<mat>/`; ver `VERSIONES.md`). No se lanza sin que el usuario dé la versión por válida.
   - Al final imprime las comprobaciones del §4 (perfiles, cama, tiempo, gramos, objetos, soporte,
     plancha, error de los planos críticos). **Revísalas** y avisa de cualquier cosa fuera de lo esperado.
2. Piezas que el script no cubre (pruebas compuestas, escariador, capuchón): misma mecánica a mano,
   con la skill `orca-slicer-cli` para aplanar perfiles y `arcos_agujeros.py --seg` para los rangos.
   **Una copia = un objeto** en el 3MF (nunca fundir copias en un STL: se pierden los `M486` por objeto).
3. Informa de tiempo, gramos y qué se aplicó.

## Reglas

- **No edites perfiles** de `~/.dotfiles`: propón el cambio y espera.
- **No propongas ni reintroduzcas opciones que no estén en `CAMBIOS_SLICER.md` o `APRENDIZAJES.md`** para
  los agujeros o el laminado (velocidades de techo, otras alturas o holguras, teardrop, soporte en el
  agujero…). Si el usuario pide reabrir algo descartado, el registro está en `punteiros-docs/Descartados.md`;
  no lo leas por iniciativa propia.
- Los resultados de las pruebas y los problemas nuevos van a `VERSIONES.md`, en la versión en curso.
- Lo que se compruebe nuevo va a `APRENDIZAJES.md` (estado actual) y, si cambia cómo laminar, a
  `CAMBIOS_SLICER.md`. Lo que se descarte, con su motivo, a `punteiros-docs/Descartados.md`, y se borra de
  los otros dos.
