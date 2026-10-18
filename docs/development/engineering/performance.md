# Performance

The target is at least 1,000 cards with nested groups and dense links, as the [decisions](/development/decisions) set it. Most of the work below keeps the canvas responsive at that size: it redraws only what changed, animates only what someone can see, and draws only the cards near the view. A perf harness checks each pull request against its base so regressions show up before they merge.

## Animate less

Looping motion on the canvas kept WebKit's GPU process near 40% CPU while the app sat idle. Each frame of a moving arrow or glow repainted everything under it. [The first pass](https://github.com/vocksel/orion/pull/29) changed the loops in three ways:

- Arrows, the active glow, and the attention line step at 15 frames per second through `steps()`. WebKit schedules each step rather than repainting on every display frame.
- The glow pulses every 3.2 seconds and rests for the second half of each cycle, so half of each cycle paints nothing.
- Loops stop below 0.6 zoom, while the window is in the background, on arrows a hover trace dims, and on arrows off screen. Each arrow checks its curve against the viewport and redraws only when it crosses the edge.

A [later pass](https://github.com/vocksel/orion/pull/171), merged once the perf harness was in place, kept the glow in `box-shadow`. A composited animation inside the zoomed canvas makes WebKit rasterize the whole canvas as one layer and blur it.

## Redraw only what changed

Before [#124](https://github.com/vocksel/orion/pull/124), hovering, selecting, or dragging one card re-rendered every card and arrow. Now each card reads its status, leverage, sources, trace role, and group stats from Jotai atoms through its own selector. Unchanged nodes and edges keep the previous render's objects, and the card and edge components are memoized. React Flow re-renders every node wrapper whenever the canvas passes new handlers, so the memoization is what stops that from reaching the cards.

Hover dimming is a class on the canvas, not a re-render of each card. The hover lift only changes the card under the pointer.

## Draw only the cards near the view

Cards far from the view no longer mount their bodies ([#345](https://github.com/vocksel/orion/pull/345)). Each card keeps its React Flow node, size, and handles, so edges, fitting, and measurement behave as before. Hiding the node would drop its edges, since React Flow draws an edge only after both ends have measured their handles.

- The margin is 400 screen pixels beyond the visible canvas, scaled by zoom. A card that leaves the margin loses its body at once.
- Cards that come into view get their bodies in batches of 40 per frame, nearest the view's center first. A burst, such as a load, a canvas switch, or unfolding a group, spreads over several frames.
- The order is sorted again once the view has been still for 150 milliseconds.
- Groups, images, and ghost cards always draw. Groups are few, and their frames are needed for layout.

This is the batching the [decisions](/development/decisions) describe: the cards on screen matter first.

## Compact cards at far zoom

Below 0.3 times zoom, cards draw in a compact form and related links stop drawing ([#332](https://github.com/vocksel/orion/pull/332)). The breakpoint is the same one the old card switch used. The debug bar shows the zoom and lets the breakpoint be tuned live.

Two choices keep this cheap:

- The canvas carries a `data-zoom` attribute, set outside React, instead of a class. React rewrites the canvas's class whenever its tool or mode changes, which would drop the class. Crossing the breakpoint updates the attribute and doesn't re-render every card.
- Only hovered or selected cards subscribe to zoom, so their detail tag keeps its full form.

Compact cards also drop animations and blurred shadows. This sits in tension with [charter](/development/charter) principle 6, which says zoom only moves the camera. The [decisions](/development/decisions) list that as an open question to reconcile.

Folded groups show a faded preview of what they hold ([#339](https://github.com/vocksel/orion/pull/339)). Each group draws at most 80 items, nearest first, so a large group stays cheap. Previews are computed once in the canvas and handed to each folded group, which redraws only when its own contents change. Zoom never recomputes them.

## Cut per-frame paint work

A [change in review](https://github.com/vocksel/orion/pull/394) addresses work that ran on every frame even with nothing moving. Panning an open group had become slow after the companion and the done shimmer landed.

- The companion's tethers draw in a 160-pixel layer that moves with its body. Its hint width is read through a `ResizeObserver` instead of a forced layout on every frame.
- The done shimmer steps at 15 frames per second and pauses while the canvas moves, sits in the background, or is zoomed out.
- The running-check spinner turns by sliding the dash of a circle, not by a transform. A transform gave the spinner its own layer, and WebKit then rasterized the whole zoomed canvas as one layer. Sliding the dash repaints only the spinner.
- Arrows step at 10 frames per second, since they run long across the canvas and repaint more than any other loop.

On a group of 29 pull request cards, in Chromium at 4x CPU throttling, raster time fell from about 1,550 ms to about 690 ms. Main-thread time didn't improve, because the companion still runs a full style and layout pass each frame. The pull request notes that a check in the desktop app is still needed, since headless WebKit doesn't drop frames on the machine used for testing.

## Measuring it

The perf harness is `npm run perf` in `app/`. It compares this checkout against `origin/main`, or another base passed with `--base`, and writes a Markdown report.

- **Data benchmarks** run over generated canvases of 1,000 and 5,000 cards. They cover the functions that derive work, trace links, merge documents, snap drags, and reflow groups, using Vitest's bench API ([#172](https://github.com/vocksel/orion/pull/172)).
- **Render runs** drive a perf story in headless Chromium at 2x scale. The story pans, pinch-zooms, hovers across cards, and drags one. A React Profiler and a Chromium trace report commits, frames, main-thread time, style and layout time, and raster time.
- **The pull request comment** is written by CI on every pull request that touches `app/`. It replaces its previous comment on each run. The verdict comes first, followed by changes beyond noise, worst first. Full tables sit in collapsed sections ([#181](https://github.com/vocksel/orion/pull/181)).

Noise was the main problem with the comment. One change to the palette had reported `needsAttention` 60% slower. [Noise is now judged by spread](https://github.com/vocksel/orion/pull/193). Benchmarks run in rounds, with each side going first in alternate rounds, because one process per side could land in a slower JIT state. A change counts only when it is larger than the greater of 10% and the two sides' spreads added together. A side's spread is the difference between its slowest and fastest run, divided by that side's median.

Where the runs happen matters as well:

- Perf runs use a dedicated CI runner with exclusive cores. Each exclusive job runs alone on its cores, so other jobs don't skew the timings ([#273](https://github.com/vocksel/orion/pull/273)). The job starts in rank order, one at a time.
- Draft pull requests skip perf. A draft that is pushed to repeatedly would otherwise back up the queue. Perf runs when a pull request is opened ready, gets a push while ready, or is marked ready for review ([#274](https://github.com/vocksel/orion/pull/274)).
- The base side is the merge commit's first parent, `HEAD^1`. Before this, the base was fetched when the job started, and the base branch could move while the job waited for a runner. The base app then ran with a harness it didn't match ([#290](https://github.com/vocksel/orion/pull/290)).

To check before pushing, run `npm run perf` on a quiet machine, one run at a time. It takes several minutes, and the numbers only mean something when nothing else is competing for the CPU.
