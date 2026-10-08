local json = require("@std/json")

local appendFlag = require("@root/cli/mcp/catalog/appendFlag")
local appendOption = require("@root/cli/mcp/catalog/appendOption")
local getRequiredString = require("@root/cli/mcp/catalog/getRequiredString")
local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

local VIEWS = { "list", "ready", "groups", "matches", "show" }

-- Each view is its own read command, and only some take an id or a group.
local function build(arguments: json.Object): { string }
	local view = getRequiredString(arguments, "view")
	local argv = { view }

	if view == "show" then
		table.insert(argv, getRequiredString(arguments, "id"))
	elseif view == "list" then
		appendOption(argv, "group", arguments.group)
		appendFlag(argv, "all", arguments.all)
	end

	appendOption(argv, "workspace", arguments.workspace)
	table.insert(argv, "--json")
	return argv
end

local tool: Tool = {
	name = "orion_inspect",
	description = "Read the canvas: list items, ready work, groups, PR matches, or one item/group.",
	annotations = { readOnlyHint = true },
	command = {},
	fields = {
		{
			name = "view",
			kind = "enum",
			required = true,
			values = VIEWS,
			at = "positional",
		},
		workspaceField,
		{
			name = "id",
			kind = "id",
			description = "Required for show.",
			at = "option",
		},
		{
			name = "group",
			kind = "id",
			description = "Limit list to descendants of a group.",
			at = "option",
		},
		{
			name = "all",
			kind = "boolean",
			description = "Include completed items in list.",
			at = "flag",
		},
	},
	build = build,
}

return tool
