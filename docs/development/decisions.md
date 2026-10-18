# Orion decisions

[The charter](./charter.md) sets Orion's direction. This file records the specific calls made along the way and why, so the intent survives after the conversation that settled it is gone.

Each entry gives the decision, the reason behind it, when it was made, and links to the issues or pull requests that carry it out.

These are current calls, not rules. The charter comes first, and any entry here can be challenged when the work shows a better way. Treat an entry as the default: follow it, and raise a change that would go against it instead of quietly working around it. When a decision changes, rewrite its entry and say what it replaced and why, rather than deleting it.

## Cards

### Rarity is the work that feeds into a card, lifted by priority

A card with no inputs is a common card. As more work flows into a card through the chain, its rarity climbs: common, uncommon, rare, and mythic. A priority set by a source lifts it further: P0 by two tiers and P1 by one, up to mythic. The exact tiers and thresholds are open to tuning.

**Why:** cards should stand out for what they are, and the cards that many pieces of work converge on are the ones worth spotting. On upstream work alone, mythic needed more than a dozen cards feeding in, so almost nothing reached it. Priority makes the top tiers reachable for work that matters now. It still comes only from a source, so nothing inside Orion can raise a card's rarity, including padding the board with cards. This replaced rarity from upstream work alone (2026-10-09), which kept priority separate.

