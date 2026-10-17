# Orion charter

Orion turns everything you're juggling into one graph you can read at a glance. Any source becomes a node, any relationship becomes a link that means something, and every view leads with what you need to decide next. It's a local-first platform as much as an app: people and agents can retheme it, script it in Luau, and remake it into their own tools and toys.

In short: one graph, many lenses, least effort to understand, yours to remake.

## Principles

1. **The graph is the product; the canvas is a lens.** The core stores nodes, typed links, and placements. Work tracking is one lens over that graph, not the shape of the schema.
2. **Types are attached, not baked in.** A node gains types from its sources and from people. Each type declares its fields, its card face, its states, and how it feeds derived meaning ([#215](https://github.com/vocksel/orion/issues/215)).
3. **Every link means one thing.** A link's type says how it reads and what it does: blocks, relates, implements, duplicates, feeds. Derived state flows along links, so connecting two things always changes what Orion can tell you ([#216](https://github.com/vocksel/orion/issues/216)).
4. **Answer first, inventory on demand.** Every view opens on an answer (what's next, what changed, what's stuck) and reveals the rest only when asked: overview, then zoom and filter, then details on demand.
5. **One meaning per mark.** Each shape, line style, and color stands for exactly one thing, state uses shape as well as color, and every encoding can be explained by a legend on the canvas ([#40](https://github.com/vocksel/orion/issues/40), [#219](https://github.com/vocksel/orion/issues/219)).
6. **Detail is chosen, not stumbled into.** Zoom moves the camera. Detail, focus depth, and grouping are separate controls the reader sets on purpose.
7. **Readable without you.** A shared view carries a title, a one-line story, and its legend, and it never relies on "you" or "mine." Someone with no context should get its point in five seconds.
8. **People and agents use the same verbs.** Every edit is one Luau operation with an inverse, and the app, CLI, and MCP all call it. Anything an agent proposes can be previewed and undone.
9. **Sources stay the source of truth.** Orion keeps references and derived meaning, never a silent copy that drifts. Writing back to a source is opt-in and visible.
10. **Work mode stays calm; play is a mode you switch into.** In work mode, stickers and celebrations mark finished work and stay quiet otherwise. Sandbox mode turns the same canvas into a toy box.

## Make it yours

Customization is a core value, not a settings page. Orion should feel like old YouTube channel pages, Tumblr themes, and VS Code: a place people bend into their own shape. It never raises the floor of cognitive load, because every change is opt-in and one switch away from stock.

1. **Everything visible is themeable.** Nearly every visible property has a named token ([#233](https://github.com/vocksel/orion/issues/233)), and themes are shareable files of those tokens ([#221](https://github.com/vocksel/orion/issues/221)). A canvas or group can carry its own cover, background, and freeform header ([#222](https://github.com/vocksel/orion/issues/222)).
2. **Any card can be made special.** Click a card and restyle it on top of the theme, then save it as a base node that other nodes extend ([#234](https://github.com/vocksel/orion/issues/234)). Cards can change with the calendar, so a birthday card's candles light a week before ([#235](https://github.com/vocksel/orion/issues/235)).
3. **Luau is the mod language.** A mod can add node types with inputs and outputs, link types that carry data, sources, commands, and derived rules, and it declares the capabilities it needs before it runs ([#223](https://github.com/vocksel/orion/issues/223)). Mods run as data mods and reach the screen through host APIs such as particles, physics bodies, and overlays.
4. **Mods compose.** Small mods that each do one thing combine into a new experience, the way a Skyrim load order does. An in-app shop backed by Lute's package manager lets people share, install, and combine them ([#236](https://github.com/vocksel/orion/issues/236)).
5. **The canvas is a sandbox.** Physics, freehand ink, and gestures are first-class ([#225](https://github.com/vocksel/orion/issues/225), [#226](https://github.com/vocksel/orion/issues/226)). Pinball, a Line Rider clone, or a Tabletop Simulator–style table should be buildable as mods.
6. **A contract in layers.** Each layer of the API promises a different stability, so mods can go deep where it's safe and Orion can still change underneath. People and agents build against the same layers.
7. **Always a way back.** Safe mode starts Orion with no mods and the stock theme, and a shared view can be read in the viewer's own theme.

| Layer                           | What mods can do                                                                                  | Promise                                                                     |
| ------------------------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Data and operations             | Query the graph and apply operations with inverses                                                | Stable and versioned; breaking changes ship with aliases first              |
| Types, links, sources, commands | Declare node and link types, fields, ports, card faces, source adapters, palette and CLI commands | Stable once the open graph lands; each mod names the API version it targets |
| Theme tokens                    | Colors, type, shapes, motion, backgrounds, sounds                                                 | Stable names; new tokens added, old ones aliased                            |
| Canvas behaviors                | Call host APIs for particles, physics bodies, overlays, and ink recognition                       | Experimental; may change between releases                                   |
| App internals                   | React components and CSS selectors                                                                | No promise                                                                  |

Anything costly to maintain stays in the bottom two rows until it earns a promise.

## Game feel

Orion should feel gummy, sweet, and fair: a charming toy you can poke while you wait, and one that never makes a move you didn't see coming.

1. **Telegraph every move.** Incoming changes wind up before they land, with a glow where they'll appear, then animate in. Large changes from agents preview first ([#230](https://github.com/vocksel/orion/issues/230)).
2. **Never steal the input.** Nothing moves, appears, or reflows under the pointer during an interaction or just before one. A misclick caused by Orion is a bug.
3. **Every action answers.** Presses squish, finishes pop, gestures end in a flourish, and the response is sized to the action's weight, so small things stay small ([#112](https://github.com/vocksel/orion/issues/112)).
4. **Something to poke.** Cards and the canvas offer small interactions that relieve restlessness and never change data by accident ([#231](https://github.com/vocksel/orion/issues/231)).
5. **Let Orion do the waiting.** Watch a card and Orion tells you when it turns over, so nobody bounces between tabs to check on CI ([#218](https://github.com/vocksel/orion/issues/218), [#232](https://github.com/vocksel/orion/issues/232)).
6. **Simple parts, deep combinations.** Script cards, timers, and signal links are small on their own and combine into puzzles, contraptions, and whole computers, the way Minecraft's redstone does ([#227](https://github.com/vocksel/orion/issues/227), [#228](https://github.com/vocksel/orion/issues/228), [#229](https://github.com/vocksel/orion/issues/229)).
7. **Play can't break the machine.** Every script runs on a time and memory budget, so a runaway contraption stops itself instead of freezing the canvas ([#224](https://github.com/vocksel/orion/issues/224)).

## Made for the senses

Orion should feel good to get your hands on, to look at, and to listen to. Games use every sense to make an action land, and OmmWriter shows how a calm screen and quiet music help someone settle into their work. Orion borrows from both, so working with your data is satisfying in itself.

1. **Every sense, in its own measure.** Sight, sound, and touch each carry feedback sized to the moment. A press clicks, a finished chain climbs in pitch and bursts with light, and an idle canvas drifts too slowly to notice ([#377](https://github.com/vocksel/orion/issues/377), [#378](https://github.com/vocksel/orion/issues/378)).
2. **Rewards take time to savor.** A payoff lasts long enough to feel. A chain of finished work plays out beat by beat, not all at once ([#379](https://github.com/vocksel/orion/issues/379)).
3. **Room to focus.** Live backdrops and a focus mode can clear the screen down to the work and a calm scene, with sound to match ([#380](https://github.com/vocksel/orion/issues/380)).
4. **Meet people where they are.** Whoever they are and whatever their background, people should be able to work with their data in a way they understand. Orion adapts to them rather than asking them to adapt. Every sense can be turned up, down, or off, defaults follow the system's accessibility settings, and nothing depends on one sense alone ([#381](https://github.com/vocksel/orion/issues/381)).
5. **Flexible by construction.** Feedback runs through shared systems: tokens, one particle layer, one sound layer, and one settings path. Meeting a new need is then a setting or a theme, not a rewrite.

## Non-goals

- A document editor. Notes stay short and link out to where long writing lives.
- A replacement for GitHub or Jira. Orion reads them, connects them, and writes back only what links them.
- A professional illustration tool. Freehand ink is welcome and mods can give it meaning, but Orion won't chase vector-editing depth.

## Vocabulary

- **Node** is anything on the graph. **Card** is the public word for the main kind of node.
- **Placement** is one appearance of a node on a canvas ([#122](https://github.com/vocksel/orion/issues/122)).
- **Canvas** replaces workspace ([#110](https://github.com/vocksel/orion/issues/110)). A workspace may later hold several canvases.

## Roadmap

Each phase clears its gate before the next one starts, except theme work, which only touches the app and can run alongside phase 1.

| Phase                   | Bets                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Gate                                                       |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| 1. One engine           | Operations with inverses ([#93](https://github.com/vocksel/orion/issues/93)), status in Luau ([#94](https://github.com/vocksel/orion/issues/94)), source adapters ([#54](https://github.com/vocksel/orion/issues/54)), file-backed workspaces with a SQLite index ([#121](https://github.com/vocksel/orion/issues/121))                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | The app holds no graph rules of its own                    |
| 2. Open graph           | Nodes split from placements ([#122](https://github.com/vocksel/orion/issues/122)), type registry ([#215](https://github.com/vocksel/orion/issues/215)), typed links ([#216](https://github.com/vocksel/orion/issues/216), [#83](https://github.com/vocksel/orion/issues/83)), database views and agent queries ([#102](https://github.com/vocksel/orion/issues/102), [#103](https://github.com/vocksel/orion/issues/103))                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | A new source or type ships with no app change              |
| 3. Less to hold in mind | Detail control ([#175](https://github.com/vocksel/orion/issues/175)), saved views ([#217](https://github.com/vocksel/orion/issues/217)), legend ([#219](https://github.com/vocksel/orion/issues/219), [#40](https://github.com/vocksel/orion/issues/40)), change feed ([#218](https://github.com/vocksel/orion/issues/218)), triage ([#195](https://github.com/vocksel/orion/issues/195), [#197](https://github.com/vocksel/orion/issues/197)), telegraphed changes ([#230](https://github.com/vocksel/orion/issues/230)), watched cards ([#232](https://github.com/vocksel/orion/issues/232))                                                                                                                                                                                                                                                                                                                                                                                | A newcomer passes the five-second test on our own canvases |
| 4. Readable by others   | Links to cards ([#176](https://github.com/vocksel/orion/issues/176)), snapshots and embeds ([#114](https://github.com/vocksel/orion/issues/114), [#177](https://github.com/vocksel/orion/issues/177)), image and JSON Canvas export ([#113](https://github.com/vocksel/orion/issues/113), [#220](https://github.com/vocksel/orion/issues/220)), live collaboration ([#80](https://github.com/vocksel/orion/issues/80))                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | A teammate reads a shared view without help                |
| 5. Make it yours        | Tokens and themes ([#233](https://github.com/vocksel/orion/issues/233), [#221](https://github.com/vocksel/orion/issues/221), [#222](https://github.com/vocksel/orion/issues/222)), mod API and sandbox ([#223](https://github.com/vocksel/orion/issues/223), [#224](https://github.com/vocksel/orion/issues/224)), ink and gestures ([#225](https://github.com/vocksel/orion/issues/225), [#226](https://github.com/vocksel/orion/issues/226)), script cards, timers, circuits ([#227](https://github.com/vocksel/orion/issues/227), [#228](https://github.com/vocksel/orion/issues/228), [#229](https://github.com/vocksel/orion/issues/229)), physics and fidgets ([#41](https://github.com/vocksel/orion/issues/41), [#231](https://github.com/vocksel/orion/issues/231)), custom cards, dates, and a shop ([#234](https://github.com/vocksel/orion/issues/234), [#235](https://github.com/vocksel/orion/issues/235), [#236](https://github.com/vocksel/orion/issues/236)) | A mod written by an agent survives an Orion update         |

## How we'll know

Ask three timed questions of a shared view, put to someone who has never seen it: what is this about, what happens next, and what is stuck. Each should take under 10 seconds, without help.

Orion should also document itself: the roadmap above belongs on an Orion canvas, embedded wherever it's discussed instead of redrawn by hand.

## Open questions

- **How far do links execute?** Ports and data-carrying links imply running work along the graph. Decide whether that runs on demand, on change, or continuously, and whether it can act outside Orion.
- **Who reads and edits shared canvases?** The goal is public reading, embeds, and a hosted site with a graph of connected cards, plus invited editors, groups, and orgs with permissions in a hosted service. Read-only sharing ships first and keeps Orion local-first.
- **Where do type definitions live?** Shipped packs, per-canvas files, mods, agent-authored, or all of these.
- **What review or signing does a shared mod need?**
