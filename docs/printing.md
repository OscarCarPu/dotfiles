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
