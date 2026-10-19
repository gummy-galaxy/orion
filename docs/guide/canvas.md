# Using the canvas

The shortcuts on this page are the defaults. Open **Settings › Keyboard Shortcuts** to see every shortcut and gesture, and click one to rebind it.

## Moving around

- Scroll, Space-drag, or middle-drag to pan. Pinch or ⌘-scroll to zoom.
- However far you zoom out, cards, notes, and folded groups keep their details at a readable size.
- The sidebar lists every group in canvas order. Click one to open it.
- Press ⌘K to search groups, cards, pull requests, and notes, then Enter to jump to a result.
- Type `>` in search, or press ⇧⌘P, to list actions instead.

## Tools

The toolbar at the bottom switches tools. Esc returns to Select.

- **Select (V)** is the default. Drag a box to select everything it touches, and hold ⇧ to add to the selection. An open group is selected only when the box covers all of it.
- **Pan (H)** drags the canvas from anywhere, links and group headers included. ⌘-drag selects or moves things, as in Select.
- **Comment (C)** drops a note where you click, then returns to Select.

## Cards and notes

- Click a card to edit it, add a note, or open its pull request.
- Press N to add a note. Notes can become work items later.
- ⌘C copies the selection, ⌘X cuts it, and ⌘V pastes it at the cursor, inside the open group. A copy takes groups with everything in them, stickers stuck to what you copied, and the links between copied items. Paste into another group or another canvas, as often as you like; each paste is a new, separate copy. ⌘D duplicates the selection beside itself.
- Right-click empty canvas and choose **Create from link** to paste a GitHub pull request or issue, or a Jira issue, and get its card where you clicked. A link that already has a card takes you to it.
- Check **Gate** in a card's inspector to make it a gate. Gates show a diamond.
- Dashed cards are pull requests that aren't opened yet.
- A card linked to a pull request shows a checks dot (green passing, red failing, amber pending) and its changed lines. Its inspector adds the author, review requests, and when it last changed.
- An unlinked card may list possible pull requests in its inspector. Use **Link** to attach one.
- A card you finish gets a stamp. Click it to clear the stamp, along with the stamps on finished cards chained to it.

## Links

- Drag from the edge of one card to another to add a dependency.
- Right-click a link to add a card or note into it.
- A card's inspector lists what it waits on, what it unblocks, and related cards. **Add link** searches for another card to connect, and each link can be flipped or removed.
- Moving lines are dependencies that are still waiting. Still lines are satisfied.
- Dotted lines are related work that never blocks. They stay faint until you hover, hold, or select one of their cards.
- **Unblocks N** on a card counts every open card downstream of it, directly or not.

## Groups

- ⌘G groups the selection, and ⇧⌘G ungroups it. Groups can nest and span repositories.
- Double-click a group, or press Enter with one selected, to open it. Esc or a double-click on empty canvas goes back up, and the breadcrumbs jump to any level.
- An open group shows the outside work it waits on along its left side and the work waiting on it along its right.
- A group's inspector picks its arrangement: **Automatic** flows by dependency and wraps rows at about six, and **Custom** keeps cards where you put them.
- Drag a group's edge or corner to resize it, like a window. An automatic group lays its cards out to fit the new width and keeps that shape when cards come and go. A custom group keeps the room you give it, and an edge you drag inward pushes the cards it meets until they fill the group. Groups beside one that grows move out of its way.
- Dragging a card around inside a group never changes the group's size. Pull it well past the group's edge to take it out; let go short of that and it lands back inside.
- **Reflow** lays out the inside of a group, and **Tidy** lays out the current level.
- From the CLI, `orion group tidy` marks groups for the app to lay out, deepest first, and `orion canvas check` reports overlapping cards, cards outside their group, and links to missing items. The CLI never lays out groups itself, so a tidy takes effect once the app is open.

## Detail

The detail stepper beside the zoom buttons, or [ and ], folds groups into single bodies one level of nesting at a time, inner groups first. A canvas starts with every group folded and remembers the level you pick. Links between folded groups bundle into one line with a count; right-click one to remove a link inside it. Zoom only moves the view.

## Seeing what matters

- Hover a card to trace what it needs (amber), what it unlocks (teal), and what relates to it.
- Hold ⌥ to see where it's your move. Lines run from the cursor to each one, and work off screen gets a chip at the edge that jumps to it.
- Hold Ctrl to inspect. The card under the cursor opens in full with its note, and its links show at full strength.
- Double-click a card to focus on it, with what it waits on in a column on the left and what it leads to on the right. Click one of those to focus on it instead. Esc goes back.

## Stickers

Hold S to open the sticker wheel, point at a sticker, and let go. A quick tap leaves the wheel open, and 1–8 pick by number. Type or paste any emoji to stamp that instead, and right-click a slot to change it. Each canvas keeps its own wheel.

Stickers stamped on a card or group move with it. In Select, drag a sticker to move it or flick it to send it sliding. Pull one past a group's wall to pop it out. Right-click a sticker to remove it.

## Settings

Open Settings with ⌘, or the button at the bottom of the sidebar.

- **Appearance** picks the theme, the card skin, the color mode, and whether the star companion shows. Vibrant and Trading cards are the defaults. The other themes and skins are tagged Deprecated: they still work, and they'll be removed later.
- **Accessibility** picks colorblind status colors and an animation level. Animations follow your system's reduced motion setting until you choose.
- **Keyboard Shortcuts** rebinds shortcuts and flags clashes.

Every status also has its own shape, so color is never the only signal: an empty ring when ready, half full in progress, three quarters in review, a check when done, a dashed ring when deferred, and a lock when blocked.

Settings are saved in the [data folder](./data) and shared by every canvas.
