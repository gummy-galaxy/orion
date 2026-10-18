# Design

Design pages cover how Orion looks and feels: its visual direction, how the canvas responds to input, and studies of ideas before they're built.

A study explores an idea and recommends what to keep. It isn't a promise that the idea ships. Once a direction is chosen, the call moves into [`DECISIONS.md`](https://github.com/vocksel/orion/blob/main/DECISIONS.md), and the [Guide](/guide/getting-started) describes what shipped.

- [Card skins](./cards) shows each way a card can be drawn.

## Live components

Components on these pages are the app's own, embedded from its [Storybook](https://main--6acd7d37ef902af0d3845e73.chromatic.com). The Storybook workflow publishes it to Chromatic whenever a change to the app lands on `main`, so the pages always show what `main` draws. To embed a story, use its id from the Storybook URL:

```md
<Story id="canvas-cards-and-edges-tradingcard--playground" title="A pull request in review" :height="440" />
```

Locally, `npm run dev` in `docs/` embeds from `npm run storybook` in `app/` instead, so stories you're editing show up as you change them.
