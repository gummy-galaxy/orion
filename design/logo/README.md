# Orion logo

Three stars of Orion's belt, linked like work on the canvas, over the grain gradient used for card art. `tide.png` is the chosen icon; `dusk.png`, `nebula.png`, and `ember.png` are the other palettes.

`index.html` renders every variant at 1024px with [Paper Shaders](https://github.com/paper-design/shaders). To render them again:

```bash
npm install
node server.mjs
```

Open http://localhost:5230, then run `saveIcon('tide')` in the console to write `tide.png` here. Generate the desktop app's icon sizes from it with `npx tauri icon design/logo/tide.png`.
