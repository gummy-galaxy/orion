# Origins

Orion was designed in conversation. Marin, who started it, talked ideas through with Claude and Codex, and most calls came out of that back-and-forth. This page records where the name, the logo, the companion, and the early directions came from, and who brought each one in, so the story survives after the sessions that held it are gone.

"Proposed" means who first brought the idea into the conversation. "Shaped" means who turned it into what shipped. Dates are in UTC, like the rest of the design timelines.

## At a glance

| Idea                                        | Proposed          | Shaped                                                                    |
| ------------------------------------------- | ----------------- | ------------------------------------------------------------------------- |
| A gamified, general canvas of work          | Marin             | Claude suggested clusters that clear like Tetris lines and become gems    |
| Constellations as the picture of the canvas | Marin             | Claude made groups fold into bodies when zoomed out                       |
| The name Orion                              | Marin             | Claude had offered constellation, workboard, and orbit                    |
| Artemis and Star Charter as other names     | Marin             | Codex drew an icon study for each                                         |
| Orion's belt in the icon                    | Marin             | Claude added the shoulders; Marin cut it back to the belt                 |
| A line joining the three stars              | Marin, and Codex  | Codex drew it first in the icon study; Marin asked for it on the app icon |
| The companion                               | Marin, and Claude | Marin named the floating stars and drew a face; Claude suggested a guide  |
| The companion's movement, arms, and noodles | Marin             | Claude built the springs and the moods                                    |
| "Gummy" as the feel                         | Marin             | Codex carried it into the brand brief                                     |
| Gummy Galaxy                                | Marin             | Claude drew the first shelf of names and marks                            |
| The Luau CLI owning the data                | Marin             | Claude moved storage behind `orion serve`                                 |
| Waiting until later for a desktop shell     | Claude            | Marin agreed; the Tauri shell came the next day                           |

## October 4, 2026: From a dashboard to a canvas

Orion grew out of the Flipbook Release Map, a dashboard Marin kept to link every Flipbook pull request and pick up where they'd left off each day. Finished work collected on one side and turned gray, and Marin said it looked like rotated Tetris. That gave Marin the idea of a general way to show work that is linked, interdependent, or in separate tracks, made into a game.

- **Rewards:** Claude suggested that a finished cluster of linked work clears like a line in Tetris and collapses into a gem, with gems stacking on a weekly shelf. Marin kept the collapse, as long as the gem could be opened to see its work, and kept the focus on unblocking.
- **Metaphors set aside:** Marin raised a supply chain and a river with blockages. Claude laid out both, and Marin chose to keep the visuals simple, close to the Release Map, with cues for flow and blockers.
- **The cues:** Claude built a sampler page of ways to draw a work graph. Marin picked four: motion only on lines still waiting, "unblocks N" leverage badges, hover to trace, and the feel of the playground where clusters clear.
- **Incentives:** Marin floated bonuses for small pull requests and for reaching out to unblock, and asked what points could be spent on. Claude split these into traits on gems and points to spend, and answered Marin's question about bounties with a score of value times avoidance. Marin added a reward for deliberately closing or parking stale pull requests.
- **The canvas:** Marin asked for a Figma-like canvas with Ilograph-style drill-in, and said it was "almost like constellations or solar systems." Claude proposed folding each group into one body when zoomed out.
- **The repository:** Claude recommended a small repository built on React Flow and ELK, and waiting on a desktop shell until sources needed stored tokens and background polling.

### The name

When Claude set up the repository, it asked what to call it and offered three names: constellation, workboard, and orbit. Marin skipped all three and typed "orion," a constellation, in keeping with the picture Marin had described a few minutes earlier. The first prototype ran that evening.

## October 5 and 6, 2026: First spikes and other names

