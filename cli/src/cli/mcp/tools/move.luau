local json = require("@std/json")

local appendOption = require("@root/cli/mcp/catalog/appendOption")
local getRequiredString = require("@root/cli/mcp/catalog/getRequiredString")
local getStringField = require("@root/getStringField")
local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

-- Without a group, the item moves to the top level.
local function build(arguments: json.Object): { string }
	local argv = { "move", getRequiredString(arguments, "id") }
	local group = getStringField(arguments.group)

	if group then
		table.insert(argv, "--to")
		table.insert(argv, group)
	else
		table.insert(argv, "--top")
	end

	appendOption(argv, "workspace", arguments.workspace)
	return argv
end

local tool: Tool = {
	name = "orion_move",
	description = "Move an item into a group or to the top level.",
	command = { "move" },
	fields = {
		{ name = "id", kind = "id", required = true, at = "positional" },
		workspaceField,
		{ name = "group", kind = "id", at = "option" },
	},
	build = build,
}

return tool
