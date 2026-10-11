# Orion decisions

[`CHARTER.md`](CHARTER.md) sets Orion's direction. This file records the specific calls made along the way and why, so the intent survives after the conversation that settled it is gone.

Each entry gives the decision, the reason behind it, when it was made, and the issues or pull requests that carry it out.

These are current calls, not rules. The charter comes first, and any entry here can be challenged when the work shows a better way. Treat an entry as the default: follow it, and raise a change that would go against it instead of quietly working around it. When a decision changes, rewrite its entry and say what it replaced and why, rather than deleting it.

## Cards

### Rarity is the work that feeds into a card

A card with no inputs is a common card. As more work flows into a card through the chain, its rarity climbs: common, uncommon, rare, and up. The exact tiers and thresholds are open to tuning.

**Why:** cards should stand out for what they are, and the cards that many pieces of work converge on are the ones worth spotting. Because rarity comes from the graph's shape, nobody can raise it by inflating one card.

2026-10-09 · #161

### Priority is foil, not rarity

P0 cards get full holo foil and P1 cards get a foil edge. P2 and below are common cards. Priority shows only when a source sets it; Orion never guesses one. Importance inferred from connections comes through rarity instead.

**Why:** P0s are the specialized cards that ideally don't come up often, and lower priorities are the common cards that keep the whole deck running: less flashy, still necessary. Making rarity mean importance was considered and rejected, because it would reward making big tickets.

2026-10-11 · #241, #242

### Reward breaking work down and finishing it, never making cards

Big work looks sealed until it's split into smaller cards. Celebrations, points, and any score come from splitting and finishing, never from creating cards.

**Why:** the behavior worth rewarding is breaking work into smaller pieces. A score that grows with card count invites padding the board to farm it.

2026-10-11 · #242, #116

### Card art is symbolic

The shapes in a card's art mean something: they tie back to what the card is, so you can tell cards apart and sort them in your head at a glance. Color is never the only cue.

**Why:** the goal is recognizing a card on sight, and art that's only decorative doesn't help with that. An earlier geometric pass leaned too far into geometry for its own sake. Relying on color alone would also shut out colorblind readers.

2026-10-09, 2026-10-11 · #163, #164

### Each slot on a card has one job

A card never says the same thing twice, such as a repo name above a "Pull request · Orion" label. Text that every card in a group would repeat, like the group's name, stays off the card. "Your move" appears only on the card that's actually yours to act on, not on everything. Sources beyond a few icons go in a details view.

**Why:** repeated and ever-present labels are noise. A mark that shows on every card stops telling you anything.

2026-10-11 · #275

### Marks over words

Stickers are an icon plus at most one word, with icons preferred and tooltips explaining them. A card shows CI state rather than a diff count. A blocked card keeps its type icon, with the lock drawn over it in a transparent tint.

**Why:** short marks read faster than phrases, and the card still has to say what it is while it's blocked.

2026-10-11 · #275

### Severity colors for priority and size

P0 is red, P1 orange, P2 blue, and P3 and below gray. Sizes follow the same scale, with XL red, L orange, M blue, and S gray. When priority or size is unknown, the card shows nothing for it.

**Why:** one familiar severity scale serves both values, and a placeholder for unknown values would only add noise.

2026-10-11 · #275

### Legibility wins over flourish

Holo and foil effects stay off text. Card styles should stay readable at a glance, like Legends of Runeterra, Balatro, and Wildfrost, without Wildfrost's chunky black outlines.

**Why:** the effects are fun, but a card you can't read has failed at its job.

2026-10-07, 2026-10-11 · #95

### Cards are a skin over sources and data

Sources and their data are one layer, and cards are the presentation attached to them. Every card can switch skins: a conventional off-white look, trading cards, plain cards, Trello-style cards, and whatever comes next. Source-specific fields live in `data.refs`, so the card itself stays general.

**Why:** the same data should be able to take on very different looks without the model changing underneath.

2026-10-09 · #152, #154

### Card art is reproducible

Generated card art can be produced again from the same card. Later, people should be able to reroll art, keep favorites, and give a card its own color.

**Why:** art that people can shape makes the canvas feel like theirs.

2026-10-07 · #234

## Canvas and input

### Mouse wheel zooms, trackpad pans

A mouse wheel zooms. A two-finger drag on a trackpad pans, and pinch zooms. A regression test with recorded events from real devices in each browser engine guards this.

**Why:** zooming with the wheel is the preferred default, and trackpad users still need two-finger panning. The behavior has broken several times while fixing one device or the other, so it needs a test that covers both.

2026-10-10, 2026-10-11 · #208, #240

### Pan mode lets clicks pass through links

In Pan, pressing on a link pans instead of grabbing the link. Holding ⌘ moves cards and groups, including by a group's header.

**Why:** on a busy canvas, presses kept landing on links and moving the pointer instead of the canvas, and Pan had no way to move anything.

2026-10-11 · #271

### Auto-arrange always wins

In an automatically arranged group, a card that's dragged or snapped returns to its arranged place on release.

**Why:** a group can't be both arranged and hand-placed, and mixing the two leaves its layout unpredictable.

