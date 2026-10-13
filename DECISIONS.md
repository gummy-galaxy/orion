# Orion decisions

[`CHARTER.md`](CHARTER.md) sets Orion's direction. This file records the specific calls made along the way and why, so the intent survives after the conversation that settled it is gone.

Each entry gives the decision, the reason behind it, when it was made, and the issues or pull requests that carry it out.

These are current calls, not rules. The charter comes first, and any entry here can be challenged when the work shows a better way. Treat an entry as the default: follow it, and raise a change that would go against it instead of quietly working around it. When a decision changes, rewrite its entry and say what it replaced and why, rather than deleting it.

## Cards

### Rarity is the work that feeds into a card, lifted by priority

A card with no inputs is a common card. As more work flows into a card through the chain, its rarity climbs: common, uncommon, rare, and mythic. A priority set by a source lifts it further: P0 by two tiers and P1 by one, up to mythic. The exact tiers and thresholds are open to tuning.

**Why:** cards should stand out for what they are, and the cards that many pieces of work converge on are the ones worth spotting. On upstream work alone, mythic needed more than a dozen cards feeding in, so almost nothing reached it. Priority makes the top tiers reachable for work that matters now. It still comes only from a source, so nothing inside Orion can raise a card's rarity, including padding the board with cards. This replaced rarity from upstream work alone (2026-10-09), which kept priority separate.

2026-10-09, 2026-10-11 · #161, #241

### Foil is rarity

Uncommon cards get a silver edge, rare cards a foil edge, and mythic cards a foil edge with holo over the art. Priority shows as a chip in the severity colors and lifts rarity, but has no finish of its own.

**Why:** card games mark rarity with foil, so a shiny card reads as a rare one at a glance. One finish ladder also keeps two shiny signals from competing on the same card. This replaced "Priority is foil, not rarity" (2026-10-11), which gave P0 holo and P1 a foil edge. That entry's worry, that rarity would reward big tickets, is still covered: rarity comes from the graph and a source's priority, never from a card's own size.

2026-10-11 · #161, #242

### Reward breaking work down and finishing it, never making cards

Big work looks sealed until it's split into smaller cards. Celebrations, points, and any score come from splitting and finishing, never from creating cards.

**Why:** the behavior worth rewarding is breaking work into smaller pieces. A score that grows with card count invites padding the board to farm it.

2026-10-11 · #242, #116

### Card art is a scene picked by kind

A card's art is a scene in the night sky. The kind picks the subject: steps are an orb rising over layered hills, pull requests a ringed planet, expected pull requests an eclipse, and gates a four-point star. The group's inks color it, the card's seed places it, and a grain dither ties it together. Kind also shapes the card's outline, so color is never the only cue.

**Why:** the goal is recognizing a card on sight. Earlier passes missed it in two ways: geometric posters leaned into geometry for its own sake, and a kind icon set over gradient art read as a label stuck onto the card rather than art. This replaced "Card art is symbolic" (2026-10-09), which asked for meaningful shapes without saying what they were.

2026-10-09, 2026-10-11 · #163, #164, #275

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

### Scrolling pans, for mouse and trackpad alike

Scrolling always pans, whether it comes from a mouse wheel or a trackpad. Pinch and ⌘-scroll zoom. There's no setting and no device detection.

**Why:** the preference was for the mouse wheel to zoom while a trackpad's two-finger scroll pans. That needs Orion to tell the two devices apart, and on macOS there's no reliable way to do it. WebKit reports a mouse wheel and a trackpad with the same delta ratio, and the only other signal relies on undocumented encoding and misses mice with smooth scrolling. Each attempt fixed one device and broke the other. This replaced zooming on scroll (#208, #240). Before trying wheel zoom again, find a reliable way to tell the devices apart in WebKit.

2026-10-11 · #268

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

### A finished card carries a Done stamp

A card that's done and closed out carries a Done stamp and fades only slightly. Until it's closed out, it shimmers. A done card has to read as finished on its own, without blocked or deferred cards beside it to compare against.

**Why:** fading alone made done look like blocked and deferred work, so a group of finished cards gave no sign it was finished. A stamp says it in one word, which fits marks over words.

2026-10-12 · #317

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
