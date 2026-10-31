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

### Every skin shares one set of card shapes

A card's outline says its kind, and every skin draws the same outlines. A skin changes only the art inside them.

- A pull request is an arrow, and an issue has a round arch on top.
- A gate is an octagon, wider than a card so it reads as a landmark. Milestones, sign-offs, and physical gates share the octagon and differ by glyph.
- Questions and decisions are round tokens, smaller than a card.
- A reference is a document with a folded corner.
- A step is a rounded rectangle. A placeholder is the same rectangle, hollow and dashed, and is never dimmed.

Gates are the only kind that take more room than a card. Questions, decisions, references, and the three gate types become kinds of their own.

A card's sources show as one coin on its top-right corner: dark, with the source's brand color only in its ring and letters, and a +N for any others. The kind comes from the ref that drives the card's status: the pull request when there is one, then the issue, then the ticket.

**Why:** at 0.33 zoom, outlines held up in grayscale, under color-vision filters, and blurred, while color alone didn't: pull request violet and issue blue match under deuteranopia. Sharing the outlines means switching skins never changes what a card says. A filled brand coin clashed with every card face, and the rim keeps the brand without fighting the art. See the [card identity study](./design/card-identity.md).

2026-10-25 · [#571](https://github.com/vocksel/orion/pull/571)

### Snoozed and optional jobs don't make a card fail

A pull request reads as failing only for a job that counts. When some of its jobs are required, a failing job that isn't required doesn't count. A failing job can also be snoozed, by name, for every card in its repository: either until it next passes on each card, so a later failure there shows again, or until a set time. Cards list their failing jobs with a checkbox each, and unchecking one snoozes it.

**Why:** one boring failure, such as stale generated docs, turns every open pull request red at once. Fixing it on each branch means a CI run per pull request, while snoozing it once clears it everywhere and still catches the job breaking again.

2026-10-13

### Card art is reproducible

Generated card art can be produced again from the same card. Later, people should be able to reroll art, keep favorites, and give a card its own color.

**Why:** art that people can shape makes the canvas feel like theirs.

2026-10-07 · [#234](https://github.com/vocksel/orion/issues/234)

### Notes are short Markdown summaries, an experiment

A card's note renders as Markdown: headings, lists, emphasis, links, and inline code. Clicking into it edits the Markdown source in place, and nothing richer is added. Notes stay a short summary that links out to where long writing lives. They're an experiment: the timeline is meant to take over the running record, so once both have been used for a while, decide whether notes stay, shrink to a short description, or go away.

**Why:** a summary reads better rendered than as raw text, but a document editor is a non-goal in the charter, so editing stays plain source. Agents rewrote one note 12 times and once recorded a pass that hadn't happened, which is why the running record gets an append-only timeline rather than more note text. Rendering uses a Markdown library that emits React elements and no raw HTML, so a note can't run code.

2026-10-12 · [#298](https://github.com/vocksel/orion/issues/298)

### Types ship in packs, then come from mods, then from canvases

A card type declares its fields, face, states, and meaning in Luau, and every type registers through one registry. The types Orion ships come first, as a pack beside the CLI, and source kinds register theirs through the same path. Mods add types next, and types declared in a canvas's own files come later. A card carries several types: its own, which picks its face, then the ones its sources attach, then the ones people attach. The built-in kinds are types on that registry, so none of them is a special case.

**Why:** a new source or type has to reach the card face without an app change, which means the app reads declarations rather than knowing kinds by name. Shipping packs first proves the declaration shape on types Orion already has, and one registry keeps mods and canvas types from each needing a path of their own. This settles the charter's open question on where type definitions live.

2026-10-26 · [#215](https://github.com/gummy-galaxy/orion/issues/215)

### Empty groups stay until an edit empties them

A group with nothing inside stays on the canvas, at the size of one card, with a faint "Empty group" hint. `orion group create` makes one, and the app keeps it through loads, saves, and writes from elsewhere. A group goes when an edit takes its last card out: a drop, a removal, or a move out. A group that was already empty is never removed by an edit that doesn't touch it, and a group the removal leaves empty goes too, cascading upward.

**Why:** an agent often lays out the groups for a plan before it has cards to fill them. Dropping empty groups on load deleted them from the file on the next save, and pruning on every edit undid a group made on purpose. This replaced groups disappearing as soon as they were empty.

2026-10-12 · [#304](https://github.com/vocksel/orion/issues/304)

## Appearance

### Vibrant and Trading Card are the defaults

New installs get the Vibrant theme and Trading cards, and so does anyone whose saved theme or skin is empty or unknown. A choice someone already made stays. Every other built-in theme and skin, Classic and Plain, is deprecated: Settings tags it, it keeps working for now, and it will be removed later. Pull request screenshots and recordings pin Vibrant and Trading cards on both sides, so captures show the look people get.

Vibrant is also the base a theme file builds on. When Classic is removed, Vibrant's values become the token defaults, so a token a theme file leaves out takes Vibrant's value.

**Why:** Vibrant and Trading cards carry Orion's visual direction, and each extra built-in look is one more that every visual change has to be designed, checked, and captured in. One default lets that work target one look. A theme file that builds on the look people already see changes only what it means to.

2026-10-18, 2026-10-20 · [#532](https://github.com/vocksel/orion/pull/532), [#146](https://github.com/vocksel/orion/issues/146)

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

Each group has its own color, so you know where you are when zoomed out. The color belongs to the group's container, never its cards: a light wash, and a header bar in the group's color. The header is a landmark, big in canvas units when zoomed out but never smaller than about 17 screen pixels, and calm up close. A folded group shows its next open card face up on a deck, with a count of each kind beside it. Cards switch to simpler forms at zoom breakpoints instead of growing or disappearing, and related links stop drawing past one of those breakpoints.

**Why:** zooming out already feels like looking at a map, so lean into it. Cards that blow up when zoomed out become unreadable, and drawing full detail everywhere is heavy enough to crash the desktop web view. Tinting each card by its group was a big reason kinds blurred together at a distance, so the color moved to the container and left the card's colors to its kind. This replaced group-tinted cards (2026-10-07).

**Open:** charter principle 6 says zoom only moves the camera and detail is a separate control ([#175](https://github.com/vocksel/orion/issues/175), [#205](https://github.com/vocksel/orion/issues/205)). Reconcile the two.

2026-10-07, 2026-10-11, 2026-10-25 · [#280](https://github.com/vocksel/orion/issues/280), [#571](https://github.com/vocksel/orion/pull/571)

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

### Details live in a panel beside the canvas

What's selected shows in a fixed panel on the right of the window, not in an overlay on the canvas. With nothing selected, the panel shows the open group, or the canvas at the top level. Focus view puts the focused card's details there too. The panel can be hidden or dragged to a new width, and Orion remembers both. Renaming or editing something brings a hidden panel back.

**Why:** an overlay that came and went with each click flashed in and out and covered cards. A panel that stays put never hides the canvas, and selecting doesn't resize it.

2026-10-19

## Celebration and triage

### Finished work gets savored

Cards marked done take on a special finish, like a golden shimmer. Double-clicking finished work sets off a cascade through its chain. Finished cards also stack into a history you can look back on, like a skyscraper or a Tetris board.

**Why:** finishing a lot of work should feel like it, and looking back at what got done builds appreciation for it. This stays within the charter: celebrations mark finished work and stay quiet otherwise.

2026-10-11 · [#112](https://github.com/vocksel/orion/issues/112)

### The companion is on by default and quiet at work

The star companion shows on every canvas until it's turned off in Appearance. In work mode it perches and reacts to the card nearest the pointer, and its idle antics stay small. It never takes input, never sits on a card's face, and holds still in its corner when motion is reduced.

**Why:** it makes the canvas feel alive and reads a card's status at a glance, so it earns its place by default. Keeping it small and out of the way respects the charter's calm work mode.

2026-10-11 · [#292](https://github.com/vocksel/orion/issues/292)

### A card's state is a band across it

Done, deferred, and blocked cards carry a full-width band across the middle of the card, over the art and clear of the title: DONE, LATER, or a striped BLOCKED with a lock. A done card that isn't closed out yet shimmers until it is. A done card has to read as finished on its own, without blocked or deferred cards beside it to compare against.

**Why:** fading alone made done look like blocked and deferred work, so a group of finished cards gave no sign it was finished. A band says each state in one word, in the same place on every card and every skin, and it leaves the title readable, so a blocked card still says what the work is. This replaced "A finished card carries a Done stamp" (2026-10-12), which stamped done work and left deferred and blocked work to fading and a lock.

2026-10-12, 2026-10-25 · #317, [#571](https://github.com/vocksel/orion/pull/571)

### Finishing a card in the app closes it out

Marking a card done from its menu or the inspector closes it out at once, and its Done band lands right away. Cards finished outside the app, by `orion card done` or a merged pull request, shimmer until someone closes them out.

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

### Reveal stays top level and opens the app

`orion reveal <id…>` stays a top-level command rather than moving under `orion focus`. It also zooms the canvas to what it selects, which setting focus shouldn't do. When no app is running, reveal launches the installed app on the same data folder, then waits for the app to show the items before it reports success.

**Why:** a reveal moves the camera as well as the selection, and focus only reports what the app shows. Agents asked to show someone a card shouldn't have to tell them to open the app first.

2026-10-12 · [#299](https://github.com/vocksel/orion/issues/299)

### Public interfaces tighten in three stages

Orion's public surfaces are its CLI commands and flags, MCP tools, `--json` shapes, and data files. How freely they change depends on the release:

- **Before 0.1.0:** cut, rename, and regroup anything. A cut goes in the same change, with no deprecation period. A rename keeps the old name working through an alias, as "Aliases and migrations share one lifecycle" describes. A command that duplicates another or serves one case is a candidate to remove.
- **From 0.1.0:** breaking changes are still allowed, but each one is deliberate. Anything new must show why it has to widen the surface rather than fit what's already there.
- **From 1.0.0:** the charter's stability promises apply, and breaking changes ship with aliases first.

0.1.0 means the first tagged release, whatever version numbers the manifests carry before it, and it lands around when the repository goes public. 1.0.0 comes much later, likely once the charter's roadmap phases are complete, though an earlier gate may fit better. The HTTP API that `orion server start` exposes is internal to the app at every stage and carries no promise.

**Why:** the CLI has already sprawled one feature at a time, and every cut costs only our own scripts before anyone else depends on it. Once there are users, sprawl is expensive to undo, so new surface has to earn its place well before stability is promised. This replaced keeping deprecated aliases such as `--repo` and `--pr` for a release. The forms that predate it, `orion sync`, `--pr`, and `--repo` used with `--pr`, go now with no alias rather than waiting out their release. Renames got aliases back once they had a lifecycle of their own: an alias costs little when it's pruned at the next release, and it turns a renamed command in a script or a saved prompt into a notice instead of an error.

2026-10-12, 2026-10-18, 2026-10-19 · [#146](https://github.com/vocksel/orion/issues/146), [#469](https://github.com/vocksel/orion/issues/469)

### Aliases and migrations share one lifecycle

An alias keeps a renamed command, option, or MCP tool working, as a migration keeps an older data folder working. Both follow the same rules:

- **The machinery stays, and the entries are pruned.** The alias resolver and the migration runner are permanent and tested. Each alias or migration is an entry, dated with the pull request that added it in its folder's README. Every release removes the entries from before it, so each release starts clean.
- **An alias is invisible except for its notice.** The CLI rewrites an old name before it parses and prints a one-line notice to stderr, never to stdout, so `--json` output stays the same. Help doesn't list aliases. The MCP server accepts an old tool name when it's called but doesn't list it.
- **Tests guard the entries.** Every alias points at a command or option that exists, none hides a live command, and each has its date and pull request.

From 1.0.0, an alias stays for at least one release before it's pruned, as the three stages require.

**Why:** renames before 0.1.0 are cheap for us but break scripts and agent prompts without warning. Sharing one lifecycle with migrations means one release step clears both, and permanent machinery means the code path is hardened by the time 1.0.0 depends on it.

2026-10-19 · [#146](https://github.com/vocksel/orion/issues/146)

### The HTTP API is internal, and the server enforces it

The API that `orion server start` serves exists for the app alone. Agents and scripts use the CLI or MCP, and the docs don't describe its routes as something to call. The server refuses requests whose `Host` or `Origin` isn't its own address or the app's dev server, and serves the static app with a content security policy. A launch token for the app waits until that check proves too loose.

**Why:** an internal API with no check is open to any web page in a browser on the same machine. `POST` routes read a cross-site `text/plain` body as JSON, which needs no CORS preflight, so a page could merge a pull request through `POST /api/merge` or change canvases and settings. The server answers any `Host`, so a DNS-rebinding page could read the canvas. Checking `Host` and `Origin` closes both without the app holding a secret.

2026-10-18 · [#146](https://github.com/vocksel/orion/issues/146), [#468](https://github.com/vocksel/orion/issues/468)

### No JSON shape is stable before 1.0.0

`--json` output carries no promise until 1.0.0, so the shapes can be made consistent first: every command takes `--json`, failures print a JSON error, every write prints its revision, groups and notes get shapes of their own, times use RFC 3339, and an absent value is `null` or missing rather than an empty string. No shape is promised at 0.1.0 either, as with what people write for Orion. From 0.1.0 until then, a change to a shape is deliberate and listed in the release notes, as the three stages ask.

**Why:** each fix for an inconsistency breaks the shape it touches, so promising a shape before fixing it would lock in the inconsistency. Shapes keep settling after 0.1.0 as commands are renamed and plans follow the CLI, so an early promise would only freeze them mid-change. This replaced promising a short list of shapes from 0.1.0.

2026-10-18, 2026-10-21 · [#146](https://github.com/vocksel/orion/issues/146), [#470](https://github.com/vocksel/orion/issues/470)

### What people write for Orion carries no promise until 1.0.0

Plans, selectors, refs, `--where` expressions, times, theme files, and JSON error codes stay unpromised at 0.1.0, as `--json` output does. They become promises with the rest of the charter's stability at 1.0.0. In the meantime, a rename keeps the old form working through an alias, as "Aliases and migrations share one lifecycle" describes.

**Why:** these formats are still settling, and the plan format is about to change shape. Aliases already soften a rename for scripts and saved prompts, so an early promise would add constraints without protecting anyone more.

2026-10-21 · [#146](https://github.com/vocksel/orion/issues/146)

### Plans are the CLI written as JSON

Each operation in a plan for `orion apply` is named after its command path, such as `card create` or `node move`, and takes fields named after that command's options. Plans no longer use the internal operation names that `POST /api/operations` takes, and Orion translates between the two.

**Why:** agents learn one vocabulary for commands and plans, and the app's internal edits can change without breaking a plan.

2026-10-21 · [#146](https://github.com/vocksel/orion/issues/146), [#567](https://github.com/vocksel/orion/issues/567)

### Failures go to stderr, and JSON errors carry a code

Without `--json`, a failure prints `Error: …` on stderr, so stdout only ever holds output. With `--json`, it prints `{"error": {"code": …, "message": …}}` on stdout, where a script already reads. Codes start with a revision conflict, a missing item, and an ambiguous selector, and grow when a script needs to act on another failure. Every failure still exits 1.

**Why:** an error on stdout ends up in whatever file or pipe the output was going to. A code lets a script retry an `--if-revision` conflict without matching the message's wording, and one exit code for every failure keeps shell scripts simple.

2026-10-21 · [#146](https://github.com/vocksel/orion/issues/146)

### A time without an offset is local

Every `--until` reads an ISO 8601 date or date-time through `time/parseUntil`. A date-time without an offset is in local time, and a date alone means the start of that local day. A time ending in `Z` or an offset means what it says. Orion stores and prints times in RFC 3339 UTC.

**Why:** people think in their own time zone. Before this, `card snooze` read local time and `ci snooze` read UTC, so the same date ended the two snoozes hours apart.

2026-10-21 · [#146](https://github.com/vocksel/orion/issues/146)

### The command line gets a guide page and a generated reference

A guide page explains working with Orion from the command line, for someone new to it. The `--where` grammar, selectors, and ref forms also get reference pages generated from the code that parses them, as the CLI and MCP references are generated from the command table.

**Why:** the guide teaches, and generated pages can't drift from the parser. Today those syntaxes are written down only in `orion help node query` and the agent guide.

2026-10-21 · [#146](https://github.com/vocksel/orion/issues/146)

### CLI commands are a noun, then a verb

Commands name the thing they act on first, then the action: `orion node remove`, `orion group remove`, `orion link create`. Each noun has its own subcommands, help, and options, so no flag changes meaning by what it targets. Flat verbs such as `orion remove` and `orion ungroup` go away. Each kind of node has its own noun for creating it, such as `orion card create` and `orion note create`, since their inputs differ, and `orion node` covers what applies to any node. `orion canvas` replaces `orion workspace`, following the charter's vocabulary. Two reads stay top level because agents run them before almost everything else: `orion focus`, and `orion next`, which lists the work that can start now, most unblocking first.

Two verbs bring things in, and which one a command uses depends on what it brings:

- **`create`** makes something new that Orion owns, which you can change or remove later: `card create`, `note create`, `link create`, `group create`, and `canvas create`.
- **`add`** brings in something that already exists outside Orion, or appends to a record that never changes: `source add`, `theme add`, `media add`, and `log add`.

`remove` undoes either. Today's `card add`, `note add`, `link add`, and `media insert` move to these names, and `group add` folds into `group create --items`.

**Why:** flat verbs grew one feature at a time and overload options across items, groups, and sources. Grouping by noun makes the surface learnable from `--help` and gives each new kind of thing an obvious home. Mixing `create` and `add` with no rule made every new command a coin flip. The split follows `gh`, which agents already know: a card is a new thing with an identity, while a source or a theme file exists before Orion learns about it, and a log entry is never edited.

2026-10-12, 2026-10-19 · [#146](https://github.com/vocksel/orion/issues/146), [#110](https://github.com/vocksel/orion/issues/110), [#55](https://github.com/vocksel/orion/issues/55), [#109](https://github.com/vocksel/orion/issues/109)

### MCP tools come from the CLI's commands

Each CLI command is one MCP tool, named after its path as `orion_<noun>_<verb>`, such as `orion_card_create`, with a field for each option in camelCase. Top-level commands keep one word, such as `orion_next`. A command declares its tool where it's defined: its annotations, the options the tool leaves out and why, or why MCP leaves the command out. An option's value type, such as an enum or an integer, sits on the line that defines it, and the input schema comes from it. A tool's description is the command's help unless the command gives an agent-facing one, which stays rare.

Every tool takes `canvas`, as every command takes `--canvas`, and ignores it where it means nothing, such as `orion_theme_list`. Only tools that name a canvas themselves, such as `orion_canvas_create`, leave it out, so the target can't land in the wrong field. No tool takes a program to run, as "Programs Orion runs are chosen on this machine" says.

**Why:** agents learn one vocabulary, and a new command or option can't leave MCP behind. One tool per command gives each a precise schema, so a client can check a call before it runs. A tool that switches between commands, as `orion_inspect` did, can't say which arguments go with which. This replaced names picked one tool at a time, which mixed verb-first, noun-first, and bare-verb patterns. A `canvas` field that's ignored costs nothing, while an exception for each tool is one more thing to explain.

2026-10-18, 2026-10-19 · [#415](https://github.com/vocksel/orion/issues/415), [#146](https://github.com/vocksel/orion/issues/146)

### Data folders move to a new layout on their own

When the data folder's layout changes, Orion moves an older folder into the new one the first time it runs, rather than asking people to move it by hand. Renaming workspaces to canvases was the first: `workspaces.json` became `canvases.json` and `workspaces/<name>/` became `canvases/<name>/`. A move keeps a backup of anything it rewrites, picks up where it left off if it stopped partway, and refuses while another build of Orion is still serving the folder.

These moves live in `workspace/orion-cli/src/storage/migrations/`, whose README dates each one. Nobody on 0.1.0 or later has an older folder, so they're all removed at that release, and the code that runs them stays for the next layout change, as "Aliases and migrations share one lifecycle" says.

Moves that would have to guess are the exception. Upgrading a version 1 data file meant guessing the GitHub owner of every short repository name, so Orion refuses a version 1 file instead, with a message saying how to upgrade it with an older build.

**Why:** interfaces break freely before 0.1.0, but a person's data isn't an interface. A move by hand is easy to miss, and a missed one looks like lost canvases. A guessed move writes wrong data, which is worse than asking.

2026-10-17 · [#110](https://github.com/vocksel/orion/issues/110), [#471](https://github.com/vocksel/orion/issues/471)

### Development stays off the real data folder

The app's dev server serves a scratch data folder seeded from a fixture, and tests, Storybook, and perf runs never start a server on the real one. A developer opts into real data with `ORION_REAL_DATA=1`.

**Why:** a CLI built from a branch moves the data it touches to that branch's layout, and the installed app can't read the result. A branch build serving the real folder once stranded every canvas that way, and a migration's refusal under a running server can't help when the app is closed.

2026-10-18

## Roadmap

### Spikes open phase 2, and an exploration track runs alongside it

Phase 2 starts by prototyping its riskiest bets, placements, database views, and agent sessions on cards, before building them for real. Alongside it, an exploration track prototypes ideas from later phases: selection and layout, a home page, ink, ambience, and script cards. Each spike is time-boxed, ends in something to try, and closes with a verdict that feeds the roadmap. Spikes don't merge.

**Why:** the filed ideas pull Orion in many directions, and trying the options by hand beats choosing between them from issue text. Opening phase 2 with its own spikes keeps the data model first, since placements change what selecting and clustering mean. Running the rest alongside, rather than as a phase of its own, gets phase 2 started sooner. Script cards that agents write give them an escape hatch for freeform logic, and what they write shows which features deserve to be first-class.

2026-10-18 · [#122](https://github.com/vocksel/orion/issues/122), [#102](https://github.com/vocksel/orion/issues/102), [#293](https://github.com/vocksel/orion/issues/293), [#456](https://github.com/vocksel/orion/issues/456), [#227](https://github.com/vocksel/orion/issues/227)

## Architecture

### Files first, with a SQLite index

A workspace is a folder of files that can live anywhere, including a repository, and opening the folder opens the workspace, like an Obsidian vault. It holds its canvases, the cards and links they place, its sources, and its themes. Cards and links belong to the workspace rather than to one canvas, so a card can appear on several canvases. SQLite does the heavy lifting as an index that can be rebuilt from the files. The index lives outside the folder with the rest of a machine's local state, such as focus and backups, so nothing in the folder needs ignoring. Agents keep simple read and write commands through the CLI, and `orion server start` keeps one `sqlite3` process open instead of starting one per request.

**Why:** files are portable and easy to inspect, and agents already work well with them. The index keeps large canvases fast. A canvas can't be the vault once a card appears in more than one place, since the card would have to live in one canvas's folder. This replaced storing each canvas as its own vault (2026-10-08), which came before a workspace could hold several canvases.

2026-10-08, 2026-10-11, 2026-10-19 · [#121](https://github.com/vocksel/orion/issues/121), [#122](https://github.com/vocksel/orion/issues/122)

### One data version covers the workspace

A `version` in `workspace.json` covers the whole workspace folder: its canvases, cards, and links. Node and link files carry no version of their own, and a layout change bumps the one version and migrates every file under it. Until the workspace folder lands ([#568](https://github.com/vocksel/orion/issues/568)), the `version` in each `canvas.json` stands in for it.

**Why:** the workspace is the vault, so it's the unit that changes layout. One version at the top keeps every card and link file small and lets a migration read one number to know what it's looking at, rather than finding files of mixed versions mid-folder.

2026-10-21 · [#146](https://github.com/vocksel/orion/issues/146), [#568](https://github.com/vocksel/orion/issues/568)

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

`orion ingest` imports from sources and runs each adapter's refresh, which keeps the cards already on the canvas current, such as GitHub pull request states. A GitHub source files your new pull requests in Unsorted. `orion server start`'s background loop runs only the refresh.

**Why:** sync was a GitHub-only path beside the general one that already supports GitHub. One command keeps the public surface small and gives every source the same shape. The background loop stays refresh-only because importing files new cards, which should happen when someone asks. This replaced keeping `orion sync`, and its `--discover` flag for filing pull requests in an Inbox group, as a deprecated alias for one release. Before 0.1.0, old forms go with no alias.

2026-10-12, 2026-10-18 · [#55](https://github.com/vocksel/orion/issues/55), [#469](https://github.com/vocksel/orion/issues/469)

### Refs are identified by their source's stable ID

A ref carries the readable key people type and see, such as `owner/name#12`, and an `id` from its source that survives a rename or move. Two refs of one kind are the same when their IDs match, or when their keys match and either has no ID yet. Anything that takes a ref or a repository by name keeps accepting the name and resolves it to the ID. A ref with no ID, from older data or added offline, gets one the next time its source is read.

**Why:** a key names where work lives, and that changes when a repository is renamed or transferred. Matching by key then treats tracked work as new. Keeping names as input means nobody has to know an ID to use Orion.

2026-10-25 · [#625](https://github.com/vocksel/orion/issues/625), [#538](https://github.com/vocksel/orion/issues/538)

### The background refresh fetches what changed

`orion server start` fetches every open pull request card in full only at startup, on a canvas switch, when you ask, and every 15 minutes. In between, it polls GitHub notifications as often as GitHub allows, 60 seconds today, and refetches the pull requests they name. Every two minutes it also sweeps the open cards' `updatedAt` and refetches only the ones that moved. Cards with pending checks are refetched every 30 seconds. What the loop remembers between polls lives in memory, and a pass that finds nothing writes nothing.

**Why:** a full refresh costs what's on the canvas, and GitHub ends a query after about 10 seconds. Notifications cover other people's activity for free, since an unchanged poll answers 304. They never include the viewer's own or agents' activity, which the `updatedAt` sweep catches. Neither reports a finished check run or a change in mergeability, so checks get their own short timer and mergeability waits for the full pass. Startup runs a full pass anyway, so persisting poll state would add writes for nothing.

2026-10-18 · [#366](https://github.com/vocksel/orion/issues/366)

### Cards in view refresh sooner

The background refresh sweeps `updatedAt` every 30 seconds, instead of every two minutes, for one set of cards that refresh sooner. The cards in view feed it: the open group and everything inside it, or the selection when no group is open, plus the cards one link away that block them. The server reads them from the focus report the app already sends. Watched cards ([#232](https://github.com/vocksel/orion/issues/232)) join the same set rather than adding a cadence of their own. Pending checks stay at 30 seconds and the full pass at 15 minutes for every card.

**Why:** what someone is looking at matters most, and a sweep of a handful of cards costs one small query. Speeding up only the sweep keeps the rest of the canvas on the cadences GitHub's limits allow.

2026-10-18 · [#450](https://github.com/vocksel/orion/issues/450)

### Adapters are Lute packages

Source adapters are Lute packages built on a shared core package. Long term, the official adapters live in their own repositories in an organization, Orion ships with them by default, and people copy them to make their own. Hop becomes a package Orion depends on, and it powers opening a pull request in VS Code.

**Why:** Orion maintains the official adapters while others build their own from the same starting point.

2026-10-11 · [#54](https://github.com/vocksel/orion/issues/54), [#98](https://github.com/vocksel/orion/issues/98)

### Adapters have source verbs and agent verbs

An adapter offers source verbs, which bring work in as cards and refs, agent verbs, which find an agent tool's sessions and talk to them, or both. The agent verbs are list, read, resume, and start, and each session an adapter lists has the same fields whatever the agent, such as its folder, branch, and whether it's working or waiting on you. Orion calls only the verbs an adapter has, and [Adapters](/development/engineering/adapters) documents the contract.

**Why:** sessions run in many tools, and a second agent should plug in the way a second source does, with no change to the app. Keeping the agent verbs apart from the source verbs lets an agent adapter skip collecting cards, since sessions attach to cards that already exist.

2026-10-26 · [#293](https://github.com/gummy-galaxy/orion/issues/293), [#606](https://github.com/gummy-galaxy/orion/issues/606)

### Session refs store state, never what was said

A session ref keeps the session's state and its label, such as "Waiting on you in Claude Code", and nothing from its transcript. The last message and recent turns are read live from the agent's own records through its adapter whenever the app shows them, and never written to a canvas's files, so `--json` shows only the stored state.

**Why:** sources stay the source of truth, and a stored message would be a copy of the transcript that drifts. Canvas files can go in git and be shared, and a session's words can quote secrets or private context.

2026-10-26 · [#608](https://github.com/gummy-galaxy/orion/issues/608)

### Programs Orion runs are chosen on this machine

A person picks any program Orion runs, such as a Jira source's command or the agent `suggestion find` hands cards to, at the CLI. The command lives in this machine's config, never in a canvas's files, and no MCP tool takes one. The tool catalog refuses a tool that would. Setting up a source that runs nothing of its own choosing, such as GitHub or hop, is open to MCP. Jira's setup stays in the CLI until its command moves to local config. Adapter packages replace `--command` later, so a custom integration is something a person installs on purpose.

**Why:** canvas files go in git, so a command stored in one would run for anyone who ingests a clone. Git keeps hooks out of clones for the same reason. A tool call can come from a prompt injection, in a client that otherwise runs no shell commands, and a command it set could run long after the call.

2026-10-19 · [#146](https://github.com/vocksel/orion/issues/146), [#552](https://github.com/vocksel/orion/pull/552)

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

### Packages live in `workspace/`, named `orion-*`

The repository's packages sit together in `workspace/`: `orion-app` is the canvas in React, `orion-cli` is the `orion` CLI and its server, and `orion-desktop` is the Tauri shell that bundles the two. Each folder's name matches its package name. The top level keeps the docs, examples, and repository-wide config, including the Lute scripts in `.lute/`, which run from the repository root and find each package through `project.luau`.

**Why:** "the app" already means the canvas a person works in, whether a browser or the desktop shell hosts it, so `orion-app` keeps that meaning and `orion-desktop` names the installable wrapper. This `workspace/` is the repository's folder of packages, not an Orion workspace of canvases.

2026-10-24

### Functions that wait on the command runner end in `Async`

A Luau function that waits on a `CommandRunner`, directly or through a call, ends in `Async`, such as `refreshAsync` and `fetchRepositoriesAsync`. That covers local programs like git and hop as well as network calls. The suffix spreads up through callers, including adapter fields such as `collectAsync`, the server's route handlers, and the sync loop's `runAsync` and `tickAsync`. It stops at callbacks whose name a shared shape sets, such as a command's `run`, and at the runner itself. The process probes `isProcessAlive` and `getParentPid` are exempt: they return at once, and following them through the workspace lock would put the suffix on nearly every read and write.

**Why:** callers can see that a call may take a while and might belong in a `task.spawn`. Tying the rule to the runner, rather than to whether a call reaches the network, makes it something to check mechanically, so it gets applied consistently.

2026-10-25 · [#627](https://github.com/vocksel/orion/pull/627)

### The CLI's source is grouped in layers

`workspace/orion-cli/src` holds a few top-level folders, each a layer: `common` for helpers with no Orion knowledge, `canvas` for the model and pure changes to it, `storage` for the data folder on disk, `sources` and `telemetry` for the outside world, and `cli` and `server` for the surfaces. A folder requires from its own layer or one below it. Types, constants, and config tables, such as `types.luau`, `geometry.luau`, and `fileNames.luau`, stay at the top of `src` under every layer, beside `testing.luau`. Requires keep the one `@root` alias, with no alias per layer. MCP lives in `cli/mcp`, since its tools are built from the CLI's commands. Code that only `.lute` scripts use lives in `.lute/lib`, not in `src`.

**Why:** with dozens of folders and loose files at the top of `src`, nothing said where a module belonged, and GitHub code sat in two places. A layer answers where a new module goes and which way its requires may point, and it leaves the requires that point up, such as the canvas model reading GitHub pull request facts, easy to spot.

2026-10-31 · [#707](https://github.com/gummy-galaxy/orion/pull/707)

## Docs

### The docs site has Guide, Reference, and Development sections

Guide pages teach someone who has never used Orion. Reference pages are generated from the CLI's command table and the MCP tool catalog. Development holds pages about how Orion is made: this log, the charter, and Design and Engineering pages for audits, proposals, and studies. The top nav shows Guide, Reference, and Development, and each one is a link to a page rather than a menu, so content is always one click from the nav. Reference's homepage is generated with its other pages.

**Why:** hand-written write-ups need a home that the reference generator doesn't own, since it removes any page in `docs/reference/` it didn't write. A Development section keeps them apart from the pages that describe what Orion does today, and one umbrella leaves room for Design and Engineering to grow without crowding the nav.

2026-10-17

### The docs site is served from `oriongraph.app` on Cloudflare

The docs site lives at the bare `oriongraph.app`, served from the root path, by the `orion` Cloudflare Worker as static assets. GitHub Actions deploys it from `main`, and each pull request that changes the docs gets a preview URL. Its home page doubles as Orion's homepage.

**Why:** the domain stays the same when the repository changes owners, while a GitHub Pages address would change with it. Cloudflare deploys while the repository is private, which GitHub Pages can't, and it sits beside the domain's DNS in Cloudflare. Deploying from CI rather than Cloudflare's own builds keeps every build in one place.

2026-10-25 · [#327](https://github.com/vocksel/orion/pull/327) · [#575](https://github.com/vocksel/orion/issues/575)

## Telemetry

### Only the person chooses whether to share usage data

The app asks once on launch, and Settings changes the answer. `orion telemetry on` and `off` cover machines without the app. The CLI and MCP server never prompt, and agents get `orion_telemetry_status` but no tool to change the choice. `DO_NOT_TRACK` and `ORION_TELEMETRY=0` turn telemetry off whatever was chosen. The choice and the anonymous install id live in `telemetry.json` in the data folder, outside `settings.json`, so they never travel with exported or synced settings.

**Why:** consent an agent can give isn't the person's consent. A prompt from the CLI would hang an agent that runs it, so the CLI stays silent and sends nothing until someone opts in.

2026-10-28 · [#507](https://github.com/gummy-galaxy/orion/issues/507), [#433](https://github.com/gummy-galaxy/orion/issues/433)

### An event needs a reason from outside

A new usage event joins the catalog only when something outside pushes for it: a decision it would change, a target it measures, such as 80% of new installs reaching a canvas, or a problem seen in real use. Performance on people's machines comes first: frame times, CPU, memory, crashes, and time to interactive. Events carry counts, durations, and Orion's own names, never content.

**Why:** every event lengthens the list people read before they opt in, needs code to emit it, and adds to what PostHog stores. Collecting only what a decision needs keeps that list short enough to read and keeps telemetry within what people agreed to. Screen views were left out on this basis until a specific question needs them.

2026-10-30 · [#624](https://github.com/gummy-galaxy/orion/issues/624), [#692](https://github.com/gummy-galaxy/orion/issues/692), [#433](https://github.com/gummy-galaxy/orion/issues/433)

### People can delete what they've shared

Settings and `orion telemetry delete` erase every event sent under the install ID, separately from opting out. Opting out stops sending but keeps the ID, so the data can still be deleted afterward. Deleting forgets the ID, and opting in again starts a new one. Erasure ships before any release that sends events.

**Why:** consent that can be withdrawn should be able to take back what was given too, and data protection law such as GDPR expects that. Keeping deletion apart from opting out means stopping doesn't silently discard data someone was happy to share, and deleting stays possible after they stop.

2026-10-30 · [#691](https://github.com/gummy-galaxy/orion/issues/691), [#433](https://github.com/gummy-galaxy/orion/issues/433)

## Releases

### Changes arrive with entries, and release notes are built from them

Each change people will notice lands with an entry in `.changes/`, and Changewrite builds the release notes and changelog from those entries when a release is cut. A pull request that changes `workspace/`, apart from Markdown files, adds one. Each entry's category is one of six surfaces: Canvas, Cards, Agents (the CLI and MCP), Sources, Desktop app, and Under the hood for internal work.

**Why:** an entry written with its change is the cheapest accurate record of it, and the category decides where it lands in the notes, so each surface gets a section that people can find.

2026-10-25 · [Ship changelogs and release notes with 0.1.0](https://github.com/vocksel/orion/issues/633)

### Release notes lead with highlights, then breaking changes, then each surface

Notes open with a TL;DR and highlights, then a callout for breaking changes, then one section per surface, with Under the hood collapsed at the end. Each bullet starts with a chip for its kind (NEW, IMPROVED, FIXED, or BREAKING) and ends with a link to its pull request. A chip is a tinted pill with a solid dot and a plain capital word, in a light and a dark version.

**Why:** a reader who skims should learn what changed first, and breaking changes shouldn't be buried in a surface's list. GitHub shows the notes in both themes, so each chip needs a pair that reads in either one.

2026-10-25 · [Ship changelogs and release notes with 0.1.0](https://github.com/vocksel/orion/issues/633)
