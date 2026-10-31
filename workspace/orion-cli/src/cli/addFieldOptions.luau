local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")
local appendEmptyValue = require("@root/cli/appendEmptyValue")
local fieldValues = require("@root/fieldValues")
local noteStyle = require("@root/cli/noteStyle")

-- Item fields, which cards take. Groups take their own, set with group set.
-- Changing a card can clear who, shape, color, and note with an empty value, so
-- their MCP fields accept one there.
local function addFieldOptions(parser: cli.Parser, clearing: boolean)
	local function getValues(values: { string }): { string }
		return if clearing then appendEmptyValue(values) else values
	end

	addArgument(parser, "status", "option", {
		help = "todo, active, review, blocked, deferred, or done",
		type = "enum",
		values = fieldValues.statuses,
	})
	parser:add("repo", "option", { help = "Repository it belongs to, as owner/name (empty to clear)" })
	addArgument(parser, "who", "option", {
		help = "Whose move: you, review, or ci (empty to clear)",
		type = "enum",
		values = getValues(fieldValues.who),
	})
	addArgument(parser, "note", "option", {
		help = "Free-form note (empty to clear)",
		mcp = {
			description = if clearing
				then `Replaces the whole note, and empty clears it. {noteStyle}`
				else `Free-form note. {noteStyle}`,
		},
	})
	addArgument(parser, "shape", "option", {
		help = "How a component is drawn: service, store, actor, external, interface, process, or queue (empty to clear)",
		type = "enum",
		values = getValues(fieldValues.shapes),
	})
	addArgument(parser, "color", "option", {
		help = "A component's tint: teal, blue, purple, amber, rose, green, or slate (empty to clear)",
		type = "enum",
		values = getValues(fieldValues.colors),
	})
	addArgument(parser, "kind", "option", {
		help = "step; gate for one that's done once everything it waits on is; "
			.. "or component for a part of a system, not work. A note given a kind becomes a work item",
		type = "enum",
		values = fieldValues.kinds,
	})
end

return addFieldOptions
