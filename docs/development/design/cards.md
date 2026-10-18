# Card skins

A card is a skin over a card's data. The same work item can be drawn as a classic off-white card, a plain card, or a trading card, and switching skins never changes what's stored. Each one has to stay readable at a glance: effects like holo foil never sit on text.

The cards below are the app's own components, rendered live from its Storybook. Each one opens in Storybook, where you can change its fields.

## Trading

The trading card gives every card its own art, generated from the card so the same card always gets the same picture.

<Story id="canvas-cards-and-edges-tradingcard--playground" title="A pull request in review" :height="440" />

<Story id="canvas-cards-and-edges-tradingcard--gate" title="A gate waiting on two cards" :height="440" />

<Story id="canvas-cards-and-edges-tradingcard--note" title="A note" :height="440" />

Zoomed far out, the canvas swaps each card for a compact tag.

<Story id="canvas-cards-and-edges-tradingcard--far-zoom" title="The far-zoom tag" :height="240" />

## Classic

<Story id="canvas-cards-and-edges-classiccard--active-pull-request" title="A pull request in progress" :height="160" />

## Plain

<Story id="canvas-cards-and-edges-plaincard--active-pull-request" title="A pull request in progress" :height="160" />
