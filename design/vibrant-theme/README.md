# Vibrant theme study

A look at Orion in a dark purple theme built from the app icon's inks: teal, blue, violet, and pink, with amber and red for review and blockers. It borrows the home-screen feel of mobile apps: big tiles, bold display type, and art on everything.

- Cards are one size, 288 × 400, in the proportions of a trading card. Each has a title bar, an art window, a type line, a text box, and a status box in the corner.
- Card art is procedural dithering from [Paper Shaders](https://github.com/paper-design/shaders), seeded by the card's id so it never changes. A repository picks the two inks, so its cards read as a set. The kind picks the pattern: pull requests flow, steps wave, expected pull requests are sparse dots, and gates are planets.
- Three hidden shaders paint every still in turn, since browsers allow only a few WebGL contexts. One live shader moves into whichever card is hovered and animates its top layer. The holo foil covers only the art and the frame. Cards tilt only while the pointer moves and settle flat when it stops, so text is never left in a 3D layer.
- Card text uses whole pixels on a 12 / 14 / 17 scale, with nothing under 12px, and the canvas renders at 100% so nothing is resampled.
- The sidebar is dense like an editor's: a workspace switcher, New card and Search with shortcuts, and groups as a tree with each card as a row and a status dot.
- Corners use medium radii, from 3px on chips to 12px on panels, set with the `--r-*` tokens.
- Your-move cards glow, finished cards fade to gray with a stamp, expected cards get a dashed frame, and gates get a full-spectrum frame.

- The logo's stars double as a companion. The center star is the body and springs to whatever you hover, while the side stars chase it on looser springs and swing in when it stops. Once perched it shows a picture and a word or two, blinks now and then, winks at your-move cards, squints happily at shipped ones, and narrows its eyes at blocked ones.

Open `index.html` through any static server, for example:

```bash
python3 -m http.server 5231
```