2026-10-08 · #104

### Zoomed out reads like a world map

Each group has its own tint, so you know where you are when zoomed out. Cards switch to simpler forms at zoom breakpoints instead of growing or disappearing, and related links stop drawing past one of those breakpoints.

**Why:** zooming out already feels like looking at a map, so lean into it. Cards that blow up when zoomed out become unreadable, and drawing full detail everywhere is heavy enough to crash the desktop web view.

**Open:** charter principle 6 says zoom only moves the camera and detail is a separate control (#175, #205). Reconcile the two.

2026-10-07, 2026-10-11 · #280

### Render work is batched from the center out

When many cards need drawing, Orion does the work in batches that spiral outward from the center of the screen, so the first batch covers most of what's in view. A camera move during a batch recalculates the order. The zoom breakpoints are tuned with a debug panel on a large real canvas.

**Why:** sending everything at once blocks the frame, and the cards on screen matter first.

2026-10-11 · #280

### Accessibility settings

Orion has a color palette for each major type of colorblindness, and status uses shapes as well as color, applied the same way across the app. Reduced motion follows the system setting by default, and one switch turns animation off entirely.

**Why:** colorblindness isn't one condition, so one palette can't cover it. Turning off motion should be a single switch rather than a list of effects to find.

2026-10-11 · #213

## Celebration and triage

### Finished work gets savored

Cards marked done take on a special finish, like a golden shimmer. Double-clicking finished work sets off a cascade through its chain. Finished cards also stack into a history you can look back on, like a skyscraper or a Tetris board.

**Why:** finishing a lot of work should feel like it, and looking back at what got done builds appreciation for it. This stays within the charter: celebrations mark finished work and stay quiet otherwise.

2026-10-11 · #112

### Triage happens in a tray, and you do the placing

New pull requests and issues land in a tray at the canvas edge, backed by the Inbox and Unsorted groups. You drag cards from the tray onto the canvas, and Orion learns from where they go. Heuristics and agents suggest where cards belong. Adding cards to the canvas automatically is held back.

**Why:** keeping the canvas current shouldn't need constant back-and-forth with agents, but filing work without a person in the loop risks clutter that has to be cleaned up later.

2026-10-10 · #195, #197

### Linking a pull request to its card ships with Orion

When an agent opens a pull request from a card's work, the pull request attaches to that card. This comes with Orion rather than as setup on each machine.

**Why:** every Orion user's agents need this, so it can't depend on one person's local configuration.

2026-10-10 · #196

## Architecture

### Files first, with a SQLite index

A workspace lives as files that can be stored in a repository, like an Obsidian vault. SQLite does the heavy lifting as an index. Agents keep simple read and write commands through the CLI, and `orion serve` keeps one `sqlite3` process open instead of starting one per request.

**Why:** files are portable and easy to inspect, and agents already work well with them. The index keeps large canvases fast.

2026-10-08, 2026-10-11 · #121

### Built for a thousand cards and more

The target is at least 1000 cards with nested groups and dense links: every pull request you've ever made, plus Jira, Slack, images, video, and Figma frames. Like a Notion database, every node can be listed and edited in a table, and canvases are where the visual work happens. The same card can appear in many places.

**Why:** Orion should hold everything you're juggling, not a slice of it.

2026-10-07 · #122, #102

### Undo history outlives a workspace switch

Undo history persists across workspace switches, either as a full session history or a rolling history capped at some number of steps. It may live in the SQLite index.

**Why:** history that disappears when you switch workspaces is too temporary to trust.

2026-10-10 · #1, #166

### Rich cards use link previews, not live embeds

Cards for links show a static snapshot of the link's preview rather than embedding the live page.

**Why:** the goal is rich cards, not running other apps inside the canvas.

2026-10-08 · #81

### Adapters are Lute packages

Source adapters are Lute packages built on a shared core package. Long term, the official adapters live in their own repositories in an organization, Orion ships with them by default, and people copy them to make their own. Hop becomes a package Orion depends on, and it powers opening a pull request in VS Code.

**Why:** Orion maintains the official adapters while others build their own from the same starting point.

2026-10-11 · #54, #98

### No eager scaffolding

Don't build concepts ahead of the features that need them, such as owners before sharing exists. Don't assume defaults that can't be known, such as a repository's owner from its name alone.

**Why:** scaffolding nothing uses yet still has to be maintained, and guessed defaults produce wrong data.

2026-10-09 · #13, #89

### MCP stays generic

Orion documents how to register `orion mcp` with any client instead of shipping setup for each AI provider.

**Why:** registering an MCP server is trivial for people to do themselves, and per-provider code is a lot to maintain for that convenience.

2026-10-09 · #134

### Physics comes from a library

Canvas physics builds on an established library rather than a homegrown engine. It loads in the background, so a canvas opens quickly and physics starts once it's ready. Pinball doesn't drive the choice; a case the library can't handle gets its own path, as Line Rider would.

**Why:** bespoke physics is costly to keep up long term, and objects passing through each other or wobbling stacks are undesirable everywhere, not just in pinball.

2026-10-11 · #41
