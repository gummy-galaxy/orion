# Orion app

The canvas, built with React, React Flow, and Jotai. [`CONTRIBUTING.md`](../CONTRIBUTING.md) covers running it, Storybook, and the perf harness.

Modules in `src/` hold logic and are tested beside themselves as `<module>.test.ts`. Each React component has its own file in `src/components/`, with its story beside it.

## Code layout

Data and state:

- `vite.config.ts`: starts `orion server start` for development and proxies its API.
- `src/persist.ts`: loading, saving, reacting to other writers, reporting focus, and receiving reveals.
- `src/reveal.ts`: the group, detail level, and camera that `orion reveal` uses to show cards.
- `src/state.ts`: the Jotai atoms the canvas shares.
- `src/model.ts`: node and link types, grouping, ungrouping, and fitting groups to their contents.
- `src/derive.ts`: status, leverage, group progress, and hover tracing.
- `src/settings.ts` and `src/keybindings.ts`: preferences, and each shortcut with its default.

Layout and interaction:

- `src/layout.ts`: laying out one group or the top level with ELK, leaving custom groups alone.
- `src/pushAside.ts`: moving neighbors out of the way when a group grows.
- `src/snap.ts`, `src/useNodeSnapping.ts`, and `components/SnapGuides.tsx`: drag geometry and alignment guides.
- `src/escape.ts`: dragging work out of its group, and the group a drop lands in.
- `src/cardDraw.ts`, `src/useDrawnCards.ts`, and `components/CardSlot.tsx`: which cards mount their bodies. Cards far from the view keep their node and size but skip the body.
- `src/useInspecting.ts` and `components/PeekCard.tsx`: holding Ctrl to inspect a card.

Components:

- `components/App.tsx` and `components/Canvas.tsx`: the app shell, the canvas, detail levels, and drill-in.
- `components/TaskView.tsx` and `components/ClusterView.tsx`: cards and group frames.
- `components/FocusView.tsx`: the columns and lines around a focused card.
- `components/CurveEdge.tsx`: arrows that loop around cards when they run backward.
- `components/ComponentCard.tsx`, `components/ShapeOutline.tsx`, and `src/cardHeight.ts`: system diagram components, drawn the same in every skin with their shape's outline, and the heights notes and components grow to from their text. `components/ComponentInspector.tsx`, `components/LinkInspector.tsx`, and `components/TintSelect.tsx` edit components, link labels, and tints.
- `components/TaskInspector.tsx`, `components/NoteBody.tsx`, and `components/LinkSection.tsx`: a card's details, note, and links in the inspector.
- `components/Timeline.tsx`, `src/useCardLog.ts`, and `src/log.ts`: a card's timeline, its entries from the canvas log newest first, read from `GET /api/log` and refetched when `orion:log` announces an append.
- `components/Markdown.tsx`: the shared Markdown renderer, with no raw HTML.
- `components/Sidebar.tsx`, `components/ContextMenu.tsx`, and `components/Palette.tsx`: the group list, right-click menu, and ⌘K search.
- `components/Settings.tsx`: the settings dialog and its pages.
- `components/SourceBadges.tsx`: source favicons on cards and groups, and the links behind them.
- `components/Companion.tsx` and `src/companion.ts`: the star companion that perches on the card nearest the pointer.

Skins:

- `src/skins.ts` lists the card skins. Each has a component, such as `components/TradingCard.tsx`, and a stylesheet in `src/skins/`.
