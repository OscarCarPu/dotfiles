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
{printer}-{material}-{producer}-{nozzle}-{tier}[-{usage}]
```

`tier` is the layer height band, not a subjective label: **draft / speed /
quality**. `usage` is only present for a special-purpose variant (`punteiros`);
its absence means general use. Filaments use the same scheme without `tier`.
Renaming a preset breaks the reference inside any saved 3MF that used it.

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

Two independent failures follow, and neither is a flow problem — which is why
calibrating the filament did not help and in fact made it worse, because the
raised flow cap let the profile print *faster*:

1. **Gaps between adjacent top-surface lines.** With `top_surface_pattern =
   monotonicline` every line is printed separately with its own travel, start and
   stop. On a 1.9 mm line the pressure transient *is* the whole line, so the
   lines never weld to each other. `monotonic` connects consecutive lines with a
   turn instead — far fewer start/stop events. **monotonicline is better on
   large surfaces and worse on narrow slivers.**
2. **Nothing underneath to sit on.** 15 % gyroid inside a 1.6 mm cavity is
   disconnected stubs, so the top shells sag. On a 4 mm part solid infill costs
   almost nothing.

`core-one-pla-figutech-hf-quality` is the answer to this: 0.15 mm layers, 100 %
infill, `monotonic` top surface, ironing on, `small_perimeter_speed` down from
the vendor's 170 to 60, outer wall 80, outer-wall acceleration halved to 1500,
and supports off (a flat topper needs none, and its internal slot cannot be
supported anyway with `support_on_build_plate_only`).

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
