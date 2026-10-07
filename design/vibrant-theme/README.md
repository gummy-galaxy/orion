# Vibrant theme study

A look at Orion in a dark purple theme built from the app icon's inks: teal, blue, violet, and pink, with amber and red for review and blockers. It borrows the home-screen feel of mobile apps: big tiles, bold display type, and art on everything.

- Cards are one size, 240 × 336, in the proportions of a trading card. Each has a title bar, an art window, a type line, a text box, and a status box in the corner.
- Card art is procedural dithering from [Paper Shaders](https://github.com/paper-design/shaders), seeded by the card's id so it never changes. A repository picks the two inks, so its cards read as a set. The kind picks the pattern: pull requests flow, steps wave, expected pull requests are sparse dots, and gates are planets.
- Three hidden shaders paint every still in turn, since browsers allow only a few WebGL contexts. One live shader moves into whichever card is hovered and animates its top layer.
- Your-move cards glow, finished cards fade to gray with a stamp, expected cards get a dashed frame, and gates get a full-spectrum frame.

Open `index.html` through any static server, for example:

```bash
python3 -m http.server 5231
```
