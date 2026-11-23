---
name: orca-slicer-cli
description: Slice STLs headlessly with the orca-slicer CLI (v2.4.x) using the user's own presets from ~/.dotfiles/configs/OrcaSlicer/user/default. Use when asked to "slice", "try to slice", or export gcode/3mf for a machine/process/filament preset combination without the GUI, including multi-copy plates with a fixed spacing.
---

# Slicing with the orca-slicer CLI

The CLI cannot load user presets by name. Their `inherits` chains must be flattened first.

## 0. Orca >= 2.5: system profiles are packed (`*.opc`)

Since 2.5.x `~/.config/OrcaSlicer/system/` only holds binary `*.opc` bundles, so `resolve_profiles.py`
finds no parents, and passing a preset that keeps `inherits` fails with
`can not resolve preset ...: Preset was not found in the loaded bundle` (return -5).
Workaround (works, verified 2.5.1):

1. Sparse-clone the profile JSONs for the installed tag (`orca-slicer --help | head -1` gives the version):
   `git clone --depth 1 --branch v2.5.1 --filter=blob:none --sparse https://github.com/SoftFever/OrcaSlicer.git orca-src && cd orca-src && git sparse-checkout set resources/profiles/Prusa resources/profiles/OrcaFilamentLibrary`
2. `python3 -I flatten_v25.py <orca-src> <outdir> '{"process_key":"override"}'` (next to this file; edit the
   three `go(...)` lines). It merges the full chain, follows `renamed_from` aliases (e.g. `Prusa Generic PLA @CORE One`
   is now `Generic PLA @Prusa CORE One`), **drops `inherits` everywhere** and blanks all compatibility fields.
3. Pass the outputs with **absolute paths** to `--load-settings` / `--load-filaments`.

Several pre-positioned STLs + `--arrange 0` keep their own coordinates as separate objects (no need to merge).

## 1. Flatten the presets (Orca <= 2.4)

`resolve_profiles.py` (next to this file) merges each user preset over its system parents
(`~/.config/OrcaSlicer/system/*/*/*.json`) and writes `m.json`, `p.json`, `f.json` in the cwd.
Copy it to the scratchpad and edit the three `go(...)` lines at the bottom for the wanted
presets (paths are relative to `~/.dotfiles/configs/OrcaSlicer/user/default/`).

Rules it applies (all required, otherwise `return -17` "not compatible"):

- `type` injected: `machine` / `process` / `filament`.
- **machine** keeps `inherits` (the system printer name, e.g. `Prusa CORE One 0.4 nozzle`).
- **process** gets `compatible_printers` = that same *system* printer name (literal string match
  against the machine's `inherits`, not against our preset name), and `compatible_printers_condition` blank.
- **filament** gets `compatible_printers`, `compatible_printers_condition`, `compatible_prints`,
  `compatible_prints_condition` all blank.

## 2. Slice

```sh
orca-slicer --datadir ~/.config/OrcaSlicer \
  --load-settings "m.json;p.json" --load-filaments f.json \
  --arrange 0 --slice 0 --export-3mf plate.3mf --outputdir out plate.stl
```

- `--slice 0` = all plates. Output is `out/<stlname>_1.gcode`.
- Time / filament: `grep -E "^; (estimated printing time \(normal|total filament used \[g\])" out/*.gcode`.
- Orca silently ignores wrong keys; verify important settings with `grep -a '<key> = ' file.gcode`.
- Gcode is ~100 MB for tall multi-part plates; slicing takes a minute or two.

## 3. Copies and spacing

The CLI has **no** spacing option: `--arrange 1` uses the GUI's stored distance, `--clone-objects`
and `--repetitions` don't take a gap. For an exact gap (e.g. "2 of each, 15 mm apart, centered"):

1. Read the STL bounding boxes (ASCII STLs: regex `vertex x y z`; binary: struct unpack).
2. Lay out the footprints yourself on the bed (CORE One: 250x220, centre 125,110) with the requested
   edge-to-edge gap, preferably a compact block centred on the bed rather than a single row.
3. Write one merged ASCII STL with each copy translated (drop each part's min Z to 0).
4. Slice with `--arrange 0` so Orca keeps those coordinates.

Caveat: the merged plate is a single Orca object, so parts can't be edited individually in the GUI.

## 4. Output conventions (punteiros project)

Save gcode in `~/docs/plasteiros/<project>/gcode/` and the STL in `~/docs/plasteiros/<project>/stls/` (punteiros: `~/docs/plasteiros/punteiros/`), named `DD_MM_<material>_<what>_xN.{stl,gcode}`
(e.g. `30_09_pla_punteiro_con_x2.gcode`). Don't overwrite existing files with the same name.

See also: the benchmarking caveat in the project memory — punteiros STLs are cooling-limited, so use a
chunky part to compare profile speed changes.