2026-10-09, 2026-10-11 · [#161](https://github.com/vocksel/orion/issues/161), [#241](https://github.com/vocksel/orion/issues/241)

### Foil is rarity

Uncommon cards get a silver edge, rare cards a foil edge, and mythic cards a foil edge with holo over the art. Priority shows as a chip in the severity colors and lifts rarity, but has no finish of its own.

**Why:** card games mark rarity with foil, so a shiny card reads as a rare one at a glance. One finish ladder also keeps two shiny signals from competing on the same card. This replaced "Priority is foil, not rarity" (2026-10-11), which gave P0 holo and P1 a foil edge. That entry's worry, that rarity would reward big tickets, is still covered: rarity comes from the graph and a source's priority, never from a card's own size.

2026-10-11 · [#161](https://github.com/vocksel/orion/issues/161), [#242](https://github.com/vocksel/orion/issues/242)

### Reward breaking work down and finishing it, never making cards

Big work looks sealed until it's split into smaller cards. Celebrations, points, and any score come from splitting and finishing, never from creating cards.

**Why:** the behavior worth rewarding is breaking work into smaller pieces. A score that grows with card count invites padding the board to farm it.

2026-10-11 · [#242](https://github.com/vocksel/orion/issues/242), [#116](https://github.com/vocksel/orion/issues/116)

### Card art is a scene picked by kind

A card's art is a scene in the night sky. The kind picks the subject: steps are an orb rising over layered hills, pull requests a ringed planet, expected pull requests an eclipse, and gates a four-point star. The group's inks color it, the card's seed places it, and a grain dither ties it together. Kind also shapes the card's outline, so color is never the only cue.

**Why:** the goal is recognizing a card on sight. Earlier passes missed it in two ways: geometric posters leaned into geometry for its own sake, and a kind icon set over gradient art read as a label stuck onto the card rather than art. This replaced "Card art is symbolic" (2026-10-09), which asked for meaningful shapes without saying what they were.

2026-10-09, 2026-10-11 · [#163](https://github.com/vocksel/orion/issues/163), [#164](https://github.com/vocksel/orion/issues/164), [#275](https://github.com/vocksel/orion/issues/275)

### Each slot on a card has one job

A card never says the same thing twice, such as a repo name above a "Pull request · Orion" label. Text that every card in a group would repeat, like the group's name, stays off the card. "Your move" appears only on the card that's actually yours to act on, not on everything. Sources beyond a few icons go in a details view.

**Why:** repeated and ever-present labels are noise. A mark that shows on every card stops telling you anything.

2026-10-11 · [#275](https://github.com/vocksel/orion/issues/275)

### Marks over words

Status badges on a card are an icon plus at most one word, with icons preferred and tooltips explaining them. A card shows CI state rather than a diff count. A blocked card keeps its type icon, with the lock drawn over it in a transparent tint.

**Why:** short marks read faster than phrases, and the card still has to say what it is while it's blocked.

2026-10-11 · [#275](https://github.com/vocksel/orion/issues/275)

### Severity colors for priority and size

P0 is red, P1 orange, P2 blue, and P3 and below gray. Sizes follow the same scale, with XL red, L orange, M blue, and S gray. When priority or size is unknown, the card shows nothing for it.

**Why:** one familiar severity scale serves both values, and a placeholder for unknown values would only add noise.

2026-10-11 · [#275](https://github.com/vocksel/orion/issues/275)

### Priority and size come from project fields, with labels as a fallback

A card reads priority and size from Project fields named Priority and Size first. When an issue has no project value, `P0`–`P3` and `size/XS`–`size/XL` labels fill in. That one base mapping works with no setup. Other field names, label schemes, and broader heuristics are tuned per project through a config file such as `orion.luau` or a setting, rather than guessed by default.

**Why:** many repositories only have labels, so a fallback covers them without extra setup. Teams label work in many different ways, and guessing broadly risks reading the wrong labels, such as severity as priority. Keeping the default narrow makes it predictable, and config covers the rest once a real project needs it.

2026-10-12 · #241

### Legibility wins over flourish

Holo and foil effects stay off text. Card styles should stay readable at a glance, like Legends of Runeterra, Balatro, and Wildfrost, without Wildfrost's chunky black outlines.

**Why:** the effects are fun, but a card you can't read has failed at its job.

2026-10-07, 2026-10-11 · [#95](https://github.com/vocksel/orion/issues/95)

### Cards are a skin over sources and data

Sources and their data are one layer, and cards are the presentation attached to them. Every card can switch skins: a conventional off-white look, trading cards, plain cards, Trello-style cards, and whatever comes next. Source-specific fields live in `data.refs`, so the card itself stays general.

**Why:** the same data should be able to take on very different looks without the model changing underneath.

2026-10-09 · [#152](https://github.com/vocksel/orion/issues/152), [#154](https://github.com/vocksel/orion/issues/154)

### Card art is reproducible

Generated card art can be produced again from the same card. Later, people should be able to reroll art, keep favorites, and give a card its own color.

**Why:** art that people can shape makes the canvas feel like theirs.

2026-10-07 · [#234](https://github.com/vocksel/orion/issues/234)

### Notes are short Markdown summaries, an experiment

A card's note renders as Markdown: headings, lists, emphasis, links, and inline code. Clicking into it edits the Markdown source in place, and nothing richer is added. Notes stay a short summary that links out to where long writing lives. They're an experiment: the timeline is meant to take over the running record, so once both have been used for a while, decide whether notes stay, shrink to a short description, or go away.

**Why:** a summary reads better rendered than as raw text, but a document editor is a non-goal in the charter, so editing stays plain source. Agents rewrote one note 12 times and once recorded a pass that hadn't happened, which is why the running record gets an append-only timeline rather than more note text. Rendering uses a Markdown library that emits React elements and no raw HTML, so a note can't run code.

2026-10-12 · [#298](https://github.com/vocksel/orion/issues/298)

### Empty groups stay until an edit empties them

A group with nothing inside stays on the canvas, at the size of one card, with a faint "Empty group" hint. `orion group create` makes one, and the app keeps it through loads, saves, and writes from elsewhere. A group goes when an edit takes its last card out: a drop, a removal, or a move out. A group that was already empty is never removed by an edit that doesn't touch it, and a group the removal leaves empty goes too, cascading upward.

**Why:** an agent often lays out the groups for a plan before it has cards to fill them. Dropping empty groups on load deleted them from the file on the next save, and pruning on every edit undid a group made on purpose. This replaced groups disappearing as soon as they were empty.

2026-10-12 · [#304](https://github.com/vocksel/orion/issues/304)

## Canvas and input

### Scrolling pans, for mouse and trackpad alike

Scrolling always pans, whether it comes from a mouse wheel or a trackpad. Pinch and ⌘-scroll zoom. There's no setting and no device detection.

**Why:** the preference was for the mouse wheel to zoom while a trackpad's two-finger scroll pans. That needs Orion to tell the two devices apart, and on macOS there's no reliable way to do it. WebKit reports a mouse wheel and a trackpad with the same delta ratio, and the only other signal relies on undocumented encoding and misses mice with smooth scrolling. Each attempt fixed one device and broke the other. This replaced zooming on scroll ([#208](https://github.com/vocksel/orion/issues/208), [#240](https://github.com/vocksel/orion/issues/240)). Before trying wheel zoom again, find a reliable way to tell the devices apart in WebKit.

2026-10-11 · [#268](https://github.com/vocksel/orion/issues/268)

### Pan mode lets clicks pass through links

In Pan, pressing on a link pans instead of grabbing the link. Holding ⌘ moves cards and groups, including by a group's header.

**Why:** on a busy canvas, presses kept landing on links and moving the pointer instead of the canvas, and Pan had no way to move anything.

2026-10-11 · [#271](https://github.com/vocksel/orion/issues/271)

### Auto-arrange always wins

In an automatically arranged group, a card that's dragged or snapped returns to its arranged place on release.

**Why:** a group can't be both arranged and hand-placed, and mixing the two leaves its layout unpredictable.

2026-10-08 · [#104](https://github.com/vocksel/orion/issues/104)

### Zoomed out reads like a world map

Each group has its own tint, so you know where you are when zoomed out. Cards switch to simpler forms at zoom breakpoints instead of growing or disappearing, and related links stop drawing past one of those breakpoints.

**Why:** zooming out already feels like looking at a map, so lean into it. Cards that blow up when zoomed out become unreadable, and drawing full detail everywhere is heavy enough to crash the desktop web view.

**Open:** charter principle 6 says zoom only moves the camera and detail is a separate control ([#175](https://github.com/vocksel/orion/issues/175), [#205](https://github.com/vocksel/orion/issues/205)). Reconcile the two.

2026-10-07, 2026-10-11 · [#280](https://github.com/vocksel/orion/issues/280)

### Every group opens at the same zoom

Opening a group always lands at actual size. A group that fits on screen is centered; a bigger one opens on its top-left corner, where its flow starts, and you pan or zoom out from there. Fit view is still there for the whole group at once.

**Why:** fitting each group to the screen opened big groups too small to read, so every visit meant zooming out to see the group and back in to read its cards. One opening zoom keeps card text the same size everywhere. This replaced fitting the whole group, up to 125%.

2026-10-12

### Render work is batched from the center out

When many cards need drawing, Orion does the work in batches that spiral outward from the center of the screen, so the first batch covers most of what's in view. A camera move during a batch recalculates the order. The zoom breakpoints are tuned with a debug panel on a large real canvas.

**Why:** sending everything at once blocks the frame, and the cards on screen matter first.

2026-10-11 · [#280](https://github.com/vocksel/orion/issues/280)

### Accessibility settings

Orion has a color palette for each major type of colorblindness, and status uses shapes as well as color, applied the same way across the app. Reduced motion follows the system setting by default, and one switch turns animation off entirely.

**Why:** colorblindness isn't one condition, so one palette can't cover it. Turning off motion should be a single switch rather than a list of effects to find.

2026-10-11 · [#213](https://github.com/vocksel/orion/issues/213)

### Hover lifts the card, and only a pinned card traces its chain

Hovering a card lifts that card alone: it grows slightly from the middle of its title, gets a light ring and a deeper shadow, and rises above its neighbors. Nothing else on the canvas changes on hover. The chain trace, with its dimming, is for a pinned card only. Holding ⌥ keeps its attention fade.

**Why:** tracing on every hover restyled the whole canvas on each pointer move and made hover heavy. Scaling from the title keeps the title readable.

2026-10-12 · [#333](https://github.com/vocksel/orion/issues/333)

## Celebration and triage

### Finished work gets savored

Cards marked done take on a special finish, like a golden shimmer. Double-clicking finished work sets off a cascade through its chain. Finished cards also stack into a history you can look back on, like a skyscraper or a Tetris board.

**Why:** finishing a lot of work should feel like it, and looking back at what got done builds appreciation for it. This stays within the charter: celebrations mark finished work and stay quiet otherwise.

2026-10-11 · [#112](https://github.com/vocksel/orion/issues/112)

### The companion is on by default and quiet at work

The star companion shows on every canvas until it's turned off in Appearance. In work mode it perches and reacts to the card nearest the pointer, and its idle antics stay small. It never takes input, never sits on a card's face, and holds still in its corner when motion is reduced.

**Why:** it makes the canvas feel alive and reads a card's status at a glance, so it earns its place by default. Keeping it small and out of the way respects the charter's calm work mode.

2026-10-11 · [#292](https://github.com/vocksel/orion/issues/292)

### A finished card carries a Done stamp

A card that's done and closed out carries a Done stamp and fades only slightly. Until it's closed out, it shimmers. A done card has to read as finished on its own, without blocked or deferred cards beside it to compare against.

**Why:** fading alone made done look like blocked and deferred work, so a group of finished cards gave no sign it was finished. A stamp says it in one word, which fits marks over words.

2026-10-12 · #317

### Finishing a card in the app closes it out

Marking a card done from its menu or the inspector closes it out at once, and its Done stamp lands right away. Cards finished outside the app, by `orion card done` or a merged pull request, shimmer until someone closes them out.

**Why:** in the app the badge click was an extra step after marking a card done, so finishing it there takes one move. Work finished elsewhere still waits for someone to see it.

2026-10-17 · [#365](https://github.com/vocksel/orion/issues/365)

### Triage happens in a tray, and you do the placing

New pull requests and issues land in a tray at the canvas edge, backed by the Inbox and Unsorted groups. You drag cards from the tray onto the canvas, and Orion learns from where they go. Heuristics and agents suggest where cards belong. Adding cards to the canvas automatically is held back.

**Why:** keeping the canvas current shouldn't need constant back-and-forth with agents, but filing work without a person in the loop risks clutter that has to be cleaned up later.

2026-10-10 · [#195](https://github.com/vocksel/orion/issues/195), [#197](https://github.com/vocksel/orion/issues/197)

### Linking a pull request to its card ships with Orion

When an agent opens a pull request from a card's work, the pull request attaches to that card. This comes with Orion rather than as setup on each machine.

**Why:** every Orion user's agents need this, so it can't depend on one person's local configuration.

2026-10-10 · [#196](https://github.com/vocksel/orion/issues/196)

## Card timeline

### One append-only log per canvas, with cards as targets

Each canvas keeps one log in `log.jsonl`, one JSON line per entry. Each entry records its text, its time, who logged it, and the targets it's attached to. A card's timeline is the log filtered to entries that name the card, so no card stores its own history. An entry that names no card is for the whole canvas and stays in the log only. Entries are never edited or removed. A mistake is corrected by a new entry.

Adding an entry appends a line under the canvas lock and leaves the canvas revision alone. The app's saves check that revision, so logging something never makes an open app's save fail.

**Why:** one stream serves every card, and an entry that concerns several cards is stored once. Appending keeps the record stable, and a correction that sits beside the mistake is more trustworthy than an edit that hides it. This replaces rewriting a card's note to add a line, which lost earlier records and once recorded a pass that hadn't happened.

2026-10-12 · [#298](https://github.com/vocksel/orion/issues/298)

### Undo leaves log entries in place

Log entries aren't canvas edits, so they have no inverses. When undo lands (#1), it restores the canvas and leaves log entries in place as a record of what was done.

**Why:** the log says what happened, including what was later undone. Charter principle 8 asks that every edit be an operation with an inverse. Log appends are records rather than canvas edits, so they sit outside that rule. If the log should be undoable, that is a change to this entry.

2026-10-12 · [#298](https://github.com/vocksel/orion/issues/298)

### Entries record a person or an agent

Entries from `orion log add` are by the person running the CLI, named by `$USER`, unless `--agent <name>` marks them as an agent's. MCP log tools always pass the agent's name, and the tool requires it.

**Why:** a shell command can't tell whether a person or an agent is running it, since agents run the same CLI. Naming the agent is the one signal that holds. Detecting the client from the environment is fragile, and the MCP server doesn't pass its client name through to commands. Both are open to challenge.

2026-10-12 · [#298](https://github.com/vocksel/orion/issues/298)

### The log is read newest first, and stored oldest first

`orion log list`, `orion card timeline`, and the MCP log tools list entries newest first. The file and `GET /api/log` keep append order, oldest first.

**Why:** a timeline is read from its latest entry. The stored order matches the file, so anyone replaying it sees entries as they were written.

2026-10-12 · [#298](https://github.com/vocksel/orion/issues/298)

## Public interfaces

### Public interfaces tighten in three stages

Orion's public surfaces are its CLI commands and flags, MCP tools, `--json` shapes, and data files. How freely they change depends on the release:

- **Before 0.1.0:** cut, rename, and regroup anything. Remove the old form in the same change, with no alias or deprecation period. A command that duplicates another or serves one case is a candidate to remove.
- **From 0.1.0:** breaking changes are still allowed, but each one is deliberate. Anything new must show why it has to widen the surface rather than fit what's already there.
- **From 1.0.0:** the charter's stability promises apply, and breaking changes ship with aliases first.

0.1.0 means the first tagged release, whatever version numbers the manifests carry before it, and it lands around when the repository goes public. 1.0.0 comes much later, likely once the charter's roadmap phases are complete, though an earlier gate may fit better. The HTTP API that `orion server start` exposes is internal to the app at every stage and carries no promise.

**Why:** the CLI has already sprawled one feature at a time, and every cut costs only our own scripts before anyone else depends on it. Once there are users, sprawl is expensive to undo, so new surface has to earn its place well before stability is promised. This replaced keeping deprecated aliases such as `--repo` and `--pr` for a release.

2026-10-12 · [#146](https://github.com/vocksel/orion/issues/146)

### CLI commands are a noun, then a verb

Commands name the thing they act on first, then the action: `orion node remove`, `orion group remove`, `orion link add`. Each noun has its own subcommands, help, and options, so no flag changes meaning by what it targets. Flat verbs such as `orion remove` and `orion ungroup` go away. Each kind of node has its own noun for creating it, such as `orion card add` and `orion note add`, since their inputs differ, and `orion node` covers what applies to any node. `orion canvas` replaces `orion workspace`, following the charter's vocabulary. Two reads stay top level because agents run them before almost everything else: `orion focus`, and `orion next`, which lists the work that can start now, most unblocking first.

**Why:** flat verbs grew one feature at a time and overload options across items, groups, and sources. Grouping by noun makes the surface learnable from `--help` and gives each new kind of thing an obvious home.

2026-10-12 · [#146](https://github.com/vocksel/orion/issues/146), [#110](https://github.com/vocksel/orion/issues/110), [#55](https://github.com/vocksel/orion/issues/55), [#109](https://github.com/vocksel/orion/issues/109)

### Data folders move to a new layout on their own

When the data folder's layout changes, Orion moves an older folder into the new one the first time it runs, rather than asking people to move it by hand. Renaming workspaces to canvases was the first: `workspaces.json` became `canvases.json` and `workspaces/<name>/` became `canvases/<name>/`. A move keeps a backup of anything it rewrites, picks up where it left off if it stopped partway, and waits while an older Orion is still serving the folder.

These moves live in `cli/src/migrations/`, whose README dates each one. Nobody on 0.1.0 or later has an older folder, so they're all removed at that release.

**Why:** interfaces break freely before 0.1.0, but a person's data isn't an interface. A move by hand is easy to miss, and a missed one looks like lost canvases.

2026-10-17 · [#110](https://github.com/vocksel/orion/issues/110)

## Architecture

### Files first, with a SQLite index

A canvas lives as files that can be stored in a repository, like an Obsidian vault. SQLite does the heavy lifting as an index. Agents keep simple read and write commands through the CLI, and `orion server start` keeps one `sqlite3` process open instead of starting one per request.

**Why:** files are portable and easy to inspect, and agents already work well with them. The index keeps large canvases fast.

2026-10-08, 2026-10-11 · [#121](https://github.com/vocksel/orion/issues/121)

### Built for a thousand cards and more

The target is at least 1000 cards with nested groups and dense links: every pull request you've ever made, plus Jira, Slack, images, video, and Figma frames. Like a Notion database, every node can be listed and edited in a table, and canvases are where the visual work happens. The same card can appear in many places.

**Why:** Orion should hold everything you're juggling, not a slice of it.

2026-10-07 · [#122](https://github.com/vocksel/orion/issues/122), [#102](https://github.com/vocksel/orion/issues/102)

### Undo history outlives a canvas switch

Undo history persists across canvas switches, either as a full session history or a rolling history capped at some number of steps. It may live in the SQLite index.

**Why:** history that disappears when you switch canvases is too temporary to trust.

2026-10-10 · [#1](https://github.com/vocksel/orion/issues/1), [#166](https://github.com/vocksel/orion/issues/166)

### Shared logic lives in Luau, and the app gets it from `orion serve`

Logic both the CLI and the app need is written once, in Luau. The app gets its results from `orion serve`, as fields on the document it receives or from an endpoint, the way #93 moves edits and #94 moves status. The app keeps only what it needs on every frame: a few geometry constants, generated from Luau, and small tree walks in TypeScript. A transpiler from Luau to TypeScript, or Luau running in WebAssembly, waits until that set grows.

**Why:** one source for each rule keeps the two sides from drifting, and the server is fast enough for it. Measured against a local `orion serve` on a 61-card canvas at 60 Hz, a small request took about 1 ms at the median and a small committed edit about 1.4 ms, 4 ms at p99. Behind heavy requests, small ones reached about 14 ms at p99, which is why input feedback stays in the app. A transpiler would mean owning a compiler to share about a dozen small helpers.

2026-10-17 · [#427](https://github.com/vocksel/orion/issues/427), [#93](https://github.com/vocksel/orion/issues/93), [#94](https://github.com/vocksel/orion/issues/94)

### Rich cards use link previews, not live embeds

Cards for links show a static snapshot of the link's preview rather than embedding the live page.

**Why:** the goal is rich cards, not running other apps inside the canvas.

2026-10-08 · [#81](https://github.com/vocksel/orion/issues/81)

### Ingest is the one command that pulls from outside

`orion ingest` imports from sources and runs each adapter's refresh, which keeps the cards already on the canvas current, such as GitHub pull request states. `orion sync` stays for one release as a deprecated way to run only the GitHub refresh, and `orion server start`'s background loop keeps running only the refresh.

**Why:** sync was a GitHub-only path beside the general one that already supports GitHub. One command keeps the public surface small and gives every source the same shape. The background loop stays refresh-only because importing files new cards, which should happen when someone asks.

2026-10-12 · [#55](https://github.com/vocksel/orion/issues/55)

### Adapters are Lute packages

Source adapters are Lute packages built on a shared core package. Long term, the official adapters live in their own repositories in an organization, Orion ships with them by default, and people copy them to make their own. Hop becomes a package Orion depends on, and it powers opening a pull request in VS Code.

**Why:** Orion maintains the official adapters while others build their own from the same starting point.

2026-10-11 · [#54](https://github.com/vocksel/orion/issues/54), [#98](https://github.com/vocksel/orion/issues/98)

### No eager scaffolding

Don't build concepts ahead of the features that need them, such as owners before sharing exists. Don't assume defaults that can't be known, such as a repository's owner from its name alone.

**Why:** scaffolding nothing uses yet still has to be maintained, and guessed defaults produce wrong data.

2026-10-09 · [#13](https://github.com/vocksel/orion/issues/13), [#89](https://github.com/vocksel/orion/issues/89)

### MCP stays generic

Orion documents how to register `orion mcp start` with any client instead of shipping setup for each AI provider.

**Why:** registering an MCP server is trivial for people to do themselves, and per-provider code is a lot to maintain for that convenience.

2026-10-09 · [#134](https://github.com/vocksel/orion/issues/134)

### Physics comes from a library

Canvas physics builds on an established library rather than a homegrown engine. It loads in the background, so a canvas opens quickly and physics starts once it's ready. Pinball doesn't drive the choice; a case the library can't handle gets its own path, as Line Rider would.

**Why:** bespoke physics is costly to keep up long term, and objects passing through each other or wobbling stacks are undesirable everywhere, not just in pinball.

2026-10-11 · [#41](https://github.com/vocksel/orion/issues/41)

### The desktop app installs to `/Applications`

Orion installs to `/Applications/Orion.app` so every user on the machine gets it, and local builds replace that copy rather than one in `~/Applications`. The `orion` CLI link and MCP setup point there too.

**Why:** every build shares one bundle id, so a second copy in `~/Applications` shows up as a duplicate Orion and leaves the CLI and the app running different builds.

2026-10-13

## Docs

### The docs site has Guide, Reference, and Development sections

Guide pages teach someone who has never used Orion. Reference pages are generated from the CLI's command table and the MCP tool catalog. Development holds pages about how Orion is made: this log, the charter, and Design and Engineering pages for audits, proposals, and studies. The top nav shows Guide, Reference, and Development, and each one is a link to a page rather than a menu, so content is always one click from the nav. Reference's homepage is generated with its other pages.

**Why:** hand-written write-ups need a home that the reference generator doesn't own, since it removes any page in `docs/reference/` it didn't write. A Development section keeps them apart from the pages that describe what Orion does today, and one umbrella leaves room for Design and Engineering to grow without crowding the nav.

2026-10-17
