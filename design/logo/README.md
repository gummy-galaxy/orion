# Orion logo

Three stars of Orion's belt, linked like work on the canvas, over the grain gradient used for card art. `tide.png` is the chosen icon; `dusk.png`, `nebula.png`, and `ember.png` are the other palettes.

The icon has two layers:

- `stars.svg`: the stars and the line between them, on the same 1024px canvas. Edit it in Figma.
- `<palette>-background.png`: the rounded square with its grain gradient, vignette, and shadow.

`index.html` renders every palette at 1024px with [Paper Shaders](https://github.com/paper-design/shaders), as a background and as the full icon with `stars.svg` on top. The grain's speckle changes a little between renders, but the colors and layout stay the same. To render them again:

```bash
npm install
node server.mjs
```

Open http://localhost:5230, then run `saveIcon('tide')` or `saveIcon('tide-background')` in the console to write that image here. Generate the desktop app's icon sizes with `npx tauri icon design/logo/tide.png`.
