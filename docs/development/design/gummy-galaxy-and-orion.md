# Gummy Galaxy and Orion

Gummy Galaxy is taking shape as a playful home for Luau projects. Our own projects are still in development, and we hope to share them here as they're ready. In time, we'd also like to support more Luau creators—by giving emerging projects a home or celebrating work wherever it lives.

I want it to feel fun and charming, almost like a candy-colored toy box for the things we're making. Useful software can still lighten the feel of a day. There can be little toys, playful interactions, and perhaps minigames alongside the tools. [Orion](/development/charter) is one expression of that: it was always meant to feel a little like a game, with personality and a vibrant, trading-card look that I enjoy using every day. Toy Hearts work might find a home here too. I don't think everything under Gummy Galaxy needs to fit one rigid definition of a "playful Luau product." Artemis, the performance machine dedicated to Orion, matters to the work even though it isn't that kind of product.

## Why Luau is at the center

Luau was the first programming language I learned, when I was about twelve or thirteen, so this direction is personal. I want Gummy Galaxy to help more people make things with it. Rust can support the work, but Luau is the thread running through it; Orion already embeds Luau in the software people use.

The practical part matters as much as the feeling. [Lute](https://github.com/luau-lang/lute) gives Luau a runtime and a package workflow backed by Loom. That could make projects easier to distribute and combine, in the way npm helped JavaScript projects build on each other. In my experience, LuaRocks was hard to get working on Windows, while the Lute and Loom workflow worked out of the box. I find that possibility exciting: more small pieces that can be shared, installed, and made into something new together.

I'd like Gummy Galaxy to leave room for other creators as it grows. Maybe an emerging project could live in the organization and welcome contributors. An established project might be better supported or spotlighted where it already lives. There may be ways to help an established organization such as Rojo, or a small new one. These are possibilities to explore, not programs Gummy Galaxy runs today. Right now there isn't a public catalog of projects to point to.

One day, a central GitHub Projects board could bring issues from several repositories together and hold draft ideas without an issue-only repository. A public organization profile could explain what has actually arrived. Neither needs to be built ahead of the projects.

## Orion: understanding by playing with the graph

I want Orion to bring many information sources onto one canvas and make their relationships understandable by getting my hands on them. I learn a graph by grabbing a card and moving it. I watch its arrows and related links, pull directly connected cards into a small area, and leave the rest where they are. That physical exploration helps me understand what I'm looking at.

Arranging the whole board can give me a starting point, but it doesn't do the same thing. It can move placements I already worked out by hand, while new cards sometimes pile up in the top-right corner. I'd like to explore small, temporary regions around connected cards: perhaps polygon boundaries that appear when useful, with layout that helps just that area and respects the rest of the canvas. [Ephemeral clusters](https://github.com/vocksel/orion/issues/368) explore that local layout idea.

The way I select and navigate matters too. I would rather work mostly with the mouse than depend on middle-button panning or constantly switch tools. Could a right drag pan while a short right click still opens the context menu? Would a box selection feel better than a sweep or magnetic reach whose radius I adjust with the wheel? Could I start with one card, pluck its connected neighbors, and leave the ones I don't want behind? Modifier keys could add or subtract when needed, with the keyboard still available. I don't know which gestures are right yet. [A separate prototype](https://github.com/vocksel/orion/issues/456) will try them on the same fake board, with simple cards about the size of trading cards, before choosing production behavior.

Game-like [completion rewards](https://github.com/vocksel/orion/issues/9) are another open thought. Points or a currency for breaking work down and finishing it, levels, or unlockable themes and skins might make progress more satisfying. They would need to reward useful work and keep Orion's [work mode calm](/development/charter#game-feel). For now, they're ideas rather than a feature plan.

The common thread is that the software should be genuinely useful and a pleasure to touch. I want to be able to understand my work by moving through it, and I want the Luau projects around it to be easy for others to pick up, play with, and remake.
