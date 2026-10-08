# Orion logo

Three stars of Orion's belt over the grain gradient used for card art. `tide.png` is the app icon, exported from Figma over `tide-background.png`; `dusk.png`, `nebula.png`, and `ember.png` are earlier renders in the other palettes, with the stars on a diagonal.

The icon has two layers:

- `stars.svg`: the earlier diagonal stars and the line between them, on the same 1024px canvas. The Figma file holds the current stars.
- `<palette>-background.png`: the rounded square with its grain gradient and vignette, on a transparent canvas with no drop shadow.

`index.html` renders every palette at 1024px with [Paper Shaders](https://github.com/paper-design/shaders), as a background and as the full icon with `stars.svg` on top. The grain's speckle changes a little between renders, but the colors and layout stay the same. To render them again:

```bash
npm install
node server.mjs
```

Open http://localhost:5230, then run `saveIcon('tide')` or `saveIcon('tide-background')` in the console to write that image here. Generate the desktop app's icon sizes with `npx tauri icon design/logo/tide.png` and keep only the files `tauri.conf.json` lists. Build `icon.icns` without the 1024px size with `iconutil`, since the grain barely compresses.