- **Horizontal skyscrapers:** Marin asked Codex for a layout where gravity pulls everything left and cards stack or fall. Marin called it a good spike and dropped it ([#16](https://github.com/vocksel/orion/pull/16)).
- **Luau owns the data:** Marin asked to "get everything over to Luau," so the CLI became the engine and the app the presentation layer ([#52](https://github.com/vocksel/orion/pull/52)).
- **Trading cards:** the [trading card spike](https://github.com/vocksel/orion/pull/31) drew every card as a trading card, with grain-gradient art. The request that started it isn't in the surviving transcripts.
- **Play and gummy:** speaking to Codex, Marin asked for the canvas to be a "little stim toy" with physics and stickers, "really nice and gummy," and stressed that gummy was the word they meant. Marin also asked for node shapes that work for colorblind readers.
- **Artemis and Star Charter:** in the same conversation, Marin asked Codex to note a rebrand as Artemis, after the hunter in Hades: green, natural, and fierce. Marin then added Star Charter, which would lean into space and mapping, and said Orion was "also quite nice." Codex drew two icons for each name ([#47](https://github.com/vocksel/orion/pull/47)). Orion kept its name; the [logo](/development/design/logo) page shows the study.

## October 6, 2026: The three stars

Marin told Codex to use Orion's belt in the icon and tie it to the canvas, maybe around the nodes. Codex's brief made the three belt stars the signature and joined them into a larger constellation, "so the mark also suggests cards and dependencies." That was the first drawing of linked belt stars.

About half an hour later, Marin asked Claude for a colorful placeholder app icon, using the dithered, moody art from the trading card spike.

1. Claude drew Orion's belt and shoulders over the card art's grain gradient, in the tide palette.
2. Marin said "let's focus on the belt triple."
3. Claude thinned the stars into lens-flare spikes, because fat four-point stars looked like the ✨ AI sparkle.
4. Marin asked for "a line between them to represent the connected nodes," and the linked belt shipped in the [desktop shell](https://github.com/vocksel/orion/pull/19).

Marin later redrew the logo in Figma as three stars joined by a stardust curve. Claude added four variants to that file, and the app icon has come from Figma since ([#92](https://github.com/vocksel/orion/pull/92), [#178](https://github.com/vocksel/orion/pull/178)).

## October 7, 2026: The vibrant study and the companion

Marin asked for a theme taking cues from Discord: vibrant dark purple from the logo's palette, big tiles, a mobile-app feel, procedural dithering, and bigger cards like rich media, building on the trading card spike. Claude built the [vibrant study](https://github.com/vocksel/orion/pull/95).

- **Hyper Light Drifter:** Marin brought it up and asked what was worth borrowing. Claude pointed to a few neon colors over gray, almost no text, and a small companion robot that carries the only UI.
- **World map:** Claude suggested giving each group its own tint so you know where you are when zoomed out. Marin said zooming out already felt like looking at a world map and asked to lean into it.

### The companion

The study's home screen had a floating cluster of stars that Claude had drawn in its hero banner. Marin called it "the fun floating guy" and asked to keep it. Marin then shared the logo from Figma, and Claude swapped it in for its hand-drawn stars. Marin had already tried giving the stars a face in Figma, as a component named Winking eyes.

1. Claude suggested, after Hyper Light Drifter, that the floating stars become a companion that hovers by the focused card.
2. Marin said they'd been thinking the same, which was why they'd made the winking face, though it "didn't come out so well." Marin described the movement: the center star is the body that moves, and the others play catch-up.
3. Claude put the face on the center star only, with plain dark eyes, because three realistic eyeballs read as creepy, and turned the side stars into hands. It built the follow on springs, with a perch, a hint bubble, and a few moods.
4. Marin asked for arm wiggles, excited eyes, and "what other emotions can we put in it??" Marin gave notes on the faces, so the softer worried eyes became the default and the curious eyes became 👀.
5. Marin asked for something joining the stars, first a light streak, then "wiggly noodles … at most like 1 wiggle." Marin set where the noodles attach.

The [companion](/development/design/companion) page follows it from the study into the app.

## October 14, 2026: Gummy Galaxy

Marin asked Claude for a shelf of every Orion design and for branding for a parent organization called Gummy Galaxy: a galaxy of gum and rock candy that looks edible. Marin remembered the name as an agent's idea. The earliest mention in the transcripts is Marin's own, so if an agent suggested it, that conversation didn't survive. The [Gummy Galaxy and Orion](/development/design/gummy-galaxy-and-orion) page covers where it went.

## How this was traced

This page comes from the Claude Code and Codex sessions on the machine where Orion was started, covering October 4 onward. Some sources aren't in the transcripts:

- **Figma:** work Marin did by hand, such as the first redrawn logo and the Winking eyes face, shows up only when an agent opened the file.
- **Published artifacts:** pages Claude published, such as the work graph sampler and the Gummy Galaxy shelf, are linked from the sessions, but their contents aren't kept there.
- **Codex voice:** many early Codex sessions were spoken, so Marin's words there are speech transcripts.

When something here turns out wrong, correct it, and say what the evidence was.
