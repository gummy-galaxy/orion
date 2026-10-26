--[[
	The canvas geometry the CLI and the app share, and the limits the app checks
	before the CLI does. The app imports these from
	`workspace/orion-app/src/geometry.ts`, which `lute run geometry` writes from
	this table. Change a value here, run that from the repository root, and
	commit both files; CI fails when they disagree.
]]
return table.freeze({
	-- A card's size in the classic skin. Notes and components grow taller to
	-- show their text.
	TASK_WIDTH = 216,
	TASK_HEIGHT = 72,
	-- Notes and components stop growing here, so one long paragraph can't
	-- swallow a group.
	TASK_MAX_HEIGHT = 320,
	-- Room between a group's edges and its cards, on the sides and below.
	GROUP_PADDING = 32,
	-- A group's title row, above its cards.
	GROUP_HEADER_HEIGHT = 78,
	-- The band a group's header takes under its title row, which pushes its
	-- cards down by the same amount.
	GROUP_HEADER_BAND = 112,
	-- The size a group takes before it has a stored one.
	GROUP_SIZE = table.freeze({ width = 320, height = 200 }),
	-- The size a new image starts at.
	IMAGE_SIZE = table.freeze({ width = 256, height = 256 }),
	-- Space between neighbors inside groups and at the top level: `x` between
	-- the layers of a linked chain, `y` between siblings stacked in one layer,
	-- and `component` between pieces with no link between them.
	GAP = table.freeze({
		inner = table.freeze({ x = 56, y = 24, component = 32 }),
		top = table.freeze({ x = 120, y = 72, component = 96 }),
	}),
	-- How a card lays out its text, as the app's stylesheet sets it. Sizes are
	-- in pixels and line heights are multiples of the size. The app measures
	-- text with these; the CLI estimates it.
	CARD_TEXT = table.freeze({
		label = table.freeze({ size = 12.5, lineHeight = 1.25 }),
		note = table.freeze({ size = 12, lineHeight = 1.3 }),
		description = table.freeze({ size = 11.5, lineHeight = 1.25 }),
		-- Card padding above and below, the meta row, and the gap after it.
		chrome = 36,
		-- Room the source badge keeps on the right of a line, plus the card's
		-- side padding.
		sides = table.freeze({ note = 49, component = 46 }),
		-- The gap between a component's label and its description.
		descriptionGap = 3,
		-- Extra room some component shapes need around their text.
		shapeRoom = table.freeze({
			store = table.freeze({ x = 0, y = 12 }),
			actor = table.freeze({ x = 12, y = 0 }),
			interface = table.freeze({ x = 0, y = 8 }),
			process = table.freeze({ x = 28, y = 0 }),
			queue = table.freeze({ x = 8, y = 8 }),
		}),
		-- An average character's width as a share of the font size, for
		-- estimating text without measuring it.
		characterWidth = 0.55,
		-- Slack added to a measured height, which then rounds up to a multiple
		-- of `step`, so rounding and a web font that measures slightly wider
		-- than its fallback still fit.
		slack = 4,
		step = 4,
	}),
	-- The longest header a group or canvas takes, in characters.
	HEADER_MAX_LENGTH = 2000,
	-- The largest image the canvas takes, in bytes.
	IMAGE_MAX_BYTES = 5 * 1024 * 1024,
})
