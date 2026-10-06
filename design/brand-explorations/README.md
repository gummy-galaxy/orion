# App icon explorations

Six square vector studies for three possible product names:

- **Orion:** Belt / constellation and Orbit / network
- **Star Charter:** Folded route and Compass rose
- **Artemis:** Bow / arrow and Moon / arrow

The SVG files are the editable sources. `previews/` contains 256 px and 64 px PNGs, plus a comparison image for each name. No concept has been selected as the app icon.

To regenerate a concept's PNGs, run `tauri icon <name>.svg --png 256,64 --output previews/<name>` from this directory. Then run `swift render-previews.swift .` to rebuild the comparison images.
