# Leaflit brand artwork

The owner selected **A / Leaf Page** on 2026-10-19: an ivory document with a green leaf on a dark green macOS tile. `leaflit.svg` is the editable master. `leaflit-1024.png` and `Sources/Leaflit/Leaflit.icns` are rendered exports. The same SVG is staged into the public website by `scripts/prepare-site.py`.

The macOS icon uses a conventional ICNS resource for the existing macOS 14 deployment target. `CFBundleIconFile` and the Xcode resource phase reference `Leaflit.icns`. This adds no runtime library. The public 0.1.0 distribution retains its original icon; selecting or building this artwork does not publish a new app release.

To regenerate on macOS with Python, Playwright and an installed supported browser:

```sh
python3 scripts/prepare-icon.py --browser-channel msedge
python3 scripts/prepare-social-preview.py --browser-channel msedge
# Or omit --browser-channel when Playwright Chromium is installed.
```

The script uses software rendering, waits for the SVG to paint, renders each physical size once and reuses it for equivalent 1× and 2× slots, then uses the system `iconutil`. It never resizes an existing raster master. Two fresh export processes on the current host produced identical PNG and ICNS hashes. Normal app builds use the committed exports and need neither Playwright nor a browser. Different browser versions or hosts may change antialiasing; retain source and export identity when comparing builds.

The [comparison page](../../docs/design/app-icon/index.html) retains alternatives B and C as design history. Read the [icon decision and verification scope](../../docs/design/app-icon/design.md) before changing the selected master. MIT License, as with the repository.

The owner identified a leftward alignment after the first implementation. The document and leaf now move together 39 units to the right in the 1024-unit SVG. The document's horizontal bounds are 273–751, centered at 512, leaving equal 193-unit gaps inside the tile. `social-preview.html` is the editable share-card composition; regenerate its PNG after changing the mark.
