--[[
	Every usage event Orion may send once someone opts in, and the properties
	each one carries, as data. `lute run generate docs` publishes the list from
	here, and `lute run generate telemetry` exports it as the JSON the
	telemetry backend checks batches against, so an event missing here never
	reaches PostHog.

	Properties hold counts, durations, and the names of Orion's own commands
	and features, never titles, notes, refs, repository names, URLs, file
	paths, or option values. The backend adds the build version, commit, and
	channel, and the session id, to every event itself.
]]

export type PropertyType = "string" | "number" | "integer" | "boolean"

export type Property = {
	name: string,
	type: PropertyType,
	help: string,
	-- The only values a string property takes, when it's one of a known set.
	values: { string }?,
}

export type Source = "app" | "cli" | "mcp"

export type Family = {
	name: string,
	help: string,
}

export type Event = {
	name: string,
	family: string,
	sources: { Source },
	help: string,
	properties: { Property },
}

-- The sections the event list is published in, in reading order.
local FAMILIES: { Family } = {
	{
		name = "Consent",
		help = "Sent once, when someone opts in. Opting out sends nothing.",
	},
	{
		name = "Performance",
		help = "How long Orion takes to draw, lay out, and save, so slow spots can be found and tracked across releases.",
	},
	{
		name = "Canvas shape",
		help = "How big canvases get, so performance can be compared on canvases of the same size.",
	},
	{
		name = "Feature use",
		help = "Which parts of the app get used, counted per session.",
	},
	{
		name = "Agent use",
		help = "Which CLI commands and MCP tools run, so the agent surface can be shaped around real use.",
	},
}

local function count(name: string, help: string): Property
	return { name = name, type = "integer", help = help }
end

local function duration(name: string, help: string): Property
	return { name = name, type = "number", help = help }
end

local EVENTS: { Event } = {
	{
		name = "telemetry_opted_in",
		family = "Consent",
		sources = { "app", "cli" },
		help = "Someone chose to share usage data, in the app's dialog or its settings, or with the CLI.",
		properties = {
			{
				name = "surface",
				type = "string",
				help = "Where the choice was made.",
				values = { "app", "cli" },
			},
		},
	},
	{
		name = "app_started",
		family = "Performance",
		sources = { "app" },
		help = "The app opened and drew its first canvas.",
		properties = {
			duration("startup_ms", "Milliseconds from launch to the first drawn canvas."),
			count("card_count", "Cards on the canvas it opened to."),
		},
	},
	{
		name = "performance_summarized",
		family = "Performance",
		sources = { "app", "cli" },
		help = "A summary of one timing over a session of the app or of `orion server start`, sent when "
			.. "the session ends.",
		properties = {
			{
				name = "metric",
				type = "string",
				help = "What was timed: a pan or zoom frame, a `derive` or `layout` pass, or a flush by "
					.. "`orion server start`.",
				values = { "pan_frame", "zoom_frame", "derive", "layout", "server_flush" },
			},
			count("sample_count", "How many times it was measured."),
			duration("p50_ms", "The median, in milliseconds."),
			duration("p95_ms", "The 95th percentile, in milliseconds."),
			duration("max_ms", "The slowest, in milliseconds."),
			count("card_count", "Cards on the canvas when the summary was taken."),
			count("group_count", "Groups on the canvas when the summary was taken."),
		},
	},
	{
		name = "canvas_measured",
		family = "Canvas shape",
		sources = { "app" },
		help = "The size of a canvas, taken when it opens and at most once a day after that.",
		properties = {
			count("card_count", "Cards."),
			count("group_count", "Groups."),
			count("nesting_depth", "The most groups nested inside one another."),
			count("link_count", "Dependency links."),
			count("note_count", "Notes."),
			count("media_count", "Images and other media."),
			count("sticker_count", "Stickers."),
			count("comment_count", "Comments."),
		},
	},
	{
		name = "features_used",
		family = "Feature use",
		sources = { "app" },
		help = "How much each feature was used during a session, sent when the session ends.",
		properties = {
			duration("session_ms", "How long the session lasted, in milliseconds."),
			duration("select_tool_ms", "Milliseconds with the Select tool active."),
			duration("pan_tool_ms", "Milliseconds with the Pan tool active."),
			duration("comment_tool_ms", "Milliseconds with the Comment tool active."),
			duration("sticker_tool_ms", "Milliseconds with the Sticker tool active."),
			count("stickers_placed", "Stickers placed."),
			count("comments_left", "Comments left."),
			count("groups_created", "Groups created."),
			count("tidies", "Times the canvas was tidied."),
			count("pastes", "Pastes onto the canvas."),
		},
	},
	{
		name = "cli_command_ran",
		family = "Agent use",
		sources = { "cli" },
		help = "An `orion` command finished.",
		properties = {
			{
				name = "command",
				type = "string",
				help = "The command's name, such as `card set`. Never its arguments.",
			},
			{
				name = "flags",
				type = "string",
				help = "The names of the flags it was given, sorted and comma-separated, such as `--json,--where`. "
					.. "Never their values.",
			},
			duration("duration_ms", "How long it ran, in milliseconds."),
			{ name = "exit_code", type = "integer", help = "The code it exited with." },
			{
				name = "interactive",
				type = "boolean",
				help = "Whether a terminal was attached, which tells a person typing from an agent running it.",
			},
		},
	},
	{
		name = "mcp_tool_called",
		family = "Agent use",
		sources = { "mcp" },
		help = "A tool served by `orion mcp start` finished.",
		properties = {
			{
				name = "tool",
				type = "string",
				help = "The tool's name, such as `orion_card_set`. Never its arguments.",
			},
			{
				name = "client",
				type = "string",
				help = "The name the MCP client gave when it connected, such as `claude-code`.",
			},
			duration("duration_ms", "How long it ran, in milliseconds."),
			{ name = "failed", type = "boolean", help = "Whether the call failed." },
		},
	},
}

local eventsByName: { [string]: Event } = {}

for _, event in EVENTS do
	eventsByName[event.name] = event
end

return table.freeze({
	families = table.freeze(FAMILIES),
	list = table.freeze(EVENTS),
	byName = table.freeze(eventsByName),
})
