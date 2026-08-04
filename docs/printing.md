[⬅ Back to main README](../README.md)

# Printing

CUPS with a driverless (IPP Everywhere) queue for the network Epson.
Set up 2026-07-21.

For the package list see [`packages.md`](packages.md#printing).

## Printer

- **Epson ET-3850** on the LAN at `192.168.4.52` (DHCP — if printing stops
  working, re-scan: it answers on ports 631/IPP and 9100/raw).
- IPP requires TLS (plain HTTP POST to `:631` returns 426 Upgrade Required).
- Does **not** accept PDF directly. `document-format-supported` is only
  `pwg-raster`, `urf`, `jpeg`, `escpr` and `octet-stream` — so something has
  to rasterize PDFs before they reach the printer. That is CUPS's job; don't
  bypass it.

## Setup

```bash
sudo pacman -S --needed cups cups-filters cups-runit
sudo ln -sf /etc/runit/sv/cupsd /run/runit/service/   # activate service
lpadmin -p epson -E -v "ipps://192.168.4.52:631/ipp/print" -m everywhere
lpadmin -d epson                                       # system default
```

`-m everywhere` builds the queue from the printer's own IPP attributes
(driverless) — no Epson driver package needed. `lpadmin` works without sudo
(user is in CUPS's admin group). Right after activating the service give
runsvdir a few seconds before touching `lpadmin`, or it fails with
"Descriptor de fichero erróneo".

## Usage

```bash
lp file.pdf                      # print to default queue
lp -d epson -o media=A4 f.pdf    # explicit queue / paper size
lp -n 2 f.pdf                    # copies
lpstat -o                        # pending jobs
lpstat -W completed -o           # finished jobs
cancel epson-42                  # cancel a job
```

Web UI: <http://localhost:631>.

## Lesson learned (why driverless CUPS, not raw IPP)

First attempt was a hand-rolled IPP Print-Job over TLS with Ghostscript
`-sDEVICE=pwgraster` output. The job printed, but shifted down and clipped
with rendering artifacts: the printer expects the raster to account for its
hardware margins and PWG header geometry, which the CUPS filter chain
(`pdftopdf → ghostscript → rastertopwg`) derives from the queue's IPP
attributes automatically. Hand-built rasters get none of that. If a print
comes out shifted/clipped, check the job went through the CUPS queue and not
straight to `:631`/`:9100`.

## 3D printing — OrcaSlicer profiles

Profiles live in `configs/OrcaSlicer/user/default/{machine,filament,process}/` and
are symlinked into `~/.config/OrcaSlicer/user/default/`, so editing either side
edits the repo. Machine presets (`core-one`, `personal-ender`) keep their plain
names because `compatible_printers` in every filament and process refers to them.

### Naming convention

```
filament:  {printer}-{material}-{producer}-{nozzle}
process:   {printer}-{material}-{nozzle}-{tier}[-{usage}]
```

`tier` is the layer height band, not a subjective label: **draft / speed /
quality**. `usage` is only present for a special-purpose variant (`punteiros`);
its absence means general use. Renaming a preset breaks the reference inside any
saved 3MF that used it.

**Processes carry no producer on purpose.** Orca has no filament↔process
compatibility mechanism — both filter by printer only. Putting a spool brand in a
process name implies a coupling that does not exist and makes you feel obliged to
change the process when you change filament. The producer belongs on the
filament, which is the only place Orca actually uses it.

### One machine preset per nozzle

`core-one` inherits *Prusa CORE One HF 0.4 nozzle*, `core-one-obxidian` inherits
*Prusa CORE One 0.4 nozzle*. This is not cosmetic. The vendor start gcode emits

```gcode
M862.1 P[nozzle_diameter] A{(printer_notes=~/.*ABRASIVE_NOZZLE.*/ ? 1 : 0)} F{(printer_notes=~/.*HF_NOZZLE.*/ ? 1 : 0)}
```

so the `F` flag — "this print requires a high-flow nozzle" — comes from the
keyword `HF_NOZZLE` in `printer_notes`, which only the HF machine preset carries.
Slicing with the HF preset while the standard Obxidian is installed emits `F1`
and the printer refuses the job. `A` works the same way for abrasive nozzles;
`A0` with a hardened nozzle installed is fine, since having more than required is
never an error.

Two presets also make the dropdowns behave: every filament and process declares
`compatible_printers` for exactly one machine, so choosing the machine filters
both lists down to that nozzle and the wrong combination cannot be picked.
Machine presets keep plain names — the convention does not cover them, and
`compatible_printers` everywhere refers to them.

| Nozzle | draft | speed | quality |
|---|---|---|---|
| CORE One HF | 0.28 DRAFT | 0.20 SPEED | 0.15 SPEED |
| CORE One Obxidian | — | 0.20 SPEED | 0.10 FAST DETAIL |
| Ender stock | 0.24 Draft | 0.16 Optimal | 0.12 Fine |

Every profile is a thin delta over a Prusa/Creality vendor base via `inherits`.
Resolve the full chain before judging a value — most of the config is inherited
and the JSON only shows what differs.

### Figutech PLA, calibrated 2026-08-04 (HF 0.4 nozzle)

| Setting | Value | How it was obtained |
|---|---|---|
| `nozzle_temperature` | 225 / 230 | temperature tower found nothing better; these are Prusa's |
| `filament_max_volumetric_speed` | 17 | Max flowrate test: degradation from 19, clearly bad at 21.5 |
| `filament_flow_ratio` | 1.02 | Flow rate pass 1 picked 0 (= 1.0), +2 % as margin |

Prusa's declared 22 mm³/s for this nozzle is optimistic — 21.5 was already
clearly failing. The failure was gradual with **no extruder clicking**, which
means it is a melt-rate limit, not a torque limit.

Consequence worth remembering: 17 mm³/s is **above** the non-HF limit of 15, so
the Figutech profile is HF-only. The Obxidian nozzle uses
`core-one-pla-generic-obxidian`, which inherits Prusa's non-HF base, until the
same test is repeated with that nozzle mounted. Max flowrate and pressure
advance are per-nozzle; temperature and flow ratio transfer.

### Calibration gotchas found the hard way

- **A temperature tower proves nothing unless the flow cap is lifted first.** With
  a low `filament_max_volumetric_speed` every band prints at the same throttled
  speed and they all look identical. Raise the cap to the vendor value for the
  test print.
- **Small models are throttled by `slow_down_layer_time` (8 s), not by flow.** A
  short tower's layers take 3-4 s, so Orca stretches them and the high-flow
  condition never happens. The Max flowrate test is immune: it sets
  `filament_max_volumetric_speed = 200` and `slow_down_layer_time = 0`, visible
  in the gcode footer — check those two lines to confirm a calibration is valid.
- **Don't chase flow ratio past ~2 %.** Filament diameter tolerance of ±0.02 mm
  on 1.75 is ±2.3 % in cross-section, so pass 2 measures spool noise.
- **Input shaping and Cornering calibrations are useless on a CORE One.** Both
  write a firmware value that Buddy does not accept from the slicer.
- Height-to-flow for the Max flowrate test with start 5 / step 0.5:
  `flow ≈ 5 + 0.5 × height_mm` (verified against the feedrates in the gcode).

### Slicer behaviours that make settings silently inert

- `support_top_z_distance` is snapped to a whole number of layers. 0.15 became
  0.2 on the 0.20 mm profiles and 0.28 on the draft one. Set it to a real
  multiple of the layer height so the file says what happens.
- At `sparse_infill_density: 100%` the sparse pattern is ignored — Orca uses
  `internal_solid_infill_pattern`. A `gyroid` line there does nothing.
- `filament_max_volumetric_speed` never causes under-extrusion; Orca slows down
  to respect it. Under-extrusion means the melt or the flow ratio, not the cap.

### Flat toppers (`toppers-tarta`): why they printed badly

Cake toppers are ~4 mm tall extruded 2D text: 20 layers at 0.2 mm, of which 8
are solid shells, and letter strokes barely wider than two perimeters. Measured
in the sliced gcode of `parabens.stl`: sparse infill segments have a **median
length of 1.63 mm** and top-surface lines **1.90 mm**, against 24 822 outer-wall
segments averaging 0.57 mm.

None of it is a flow problem — which is why calibrating the filament did not
help and in fact made it worse, since the raised flow cap let the profile print
*faster* (144 → 189 mm/s).

**Root cause: `wall_loops` caps arachne.** The gcode used line widths of 0.492,
0.546, 0.594 and **0.643 mm** from a 0.45 nominal — arachne widening beads to
1.43×. That only happens when it is not allowed to add another one. A ~1.3 mm
letter stroke wants three beads of 0.43; `wall_loops: 2` forces two of 0.64
instead, and two heavily over-widened beads do not fuse in the middle — they
leave a valley running the length of every stroke. Where not even widening
reaches, the leftover sliver is filled by internal solid infill stubs with a
**median length of 0.35 mm** (6299 of them), each its own start and stop.

Raising `wall_loops` to 6 lets arachne cover a narrow stroke entirely with
properly-sized concentric loops. A loop is continuous, so the start/stop
transients disappear along with the gaps. Note the punteiros profiles had
already arrived at `wall_loops: 4` empirically for the same reason.

Two secondary contributors, both inherited from the vendor base:

- `precise_outer_wall: 1` deliberately reduces overlap between the outer wall
  and the next one so outer dimensions come out exact. The documented side
  effect is a gap between those two beads. Fine for functional parts, wrong for
  decorative ones — set it to 0.
- `top_surface_pattern: monotonicline` prints every line separately with its own
  travel, start and stop. On a 1.9 mm line the pressure transient *is* the whole
  line. `monotonic` connects consecutive lines with a turn instead.
  **monotonicline is better on large surfaces and worse on narrow slivers.**

Both `-quality` profiles now carry `wall_loops: 6`, `precise_outer_wall: 0`,
`detect_thin_wall: 1`, `monotonic` top surface, ironing on, and
`infill_wall_overlap: 25%`. Infill density stays at the vendor's 15 %: once the
perimeters cover the stroke there is nothing left for infill to do, so forcing
100 % only costs time.

`small_perimeter_speed` is the setting nobody looks at and it governs exactly
these letter contours — the vendor bases leave it at 145-170 mm/s. It is set per
profile to land at the same **~4 mm³/s** floor rather than the same speed: 60 at
0.15 mm, 90 at 0.10 mm. Going below that floor is how the earlier heat-creep jam
happened.

### Tall slender parts (`punteiros`): plate several at once

A ~93 mm² × 230 mm punteiro at 0.10 mm is 2300 layers of only 214 mm of
extrusion each. That takes 1.78 s at the profile's speeds, so
`slow_down_layer_time` (8 s) stretches every one of them by **4.5×** — the
speeds written in the profile never apply. The result is 27 mm/s average, i.e.
**1.2 mm³/s sustained for over five hours** with the hotend at 225 °C in a
closed chamber. That is the heat-creep jam, and no combination of process
settings avoids it: `slow_down_layer_time` is a *filament* setting and raising it
just trades a jam for a deformed tower, which is what the rule exists to prevent.

The fix is on the plate, not in the profile: **print five at once**. Per-layer
extrusion goes to ~1070 mm, each layer takes 8.9 s naturally with no throttling
at all, flow rises to ~5.4 mm³/s, and the cooling requirement is satisfied
because the head is away from any given part 80 % of the time. Both problems
disappear together.

Second trap on tapering parts: `wall_generator: classic` with `wall_loops: 4`
needs 3.6 mm of section for the walls to fit, and the classic generator cannot
vary bead width — it silently drops what does not fit. On a part that comes to a
point, the point is what disappears. Use `arachne` plus `detect_thin_wall: 1`.

Also relevant: uneven layer times cause banding on these parts. Solid layers
move ~2000 mm of extrusion and run at full speed; sparse layers move ~700 mm and
get stretched to the 8 s minimum, so bands of layers print at different speeds
and look different. `slow_down_layer_time` is a *filament* setting, not a process
one, if that ever needs equalising.

## MuseScore batch PDF export

Related workflow (tune folders like `~/docs/tiamila/arreglos/`): export the
full score (all instruments) of every `.mscz` headlessly:

```bash
for f in *.mscz; do
  QT_QPA_PLATFORM=offscreen mscore -o "${f%.mscz}.pdf" "$f"
done
```

- Exports the main score only; individual parts need `--score-parts-pdf`.
- **Scores saved in continuous view export as one giant page.** The culprit is
  `<layoutMode>system</layoutMode>` near the top of the `.mscx` inside the
  `.mscz` (the `viewsettings.json` member is irrelevant to export). Fix in the
  GUI (switch to page view, save) or strip the element from the zip member and
  re-export. Symptom: `pdfinfo` shows a page much taller than A4.
- Concert-pitch state is whatever was saved in the file — check with
  `unzip -p score.mscz score_style.mss | grep concertPitch` (`0` = off,
  i.e. transposing view).
- Count pages of the result: `for f in *.pdf; do pdfinfo "$f" | awk '/^Pages:/{print $2}'; done`.
